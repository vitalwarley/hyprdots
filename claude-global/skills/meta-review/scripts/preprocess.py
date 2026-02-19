"""Preprocess diary and reflection files for /meta-review analysis.

Loads, filters, and extracts structured sections from diary and reflection
files. Outputs a condensed JSON summary to stdout for Claude to analyze.
"""

import json
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

DIARY_DIR = Path.home() / ".claude" / "memory" / "diary"
REFLECTIONS_DIR = Path.home() / ".claude" / "memory" / "reflections"

# Sections relevant to meta-review analysis, ordered by priority.
# Task Summary kept short for context; the rest are analysis-critical.
DIARY_SECTIONS = [
    "Task Summary",
    "Challenges Encountered",
    "Solutions Applied",
    "User Preferences Observed",
    "Design Decisions Made",
    "Actions Taken",
]

REFLECTION_SECTIONS = [
    "Summary",
    "CRITICAL: Rule Violations Detected",
    "Patterns Identified",
    "Anti-Patterns to Avoid",
    "Notable Mistakes and Learnings",
    "Proposed CLAUDE.md Updates",
]


def parse_date_from_filename(filename: str) -> datetime | None:
    match = re.match(r"(\d{4}-\d{2}-\d{2})-session-\d+\.md", filename)
    if match:
        return datetime.strptime(match.group(1), "%Y-%m-%d")
    return None


def extract_sections(
    text: str, section_names: list[str], max_lines_per_section: int = 0
) -> dict[str, str]:
    """Extract markdown sections by heading name.

    Args:
        max_lines_per_section: Truncate each section to this many lines. 0 = no limit.
    """
    sections: dict[str, str] = {}
    lines = text.split("\n")
    current_section = None
    current_lines: list[str] = []

    for line in lines:
        heading_match = re.match(r"^#{1,3}\s+(.+)$", line)
        if heading_match:
            if current_section:
                content = "\n".join(current_lines).strip()
                if content:
                    sections[current_section] = content
            heading = heading_match.group(1).strip()
            if heading in section_names:
                current_section = heading
                current_lines = []
            else:
                current_section = None
                current_lines = []
        elif current_section:
            if max_lines_per_section and len(current_lines) >= max_lines_per_section:
                continue
            current_lines.append(line)

    if current_section:
        content = "\n".join(current_lines).strip()
        if content:
            sections[current_section] = content

    return sections


def extract_metadata(text: str) -> dict[str, str]:
    """Extract **Key**: Value metadata from diary header."""
    meta: dict[str, str] = {}
    for match in re.finditer(r"\*\*(\w[\w\s]*)\*\*:\s*(.+)", text):
        meta[match.group(1).strip()] = match.group(2).strip()
    return meta


def compute_date_range(window: str) -> tuple[datetime, datetime]:
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

    if window == "deep":
        return datetime(2000, 1, 1), today
    elif window == "last month":
        return today - timedelta(days=30), today
    elif window == "last week":
        return today - timedelta(days=7), today
    else:
        # Default: last 7 days
        return today - timedelta(days=7), today


def load_diaries(
    start: datetime, end: datetime, project_filter: str | None
) -> list[dict]:
    entries = []
    if not DIARY_DIR.exists():
        return entries

    for f in sorted(DIARY_DIR.iterdir()):
        if not f.name.endswith(".md") or f.name == "INDEX.md":
            continue

        file_date = parse_date_from_filename(f.name)
        if not file_date or file_date < start or file_date > end:
            continue

        text = f.read_text(encoding="utf-8")
        meta = extract_metadata(text)

        if project_filter:
            project = meta.get("Project", "").lower()
            if project_filter.lower() not in project:
                continue

        sections = extract_sections(text, DIARY_SECTIONS, max_lines_per_section=8)
        # Skip empty diaries
        if not sections:
            continue

        entries.append(
            {"file": f.name, "date": file_date.strftime("%Y-%m-%d"), **meta, **sections}
        )

    return entries


def load_reflections() -> list[dict]:
    entries = []
    if not REFLECTIONS_DIR.exists():
        return entries

    for f in sorted(REFLECTIONS_DIR.iterdir()):
        if not f.name.endswith(".md"):
            continue

        text = f.read_text(encoding="utf-8")
        meta = extract_metadata(text)
        sections = extract_sections(text, REFLECTION_SECTIONS)
        if not sections:
            continue

        entries.append({"file": f.name, **meta, **sections})

    return entries


def main() -> None:
    args = sys.argv[1:]

    # Parse arguments
    window = "last week"
    project_filter = None
    focus = None

    i = 0
    while i < len(args):
        arg = args[i].lower()
        if arg == "deep":
            window = "deep"
        elif arg == "last" and i + 1 < len(args):
            window = f"last {args[i + 1].lower()}"
            i += 1
        elif arg == "for" and i + 2 < len(args) and args[i + 1].lower() == "project":
            project_filter = args[i + 2]
            i += 2
        elif arg in ("errors", "drift", "automation", "efficiency"):
            focus = arg
        i += 1

    start, end = compute_date_range(window)

    diaries = load_diaries(start, end, project_filter)
    reflections = load_reflections()

    output = {
        "window": window,
        "date_range": {
            "start": start.strftime("%Y-%m-%d"),
            "end": end.strftime("%Y-%m-%d"),
        },
        "project_filter": project_filter,
        "focus": focus,
        "diary_count": len(diaries),
        "reflection_count": len(reflections),
        "diaries": diaries,
        "reflections": reflections,
    }

    json.dump(output, sys.stdout, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
