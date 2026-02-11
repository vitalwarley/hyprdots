#!/usr/bin/env bash
# Patch HyDE's env.zsh to prevent double-sourcing that clobbers PATH
#
# Problem: hyde/env.zsh line 14 reassigns PATH on every source, stripping
# entries added by later conf.d scripts (e.g., nvm node bin from 01-dev-paths.zsh).
#
# Fix: Add a source guard (_HYDE_ENV_SOURCED) and make PATH prepend idempotent.
#
# Usage: Run after every `hyde update` that overwrites conf.d/hyde/env.zsh
#   ./shell/patch-hyde-env.sh

set -euo pipefail

TARGET="${ZDOTDIR:-$HOME/.config/zsh}/conf.d/hyde/env.zsh"

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: $TARGET not found" >&2
  exit 1
fi

# Check if already patched
if grep -q '_HYDE_ENV_SOURCED' "$TARGET"; then
  echo "Already patched: $TARGET"
  exit 0
fi

# Verify the line we're patching exists
if ! grep -q '^PATH="\$HOME/.local/bin:\$PATH"' "$TARGET"; then
  echo "ERROR: Expected PATH assignment not found in $TARGET" >&2
  echo "HyDE may have changed env.zsh format — manual patch needed." >&2
  exit 1
fi

# Apply patch: insert source guard before PATH line, make PATH idempotent
sed -i.bak \
  '/^# Hyde.*Shell Environment/a\
\
# Source guard: prevent double-sourcing that clobbers PATH entries from later conf.d scripts\
(( _HYDE_ENV_SOURCED )) \&\& return\
_HYDE_ENV_SOURCED=1' \
  "$TARGET"

sed -i \
  's|^PATH="\$HOME/.local/bin:\$PATH"|# Basic PATH prepending (user local bin) — idempotent\nif [[ ":\$PATH:" != *":\$HOME/.local/bin:"* ]]; then\n  PATH="\$HOME/.local/bin:\$PATH"\nfi|' \
  "$TARGET"

# Remove the now-redundant comment that sed preserved
sed -i '/^# Basic PATH prepending (user local bin)$/d' "$TARGET"

echo "Patched: $TARGET"
echo "Backup:  ${TARGET}.bak"
echo ""
echo "Verify with: zsh -l -c 'which npm'"
