#!/usr/bin/env python3
"""
scan-sessions.py — D2 session sink.

Scans Claude Code JSONL transcripts (CC CLI + Claudian, both land in
~/.claude/projects/<hashed-cwd>/<session-uuid>.jsonl because Claudian uses
Agent SDK with the user's ~/.claude) and emits per-(session, model, day)
aggregates appended to ~/.local/share/claude-usage/sessions-YYYY-MM.jsonl.

Output line schema (one per session × model × day):
    {
      "day":                   "YYYY-MM-DD",        # UTC date of first turn that day
      "session_id":            "<uuid>",            # JSONL basename
      "project":               "<readable>",         # derived from parent dir
      "model":                 "claude-opus-4-7",
      "turns":                 47,                   # assistant records
      "input_tokens":          521000,
      "output_tokens":         38000,
      "cache_creation_tokens": 89000,
      "cache_read_tokens":     1240000,
      "peak_ctx_turn":         192000,               # max (input+cache_read+cache_creation) per turn
      "first_ts":              "ISO8601 Z",
      "last_ts":               "ISO8601 Z"
    }

Dedup: per-run set of seen message.id (drops retried duplicates within a session
and rare cross-file ID overlaps between simultaneous tabs / Claudian + CLI).

Idempotency: before append, read current month's file and skip lines whose
(session_id, model, day) tuple is already present.

Rotation: at run start, gzip any sessions-YYYY-MM.jsonl whose month has passed,
then delete .jsonl.gz older than RETENTION_DAYS.
"""

import argparse
import datetime as dt
import gzip
import json
import os
import sys
from collections import defaultdict
from pathlib import Path


SOURCES = [
    Path.home() / ".claude" / "projects",
]
RETENTION_DAYS = 90


def log(verbose: bool, msg: str) -> None:
    if verbose:
        print(f"[scan-sessions] {msg}", file=sys.stderr)


def parse_ts(s: str) -> dt.datetime:
    """ISO8601 with trailing Z → aware UTC datetime."""
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    return dt.datetime.fromisoformat(s)


def project_name(jsonl_path: Path) -> str:
    """Derive readable project name from CC-hashed parent dir.

    `~/.claude/projects/-home-warley-life-notes/...jsonl`
        → "life/notes"
    `~/.claude/projects/-home-warley-life-1-projects-noux/...jsonl`
        → "life/1-projects/noux"
    """
    parent = jsonl_path.parent.name
    home_prefix = f"-home-{os.environ.get('USER', 'warley')}-"
    if parent.startswith(home_prefix):
        rel = parent[len(home_prefix):]
    else:
        rel = parent.lstrip("-")
    return rel.replace("-", "/")


def iter_jsonl_records(path: Path, verbose: bool):
    """Yield decoded JSON records, skipping malformed lines."""
    try:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line_no, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    log(verbose, f"skip malformed line {path}:{line_no}")
                    continue
    except OSError as e:
        log(verbose, f"skip unreadable {path}: {e}")


def aggregate_session(
    path: Path,
    since: dt.datetime,
    seen_ids: set,
    verbose: bool,
) -> dict:
    """Walk one JSONL; return {(session_id, model, day): agg-dict}.

    `seen_ids` is mutated for cross-file dedup.
    """
    session_id = path.stem
    project = project_name(path)
    aggs: dict = {}

    for rec in iter_jsonl_records(path, verbose):
        if rec.get("type") != "assistant":
            continue
        msg = rec.get("message") or {}
        msg_id = msg.get("id")
        if not msg_id or msg_id in seen_ids:
            continue
        usage = msg.get("usage") or {}
        ts_raw = rec.get("timestamp")
        if not ts_raw:
            continue
        try:
            ts = parse_ts(ts_raw)
        except (ValueError, TypeError):
            continue
        if ts < since:
            continue

        seen_ids.add(msg_id)
        model = msg.get("model") or "unknown"
        day = ts.date().isoformat()
        key = (session_id, model, day)

        inp = int(usage.get("input_tokens") or 0)
        out = int(usage.get("output_tokens") or 0)
        cc = int(usage.get("cache_creation_input_tokens") or 0)
        cr = int(usage.get("cache_read_input_tokens") or 0)
        ctx = inp + cc + cr

        agg = aggs.get(key)
        if agg is None:
            agg = {
                "day": day,
                "session_id": session_id,
                "project": project,
                "model": model,
                "turns": 0,
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_creation_tokens": 0,
                "cache_read_tokens": 0,
                "peak_ctx_turn": 0,
                "first_ts": ts_raw,
                "last_ts": ts_raw,
                "_first_dt": ts,
                "_last_dt": ts,
            }
            aggs[key] = agg

        agg["turns"] += 1
        agg["input_tokens"] += inp
        agg["output_tokens"] += out
        agg["cache_creation_tokens"] += cc
        agg["cache_read_tokens"] += cr
        if ctx > agg["peak_ctx_turn"]:
            agg["peak_ctx_turn"] = ctx
        if ts < agg["_first_dt"]:
            agg["_first_dt"] = ts
            agg["first_ts"] = ts_raw
        if ts > agg["_last_dt"]:
            agg["_last_dt"] = ts
            agg["last_ts"] = ts_raw

    for agg in aggs.values():
        agg.pop("_first_dt", None)
        agg.pop("_last_dt", None)
    return aggs


