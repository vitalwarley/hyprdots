#!/usr/bin/env python3
"""Parse Claude Code JSONL transcript into clean readable text for diary generation.

Extracts human/assistant conversation, summarizes tool usage, and includes
compaction boundary markers. Supports partial parsing via --from-line for
diary versioning (only parse new content since last diary).

Usage:
    uv run parse-transcript.py <transcript.jsonl> [--from-line N] [--max-chars N]

Output includes a trailer line with the JSONL line range processed:
    <!-- JSONL lines: 1-1538 -->
"""

import json
import sys
from pathlib import Path


def extract_text_from_content(content: list[dict]) -> tuple[str, list[str]]:
    """Extract readable text and tool summaries from a message's content blocks."""
    texts = []
    tools = []

    for block in content:
        if block.get("type") == "text":
            text = block.get("text", "").strip()
            if text:
                texts.append(text)
        elif block.get("type") == "tool_use":
            name = block.get("name", "unknown")
            inp = block.get("input", {})
            if name in ("Read", "Glob", "Grep"):
                target = inp.get("file_path") or inp.get("pattern") or inp.get("path", "")
                tools.append(f"[{name}: {target}]")
            elif name == "Write":
                tools.append(f"[Write: {inp.get('file_path', '')}]")
            elif name == "Edit":
                tools.append(f"[Edit: {inp.get('file_path', '')}]")
            elif name == "Bash":
                cmd = inp.get("command", "")
                tools.append(f"[Bash: {cmd[:80]}]")
            elif name == "TodoWrite":
                pass
            else:
                tools.append(f"[{name}]")

    return "\n".join(texts), tools


def parse_transcript(
    jsonl_path: str, from_line: int = 1, max_chars: int = 400_000
) -> tuple[str, int]:
    """Parse JSONL transcript into readable conversation text.

    Args:
        jsonl_path: Path to the .jsonl transcript file
        from_line: 1-based line number to start parsing from
        max_chars: Approximate character budget (400K chars ≈ ~100K tokens)

    Returns:
        Tuple of (parsed text with line range trailer, last line number processed)
    """
    path = Path(jsonl_path)
    if not path.exists():
        print(f"Error: {jsonl_path} not found", file=sys.stderr)
        sys.exit(1)

    messages: list[str] = []
    compact_count = 0
    last_line = 0

    with open(path) as f:
        for line_num, line in enumerate(f, start=1):
            last_line = line_num
            if line_num < from_line:
                continue

            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Claude Code uses "type", Cursor uses "role" at top level
            rtype = record.get("type") or record.get("role")

            if rtype == "system" and record.get("subtype") == "compact_boundary":
                compact_count += 1
                pre_tokens = record.get("compactMetadata", {}).get("preTokens", "?")
                messages.append(
                    f"\n--- [Compaction #{compact_count}, ~{pre_tokens} tokens compressed] ---\n"
                )
                continue

            if rtype not in ("user", "assistant"):
                continue

            msg = record.get("message", {})
            role = msg.get("role", rtype)
            content = msg.get("content")

            if isinstance(content, str):
                text = content.strip()
                tool_summary: list[str] = []
            elif isinstance(content, list):
                text, tool_summary = extract_text_from_content(content)
            else:
                continue

            if not text and not tool_summary:
                continue

            parts = [f"## {role.upper()}"]
            if text:
                parts.append(text)
            if tool_summary:
                parts.append("Tools: " + ", ".join(tool_summary))
            messages.append("\n".join(parts))

    output = "\n\n".join(messages)

    # Truncate from the beginning if over budget (keep recent context)
    if len(output) > max_chars:
        output = output[-max_chars:]
        boundary = output.find("\n## ")
        if boundary > 0:
            output = output[boundary:]
        output = "[... earlier messages truncated ...]\n" + output

    # Build header
    if from_line > 1:
        header = f"# Session Transcript (continuation from line {from_line})\n\n"
    elif compact_count:
        header = f"# Session Transcript ({compact_count} compaction(s) detected — full pre-compaction content included)\n\n"
    else:
        header = "# Session Transcript\n\n"

    # Append line range as metadata trailer
    body = header + output
    body += f"\n\n<!-- JSONL lines: {from_line}-{last_line} -->"

    return body, last_line


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            f"Usage: {sys.argv[0]} <transcript.jsonl> [--from-line N] [--max-chars N]",
            file=sys.stderr,
        )
        sys.exit(1)

    jsonl_path = sys.argv[1]
    from_line = 1
    max_chars = 400_000

    if "--from-line" in sys.argv:
        idx = sys.argv.index("--from-line")
        from_line = int(sys.argv[idx + 1])

    if "--max-chars" in sys.argv:
        idx = sys.argv.index("--max-chars")
        max_chars = int(sys.argv[idx + 1])

    text, _ = parse_transcript(jsonl_path, from_line, max_chars)
    print(text)
