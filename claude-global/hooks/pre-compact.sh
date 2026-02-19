#!/bin/bash
# Pre-compact hook: remind Claude to save session context before compaction.
# Hook stdout appears as system context to Claude, but cannot invoke skills directly.
# This outputs an instruction that Claude should interpret as a user request.

echo "IMPORTANT: Context is about to be compacted. Before proceeding, invoke the /claude-memory:diary skill to save a diary entry for this session. Do this NOW before context is lost."
