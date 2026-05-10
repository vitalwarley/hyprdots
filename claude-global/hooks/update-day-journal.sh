#!/bin/bash
# Thin wrapper: validates inputs, resolves transcript path, delegates to the
# Python structural editor (update_day_journal.py). The Python module owns
# parsing, splice, frontmatter recompute, Agregados rebuild, Sinais gating,
# and atomic write — the model only generates per-block content.
#
# Invoked at the end of generate-diary.sh with the diary path.
# Failure is non-fatal — generate-diary.sh swallows the exit code so the
# diary itself is preserved even if journal upsert breaks.

set -u

DIARY_PATH="${1:-}"
TRANSCRIPT_PATH="${2:-}"
CWD="${3:-}"

if [[ -z "$DIARY_PATH" || ! -f "$DIARY_PATH" ]]; then
    logger -t update-day-journal "missing or invalid diary_path: $DIARY_PATH"
    exit 1
fi

# Anchor regex to start-of-line: prevents matching inline occurrences of
# `<!-- Session ID: ... -->` inside diary body text. Unanchored grep
# previously extracted "X" from a bullet discussing the auto-diary system,
# corrupting the journal (commit 3771318).
SESSION_ID=$(grep -oP '^<!-- Session ID: \K[^ ]+' "$DIARY_PATH" | head -1)
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID=$(sed -n 's/^session_id:[[:space:]]*//p' "$DIARY_PATH" | head -1)
fi
if [[ -z "$SESSION_ID" ]]; then
    logger -t update-day-journal "no session_id in diary: $DIARY_PATH"
    exit 1
fi

# UUID validation gate — bogus IDs reach the Python module otherwise and
# could corrupt the marker space.
if ! [[ "$SESSION_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    logger -t update-day-journal "invalid session_id '$SESSION_ID' in $DIARY_PATH — aborting"
    exit 1
fi

# Resolve transcript path (CC | Cursor | Claudian — all use JSONL on disk;
# Claudian transcripts land at ~/.claude/projects/-home-warley-life-notes/).
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    TRANSCRIPT_PATH=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
    if [[ -z "$TRANSCRIPT_PATH" ]]; then
        TRANSCRIPT_PATH=$(find "$HOME/.cursor/projects" -path "*agent-transcripts/${SESSION_ID}/${SESSION_ID}.jsonl" 2>/dev/null | head -1)
    fi
fi

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
    logger -t update-day-journal "transcript not found for session $SESSION_ID"
    exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PY_MODULE="$SCRIPT_DIR/update_day_journal.py"
if [[ ! -f "$PY_MODULE" ]]; then
    logger -t update-day-journal "missing python module: $PY_MODULE"
    exit 1
fi

ARGS=(--diary "$DIARY_PATH" --transcript "$TRANSCRIPT_PATH")
[[ -n "$CWD" ]] && ARGS+=(--cwd "$CWD")

# Python writes atomically via tmpfile + rename — a crash leaves the
# existing journal intact, so no shell-side backup is needed.
uv run "$PY_MODULE" "${ARGS[@]}" 2>&1 | logger -t update-day-journal
RC=${PIPESTATUS[0]}

exit "$RC"
