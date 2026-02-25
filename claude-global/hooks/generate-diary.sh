#!/bin/bash
# Deferred diary generation — runs via systemd timer, outside any Claude session.
# Called by auto-diary.sh after debounce period expires.
#
# Always uses JSONL transcript parsing (never --resume) to avoid:
# 1. UX issue: --resume reopens the session visibly
# 2. Fidelity loss: compacted sessions lose pre-compaction content
#
# Supports versioning: if a diary already exists for this session, generates
# a new version covering only the delta (new conversation since last diary).

META_FILE="$1"

if [[ ! -f "$META_FILE" ]]; then
    exit 1
fi

TRANSCRIPT_PATH=$(jq -r '.transcript_path' "$META_FILE")
SESSION_ID=$(jq -r '.session_id' "$META_FILE")
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")/../scripts"

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

TODAY=$(date '+%Y-%m-%d')
DIARY_DIR="$HOME/.claude/memory/diary"
mkdir -p "$DIARY_DIR"

# --- Versioning logic ---
# Find existing diary entries for this session (any date, any version).
# Convention: base = YYYY-MM-DD-session-N.md, versions = ...-session-N-v2.md, ...-v3.md
EXISTING_FILES=$(grep -rl "<!-- Session ID: $SESSION_ID -->" "$DIARY_DIR"/*.md 2>/dev/null | sort)
LATEST_EXISTING=$(echo "$EXISTING_FILES" | tail -1)

FROM_LINE=1
PREV_DIARY_CONTENT=""
VERSION_SUFFIX=""

if [[ -n "$LATEST_EXISTING" ]]; then
    # Extract the JSONL line range from the previous version
    PREV_LINE_RANGE=$(grep -oP '<!-- JSONL lines: \K[0-9]+-[0-9]+' "$LATEST_EXISTING" 2>/dev/null)
    if [[ -n "$PREV_LINE_RANGE" ]]; then
        PREV_END_LINE=$(echo "$PREV_LINE_RANGE" | cut -d'-' -f2)
        FROM_LINE=$((PREV_END_LINE + 1))
    fi

    # Check if there's actually new content since the last diary
    TOTAL_LINES=$(wc -l < "$TRANSCRIPT_PATH")
    if [[ "$FROM_LINE" -gt "$TOTAL_LINES" ]]; then
        # No new content since last diary — nothing to do
        rm -f "$META_FILE"
        exit 0
    fi

    # Read previous diary for context
    PREV_DIARY_CONTENT=$(cat "$LATEST_EXISTING")

    # Determine version number: base file = v1, then v2, v3, ...
    # Extract the base name (without -vN suffix) from the latest existing file
    LATEST_BASENAME=$(basename "$LATEST_EXISTING" .md)
    if [[ "$LATEST_BASENAME" =~ -v([0-9]+)$ ]]; then
        PREV_VERSION=${BASH_REMATCH[1]}
        NEXT_VERSION=$((PREV_VERSION + 1))
        # Strip the -vN to get the base name
        BASE_NAME=$(echo "$LATEST_BASENAME" | sed 's/-v[0-9]*$//')
    else
        # First file has no version suffix — it's v1, next is v2
        NEXT_VERSION=2
        BASE_NAME="$LATEST_BASENAME"
    fi
    VERSION_SUFFIX="-v${NEXT_VERSION}"
    DIARY_FILE="$DIARY_DIR/${BASE_NAME}${VERSION_SUFFIX}.md"
else
    # New diary — find next available session number for today
    N=1
    while [[ -f "$DIARY_DIR/${TODAY}-session-${N}.md" ]]; do N=$((N+1)); done
    DIARY_FILE="$DIARY_DIR/${TODAY}-session-${N}.md"
fi

# --- Parse transcript ---
PARSED=$(uv run "$SCRIPT_DIR/parse-transcript.py" "$TRANSCRIPT_PATH" --from-line "$FROM_LINE" 2>/dev/null)

if [[ -z "$PARSED" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

# --- Build prompt ---
DIARY_TEMPLATE="# Session Diary Entry

**Date**: $TODAY
**Session ID**: $SESSION_ID
**Project**: [project name from conversation]

## Task Summary
[2-3 sentences: what the user was trying to accomplish]

## Work Summary
- [bullet list of what was accomplished]

## Design Decisions Made
- [key decisions and why they were made]

## Challenges Encountered
- [errors, failed approaches, debugging steps]

## Solutions Applied
[how problems were resolved]

## Notes
[any other relevant observations]"

if [[ -n "$PREV_DIARY_CONTENT" ]]; then
    DIARY_PROMPT="You are generating a FOLLOW-UP diary entry for a session that continued after a previous diary was written.

Here is the PREVIOUS diary entry for context (do NOT repeat its content):
---
${PREV_DIARY_CONTENT}
---

Below is the NEW conversation that happened AFTER the previous diary was written.
Write a diary entry covering ONLY this new portion. Reference the previous version if the work continues a thread from it.

${PARSED}

---

Write the diary entry to: $DIARY_FILE
Use this structure:
${DIARY_TEMPLATE}

Add this line at the top after the title:
**Version**: v${NEXT_VERSION} (previous: $(basename "$LATEST_EXISTING"))

Use the Write tool to write directly to $DIARY_FILE. Do not ask for confirmation — just write the file."
else
    DIARY_PROMPT="${PARSED}

---

Create a structured diary entry for this session and write it to: $DIARY_FILE

Use this structure:
${DIARY_TEMPLATE}

Use the Write tool to write directly to $DIARY_FILE. Do not ask for confirmation — just write the file."
fi

# --- Generate diary ---
(cd /tmp && echo "$DIARY_PROMPT" | claude \
    --model haiku --max-turns 5 --permission-mode bypassPermissions \
    --allowedTools Write \
    -p) 2>&1

# --- Post-processing ---
if [[ ! -s "$DIARY_FILE" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

# Append session ID and JSONL line range for deduplication and versioning
if ! grep -q "<!-- Session ID:" "$DIARY_FILE"; then
    echo "" >> "$DIARY_FILE"
    echo "<!-- Session ID: $SESSION_ID -->" >> "$DIARY_FILE"
fi

# Extract JSONL line range from the parsed output and append to diary
JSONL_LINE_TAG=$(echo "$PARSED" | grep -oP '<!-- JSONL lines: [0-9]+-[0-9]+ -->' | tail -1)
if [[ -n "$JSONL_LINE_TAG" ]] && ! grep -q "JSONL lines:" "$DIARY_FILE"; then
    echo "$JSONL_LINE_TAG" >> "$DIARY_FILE"
fi

# --- Update INDEX.md ---
INDEX_FILE="$DIARY_DIR/INDEX.md"
SUMMARY=$(sed -n '/^## Task Summary$/,/^##/{/^## Task Summary$/d;/^##/d;p;}' "$DIARY_FILE" | head -1 | sed 's/^ *//')
PROJECT=$(sed -n 's/^\*\*Project\*\*: *//p' "$DIARY_FILE" | head -1)

CREATED_AT=$(stat -c '%w' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
if [[ -z "$CREATED_AT" || "$CREATED_AT" == "-" ]]; then
    CREATED_AT=$(stat -c '%y' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
fi
UPDATED_AT=$(stat -c '%y' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)

ENTRY="| $TODAY | $(basename "$DIARY_FILE") | $PROJECT | $CREATED_AT | $UPDATED_AT | $SUMMARY |"

if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" <<'HEADER'
# Diary Index

| Date | File | Project | Created At | Updated At | Summary |
|------|------|---------|------------|------------|---------|
HEADER
fi

DIARY_BASENAME=$(basename "$DIARY_FILE")
grep -v "| $DIARY_BASENAME |" "$INDEX_FILE" > "${INDEX_FILE}.tmp" 2>/dev/null || true
mv "${INDEX_FILE}.tmp" "$INDEX_FILE"
echo "$ENTRY <!-- $SESSION_ID -->" >> "$INDEX_FILE"

rm -f "$META_FILE"
