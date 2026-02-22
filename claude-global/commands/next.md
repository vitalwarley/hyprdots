---
description: Determine what to do next on the current branch by reading project docs
---

# Next: Resume Work on Current Feature

You are determining what to do next for the current project. The workflow adapts based on the project's documentation structure.

**Arguments**: `$ARGUMENTS`

## 0. Detect Project Context

Check which documentation structure exists in `{{ cwd }}`:

```bash
ls docs/plans/ 2>/dev/null && echo "HAS_PLANS=true"
ls docs/features/ 2>/dev/null && echo "HAS_FEATURES=true"
```

- If `docs/plans/` exists with plan files → go to **Phase 1A** (plans-based)
- If `docs/features/` exists with feature subdirectories (beyond `_TEMPLATE/`) → go to **Phase 1B** (feature-docs)
- If neither exists → go to **Phase 1C** (fallback)

If BOTH exist, prefer the one most relevant to the current branch. Check `$ARGUMENTS` too — if the user passed a plan name, go 1A; if they passed a feature slug, go 1B.

---

## 1A. Plans-Based Workflow

For projects that track progress via `docs/plans/` and GitHub milestones.

### Resolve Plan

If `$ARGUMENTS` is provided:
- If it looks like a path (contains `/` or ends in `.md`), read it directly
- Otherwise, treat it as a name fragment and find the matching plan:
  ```bash
  find docs/plans/ -name "*$ARGUMENTS*" -type f
  ```
- If no match, list available plans and ask the user to clarify

If `$ARGUMENTS` is empty, list available plans and ask which to use:
```bash
ls docs/plans/
```

Read the resolved plan file. Extract the milestone name from the `**Milestone**:` line.

### Check for Issues

First, determine if issues exist for this plan's steps. Scan the plan for step table rows — if any have `TBD` in the Issue column (no GitHub issue created yet):

1. Check if the plan has a waves/execution section with step definitions
2. If steps exist but issues are `TBD` → offer to create them:
   - "This plan has N steps without GitHub issues. Run `/create-issues` to create them?"
   - If user confirms → invoke `/create-issues` with the plan path
   - After issues are created, continue below with the now-populated issue numbers

If a `**Milestone**:` line exists, also verify the milestone exists on GitHub:
```bash
gh api repos/:owner/:repo/milestones --jq '.[] | select(.title == "<milestone_name>") | .title' 2>/dev/null
```
If milestone doesn't exist, note it — `/create-issues` can create it.

### Determine Next Task

Check GitHub issue status using the extracted milestone name:

```bash
gh issue list --milestone "<milestone_name>" --json number,title,state --jq '.[] | "\(.number) \(.title) [\(.state)]"'
```

If no milestone exists but the plan has issue numbers, check issues directly:
```bash
gh issue view <N> --json state --jq '.state'
```

Identify the next uncompleted step in the build order. If a step is partially done, check git log and session docs for context.

**Wave awareness**: If the plan defines waves, respect wave boundaries. Don't suggest a Wave 2 step if any Wave 1 step is still open. Present the next available step(s) within the current wave, noting which can run in parallel.

### Present and Confirm

Present to the user:
- **Next task**: Which step and issue number
- **Key decisions**: Design choices or trade-offs from the plan relevant to this step
- **Questions**: Anything needing user input before proceeding
- **Estimated scope**: Files to create/modify

**Wait for user confirmation before writing any code.**

### Implement

After user confirms:
- Create a feature branch from the appropriate base branch
- Implement the step following the plan's file list and architecture
- Run tests after each meaningful change
- Use TodoWrite to track progress on substeps

---

## 1B. Feature-Docs Workflow

For projects that track progress via `docs/features/<slug>/` with PLAN.md, LOG.md, REVIEW.md.

### Find Feature Directory

Get the current branch:
```bash
git branch --show-current
```

Find the matching feature directory:

1. **Primary**: Search all PLAN.md files for the branch name:
   ```bash
   grep -rl "$(git branch --show-current)" docs/features/*/PLAN.md 2>/dev/null
   ```

2. **Fallback**: Strip common prefixes (`feat/`, `feature/`, `fix/`) from the branch name and look for a matching directory name in `docs/features/`. Try partial matching (e.g., `feat/agno-qdrant-integration` → look for `agno-qdrant`).

3. **No match found**: Inform the user that no feature docs were found for this branch. Suggest creating docs from the template:
   ```
   cp -r docs/features/_TEMPLATE docs/features/<slug>
   ```
   Then fall through to **Phase 1C** for basic git-based context.

### Read Feature State

Read whichever files exist in the feature directory:

**From PLAN.md** — extract:
- Feature name (first `# Feature:` heading)
- PR number (`**PR**:` line)
- Status (`**Status**:` line)
- Unchecked success criteria (lines matching `- [ ]`)

**From LOG.md** — extract from the LAST session entry:
- Session number and date
- "Next Session" items (the `### Next Session` section, usually `- [ ]` items)
- "Blockers / Open Questions" section content

**From REVIEW.md** — extract:
- Any finding rows where the Status column is NOT "Fixed" and NOT "Accepted" and NOT "Previously fixed"
- Unchecked review sources (lines matching `- [ ]` in the Review Sources section)

### Present Summary

Present a structured summary:

```markdown
## Feature: <name>
**Branch**: <branch> | **PR**: #XX | **Status**: <status>

### Pending Success Criteria
- [ ] <unchecked items from PLAN.md>

### Next Tasks (from Session N)
- [ ] <items from LOG.md "Next Session" section>

### Open Blockers / Questions
- <items from LOG.md "Blockers" section>

### Open Review Findings
| ID | File | Issue | Status |
<only rows where status is not Fixed/Accepted>

(omit any section that has no items)
```

