# /review - Comprehensive Code Review

Generate a structured review report for recent changes, combining multiple specialized analysis agents. Produces an artifact that can be reviewed asynchronously — your equivalent of a walkthrough report.

## Usage

```
/review [scope]
```

## Scopes

- **(empty)** — review unstaged changes in current repo (default)
- `staged` — review only staged changes
- `branch` — review all commits on current branch vs base branch
- `pr <number>` — review a specific PR
- `files path1 path2` — review specific files

## Examples

```bash
/review                    # Review current uncommitted work
/review staged             # Review what's about to be committed
/review branch             # Review entire feature branch
/review pr 42              # Review PR #42
/review files src/auth/    # Review specific directory
```

## Workflow

### 0. Checkout PR Branch

For `pr` and `branch` scopes, checkout the target branch before any work:

```bash
# PR scope
git fetch origin <pr-branch>
git checkout <pr-branch>

# Branch scope — already on the branch (verify)
```

**Stay on this branch for the entire review session.** Do not switch back to the original branch after committing the report. If other branches are needed (e.g., `develop` for convention updates), do that work last — after the user has reviewed the report and approved the PR comment.

**Why**: Switching branches makes the review report invisible in the user's IDE. Workarounds like `git show` into untracked files create cleanup problems.

### 1. Determine Diff Scope

Based on the scope argument, collect the diff to review:

```bash
# Default (unstaged)
git diff

# Staged
git diff --cached

# Branch (vs main/develop)
BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD develop)
git diff $BASE...HEAD

# PR
gh pr diff <number>
```

If diff is empty, inform user and exit.

### 1.5. Load Prior State

Before forming any opinions, check if this is a continuation of prior work:

- **Prior review artifacts**: Check `docs/reviews/` for existing reports on the same PR/branch. Read them in full — they contain findings, decisions, and fix guides that inform this round.
- **PR review history**: For `pr` scope, read all prior review bodies and comments (`gh pr view <number> --json reviews`). Understand what was already requested and what was fixed.
- **Spec/plan referenced**: If the prior review links a spec, read it to understand the contract being reviewed against. **Always search for task-specific specs** on the base branch (e.g., `git show origin/develop:docs/tasks/task-NNN-*.md`) — the PR branch may not have them, and the issue may link a stale overview instead of the detailed spec. Also check the linked GitHub issue for spec references.
- **Recent project reviews (this week)**: Scan `docs/reviews/` for reports from the last 7 days across all PRs (not just the current one). **Review reports live on PR branches, not develop** — check open PR branches (`gh pr list --limit 10`, then `git show origin/<branch>:docs/reviews/`) and recently merged/closed PRs (`gh pr list --state all --limit 10`). Recent reviews surface emerging conventions, recurring anti-patterns, and decisions that apply project-wide. Use them to:
  - Enforce conventions established in other PRs this week (even if not yet in convention docs)
  - Detect the same anti-pattern appearing across concurrent PRs
  - Avoid contradicting a decision made in a sibling review
  - **Calibrate depth**: Read 1-2 recent reports in full to match the expected level of analysis (Root Cause Analysis depth, Spec Compliance table granularity, Bot Verification thoroughness). A shallow report in a project with deep reports signals insufficient analysis.

**Why this matters**: Without prior state, you re-derive context from scratch — slower, and risks contradicting decisions already made. Iterative artifacts accumulate decisions; ignoring them means reviewing in a vacuum. Recent cross-PR reviews prevent convention drift between parallel workstreams.

**For first reviews**: Skip same-PR prior state, but still load recent project reviews for depth calibration and cross-PR patterns. For subsequent rounds: the prior review is as important as the diff itself.

### 2. Cross-Environment Context Gathering

Before forming opinions, gather context that cuts across environments. This step prevents the anchoring bias of reviewing config in isolation.