def discover_files(since: dt.datetime, verbose: bool):
    """Yield JSONL paths whose mtime is ≥ since (cheap pre-filter)."""
    since_ts = since.timestamp()
    for root in SOURCES:
        if not root.exists():
            log(verbose, f"missing source root: {root}")
            continue
        for path in root.rglob("*.jsonl"):
            try:
                if path.stat().st_mtime >= since_ts:
                    yield path
            except OSError:
                continue


def existing_keys(month_file: Path) -> set:
    """Return set of (session_id, model, day) tuples already persisted."""
    if not month_file.exists():
        return set()
    keys = set()
    with month_file.open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            keys.add((rec.get("session_id"), rec.get("model"), rec.get("day")))
    return keys


def month_path(data_dir: Path, day: str) -> Path:
    """sessions-YYYY-MM.jsonl path for a given YYYY-MM-DD day."""
    return data_dir / f"sessions-{day[:7]}.jsonl"


def rotate_and_prune(data_dir: Path, today: dt.date, verbose: bool) -> None:
    """Gzip closed months; delete .gz older than RETENTION_DAYS."""
    if not data_dir.exists():
        return
    current_prefix = f"sessions-{today.strftime('%Y-%m')}"
    cutoff_ts = (today - dt.timedelta(days=RETENTION_DAYS)).strftime("%Y-%m")
    for path in sorted(data_dir.iterdir()):
        name = path.name
        if name.startswith("sessions-") and name.endswith(".jsonl"):
            if name.startswith(current_prefix):
                continue
            gz_path = path.with_suffix(".jsonl.gz")
            log(verbose, f"compress {path} → {gz_path}")
            with path.open("rb") as src, gzip.open(gz_path, "wb") as dst:
                dst.writelines(src)
            path.unlink()
        elif name.startswith("sessions-") and name.endswith(".jsonl.gz"):
            month = name[len("sessions-"):-len(".jsonl.gz")]
            if month < cutoff_ts:
                log(verbose, f"prune (>{RETENTION_DAYS}d): {path}")
                path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument(
        "--data-dir",
        default=os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share"),
        help="parent for claude-usage/ output dir (default $XDG_DATA_HOME or ~/.local/share)",
    )
    parser.add_argument(
        "--since",
        help="only ingest assistant records with ts ≥ YYYY-MM-DD (default: 7d ago)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print aggregates to stdout instead of writing to disk",
    )
    parser.add_argument(
        "--simulate-date",
        help="override 'today' for rotation testing (YYYY-MM-DD)",
    )
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    now_utc = dt.datetime.now(dt.timezone.utc)
    today = (
        dt.date.fromisoformat(args.simulate_date) if args.simulate_date else now_utc.date()
    )

    if args.since:
        since_date = dt.date.fromisoformat(args.since)
        since = dt.datetime.combine(since_date, dt.time(0, 0, tzinfo=dt.timezone.utc))
    else:
        since = now_utc - dt.timedelta(days=7)

    data_dir = Path(args.data_dir) / "claude-usage"
    if not args.dry_run:
        data_dir.mkdir(parents=True, exist_ok=True)
        rotate_and_prune(data_dir, today, args.verbose)

    log(args.verbose, f"scanning since {since.isoformat()} (data_dir={data_dir})")

    seen_ids: set = set()
    files_scanned = 0
    new_aggs = defaultdict(list)  # month_key → list[agg]

    for path in discover_files(since, args.verbose):
        files_scanned += 1
        for agg in aggregate_session(path, since, seen_ids, args.verbose).values():
            month_key = agg["day"][:7]
            new_aggs[month_key].append(agg)

    log(args.verbose, f"scanned {files_scanned} JSONLs, {len(seen_ids)} unique msg ids")

    total_lines_written = 0
    if args.dry_run:
        for month_aggs in new_aggs.values():
            for agg in month_aggs:
                print(json.dumps(agg, ensure_ascii=False))
                total_lines_written += 1
    else:
        for month_key, aggs in new_aggs.items():
            mfile = data_dir / f"sessions-{month_key}.jsonl"
            present = existing_keys(mfile)
            with mfile.open("a", encoding="utf-8") as fh:
                for agg in aggs:
                    key = (agg["session_id"], agg["model"], agg["day"])
                    if key in present:
                        continue
                    fh.write(json.dumps(agg, ensure_ascii=False) + "\n")
                    present.add(key)
                    total_lines_written += 1

    log(args.verbose, f"emitted {total_lines_written} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
