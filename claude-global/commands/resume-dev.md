You are continuing previous work on this project. Execute this workflow:

**Context argument**: `$ARGUMENTS`

## 0. Resolve Context

Determine what to continue from based on `$ARGUMENTS`:

**If empty** (auto-detect):
- Read the most recent diary entry from `~/.claude/memory/diary/` for this project
- Check for open PRs on the current branch:
  ```bash
  gh pr list --head "$(git branch --show-current)" --json number,title,state,url
  ```
- For each open PR found, fetch review comments and CI status:
  ```bash
  gh pr view <number> --comments
  gh api repos/:owner/:repo/pulls/<number>/comments
  gh pr checks <number>
  ```

**If a PR number** (e.g., `121`):
- Fetch PR details, review comments, and CI status:
  ```bash
  gh pr view $ARGUMENTS --json number,title,state,headRefName
  gh pr view $ARGUMENTS --comments
  gh api repos/:owner/:repo/pulls/$ARGUMENTS/comments
  gh pr checks $ARGUMENTS
  ```
- Read the most recent diary entry for this project as supplementary context

**If a session identifier** (e.g., `session-8` or `8`):
- Read `~/.claude/memory/diary/*session-$ARGUMENTS.md`

**If a path or filename**:
- Read the specified diary file directly

## 1. Gather State

Collect current project state (run in parallel):

```bash
git branch --show-current
git log --oneline -10
git status
git diff --stat
```

Cross-reference diary + PR reviews + CI checks + git state to identify:
- **Completed**: What was finished in the previous session
- **Pending**: What was deferred, left incomplete, or flagged for follow-up
- **Review findings**: Unresolved PR review comments (blocking vs non-blocking)
- **CI failures**: Failing checks on open PRs (fetch logs with `gh run view <run-id> --log-failed`)
- **New issues**: Problems discovered during the session

## 2. Present Situation

Present to the user:
- **Previous session**: 1-2 line summary of what was done
- **Current state**: Branch, PR status, CI check results, uncommitted changes
- **Pending work**: Unresolved items ordered by priority (blocking first)
- **Suggested focus**: Recommended next action with rationale

Wait for user confirmation before proceeding.

## 3. Implement

After user confirms:
- Use TodoWrite to track substeps
- Work on the confirmed task
- Run tests after meaningful changes