**For infrastructure/config changes** (K8s manifests, docker-compose, Dockerfiles, .env):
- Find all equivalent config files across environments (grep for the same service/setting in `docker-compose.*`, `k8s/`, `.env.*`)
- Compare the PR's config against existing environments — flag divergences, justify parity
- Grep the codebase for actual usage of features/permissions being added or changed

**For permission/security changes** (allowlists, RBAC, procedure access, IAM):
- Identify every code path that uses the permission being changed
- Check official docs for whether a proposed restriction would break functionality
- Only recommend restricting permissions after confirming safety via code + docs

**For dependency/version changes**:
- Check if the dependency appears in other config files (requirements.txt, pyproject.toml, package.json, Dockerfile)
- Verify version consistency across environments

**For bot review comments** (Copilot, Gemini, CodeRabbit, etc.):
- Read all bot comments on the PR
- Treat each as an unverified claim — verify against code and official docs before agreeing or disagreeing
- Explicitly state when a bot comment is incorrect and why

**For architecture/convention violations** (import direction, layer placement, pattern choices):
- For each suspected violation, grep the spec (`docs/tasks/`), linked issue body, and convention docs for the exact code pattern (import path, function name, lock type, etc.)
- **Spec archaeology**: Check the spec **as it existed when the dev started**, not the current version. Use `git log --format="%ai %s" -- docs/tasks/task-NNN-*.md` to find the timeline, then `git show <commit-before-PR>:docs/tasks/task-NNN-*.md` to read the version the dev worked from. Convention docs and specs may have been corrected during sibling PR reviews — the current spec may say `interfaces/api/` while the dev's version said `infrastructure/adapters/api/`.
- If the spec or issue directed the dev to use the pattern, the finding is **spec-caused** — the reviewer applies the fix and updates the spec, not the dev
- Example: finding `from interfaces.api... import detection_event_to_dto` → grep spec for `detection_event_to_dto` and `interface layer` to check if the spec told the dev to do this

Skip this step entirely if the diff is pure application code with no config/infra changes, no bot comments, and no architecture violations.

### 2.5. Mechanical Checks (run before agents — cheap, fast signals)

Before launching any agents, run these in parallel (~5s total):

```bash
# 1. Linter on changed files only
<project-linter> <changed-files>  # e.g., ruff check, eslint

# 2. Import/collection check on changed test files
pytest --collect-only <changed-test-files>  # catches ModuleNotFoundError, broken imports

# 3. Tests covering changed code
<project-test-cmd> <relevant-test-files>

# 4. Convention violation scan
# Read each convention doc referenced in CLAUDE.md (e.g., DOMAIN_CONVENTIONS.md, DTO_CONVENTIONS.md)
# For each checklist item, grep the diff for violations
```

**Why before agents**: Lint and test failures are objective, instant, and high-signal. Discovering them after 3 minutes of agent analysis wastes the agent's context (it analyzed code that will change). Convention checklists catch violations that agents miss because agents don't read convention docs unless prompted.

**Import verification**: Linters catch style issues but not `ModuleNotFoundError`. Always run `pytest --collect-only` on changed test files — it catches broken imports before any test executes. This is especially important when the PR introduces new modules or changes import paths.

**Stacked PRs** (base is a feature branch, not main/develop): Dependencies from the base branch may not exist on the PR branch in isolation. **Always merge the base branch locally** before running any checks (`git merge --no-commit origin/<base-branch>`). This is not optional — without it, mechanical checks produce noise (ModuleNotFoundError) instead of signal (actual code quality issues). Run checks on the merged state, then reset. If merge has conflicts, document the limitation. Never skip this step and never report "missing imports" as a finding when the cause is an unmerged parent branch.

**Record findings from this step** — they feed directly into the report. Don't duplicate these checks in agent prompts.

**Test evidence check**: If mechanical checks reveal failures the dev should have caught (import errors, syntax errors, test failures), flag this explicitly in the report. The PR's "Tests pass locally" checkbox is insufficient — request test output as evidence in the review comment.

### 2.7. Detect Verification Pass

If this is a round N+1 review where all prior findings were reportedly fixed:

- **Use lightweight flow**: Skip agents entirely. Instead:
  1. For each prior finding, verify the fix commit exists and addresses the finding
  2. Run mechanical checks (Step 2.5)
  3. Spot-check convention compliance on newly added code only
  4. Write a short verification report (not the full template)
- **Escalate to full review only if** mechanical checks reveal new issues or fix verification fails

**Why**: A verification pass that launches 3 agents for 3 minutes each to confirm "yes, the fixes landed" is a 10-minute tax on every review cycle. The prior round already did the deep analysis.

### 3. Launch Parallel Analysis Agents

Use the Task tool to launch these agents **in parallel**. **Agents must not write files** — they return findings to the main process, which synthesizes the report.

**Critical**: For PR reviews, ensure agents work on the PR branch HEAD. Include in each agent prompt: "You are reviewing branch `<branch>` at commit `<sha>`. Fetch and checkout before reading files."

**a. Code Review** (pr-review-toolkit:code-reviewer)
- Check adherence to project CLAUDE.md guidelines
- Style consistency, naming conventions
- Identify potential bugs or logic errors

**b. Silent Failure Hunt** (pr-review-toolkit:silent-failure-hunter)
- Identify swallowed errors, empty catch blocks
- Check for inappropriate fallback behavior
- Flag missing error propagation
- **Analyze try-block scope**: check what *all* is inside each try block, not just the except handler. If unrelated operations (logging, caching, metrics) share a try block with the core operation, a failure in the secondary operation can incorrectly trigger the error path for the primary one.

**c. Type Design Analysis** (pr-review-toolkit:type-design-analyzer)
- Only if new types/interfaces are introduced
- Review encapsulation and invariant expression
- Skip if no new types in diff

**d. Comment Quality** (pr-review-toolkit:comment-analyzer)
- Only if significant comments/docstrings were added
- Check accuracy against implementation
- Skip if no meaningful comment changes

### 4. Synthesize and Save Report

Combine all agent outputs into a single structured report. **Always save to file — do not output the full report to chat.**

**Mandatory sections** (never skip regardless of PR size):
- **Spec Compliance**: requirement-by-requirement table cross-referencing spec, issue, and ADRs
- **Root Cause Analysis / Spec Divergence Analysis**: for every finding, trace whether the dev followed stale/ambiguous docs or made an independent error. Include a timeline showing when specs, conventions, and the PR were created. This is the most valuable part of the review for the team — it surfaces doc problems that cause recurring issues across PRs.
- **Documentation fixes applied**: when spec/issue updates are made, list them with commit hashes

**File naming**: `docs/reviews/YYYY-MM-DD-<scope>.md` where scope is:
- `pr-<number>` for PR reviews
- `branch-<name>` for branch reviews
- `local` for unstaged/staged changes
- Append `-r2`, `-r3` for iterative rounds on the same scope

**Chat output**: After saving, output **only** a brief summary (~5-7 lines) with:
- Finding counts by severity (Critical, Warnings, Suggestions)
- Link to the full report file
- Any immediate action needed

**Do not paste the full report to chat.** The file is the source of truth.

Full report template (for file only):