End with a **Suggested First Action** — synthesize the most impactful next step based on:
1. Open blockers (highest priority — unblock first)
2. Open review findings (address before merge)
3. Pending success criteria (work toward completion)
4. Next session tasks (continue planned work)

**Wait for user confirmation before writing any code.**

### Implement

After user confirms:
- If not already on a feature branch, create one
- Begin implementation
- Run tests after each meaningful change
- Use TodoWrite to track progress on substeps

---

## 1C. Fallback Workflow

For projects without structured feature/plan documentation.

### Gather Context

Run these to understand current state:
```bash
git branch --show-current
git log --oneline -10
gh pr list --author @me --json number,title,state,headRefName --jq '.[] | "#\(.number) \(.title) [\(.state)] (\(.headRefName))"' 2>/dev/null
```

Also check for:
- `SESSIONS.md` at project root (recent session summaries)
- `.sessions/` directory (session diary entries — read the most recent one)
- `CLAUDE.md` at project root (project context and conventions)

### Route Based on PR State

If open PRs authored by you exist → skip to **Phase 2, State A** (PR Triage).

Otherwise, show the user what you found:
- Current branch and recent commits
- Latest session context (if available)
- Ask: "What would you like to work on?"

---

## 2. PR Triage Phase

Applies in two contexts:
- **Plans-based**: After Phase 1A, when all milestone issues have open PRs
- **Standalone**: When no plans/features/milestone context exists, but there are open PRs authored by you. This covers ad-hoc fixes pushed without `/next` or milestone tracking.

### Detect Standalone Trigger

If Phase 1C was reached (no plans, no features), check for open PRs before presenting the fallback:

```bash
gh pr list --author @me --state open --json number,title,headRefName,statusCheckRollup,additions,deletions
```

If open PRs exist, proceed to **State A** below instead of the fallback "What would you like to work on?" prompt.

### State A: Open PRs — Triage

**Trigger (plans-based)**: Every issue in the milestone has an associated open PR.
**Trigger (standalone)**: One or more open PRs authored by you exist.

**Fetch all PR data in parallel** — use a single message with multiple tool calls:

For each PR, fetch these three in parallel:
```bash
# 1. CI status
gh pr view <N> --json statusCheckRollup,additions,deletions,files --jq '{checks: [.statusCheckRollup[] | {name, status, conclusion}], additions, deletions, files: [.files[].path]}'

# 2. Bot review comments
gh api repos/<owner>/<repo>/issues/<N>/comments --jq '.[] | select(.user.login | test("claude|bot")) | .body'

# 3. PR diff (for cross-PR conflict detection)
gh pr diff <N>
```

**All PRs fetched in one round** — launch all `gh` calls as parallel Bash tool invocations.

Then analyze:
1. Parse bot review comments — extract findings by severity (Critical, Medium, Low)
2. Check CI status — any failures block merge
3. Scan diffs for cross-PR conflicts (overlapping file changes, shared state)
4. Verify any `git add -f` usage in diffs — flag as gitignore issue to fix before merge

Present consolidated summary:

```markdown
## PR Triage

| PR | CI | Verdict | Critical | Medium | Low |
|----|-----|---------|----------|--------|-----|
| #197 | Pass | Approve | 0 | 0 | 2 |
| #198 | Pass | Approve | 0 | 1 | 3 |

### Cross-PR Findings
- <any finding that applies across PRs>

### Pre-Merge Actions
- <any fix needed before merge, e.g., gitignore, type error>
```

Ask the user: "Any findings to propagate to other issues? Ready to merge?" — triage is a judgment call requiring user input.

After user confirms:
1. Apply any pre-merge fixes (commit to develop or to the PR branch)
2. Merge PRs in dependency order (if one PR depends on another, merge the dependency first)
3. Proceed to State B.

### State B: All Issues CLOSED — Validate and Close Out

**Trigger**: All issues in the milestone are CLOSED (either just merged or from a previous session).

Execute the plan's completion criteria without asking:

```bash
# Example: plan says "bash scripts/pre-push.sh passes on develop after both merge"
git checkout develop && git pull
bash scripts/pre-push.sh
```

Report pass/fail. If all pass:
- State: "v0.2.3 complete. All issues closed, all checks pass."
- Do NOT close the milestone (that's a user action)

---

## 3. Enrich with Reflection Context

**After gathering project state (1A/1B/1C) and before presenting to the user**, check for recent reflections:

1. List reflection files: `ls -t ~/.claude/memory/reflections/*.md | head -3`
2. Read the most recent reflection file
3. Extract items relevant to the current project:
   - **Anti-Patterns to Avoid** — surface any that match the technology/area of the next task
   - **Design Decisions That Worked** — surface reusable patterns relevant to the next task
   - **Cross-Project Knowledge Transfer** — surface any items targeting this project
   - **Rule Violations Detected** — flag if the planned work touches an area where violations were found

4. Add a `### Reflection Context` section to your summary (only if relevant items found):

```markdown
### Reflection Context (from YYYY-MM reflection)
- ⚠️ <relevant anti-pattern or violation>
- ✓ <relevant design decision to reuse>
```

Keep this section to 2-4 bullets max. Omit if nothing relevant.

---

## Important Guidelines

- **Never write code without user confirmation** in implementation phases
- **Read before summarizing** — actually read the files, don't guess from filenames
- **Be concise** — the summary should fit on one screen
- **Omit empty sections** — if REVIEW.md has no open findings, don't show that section
- **Respect project conventions** — read CLAUDE.md for branch naming, commit format, test commands
