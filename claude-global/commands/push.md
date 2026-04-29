# /push — Commit staged/unstaged changes and push

Stage everything pending, create a single commit with a conventional-commits message, and push to the current branch's upstream.

## Workflow

1. **Survey state** (parallel):
   - `git status` — what's modified, staged, untracked
   - `git diff` and `git diff --cached` — actual changes
   - `git log -5 --oneline` — recent commit style for this repo
   - `git branch --show-current` and `git rev-parse --abbrev-ref @{u} 2>/dev/null` — current branch + upstream (if any)

2. **Draft message**:
   - Conventional prefix matching change kind: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`
   - Subject ≤ 72 chars, focused on **why** not what (the diff already shows what)
   - Body only if needed for non-obvious context (1–3 lines)
   - Always include trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
   - Use heredoc for multi-line messages

3. **Stage**:
   - Add specific files by name when feasible — never blanket `git add -A` if untracked files exist that look unrelated (logs, secrets, build artifacts)
   - If untracked files are present, list them and confirm with the user before adding

4. **Commit + push** (sequential):
   - `git commit -m "$(cat <<'EOF' ... EOF)"`
   - On hook failure: fix and create a **new** commit (never `--amend` here, never `--no-verify`)
   - `git push` — if no upstream, use `git push -u origin <branch>`

5. **Report**:
   - Commit hash + subject
   - Push result (branch → remote)

## Guardrails

- **Never** force-push (`--force` / `-f`)
- **Never** push to `main`/`master` if pre-push hooks fail — investigate first
- **Never** commit files matching `.env*`, `*.key`, `credentials*`, `*.pem` without explicit confirmation
- If `git status` shows nothing to commit, say so and exit — do not create empty commits
- If multiple unrelated changes are staged, suggest splitting into separate commits before proceeding (user can override)

## Args

No args needed. Optional: pass a subject override (e.g., `/push fix: handle empty embedding case`) to skip auto-drafting.