```markdown
# Review Report

**Scope**: <what was reviewed>
**Files**: <count> files, <additions>+/<deletions>-
**Date**: YYYY-MM-DD

## Summary

<2-3 sentence overall assessment>

## Findings

Every finding has a unique ID (C1, W1, S1) for cross-referencing in fix guides, reviewer-applied fixes, and spec compliance tables. Use structured multi-line format — not wall-of-text paragraphs.

### Critical (must fix before merge)

**C1** — Short title ✅/⏳ `commit` or status
- **File**: `file.py:line`
- **Principle**: The design rule being violated.
- **Issue**: What's wrong and what happens at runtime.

### Warnings (should fix)

**W1** — Short title ✅/⏳ `commit` or status
- **File**: `file.py:line`
- **Issue**: Description of concern.

### Suggestions (nice to have)

**S1** — Short title ✅/⏳ `commit` or status
- **File**: `file.py:line`
- **Issue**: Improvement opportunity.

## Agent Reports

### Code Quality
<Summarized findings from code-reviewer>

### Error Handling
<Summarized findings from silent-failure-hunter>

### Type Design
<Summarized findings from type-design-analyzer, or "No new types introduced">

### Comment Quality
<Summarized findings from comment-analyzer, or "No significant comment changes">

## Image Evaluation

Screenshots attached to the PR, evaluated against spec/design expectations.

| Screenshot | What it shows | Expected | Matches? | Notes |
|------------|---------------|----------|----------|-------|
| `screenshot.png` | What the screenshot depicts | What spec/design requires | ✅/⚠️/❌ | Details |

*If no screenshots attached: "No screenshots provided — request from PR author if UI changes are involved."*
*Omit this section entirely if the PR has no UI changes.*

## Spec Compliance

Cross-reference implementation against the PRD/spec requirements.

| Requirement (from spec) | Status | Evidence | Gap |
|--------------------------|--------|----------|-----|
| Requirement text | ✅/❌ | How verified | Missing feature or — |

*Source: link to PRD/spec section. Omit this section if no spec exists for the work.*

## Spec Divergence Analysis

When the spec/issue contains stale or inconsistent instructions, findings must be attributed to their root cause. Not all "wrong code" is a developer mistake — some is caused by following incorrect documentation.

| Finding | What dev followed | What's correct | Root cause |
|---------|-------------------|----------------|------------|
| ID | Spec/issue instruction | Convention or correct spec section | **Stale spec** / **Dev issue** |

For each **stale spec** finding: note what doc needs updating and whether the reviewer will apply the code fix (since it's not the dev's fault). For each **dev issue**: the dev is responsible for fixing it.

*Omit this section if spec and implementation are aligned. Include whenever findings trace to documentation inconsistencies — this surfaces the real problem (docs, not people) and prevents the same issue on future PRs.*

## Previous Review Findings

Track status of findings from prior review rounds on the same PR/branch.

| ID | Finding (from round N) | Status | Resolution |
|----|------------------------|--------|------------|
| R1-C1 | Finding description | ✅ Resolved / ⏳ Pending | Commit hash or reason |

*First review: omit this section. Subsequent reviews: carry forward all prior findings.*

## Bot Comments Verification

Automated review comments (Gemini, CodeRabbit, etc.) verified against actual code.

| Bot | Comment | Claim | Verified? | Verdict |
|-----|---------|-------|-----------|---------|
| bot-name | Comment summary | What it claims | ✅/❌ | Action taken or why wrong |

*Rule: never agree with a bot comment without verifying — treat as unverified claim.*

## Finding Provenance (for round 2+ reviews)

Classify each new finding by origin to surface review process failures:

| Finding | Origin | Explanation |
|---------|--------|-------------|
| ID | pre-existing / review-induced / genuinely new | Why it wasn't caught before, or how a prior fix created it |

**Origin categories**:
- **Pre-existing**: Was in the original code but missed in prior rounds, OR the dev partially applied a correct fix guide (e.g., updated imports but didn't rename the file). Root-cause the gap (depth of analysis? wrong focus area? incomplete execution by dev?).
- **Review-induced**: The fix guide itself was wrong, imprecise, or led to a bug even when followed correctly. This is a review failure — the fix guide prescribed something that doesn't work. A dev partially applying correct instructions is NOT review-induced — that's pre-existing (incomplete fix).
- **Genuinely new**: Appeared in commits made since the last review (new code, not a response to review feedback).

*Omit this section on first review. On subsequent rounds, every new finding MUST be classified.*

## Convention Updates

New patterns or architectural decisions surfaced by this review that should be codified.

| Convention Doc | Action | Description |
|----------------|--------|-------------|
| `docs/CONVENTIONS.md` | New / Update / Violated | What to add, change, or reference |

*Omit this section if no convention updates are needed.*

## Verdict

[ ] Ready to merge
[ ] Needs changes (see Critical findings)
[ ] Needs discussion (see Open Questions)

## Reviewer-Applied Fixes

When the reviewer applies code fixes (typically for spec-divergence issues that are not the dev's fault), list them with commit hashes. Each finding resolved by a reviewer fix must be marked ✅ with the commit hash inline.

| Fix | Commit | Findings resolved |
|-----|--------|-------------------|
| Short description | `abc1234` | C1, C2, W1 |

*Omit this section if the reviewer did not apply any fixes. See §6 "Reviewer-applies-fixes" for rules.*

## Fix Guide (if Critical or Warning findings exist)

For each fixable finding, provide:
1. **Resolves** — list the finding IDs this fix addresses (e.g., "C4", "W4, W5, W6, S2")
2. **Principle** — the design rule being violated (e.g., "single source of truth", "fail visibly")
3. **What to change** — concrete fix description (not just "consider improving")
4. **Propagation check** — other locations where the same anti-pattern may exist (grep result or "checked, no other instances")
5. **Why** — what breaks or degrades without the fix

**Fix guide rules**:
- State the **principle first**, then the mechanism. A fix guide that says "use Literal" when an enum already exists teaches the wrong lesson. Say "single source of truth for status values — use the existing `JobStatus` enum" so the dev understands *why*, not just *what*.
- **Principle and entry point, not hand-holding.** State the principle and the key action. Don't enumerate every cascading file — the dev is responsible for following through on implications (updating imports, running tests, checking references). A rename is a cascade operation; the review says "rename to snake_case," not "rename file, then update __init__.py line 5, then update test_foo.py line 3."
- When a fix changes a pattern in one file, **grep the diff for the same anti-pattern** in other files. Fixing one side of an inconsistency without checking the other creates a new inconsistency.
- Never suggest an implementation without verifying it exists (types, methods, APIs). The fix guide is a contract — if the dev follows it literally and it introduces a new problem, that's a review failure.
- When a fix **removes behavior** (validation, error handling, a code path), explicitly state what to do with the **test that asserts that behavior** (remove it, update it, or defer it). A fix guide that says "remove the validation" without mentioning the test that expects `ValueError` creates a review-induced finding when the dev follows it literally.

Example:
> **[src/api/auth.py:42]** *Principle: fail visibly — exceptions should propagate or be logged, never swallowed.* Replace bare `except:` with `except ValueError:` — current code swallows all exceptions including KeyboardInterrupt. *Propagation: grep found no other bare `except:` in diff.*
```

