#!/usr/bin/env bash
# cursor-diary-poll.sh — Polls Cursor agent transcripts for active sessions
# and schedules diary generation with the same debounce as auto-diary.sh.
#
# Called by: systemd timer (cursor-diary-poll.timer) every 2 minutes
# Debounce: schedules generate-diary.sh 5min out per session, cancelling previous

set -euo pipefail

CURSOR_PROJECTS="$HOME/.cursor/projects"
SCRATCHPAD="$HOME/.claude/memory/scratchpad"
GENERATE_SCRIPT="$HOME/.claude/hooks/generate-diary.sh"
ACTIVE_WINDOW_MINUTES=7  # sessions modified within this window are "active"

# Guard: no Cursor projects dir
[[ -d "$CURSOR_PROJECTS" ]] || exit 0

mkdir -p "$SCRATCHPAD"

# Find JSONL transcripts modified recently
# (ACTIVE_WINDOW_MINUTES > debounce window so we don't miss the final write)
find "$CURSOR_PROJECTS" -path "*/agent-transcripts/*/*.jsonl" -mmin "-${ACTIVE_WINDOW_MINUTES}" 2>/dev/null | while read -r jsonl_path; do
    # Extract session ID from directory name
    session_dir=$(dirname "$jsonl_path")
    session_id=$(basename "$session_dir")

    # Extract project slug from path:
    # ~/.cursor/projects/<slug>/agent-transcripts/<session-id>/<session-id>.jsonl
    slug=$(echo "$jsonl_path" | sed 's|.*/\.cursor/projects/\([^/]*\)/agent-transcripts/.*|\1|')

    # Infer cwd from slug: home-warley-dev-noux → /home/warley/dev/noux
    cwd=$(echo "$slug" | sed 's|-|/|g; s|^|/|')

    meta_file="$SCRATCHPAD/${session_id}-meta.json"

    # Check message count (at least 3 lines = 3 messages)
    line_count=$(wc -l < "$jsonl_path")
    if [[ "$line_count" -lt 3 ]]; then
        continue
    fi

    # Determine diary directory based on session context
    if [[ "$cwd" == "$HOME/life/notes"* ]]; then
        diary_search_dir="$HOME/life/notes/resources/exports/claudian"
        mkdir -p "$diary_search_dir"
    else
        diary_search_dir="$HOME/.claude/memory/diary"
    fi

    # Check if diary already exists for this session with matching line count
    # (avoid re-triggering for completed sessions)
    existing_diary=$(grep -rl "<!-- Session ID: $session_id -->" "$diary_search_dir/" 2>/dev/null | sort | tail -1 || true)
    if [[ -n "$existing_diary" ]]; then
        prev_end=$(grep -o 'JSONL lines: [0-9]*-[0-9]*' "$existing_diary" | tail -1 | grep -o '[0-9]*$' || echo "0")
        if [[ "$line_count" -le "$prev_end" ]]; then
            # No new content since last diary version
            continue
        fi
    fi

    # Write metadata (same contract as auto-diary.sh)
    cat > "$meta_file" <<METAEOF
{
  "transcript_path": "$jsonl_path",
  "cwd": "$cwd",
  "session_id": "$session_id"
}
METAEOF

    # Debounce: cancel previous timer for this session, schedule new one
    timer_name="cursor-diary-${session_id}"
    systemctl --user stop "${timer_name}.timer" 2>/dev/null || true

    systemd-run --user \
        --unit="$timer_name" \
        --on-active=5m \
        --timer-property=AccuracySec=10s \
        --description="Cursor diary generation for $session_id" \
        bash "$GENERATE_SCRIPT" "$meta_file"
done
