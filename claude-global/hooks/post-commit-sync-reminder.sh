#!/bin/bash
# PostToolUse hook: after a successful git commit, remind about external artifact sync.
# Hooks inject context — they don't trigger actions. Claude decides whether to act.

INPUT=$(cat)

EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exitCode // .tool_response.exit_code // 1')
if [[ "$EXIT_CODE" != "0" ]]; then
    exit 0
fi

echo "Commit successful. Check if any external artifacts need updating (vault notes, sprint issues, etc.)."