### 5. Update Conventions

If any finding reveals a pattern that should be codified for the team:

- Check if a project-level conventions doc exists (`docs/CONVENTIONS.md` or similar)
- If a finding matches an existing convention: note that the convention was violated (the dev should have caught it)
- If a finding reveals a **new** pattern not yet codified: add it to the conventions doc
- If a prior convention was **wrong or incomplete** (e.g., caused a review-induced finding): update it
- If findings reveal patterns for a **layer that has no convention doc yet**: propose creating one in the Convention Updates table (Action: "Propose new doc"). Include the specific patterns that would seed it. Don't block the review on creating the doc — just flag it as a follow-up.

Convention updates are part of the review's output — they prevent the same finding from recurring in future PRs.

### 6. Save Report and Post Review

#### Branch placement rules

| Artifact | Branch | Why |
|----------|--------|-----|
| Review report (`docs/reviews/`) | **PR branch** | It's about the PR's code — lives with the code being reviewed |
| Convention docs (`docs/*_CONVENTIONS.md`) | **develop** | Project-wide standards, not PR-specific |
| ADRs (`docs/decisions/`) | **develop** | Project-wide decisions, not PR-specific |
| Task spec updates (`docs/tasks/`) | **develop** | Specs are source of truth independent of PRs |

#### Reviewer-applies-fixes

