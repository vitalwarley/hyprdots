#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
Structural upsert for ~/life/notes/journal/ai/<date>.md.

Replaces the prior whole-file Haiku rewrite. Bash gathers metadata and
invokes this script; the script owns parsing/splice/recompute/render and
the atomic write. The model only produces the new block's narrative,
bullets, tipo tags, output, and (when sessions >= 3) an optional Sinais
update — never the file itself. This eliminates probabilistic block-drop
and field drift.

Tripwire: post-render block count must never shrink. Atomic write via
tmpfile + rename means a Python crash leaves the existing file intact.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

MACEIO_TZ = timezone(timedelta(hours=-3))
DAYS_PT = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
JOURNAL_ROOT = Path.home() / "life" / "notes" / "journal" / "ai"
SINAIS_PLACEHOLDER = "(será preenchido quando houver ≥3 sessões no dia)"

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
MARKER_RE = re.compile(r"^<!-- session: ([0-9a-fA-F-]+) -->\s*$", re.MULTILINE)
HEADER_RE = re.compile(
    r"^### (\d{2}:\d{2}) → (\d{2}:\d{2}) · (\S+) · (\S+) · #source/(\S+)\s*$"
)
DURATION_RE = re.compile(r"^(?:(\d+)h(\d{2})|(\d+)min)$")
TIPO_RE = re.compile(r"^\*\*tipo\*\*:\s*(.+?)\s*$", re.MULTILINE)


@dataclass
class Block:
    session_id: str
    start_dt: datetime
    end_dt: datetime
    duration_min: int
    project: str
    source: str
    raw_text: str

    def tipo_list(self) -> list[str]:
        m = TIPO_RE.search(self.raw_text)
        if not m:
            return []
        return [t.strip() for t in re.split(r"[,·]", m.group(1)) if t.strip()]

    def output_lines(self) -> list[str]:
        m = re.search(r"\*\*Output\*\*:\s*\n((?:- .*\n?)+)", self.raw_text)
        if not m:
            return []
        return [
            line[2:].strip()
            for line in m.group(1).splitlines()
            if line.startswith("- ")
        ]


@dataclass
class JournalDoc:
    date_str: str
    day_name_pt: str
    sessions: int
    active_time: str
    tags: list[str]
    blocks: list[Block]
    sinais_text: str


def escape_obsidian_html(text: str) -> str:
    """Backslash-escape `<` and `>` outside backtick spans.

    Obsidian parses bare `<token>` sequences as HTML and hides them in
    Live Preview / Reading view. Markdown backslash-escape (`\\<`, `\\>`)
    renders as literal `<` and `>` while preventing the HTML branch.
    Content inside backticks is already protected by code-span semantics
    and is left untouched (escaping would render the backslashes verbatim).
    """
    out: list[str] = []
    in_code = False
    i, n = 0, len(text)
    while i < n:
        if text[i] == "`":
            start = i
            while i < n and text[i] == "`":
                i += 1
            out.append(text[start:i])
            in_code = not in_code
            continue
        if not in_code and text[i] in "<>":
            out.append("\\" + text[i])
        else:
            out.append(text[i])
        i += 1
    return "".join(out)


def fmt_duration(minutes: int) -> str:
    if minutes < 60:
        return f"{minutes}min"
    h, m = divmod(minutes, 60)
    return f"{h}h{m:02d}"


def to_maceio(iso: str) -> datetime:
    if iso.endswith("Z"):
        iso = iso[:-1] + "+00:00"
    return datetime.fromisoformat(iso).astimezone(MACEIO_TZ)


