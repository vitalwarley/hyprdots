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
DIARY_DIR="$HOME/.claude/memory/diary"

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    rm -f "$META_FILE"
    exit 1
fi

# Determine diary filename — reuse existing file for same session, or create new
TODAY=$(date '+%Y-%m-%d')
EXISTING_FILE=$(grep -rl "Session ID: $SESSION_ID" "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | head -1)
if [[ -n "$EXISTING_FILE" ]]; then
    DIARY_FILE="$EXISTING_FILE"
else
    EXISTING=$(ls "$DIARY_DIR"/${TODAY}-session-*.md 2>/dev/null | wc -l || echo 0)
    NEXT_SESSION=$((EXISTING + 1))
    DIARY_FILE="$DIARY_DIR/${TODAY}-session-${NEXT_SESSION}.md"
fi

mkdir -p "$DIARY_DIR"

# Extract conversation content from transcript JSONL (full transcript)
TRANSCRIPT_EXCERPT=$(jq -r '
    select(.type == "human" or .type == "assistant") |
    if .type == "human" then
        "**User**: " + (
            if (.message.content | type) == "string" then .message.content
            elif (.message.content | type) == "array" then
                [.message.content[] | select(.type == "text") | .text] | join("\n")
            else ""
            end
        )
    elif .type == "assistant" then
        "**Assistant**: " + (
            if (.message.content | type) == "string" then .message.content
            elif (.message.content | type) == "array" then
                [.message.content[] | select(.type == "text") | .text] | join("\n")
            else ""
            end
        )
    else empty
    end
' "$TRANSCRIPT_PATH" 2>/dev/null || echo "(transcript extraction failed)")

# Build prompt
PROMPT_FILE="$(mktemp)"
trap 'rm -f "$PROMPT_FILE"' EXIT

cat > "$PROMPT_FILE" <<PROMPTEOF
You are generating a session diary entry from a conversation transcript.

Generate a diary entry in this exact format:

# Session Diary Entry

**Date**: YYYY-MM-DD
**Project**: <working directory or project name>
**Git Branch**: <if detectable>

## Task Summary
<1-3 sentence summary of what the session accomplished>

## Work Summary
<bullet list of concrete actions taken>

## Design Decisions Made
<decisions with rationale — WHY choices were made, trade-offs considered>

## Challenges Encountered
<problems hit during the session>

## Solutions Applied
<how challenges were resolved>

## User Preferences Observed
<workflow preferences, style choices, or patterns worth remembering>

## Notes
<anything else notable — next steps, open questions, context for future sessions>

Rules:
- Focus on WHY decisions were made, not just WHAT happened
- Keep it concise but preserve reasoning context
- If the session was mostly research/discussion with no code changes, note that
- Omit empty sections rather than writing "None"

## Session context:
- Working directory: $CWD
- Session ID: $SESSION_ID
- Date: $TODAY

## Session transcript (conversation):
$TRANSCRIPT_EXCERPT

Generate the diary entry now.
PROMPTEOF

# Generate diary via claude
claude -p "$(cat "$PROMPT_FILE")" \
    --model haiku \
    --allowedTools '' \
    --max-turns 1 \
    > "$DIARY_FILE" 2>/dev/null

# Append session ID metadata for deduplication on re-runs
if [[ -s "$DIARY_FILE" ]]; then
    echo "" >> "$DIARY_FILE"
    echo "<!-- Session ID: $SESSION_ID -->" >> "$DIARY_FILE"

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

    # Update or append entry (remove previous entry for same session if re-running)
    grep -v "$SESSION_ID" "$INDEX_FILE" > "${INDEX_FILE}.tmp" 2>/dev/null || true
    mv "${INDEX_FILE}.tmp" "$INDEX_FILE"
    echo "$ENTRY <!-- $SESSION_ID -->" >> "$INDEX_FILE"

    rm -f "$META_FILE"
else
    rm -f "$DIARY_FILE"
fi