When the user asks the reviewer to apply the fix guide directly (e.g., PR is old, already has one round of revision, or fixes are trivial), the reviewer may commit fixes to the PR branch. Rules:

- One commit per fix — atomic, semantic messages (not `fix: review of pr`)
- Update the review report with each fix commit hash
- Update the verdict to reflect the new state
- This is **not the default** — fixes are the dev's responsibility unless the user explicitly requests otherwise

#### Execution order

1. **Checkout the PR branch** and commit the review report there. Push.
2. **Checkout develop** and commit any convention updates, ADRs, or spec changes. Push.
3. **User revision gate**: Present the review summary in chat and **wait for the user to approve** before posting to GitHub. The user may want to edit findings, adjust severity, or rephrase before the team sees it. Never auto-post.
4. **Post to GitHub** (only after user approval):
   - **R1**: Submit a GitHub review (`gh pr review`) with the summary.
   - **R2+**: Post a new PR comment (`gh pr comment`) — never overwrite a prior round's review. Each round's review is a historical record.
   - **Same-round dedup only**: If you accidentally post the same round twice, edit the duplicate (`gh api ... --method PUT`). "Duplicate" means the exact same round posted twice, not a new round on the same PR.

Always save the report to `docs/reviews/YYYY-MM-DD-<scope>.md` (create directory if needed). Scope naming: `pr-<number>` for PRs, branch name for branch reviews, `local` for unstaged/staged changes. For round 2+ reviews on the same scope, append `-r2`, `-r3` etc.

Output a brief summary to the conversation with findings count by severity and a link to the saved file. The full report lives in the file, not the chat.

### 6.5. Scope Check

Compare each changed file against the PR's stated architecture layer (from the PR template's "Architecture Layer" section).

- If a file belongs to a **different layer** (e.g., API contracts in a domain entity PR, infrastructure config in an application layer PR), flag it as out of scope.
- **Why**: Files from other layers will be reviewed in their own PR with the right context. Premature additions (like documenting API endpoints before they exist) become stale if the design changes during implementation.

### 6.7. Process Feedback

When the review surfaces workflow issues beyond code quality, post a separate PR comment (not in the review report) addressing the dev directly. Examples:

- **Commit hygiene**: Generic messages like `fix: review of pr` — advise semantic, atomic commits (one per fix).
- **Test evidence**: If mechanical checks caught failures the dev should have seen — ask whether tests were run, request output as evidence.
- **Artifact preservation**: If review reports or other artifacts were deleted — explain why they must be preserved.
- **Comment quality**: Non-informational PR comments ("Ciente", "Atualizado") — advise that commits communicate updates; comments should add context not obvious from the diff.

This feedback is educational, not part of the formal review findings. Keep it constructive — the goal is to help the dev build better habits, not to lecture.

### 7. Propagate Decisions

When a review produces an ADR or changes a contract (port shape, entity API, convention), propagate to all consumers before considering the work done:

1. **Grep `docs/tasks/`** for references to the changed interface/pattern — update affected specs
2. **Find linked GitHub issues** for affected tasks (`gh issue list`) — update issue bodies to match specs
3. **Check sibling PRs** in the same stack — note required changes in the review comment

**Why this is a step and not optional**: Specs and issues that reference a superseded design become "dead docs" that misinform. The cost of updating 3 issues now is 5 minutes; the cost of a dev implementing against a stale issue is a full review cycle.

ADRs contain **only** Context → Options → Decision → Consequences. Action items go in the review fix guide or issue updates, never in the ADR.

## Design Principles

- **Parallel execution**: All agents run simultaneously to minimize wait time
- **Skip irrelevant agents**: Don't run type-design-analyzer if no types changed
- **Actionable output**: Every finding references a specific file and line
- **Severity tiers**: Critical vs Warning vs Suggestion prevents alert fatigue
- **No false urgency**: Only "Critical" blocks merging

## Integration

```
/prd     → spec file
/next    → implementation
/review  → quality gate    ← THIS COMMAND
/wrap-up → commit and ship
```

## Review Termination Rules

