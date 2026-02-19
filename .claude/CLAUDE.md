# hyprdots

Dotfiles and global Claude tooling for Arch Linux setup.

## Structure

- `claude-global/` — version-controlled source for all global Claude config:
  - `CLAUDE.md` → symlinked as `~/.claude/CLAUDE.md`
  - `commands/` → symlinked into `~/.claude/commands/`
  - `skills/` → symlinked into `~/.claude/skills/`
  - `hooks/` → symlinked into `~/.claude/hooks/`
- `.claude/hooks/` — no longer used; hooks live in `claude-global/hooks/`

## Deployment

Symlinks are created manually after cloning. To re-create:

```bash
REPO=~/life/2-areas/dev-tools/hyprdots/claude-global

ln -sf "$REPO/CLAUDE.md" ~/.claude/CLAUDE.md
for f in "$REPO/commands/"*.md; do ln -sf "$f" ~/.claude/commands/$(basename "$f"); done
for d in "$REPO/skills/"/*/; do ln -sf "$d" ~/.claude/skills/$(basename "$d"); done
for h in "$REPO/hooks/"*.sh; do ln -sf "$h" ~/.claude/hooks/$(basename "$h"); done
```
