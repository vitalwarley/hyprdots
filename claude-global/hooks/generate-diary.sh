#!/bin/bash
# Deferred diary generation — runs via systemd timer, outside any Claude session.
# Called by auto-diary.sh after debounce period expires.

META_FILE="$1"

if [[ ! -f "$META_FILE" ]]; then
    exit 1
fi

TRANSCRIPT_PATH=$(jq -r '.transcript_path' "$META_FILE")
CWD=$(jq -r '.cwd' "$META_FILE")
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

# Snapshot existing diary files to detect what the skill creates
BEFORE_NEWEST=$(ls -t "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | head -1)

# Invoke the /diary skill — uses JSONL fallback since session has ended.
# The skill handles: transcript extraction, formatting, saving, and SESSIONS.md update.
# Use bypassPermissions mode since this runs in background without user interaction.
(cd "$CWD" && claude -p /diary --model haiku --max-turns 5 --permission-mode bypassPermissions) 2>&1

# Detect the file created or updated by the skill
AFTER_NEWEST=$(ls -t "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | head -1)

if [[ -n "$AFTER_NEWEST" && "$AFTER_NEWEST" != "$BEFORE_NEWEST" ]]; then
    # Skill created a new file
    DIARY_FILE="$AFTER_NEWEST"
elif [[ -n "$AFTER_NEWEST" ]]; then
    # Skill may have updated the existing newest file (re-run deduplication)
    DIARY_FILE="$AFTER_NEWEST"
else
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