Reviews must converge. Without stopping rules, each round's fixes create surface area for the next round — diminishing returns that block shipping.

### When to stop

A PR is **ready to merge** when ALL hold:

1. **No critical findings** — nothing that causes data loss, security vulnerability, or silent corruption
2. **No warnings from the current round** — all warnings either fixed or explicitly deferred with rationale
3. **Review-induced findings are resolved** — if a prior fix guide introduced a new issue, fix it in the same round (reviewer's responsibility, not the dev's)

### Maximum rounds

- **Hard cap: 3 rounds of code changes** (R1 review → fixes → R2 review → fixes → R3 review → fixes → final verification)
- The "final check" after round 3 fixes is a **verification pass only** — confirm fixes landed, no new findings. If new issues appear, they go to a follow-up PR/issue unless critical
- If round 3 still has critical findings, escalate to synchronous discussion (call/pairing) instead of another async round

### What counts as a "round"

- A round = review + fix commit(s). Counted by fix cycles, not review comments
- Multiple review comments in a single GitHub review = 1 round
- Fixup commits addressing the same review = still the same round

### Deferral rules by round

| Round | Critical | Warnings | Suggestions |
|-------|----------|----------|-------------|
| 1 | Must fix | Must fix | Fix or defer |
| 2 | Must fix | Must fix | Defer to follow-up |
| 3+ | Must fix | Fix or defer (with rationale) | Defer to follow-up |

### Fix guide discipline (prevents review-induced findings)

When writing a fix guide that restructures error handling (try/except boundaries, error propagation):
1. Verify all moved code lands in a protected block or is provably infallible
2. Check that callbacks/lifecycle hooks account for new failure modes
3. State the **principle** first, then the mechanism — so the dev can adapt if the mechanism doesn't fit

**Provenance**: PR #127 produced 3 review-induced findings across 4 rounds. Common cause: fix guides that prescribed mechanism without verifying full consequence of structural changes.

## Anti-Patterns

- Don't review files that weren't changed — focus on the diff
- Don't run all 4 agents if the change is 5 lines — use judgment
- Don't launch agents for verification passes (round N+1 where all findings were fixed) — use Step 2.7 lightweight flow
- Don't let agents write to the repo (reports, convention docs) — agents return findings, the main process writes artifacts
- Don't block on suggestions — only Critical findings are blockers
- Don't duplicate what CI already catches (lint, format, type-check) — but DO run the linter yourself in Step 2.5 since CI may not have run yet
- Don't skip the convention checklist scan (Step 2.5) — agents miss convention violations because they don't read convention docs unless explicitly prompted
- Don't sleep-poll for agent completion — launch agents in background, do mechanical checks (Step 2.5) in foreground, then synthesize when both are ready
- Don't skip Step 1.5 on iterative reviews — re-deriving context from scratch is slower and risks contradicting prior decisions
- Don't prescribe mechanism without principle in fix guides — "use Literal" without "because single source of truth" leads to review-induced bugs
- Don't fix a pattern in one file without grepping for the same pattern elsewhere in the diff — partial fixes create new inconsistencies
- Don't focus only on the `except` handler — always check what's inside the `try` block and whether unrelated operations share the same error path
- Don't start a new round after the 3-round cap — defer to follow-up PR/issue. Perfectionism in reviews has diminishing returns
- Don't commit review reports to develop — they belong on the PR branch (see Step 6 branch placement rules)
- Don't put action items in ADRs — ADRs are decisions, not task trackers. Action items go in the fix guide or issue updates
- Don't update only the directly affected task spec — grep for all consumers of a changed contract (ports, entity APIs) across `docs/tasks/` and GitHub issues
- Don't overwrite a prior round's GitHub review with the current round — each round is a historical record; post R2+ as a new PR comment
- Don't enumerate every cascading file in fix guides — state the principle and entry point; the dev owns the follow-through
- Don't post PR comments or reviews to GitHub without the user's explicit approval — present the summary in chat first and wait
