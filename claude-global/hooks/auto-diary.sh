#!/bin/bash
# Stop hook: generate diary entry from session transcript.
# Uses debounce pattern — each Stop cancels the previous timer and reschedules.
# Only the last turn's timer fires, ensuring the full session is captured.

INPUT=$(cat)

# Prevent infinite loops
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [[ "$STOP_ACTIVE" == "true" ]]; then
    exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
CWD=$(echo "$INPUT" | jq -r '.cwd')
DIARY_DIR="$HOME/.claude/memory/diary"
TIMER_UNIT="auto-diary-${SESSION_ID}"

# Skip sessions inside Obsidian vault (claudian — no diary needed)
if [[ "$CWD" == "$HOME/life/notes"* ]]; then
    exit 0
fi

# Skip if no transcript
if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

# Skip trivial sessions (fewer than 3 human+assistant messages)
MSG_COUNT=$(jq -r 'select(.type == "human" or .type == "assistant") | .type' "$TRANSCRIPT_PATH" 2>/dev/null | wc -l || echo 0)
if [[ "$MSG_COUNT" -lt 3 ]]; then
    exit 0
fi

# Cancel previous timer for this session (debounce)
systemctl --user stop "${TIMER_UNIT}.timer" 2>/dev/null
systemctl --user reset-failed "${TIMER_UNIT}.service" 2>/dev/null

# Store metadata for the deferred generation script
META_DIR="$HOME/.claude/memory/scratchpad"
mkdir -p "$META_DIR"
META_FILE="$META_DIR/${SESSION_ID}-meta.json"

# Find the directory --resume must be run from by walking up from CWD
# and comparing each candidate's encoded form against the transcript's project dir name.
# This works even when directory names contain hyphens (e.g. 1-projects, dev-tools).
PROJ_DIR_NAME=$(basename "$(dirname "$TRANSCRIPT_PATH")")
RESUME_DIR="$CWD"
CANDIDATE="$CWD"
while [[ "$CANDIDATE" != "/" ]]; do
    ENCODED=$(echo "$CANDIDATE" | tr '/' '-')
    if [[ "$ENCODED" == "$PROJ_DIR_NAME" ]]; then
        RESUME_DIR="$CANDIDATE"
        break
    fi
    CANDIDATE=$(dirname "$CANDIDATE")
done

cat > "$META_FILE" <<EOF
{"transcript_path":"$TRANSCRIPT_PATH","cwd":"$CWD","resume_dir":"$RESUME_DIR","session_id":"$SESSION_ID"}
EOF

# Schedule diary generation 5 minutes from now.
# If user sends another message, this timer gets cancelled and rescheduled.
# Only the final turn's timer fires, capturing the complete session.
systemd-run --user --on-active=5m --unit="$TIMER_UNIT" \
    bash "$HOME/.claude/hooks/generate-diary.sh" "$META_FILE" \
    2>/dev/null

exit 0
