#!/bin/bash
# Deferred diary generation — runs via systemd timer, outside any Claude session.
# Called by auto-diary.sh after debounce period expires.

META_FILE="$1"

if [[ ! -f "$META_FILE" ]]; then
    exit 1
fi

TRANSCRIPT_PATH=$(jq -r '.transcript_path' "$META_FILE")
CWD=$(jq -r '.cwd' "$META_FILE")
RESUME_DIR=$(jq -r '.resume_dir // .cwd' "$META_FILE")
SESSION_ID=$(jq -r '.session_id' "$META_FILE")

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

TODAY=$(date '+%Y-%m-%d')
DIARY_DIR="$HOME/.claude/memory/diary"
mkdir -p "$DIARY_DIR"

# Deduplication: skip if this session already has a diary entry
EXISTING_FILE=$(grep -rl "Session ID: $SESSION_ID" "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | head -1)
if [[ -n "$EXISTING_FILE" ]]; then
    rm -f "$META_FILE"
    exit 0
fi

# Pre-compute the diary filename so we can check it directly after claude runs.
# This avoids the before/after comparison which incorrectly re-attributes existing files.
N=1
while [[ -f "$DIARY_DIR/${TODAY}-session-${N}.md" ]]; do N=$((N+1)); done
DIARY_FILE="$DIARY_DIR/${TODAY}-session-${N}.md"

# Resume the ended session and write a diary entry directly to DIARY_FILE.
# Uses an explicit write instruction rather than the /diary skill, which can produce
# conversational output instead of a file when the session has been context-compacted.
(cd "$RESUME_DIR" && claude --resume "$SESSION_ID" \
    --model haiku --max-turns 5 --permission-mode bypassPermissions \
    -p "Create a structured diary entry for this session and write it to: $DIARY_FILE

Review the conversation history above and write a markdown file with this structure:
# Session Diary Entry

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
[any other relevant observations]

Use the Write tool to write directly to $DIARY_FILE. Do not ask for confirmation — just write the file.") 2>&1

# Only proceed if the expected file was actually created with content.
# If claude produced conversational output instead of creating the file, exit cleanly.
if [[ ! -s "$DIARY_FILE" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

# Append session ID metadata for deduplication on re-runs
if [[ -s "$DIARY_FILE" ]]; then
    # Only append session ID if the file doesn't already have one
    if ! grep -q "<!-- Session ID:" "$DIARY_FILE"; then
        echo "" >> "$DIARY_FILE"
        echo "<!-- Session ID: $SESSION_ID -->" >> "$DIARY_FILE"
    fi

    # Append one-line entry to diary index
    INDEX_FILE="$DIARY_DIR/INDEX.md"
    SUMMARY=$(sed -n '/^## Task Summary$/,/^##/{/^## Task Summary$/d;/^##/d;p;}' "$DIARY_FILE" | head -1 | sed 's/^ *//')
    PROJECT=$(sed -n 's/^\*\*Project\*\*: *//p' "$DIARY_FILE" | head -1)

    # Extract timestamps: created_at (birth time or fallback to mtime), updated_at (mtime)
    CREATED_AT=$(stat -c '%w' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
    if [[ -z "$CREATED_AT" || "$CREATED_AT" == "-" ]]; then
        CREATED_AT=$(stat -c '%y' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
    fi
    UPDATED_AT=$(stat -c '%y' "$DIARY_FILE" 2>/dev/null | cut -d' ' -f1,2 | head -c19)

    ENTRY="| $TODAY | $(basename "$DIARY_FILE") | $PROJECT | $CREATED_AT | $UPDATED_AT | $SUMMARY |"

    # Create index header if it doesn't exist
    if [[ ! -f "$INDEX_FILE" ]]; then
        cat > "$INDEX_FILE" <<'HEADER'
# Diary Index

| Date | File | Project | Created At | Updated At | Summary |
|------|------|---------|------------|------------|---------|
HEADER
    fi

    # Update or append entry (remove all previous entries for this diary file by filename)
    DIARY_BASENAME=$(basename "$DIARY_FILE")
    grep -v "| $DIARY_BASENAME |" "$INDEX_FILE" > "${INDEX_FILE}.tmp" 2>/dev/null || true
    mv "${INDEX_FILE}.tmp" "$INDEX_FILE"
    echo "$ENTRY <!-- $SESSION_ID -->" >> "$INDEX_FILE"

    rm -f "$META_FILE"
else
    rm -f "$DIARY_FILE"
fi
