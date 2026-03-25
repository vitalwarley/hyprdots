#!/usr/bin/env bash
# Check for HyDE updates via git fetch and notify if behind

HYDE_DIR="${HYDE_DIR:-$HOME/life/2-areas/dev-tools/HyDE}"

if [ ! -d "$HYDE_DIR/.git" ]; then
    notify-send -a "HyDE" "Update Check Failed" "HyDE directory not found: $HYDE_DIR"
    exit 1
fi

cd "$HYDE_DIR" || exit 1

git fetch origin master --quiet 2>/dev/null

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" != "$REMOTE" ]; then
    BEHIND=$(git rev-list --count HEAD..origin/master)
    LATEST=$(git log origin/master -1 --format="%s")
    notify-send -a "HyDE" -u normal "HyDE Update Available" "${BEHIND} commits behind master\nLatest: ${LATEST}\n\nRun: hyde-update"
fi