def transcript_first_last(
    transcript: Path, jsonl_end: int | None
) -> tuple[datetime, datetime]:
    first_ts = last_ts = None
    with transcript.open() as fh:
        for i, line in enumerate(fh, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = obj.get("timestamp")
            if not ts:
                continue
            if first_ts is None:
                first_ts = ts
            last_ts = ts
            if jsonl_end is not None and i >= jsonl_end:
                break
    if not first_ts or not last_ts:
        raise SystemExit(f"no timestamps in {transcript}")
    return to_maceio(first_ts), to_maceio(last_ts)


def parse_journal(path: Path) -> JournalDoc | None:
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8")
    fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not fm_match:
        return None
    fm: dict[str, str] = {}
    for line in fm_match.group(1).splitlines():
        if ":" in line:
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    body = text[fm_match.end():]
    h1 = re.search(r"^#\s+(\d{4}-\d{2}-\d{2})\s*\(([^)]+)\)", body, re.MULTILINE)
    date_str = h1.group(1) if h1 else fm.get("date", "")
    day_name = h1.group(2) if h1 else ""
    blocks = parse_blocks(body, date_str)
    sinais = extract_section(body, "Sinais").strip() or SINAIS_PLACEHOLDER
    tags_raw = fm.get("tags", "[ai-journal]")
    tags = [t.strip() for t in tags_raw.strip("[]").split(",") if t.strip()]
    return JournalDoc(
        date_str=date_str,
        day_name_pt=day_name,
        sessions=int(fm.get("sessions", "0") or "0"),
        active_time=fm.get("active_time", "0min"),
        tags=tags or ["ai-journal"],
        blocks=blocks,
        sinais_text=sinais,
    )


def parse_blocks(body: str, date_str: str) -> list[Block]:
    timeline_match = re.search(
        r"^## Timeline\s*\n(.*?)(?=^## )", body, re.MULTILINE | re.DOTALL
    )
    if not timeline_match:
        return []
    timeline = timeline_match.group(1)
    chunks = re.split(r"(?m)(?=^### )", timeline)
    out: list[Block] = []
    for chunk in chunks:
        if not chunk.startswith("### "):
            continue
        chunk = chunk.rstrip()
        first_line = chunk.splitlines()[0]
        hm = HEADER_RE.match(first_line)
        marker = MARKER_RE.search(chunk)
        if not hm or not marker:
            continue
        start_hm, end_hm, dur_str, project, source = hm.groups()
        dm = DURATION_RE.match(dur_str)
        if not dm:
            continue
        if dm.group(3):
            duration_min = int(dm.group(3))
        else:
            duration_min = int(dm.group(1)) * 60 + int(dm.group(2))
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            d = datetime.now(MACEIO_TZ).date()
        start_dt = datetime.combine(
            d, datetime.strptime(start_hm, "%H:%M").time(), tzinfo=MACEIO_TZ
        )
        end_dt = datetime.combine(
            d, datetime.strptime(end_hm, "%H:%M").time(), tzinfo=MACEIO_TZ
        )
        out.append(
            Block(
                session_id=marker.group(1),
                start_dt=start_dt,
                end_dt=end_dt,
                duration_min=duration_min,
                project=project,
                source=source,
                raw_text=chunk,
            )
        )
    return out


def extract_section(body: str, name: str) -> str:
    m = re.search(
        rf"^## {re.escape(name)}\s*\n(.*?)(?=^## |\Z)",
        body,
        re.MULTILINE | re.DOTALL,
    )
    return m.group(1) if m else ""


def render_block(
    b: Block,
    narrative: str,
    bullets: list[str],
    tipo: list[str],
    output: list[str],
    diary_link: str,
) -> str:
    header = (
        f"### {b.start_dt.strftime('%H:%M')} → {b.end_dt.strftime('%H:%M')} "
        f"· {fmt_duration(b.duration_min)} · {b.project} · #source/{b.source}"
    )
    tipo_line = "**tipo**: " + ", ".join(tipo) if tipo else "**tipo**:"
    diary_line = f"[diary]({diary_link})"
    marker_line = f"<!-- session: {b.session_id} -->"
    lines = [header, tipo_line, diary_line, marker_line, "", narrative.strip(), ""]
    for bullet in bullets:
        text = bullet.strip().lstrip("- ").strip()
        if text:
            lines.append(f"- {text}")
    if output:
        lines.append("")
        lines.append("**Output**:")
        for o in output:
            text = o.strip().lstrip("- ").strip()
            if text:
                lines.append(f"- {text}")
    return "\n".join(lines)


def render_agregados(blocks: list[Block]) -> str:
    tipo_count: dict[str, int] = {}
    proj_seen: list[str] = []
    src_count: dict[str, int] = {}
    for b in blocks:
        for t in b.tipo_list():
            tipo_count[t] = tipo_count.get(t, 0) + 1
        if b.project not in proj_seen:
            proj_seen.append(b.project)
        src_count[b.source] = src_count.get(b.source, 0) + 1
    tipos = " · ".join(f"{k}({v})" for k, v in tipo_count.items()) or "—"
    projetos = ", ".join(proj_seen) or "—"
    fontes = ", ".join(f"{k}({v})" for k, v in src_count.items()) or "—"
    out_lines: list[str] = []
    for b in blocks:
        out_lines.extend(b.output_lines())
    output_summary = "; ".join(out_lines) if out_lines else "—"
    return (
        "## Agregados\n\n"
        f"- **Tipos**: {tipos}\n"
        f"- **Projetos**: {projetos}\n"
        f"- **Fontes**: {fontes}\n"
        f"- **Output**: {output_summary}\n"
    )


def render_journal(doc: JournalDoc) -> str:
    blocks_str = "\n\n".join(b.raw_text for b in doc.blocks)
    return (
        "---\n"
        f"date: {doc.date_str}\n"
        f"sessions: {doc.sessions}\n"
        f"active_time: {doc.active_time}\n"
        f"tags: [{', '.join(doc.tags)}]\n"
        "---\n\n"
        f"# {doc.date_str} ({doc.day_name_pt})\n\n"
        "## Timeline\n\n"
        f"{blocks_str}\n\n"
        f"{render_agregados(doc.blocks)}\n"
        "## Sinais\n\n"
        f"{doc.sinais_text.rstrip()}\n"
    )


def splice(doc: JournalDoc, new_block: Block) -> str:
    op = "insert"
    for i, b in enumerate(doc.blocks):
        if b.session_id == new_block.session_id:
            doc.blocks[i] = new_block
            op = "replace"
            break
    else:
        doc.blocks.append(new_block)
    doc.blocks.sort(key=lambda b: b.start_dt)
    return op


MODEL_TEMPLATE = """You are summarizing one Claude Code / Claudian / Cursor session into JSON.

Output STRICT JSON matching this exact shape — no markdown, no prose, no fences:
{{
  "narrative": "<2-4 sentence Portuguese paragraph paraphrasing the session>",
  "bullets": ["<bullet 1>", "<bullet 2>", "..."],
  "tipo": ["<tag1>", "<tag2>"],
  "output": ["<concrete artifact 1>", "..."]{sinais_hint}
}}

Constraints:
- 5-10 bullets, concise; preserve commit hashes / PR numbers / file paths / decisions verbatim.
- 1-3 lowercase tipo tags. Examples: refactor, debug, meta-tooling, feature, planning, learning, review, performance, diagnostic, infra, docs, spec.
- "output" lists concrete artifacts (commits, PRs, files, prompts). Empty array if none.
- Portuguese for narrative + bullets. Match vault tone: neutral technical language, no marketing-speak ("Key Insight", "Novel", etc).
{sinais_rule}

Session metadata (context — do not echo):
- session_id: {session_id}
- date: {date} ({day_name})
- start: {start_hm} (UTC-3)  end: {end_hm}  duration: {duration}
- project: {project}  source: {source}

Diary content (your only source for the bullets):
<diary>
{diary_text}
</diary>
{sinais_context}
Respond with ONLY the JSON object. The first character of your output must be `{{` and the last must be `}}`."""


def call_model(
    metadata: dict,
    diary_text: str,
    request_sinais: bool,
    current_sinais: str,
) -> dict:
    if request_sinais:
        sinais_hint = (
            ',\n  "sinais": "<1-3 short markdown bullets joined by \\n describing intra-day pattern, '
            'or null to preserve existing>"'
        )
        sinais_rule = (
            "- Sinais: when sessions >= 3 and a clear pattern emerges (recurring tipo, "
            "time-of-day shift, project switching cadence, energy drop), produce a fresh "
            "Sinais value. Otherwise set `sinais` to null to preserve the current content. "
            "Format: 1-3 markdown bullets joined by `\\n`, no `## Sinais` header."
        )
        sinais_context = (
            f"\nCurrent Sinais content:\n<sinais>\n{current_sinais}\n</sinais>\n"
        )
    else:
        sinais_hint = ""
        sinais_rule = "- Do NOT include a `sinais` field — sessions count after upsert is < 3."
        sinais_context = ""

    prompt = MODEL_TEMPLATE.format(
        sinais_hint=sinais_hint,
        sinais_rule=sinais_rule,
        sinais_context=sinais_context,
        diary_text=diary_text,
        **metadata,
    )

    cmd = [
        "claude",
        "--model", "claude-haiku-4-5",
        "--max-turns", "1",
        "--permission-mode", "bypassPermissions",
        "-p",
    ]
    proc = subprocess.run(
        cmd,
        input=prompt,
        capture_output=True,
        text=True,
        cwd="/tmp",
        timeout=180,
    )
    if proc.returncode != 0:
        raise SystemExit(
            f"claude -p failed (rc={proc.returncode}): {proc.stderr[:500]}"
        )
    return parse_json_response(proc.stdout)


def parse_json_response(raw: str) -> dict:
    raw = raw.strip()
    if raw.startswith("```"):
        lines = raw.split("\n")
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        raw = "\n".join(lines).strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise SystemExit(f"model response not valid JSON: {e}\n--- raw ---\n{raw[:1000]}")


def extract_session_id(diary_path: Path) -> str:
    text = diary_path.read_text(encoding="utf-8")
    m = re.search(r"^<!-- Session ID: (\S+) -->", text, re.MULTILINE)
    if m:
        return m.group(1).rstrip("-")
    m = re.search(r"^session_id:\s*(\S+)", text, re.MULTILINE)
    if not m:
        raise SystemExit(f"no session_id in {diary_path}")
    return m.group(1)


def extract_jsonl_end(diary_path: Path) -> int | None:
    text = diary_path.read_text(encoding="utf-8")
    matches = re.findall(r"<!-- JSONL lines: \d+-(\d+) -->", text)
    return int(matches[-1]) if matches else None


def detect_source(transcript: Path, cwd: str | None, diary_path: Path) -> str:
    s = str(transcript)
    if "/.cursor/projects/" in s:
        return "cursor"
    if "/exports/claudian/" in s:
        return "claudian"
    home_notes = str(Path.home() / "life" / "notes")
    if cwd and cwd.startswith(home_notes):
        return "claudian"
    if "/exports/claudian/" in str(diary_path):
        return "claudian"
    return "cc"


def get_project(diary_path: Path, override: str | None, cwd: str | None) -> str:
    if override:
        return override
    text = diary_path.read_text(encoding="utf-8")
    m = re.search(r"^project:\s*(\S+)", text, re.MULTILINE)
    if m and m.group(1) not in ("", "unknown"):
        return m.group(1)
    home_notes = str(Path.home() / "life" / "notes")
    if cwd and cwd.startswith(home_notes):
        return "life"
    return "unknown"


def tildify(p: Path) -> str:
    home = str(Path.home())
    s = str(p)
    return "~" + s[len(home):] if s.startswith(home) else s


def atomic_write(path: Path, content: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--diary", required=True)
    ap.add_argument("--transcript", required=True)
    ap.add_argument("--cwd", default=None)
    ap.add_argument("--project", default=None)
    ap.add_argument("--journal-dir", default=str(JOURNAL_ROOT))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    diary_path = Path(args.diary).expanduser().resolve()
    transcript_path = Path(args.transcript).expanduser().resolve()
    if not diary_path.is_file():
        raise SystemExit(f"diary not found: {diary_path}")
    if not transcript_path.is_file():
        raise SystemExit(f"transcript not found: {transcript_path}")

    session_id = extract_session_id(diary_path)
    if not UUID_RE.match(session_id):
        raise SystemExit(f"invalid session_id '{session_id}' in {diary_path}")

    jsonl_end = extract_jsonl_end(diary_path)
    first_dt, last_dt = transcript_first_last(transcript_path, jsonl_end)
    duration_min = max(0, int((last_dt - first_dt).total_seconds() // 60))
    project = get_project(diary_path, args.project, args.cwd)
    source = detect_source(transcript_path, args.cwd, diary_path)

    date_str = first_dt.strftime("%Y-%m-%d")
    day_name = DAYS_PT[(first_dt.weekday() + 1) % 7]

    journal_dir = Path(args.journal_dir).expanduser()
    journal_dir.mkdir(parents=True, exist_ok=True)
    journal_path = journal_dir / f"{date_str}.md"

    existing = parse_journal(journal_path)
    pre_count = len(existing.blocks) if existing else 0
    is_replace = bool(
        existing and any(b.session_id == session_id for b in existing.blocks)
    )
    sessions_after = pre_count if is_replace else pre_count + 1
    request_sinais = sessions_after >= 3

    metadata = {
        "session_id": session_id,
        "date": date_str,
        "day_name": day_name,
        "start_hm": first_dt.strftime("%H:%M"),
        "end_hm": last_dt.strftime("%H:%M"),
        "duration": fmt_duration(duration_min),
        "project": project,
        "source": source,
    }

    diary_text = diary_path.read_text(encoding="utf-8")
    current_sinais = existing.sinais_text if existing else SINAIS_PLACEHOLDER
    response = call_model(metadata, diary_text, request_sinais, current_sinais)

    narrative = escape_obsidian_html((response.get("narrative") or "").strip())
    bullets = [escape_obsidian_html(b) for b in (response.get("bullets") or [])]
    tipo = response.get("tipo") or []  # tipo tags are slugs — no HTML risk
    output = [escape_obsidian_html(o) for o in (response.get("output") or [])]
    sinais_update = response.get("sinais") if request_sinais else None
    if sinais_update is not None:
        sinais_update = escape_obsidian_html(str(sinais_update))
    if not narrative:
        raise SystemExit("model response missing narrative")

    new_block = Block(
        session_id=session_id,
        start_dt=first_dt,
        end_dt=last_dt,
        duration_min=duration_min,
        project=project,
        source=source,
        raw_text="",
    )
    new_block.raw_text = render_block(
        new_block, narrative, bullets, tipo, output, tildify(diary_path)
    )

    if existing is None:
        existing = JournalDoc(
            date_str=date_str,
            day_name_pt=day_name,
            sessions=0,
            active_time="0min",
            tags=["ai-journal"],
            blocks=[],
            sinais_text=SINAIS_PLACEHOLDER,
        )

    op = splice(existing, new_block)
    existing.sessions = len(existing.blocks)
    existing.active_time = fmt_duration(
        sum(b.duration_min for b in existing.blocks)
    )

    if existing.sessions < 3:
        existing.sinais_text = SINAIS_PLACEHOLDER
    elif sinais_update is not None and str(sinais_update).strip():
        existing.sinais_text = str(sinais_update).strip()

    rendered = render_journal(existing)

    expected_min = pre_count if is_replace else pre_count + 1
    new_count = len(MARKER_RE.findall(rendered))
    if new_count < expected_min:
        raise SystemExit(
            f"block-drop tripped: expected>={expected_min}, got {new_count} "
            f"session={session_id}"
        )

    if args.dry_run:
        sys.stdout.write(rendered)
        return

    atomic_write(journal_path, rendered)
    print(
        f"ok session={session_id} op={op} source={source} project={project} "
        f"date={date_str} blocks={new_count} journal={journal_path}"
    )


if __name__ == "__main__":
    main()
