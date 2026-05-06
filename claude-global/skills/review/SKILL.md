---
name: review
description: Comprehensive code review — analyzes PR or branch changes with parallel agents, produces a structured report with spec compliance, root cause analysis, and fix guide. Use for /review pr <N>, /review branch, /review staged, /review files.
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(uv run *), Bash(PYTHONPATH=* uv run *), Bash(cd * && uv run *), Bash(ruff *), Bash(pytest *), Bash(ls *), Write, Edit, Agent
---

# /review — Comprehensive Code Review

Generate a structured review report for recent changes, combining multiple specialized analysis agents. Produces a file artifact reviewable asynchronously.

## Usage

```
/review [scope]
```

**Scopes**:
- **(empty)** — unstaged changes in current repo
- `staged` — only staged changes
- `branch` — all commits on current branch vs base
- `pr <number>` — specific PR
- `files path1 path2` — specific files

---

## Workflow

### Step 0 — Checkout PR Branch

For `pr` and `branch` scopes, checkout the target branch before any work:

```bash
git fetch origin <pr-branch>
git checkout <pr-branch>
git pull
```

**Stay on this branch for the entire review session.** Convention updates and ADRs go to develop last — after the user approves the report.

---

### Step 1 — Determine Diff Scope

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

---

### Step 1.5 — Load Prior State

Before forming any opinions:

**Same-PR history (mandatory for R2+):**
- Check `docs/reviews/` on the PR branch for existing reports. Read the most recent one in full.
- Read all prior review bodies: `gh pr view <number> --json reviews,comments`
- If the prior review links a spec, read it.

**Recent cross-PR reviews (mandatory for all rounds):**

```bash
# 1. List all recent PRs
gh pr list --state all --limit 15 --json number,title,headRefName,state,updatedAt

# 2. For each branch with recent activity, check for review files
git show origin/<branch>:docs/reviews/ 2>/dev/null

# 3. Read the 2-3 most recent review files in full
git show origin/<branch>:docs/reviews/<file>.md
```

**Never read only from files on the current branch** — those only reflect what merged into this branch's ancestors, missing reviews on parallel open PRs.

Use cross-PR reviews to:
- Detect recurring anti-patterns across the same developer's PRs
- Enforce conventions established in sibling reviews this week
- Calibrate depth — match the analysis level of recent reports
- Avoid contradicting decisions made in concurrent reviews

**Sibling-PR finding carryover (mandatory when a finding mirrors a sibling review):**

When you file a finding that is "the same issue as PR #N's NX" (shared file, shared code, or shared design pattern), check whether that sibling PR's review already created a tracking issue for it:

```bash
# Search by keywords from the sibling finding's title
gh issue list --state all --search "<keyword from finding>" --limit 10 --json number,title,state

# Fallback: list recent issues and scan
gh issue list --state all --limit 30 --json number,title,state
```

If a tracking issue exists, reference it in the Fix Guide / follow-up section by number (e.g., "tracked in #81") instead of proposing to open a new one. Opening a duplicate issue is a process failure: it fragments the conversation and the dev gets two notifications for one concern.

**Spec/issue alignment (mandatory):**
- Find task-specific spec on the base branch: `git show origin/develop:docs/tasks/task-NNN-*.md`
- Read the linked GitHub issue body
- Compare issue AC vs spec subtask AC — divergences are process failures, not dev failures

**Convention revision histories (read before reviewing):**

```bash
# Read the Revision History section of each relevant convention doc
git show origin/develop:docs/DOMAIN_CONVENTIONS.md | grep -A 20 "## Revision History"
git show origin/develop:docs/APPLICATION_CONVENTIONS.md | grep -A 20 "## Revision History"
git show origin/develop:docs/ARCH_CONVENTIONS.md | grep -A 20 "## Revision History"
```

Revision histories record aged-out rules, when they changed, and why. Reading them prevents filing a finding that is already a known convention debt — and surfaces which open PRs may carry the same risk.

**Depth calibration is mandatory on first reviews.** Read at least one recent report in full before writing anything. If recent reports have Root Cause Analysis timelines, dual spec compliance tables, and bot verification — yours must too.

---

### Step 2 — Cross-Environment Context Gathering

Skip if pure application code with no config/infra changes, no bot comments, no architecture violations.

**For config/infra changes**: grep all environment files for the same setting; compare across environments.

**For architecture/convention violations**: grep spec, issue body, and convention docs for the exact pattern before attributing it to the dev. Do spec archaeology — check the spec as it existed when the dev started:
```bash
git log --format="%ai %s" -- docs/tasks/task-NNN-*.md
git show <commit-before-PR>:docs/tasks/task-NNN-*.md
```

**For bot comments**: read all bot comments (`gh pr view <N> --json reviews,comments`), treat each as an unverified claim, verify against code and docs before agreeing.

---

### Step 2.5 — Mechanical Checks

Run in parallel before launching agents:

```bash
# 1. Linter on changed files
uv run ruff check <changed-files>

# 2. Import/collection check (catches ModuleNotFoundError before test run)
PYTHONPATH=. uv run pytest --collect-only <changed-test-files>

# 3. Tests covering changed code
PYTHONPATH=. uv run pytest <relevant-test-files> -v

# 4. Convention violation scan
# Read each convention doc in CLAUDE.md, grep diff for checklist items
```

**Stacked PRs**: merge the base branch locally before running checks:
```bash
git merge --no-commit origin/<base-branch>
# run checks, then git merge --abort
```
Never report "missing imports" when the cause is an unmerged parent branch.

**Runtime behavior verification (mandatory for every Critical finding):**

Every finding that claims "this code fails at runtime" or "this behavior is wrong" must be verified with a reproducible `uv run python -c "..."` script before being filed. Reading the code and believing it fails is not enough.

When a line has an **explanatory comment** (e.g., `# ID will be generated by the repository`), verify that the comment's claim is true — run or trace the full call chain. A comment that contradicts the implementation is itself a finding. Never verify only the single flagged line in isolation; verify the entire stated intent.

```bash
# Example: verifying a claimed runtime failure
PYTHONPATH=. uv run python -c "
from domain.entities.zone import Zone
from domain.enums.zone_type import ZoneType
try:
    Zone(zone_id='', name='t', camera_id='c', zone_type=ZoneType.RESTRICTED, polygon=[(0,0),(1,0),(1,1)])
    print('BUG: succeeded unexpectedly')
except ValueError as e:
    print('Confirmed failure:', e)
# Also verify the call chain claim in the comment:
from infrastructure.persistence.zone_repository import ZoneRepository
import inspect
print('Repository.create source:', inspect.getsource(ZoneRepository.create))
"
```

Record all findings from this step — they feed directly into the report.

---

### Step 2.7 — Detect Verification Pass

If this is R2+ and all prior findings were reportedly fixed, use the **lightweight flow**:
1. For each prior finding, verify the fix commit exists and addresses it
2. Run mechanical checks (Step 2.5)
3. Spot-check newly added code for convention compliance
4. Write using the **Verification Pass Template** (see Step 4.5) — not the full template

**A verification pass still requires all mandatory sections** — it just has shorter content in each. "Short" means fewer findings, not missing sections.

Escalate to full review if mechanical checks reveal new issues or fix verification fails.

---

### Step 3 — Launch Parallel Analysis Agents

Skip for verification passes. For full reviews, launch in parallel using the Agent tool. Agents must not write files — they return findings to the main process.

Include in each agent prompt: "You are reviewing branch `<branch>` at commit `<sha>`. Fetch and checkout before reading files."

**a. Code Review** (`pr-review-toolkit:code-reviewer`) — style, conventions, bugs, CLAUDE.md adherence

**b. Silent Failure Hunt** (`pr-review-toolkit:silent-failure-hunter`) — swallowed errors, wrong fallback, missing propagation, try-block scope (what's inside the try, not just the except)

**c. Type Design** (`pr-review-toolkit:type-design-analyzer`) — only if new types introduced; encapsulation, invariant expression

**d. Comment Quality** (`pr-review-toolkit:comment-analyzer`) — only if significant comments/docstrings added

---

### Step 4 — Write Full Review Report

Use this template for first reviews and for R2+ reviews where new critical/warning findings were found.

Save to `docs/reviews/YYYY-MM-DD-pr-<N>.md` (append `-r2`, `-r3` for subsequent rounds).

**Do not paste the full report to chat.** Save to file, then output a 5-7 line summary to chat with finding counts and the file link.

```markdown
# Review Report — PR #<number>

**Scope**: PR #<number> — `<PR title>`
**Base**: `<base-branch>`
**Author**: <login> (<full name>)
**Files**: <count> files, <additions>+/<deletions>-
**Date**: YYYY-MM-DD
**Round**: <N>
**PR**: <URL>
**Spec**: `<spec path>` (<subtask>)
**Issue**: #<number>

**Mechanical checks**: Linter: <N violations>. Tests: <N/N pass> (`<exact command>`). Import collection: <clean/errors>.

---

## Summary

<2-3 sentences: what's well-done, what blocks merge, any cross-PR concerns.>

---

## Findings

Every finding has a unique ID (C1, W1, S1) for cross-referencing.

### Critical (must fix before merge)

**C1** — <Short title> ⏳
- **File**: `file.py:line`
- **Principle**: The design rule being violated.
- **Issue**: What's wrong and what happens at runtime.
- **Evidence**: How you verified this (test output, grep, code trace).
- **Downstream impact**: What breaks if unfixed.

### Warnings (should fix)

**W1** — <Short title> ⏳
- **File**: `file.py:line`
- **Principle**: Rule or convention reference.
- **Issue**: Description of concern.
- **Evidence**: How you verified.
- **Downstream impact**: What degrades if unfixed.

### Suggestions (nice to have)

**S1** — <Short title> ⏳
- **File**: `file.py:line`
- **Issue**: Improvement opportunity.

---

## Agent Reports

### Code Quality
<Summarized findings. Include positives (what follows conventions well) alongside issues.>

### Error Handling
<Summarized findings from silent-failure-hunter.>

### Type Design
<Summarized findings, or "No new types introduced.">

### Comment Quality
<Summarized findings, or "No significant comment changes.">

---

## Scope Check

| File | Layer | In PR scope? |
|------|-------|--------------|
| `path/to/file.py` | Domain / Application / Infrastructure / Interface | ✅ / ❌ Out of scope |

---

## Spec Compliance

### Issue #<N> Acceptance Criteria (dev's actual contract)

| Requirement (from issue) | Status | Evidence |
|--------------------------|--------|----------|
| Requirement text | ✅/❌/⚠️ | File:line or test name |

**Result**: X/Y issue criteria met.

### Spec Subtask <ID> (authoritative requirements)

| Requirement (from spec) | Status | Evidence | Gap |
|-------------------------|--------|----------|-----|
| Requirement text | ✅/❌/⚠️ | How verified | Finding ID or — |

**Result**: X/Y spec criteria met.

### Spec Component Specification (full spec, beyond subtask scope)

| Field/Requirement | In subtask scope? | Implemented? | Notes |
|-------------------|------------------|--------------|-------|
| Field or method | ✅/❌ | ✅/❌ | S1 — reason |

*Sources: spec path, issue URL.*

---

## Root Cause Analysis

### Timeline

| Date | Event | Relevance |
|------|-------|-----------|
| YYYY-MM-DD | Issue created | Dev's work contract |
| YYYY-MM-DD | Spec committed (`hash`) | Authoritative requirements |
| YYYY-MM-DD | First PR commit (`hash`) | Implementation started |
| YYYY-MM-DD | Convention docs created | When rules became binding |
| YYYY-MM-DD | PR opened | — |
| YYYY-MM-DD | This review | — |

### Issue↔Spec Scope Alignment

<Compare issue AC vs spec subtask AC. If they diverge, attribute the gap to process (stale issue), not the dev.>

### Finding Attribution

| Finding | Root cause | Classification |
|---------|------------|----------------|
| C1 | Description | **Dev issue** / **Spec-caused** / **Process gap** / **Dev oversight** |

### Cross-PR Patterns

| Pattern | PRs | Notes |
|---------|-----|-------|
| Anti-pattern description | PR #N, PR #M | Frequency, same dev or project-wide |

---

## Spec Divergence Analysis

### Divergences where the dev is correct (spec needs updating)

| Finding | What dev did | What spec says | Root cause | Resolution |
|---------|-------------|----------------|------------|------------|
| Description | Dev's choice | Spec text | **Stale spec** | ✅ `hash` / ⏳ pending |

### Divergences that are design decisions (need team alignment)

| Finding | What dev did | What spec says | Impact |
|---------|-------------|----------------|--------|

### Divergences caused by subtask scoping (not gaps)

| Field | In subtask scope? | In full component spec? | Status |
|-------|-------------------|------------------------|--------|

*Omit subsections with no entries.*

---

## Previous Review Findings

*First review: omit this section.*

| ID | Finding (from round N) | Status | Resolution |
|----|------------------------|--------|------------|
| R1-C1 | Finding description | ✅ Resolved / ⏳ Pending | Commit hash or reason |

---

## Bot Comments Verification

| Bot | Comment summary | Verified? | Verdict |
|-----|-----------------|-----------|---------|
| gemini / copilot | What it claims | ✅/❌ | Action taken or why wrong |

*Verify against current HEAD. Note bot's `submittedAt` vs PR commit log — bot may have reviewed earlier code.*

---

## Finding Provenance

*First review: omit this section. R2+: every new finding must be classified.*

| Finding | Origin | Explanation |
|---------|--------|-------------|
| ID | pre-existing / review-induced / genuinely new | Why it wasn't caught before, or how a prior fix created it |

**Origins**:
- **Pre-existing**: In original code, missed in prior rounds
- **Review-induced**: Fix guide was wrong/imprecise — reviewer failure
- **Genuinely new**: Appeared in commits since the last review

---

## Convention Updates

| Convention Doc | Action | Description | Status |
|----------------|--------|-------------|--------|
| `docs/CONVENTIONS.md` | New / Update / Violated | What to add or change | ✅ `hash` / ⏳ proposed |

*Omit if no convention updates needed.*

---

## Verdict

[ ] Ready to merge
[ ] Needs changes (see Critical/Warning findings)
[ ] Needs discussion

<Which findings are dev-owned, which are spec-caused, what blocks merge.>

---

## Process Feedback

*Omit if no recurring workflow issues.*

- **Lint**: <count + cross-PR pattern if recurring>
- **Tests**: <gaps in test strategy>
- **Coordination**: <cross-PR concerns>
- **Commit hygiene**: <generic messages, missing evidence>

---

## Documentation Fixes Applied (by reviewer)

| Fix | Branch | Commit | Description |
|-----|--------|--------|-------------|

*Omit if reviewer applied no doc fixes.*

---

## Reviewer-Applied Fixes

| Fix | Commit | Findings resolved |
|-----|--------|-------------------|

*Omit if reviewer applied no code fixes.*

---

## Fix Guide

For each C/W finding:

1. **Resolves** — finding IDs
2. **Principle** — the design rule (e.g., "single source of truth", "fail visibly")
3. **What to change** — concrete action with key entry point (not every cascading file)
4. **Propagation check** — grep result or "checked, no other instances"
5. **Why** — what breaks without the fix

When a fix **removes behavior**, state what to do with the test asserting that behavior.
When a fix guide prescribes logging, specify format: `logger.warning("msg %s", var)` not f-strings.
```

---

### Step 4.5 — Verification Pass Template

Use this template for R2+ where all prior findings were reportedly fixed. **All sections are still required** — "short" means fewer findings, not missing sections. Sections with no content get one line (e.g., "No new bot comments since R1.").

```markdown
# Review Report — PR #<number> (Round <N>)

**Scope**: PR #<number> — `<PR title>`
**Branch**: `<head>` → `<base>`
**Author**: <login> (<name>)
**Files**: <count> files, <additions>+/<deletions>-
**Date**: YYYY-MM-DD
**Round**: <N> (verification pass)
**PR**: <URL>
**Spec**: `<spec path>` (<subtask>)
**Issue**: #<number>
**Prior report**: [`<filename>`](<relative-link>)

**Mechanical checks**: Linter: <N violations>. Tests: <N/N pass> (`<exact command>`). Import collection: <clean/errors>.

---

## Summary

<2-3 sentences: which R(N-1) findings were resolved, what new findings (if any) were found, merge status.>

---

## Findings

### Critical

<None. — or findings with full C1/W1/S1 structured format including Evidence and Downstream impact>

### Warnings

<None. — or findings>

### Suggestions

<None. — or findings>

---

## Agent Reports

Skipped — verification pass. No agents launched.

---

## Scope Check

| File | Layer | In PR scope? |
|------|-------|--------------|

---

## Spec Compliance

### Issue #<N> Acceptance Criteria

| Requirement | R(N-1) Status | R<N> Status | Evidence |
|-------------|---------------|-------------|----------|
| Requirement | ❌ | ✅ | File:line |

**Result**: X/Y criteria met. <All previously failing criteria now pass / N criteria remain open.>

---

## Root Cause Analysis

*Omit Timeline and Issue↔Spec subsections if unchanged from prior round.*

### Finding Attribution

| Finding | Origin | Explanation |
|---------|--------|-------------|

### Cross-PR Patterns

| Pattern | PRs | Notes |
|---------|-----|-------|

---

## Previous Review Findings

| ID | Finding (from round N-1) | Status | Resolution |
|----|--------------------------|--------|------------|
| C1 | Description | ✅ Resolved / ⏳ Pending | Commit hash |

---

## Bot Comments Verification

<"No new bot comments since R(N-1)." — or table>

---

## Finding Provenance

| Finding | Origin | Explanation |
|---------|--------|-------------|
| NW1 | pre-existing / review-induced / genuinely new | Explanation |

*Every new finding must be classified.*

---

## Convention Updates

| Convention Doc | Action | Description | Status |
|----------------|--------|-------------|--------|

*Omit if none.*

---

## Verdict

[ ] Ready to merge
[ ] Needs changes (NW1, NW2)
[ ] Needs discussion

<Brief: dev-owned vs reviewer-owned findings, what blocks merge.>

---

## Process Feedback

*Omit if no recurring workflow issues.*

---

## Fix Guide

<Fixes for any new C/W findings. Omit if none.>
```

---

### Step 4.9 — Pre-Save Section Checklist

Before writing the report file, verify the draft has every required section. This step is **non-skippable** — the most common failure mode is saving a report missing mandatory sections.

Go through this list mentally (or literally) against the draft:

```
FULL REVIEW checklist:
[ ] Header (Scope, Author, Files, Date, Round, PR, Spec, Issue, Mechanical checks)
[ ] Summary
[ ] Findings (structured C1/W1/S1 with File, Principle, Issue, Evidence, Downstream impact)
[ ] Agent Reports (all 4 subsections, even if "Skipped" or "No new types")
[ ] Scope Check (file-by-file table)
[ ] Spec Compliance (Issue AC table + Spec table)
[ ] Root Cause Analysis (Timeline, Issue↔Spec alignment, Finding Attribution, Cross-PR Patterns)
[ ] Spec Divergence Analysis (all 3 subsections, omit empty ones)
[ ] Previous Review Findings (omit on R1; required on R2+)
[ ] Bot Comments Verification
[ ] Finding Provenance (omit on R1; required on R2+, every new finding classified)
[ ] Convention Updates (omit only if genuinely none)
[ ] Verdict
[ ] Process Feedback (omit only if genuinely none)
[ ] Documentation Fixes Applied (omit if none)
[ ] Reviewer-Applied Fixes (omit if none)
[ ] Fix Guide (required if any C or W findings exist)

VERIFICATION PASS additional checks:
[ ] All R(N-1) findings have explicit status (✅ Resolved or ⏳ Pending) in Previous Review Findings
[ ] Every new finding has a Finding Provenance entry (pre-existing / review-induced / genuinely new)
[ ] Spec Compliance table updated to show R(N-1) status → R(N) status
[ ] S2-type findings from prior rounds re-evaluated against sibling PRs (e.g., "scope bleed" may be intentional pre-work)
```

If any box is unchecked, fill the section before saving — even a one-liner is better than a missing section.

---

### Step 4.8 — Convention Archaeology

Run this step after finalizing findings, before writing Convention Updates. It catches a class of problem that per-finding analysis misses: a convention that was correct when written but has aged out as new types arrived.

**Trigger questions** (answer each in one sentence; skip if clearly N/A):

1. **Overgeneralization**: Was the convention written for a narrow set of types (e.g., domain events, early entities) and then applied uniformly to new types that have different semantics?
2. **Silent divergence**: Has the codebase already drifted away from this convention in files not touched by this PR? (Check with `grep -rn "@dataclass\b\|class.*:" backend/domain/`)
3. **Downstream risk**: Which open PRs introduce new types that the same aged convention would apply to incorrectly?
4. **Root cause chain**: Is the finding you filed a symptom of a wrong convention rather than a developer error?

**Process:**

```bash
# Check for divergence — example: frozen convention
grep -rn "@dataclass" backend/domain/ --include="*.py" | grep -v ".venv\|__pycache__"

# Check open PRs for types that might be affected
gh pr list --state open --json number,title,headRefName
```

If you find a convention that has aged out:
1. Update the relevant `docs/*_CONVENTIONS.md` on develop with the corrected rule and a Revision History entry (this IS the durable cross-session record — future sessions read revision histories in Step 1.5)
2. Re-classify affected findings as **pre-existing** (convention was wrong) rather than **dev-owned**
3. Note affected open PRs in the Convention Updates table and in the attack plan if one exists

---

### Step 5 — Update Conventions

If any finding reveals a new pattern or an existing convention was violated:
- Violated existing convention: note it in the Convention Updates table
- New pattern not yet codified: add to the relevant `docs/*_CONVENTIONS.md` on develop
- Convention was wrong/incomplete (caused a review-induced finding): update it, note in Finding Provenance
- Run Step 4.8 to check whether the violation is a symptom of an aged-out rule, not a one-off dev error

---

### Step 6 — Save Report and Post Review

#### Branch placement

| Artifact | Branch |
|----------|--------|
| Review report (`docs/reviews/`) | PR branch |
| Convention docs (`docs/*_CONVENTIONS.md`) | develop |
| ADRs (`docs/decisions/`) | develop |
| Task specs (`docs/tasks/`) | develop |

#### Execution order

1. Checkout PR branch → commit report → push
2. Checkout develop → commit convention/spec/ADR changes → push
3. **User revision gate**: present summary in chat, wait for approval before posting to GitHub
4. Post to GitHub (only after approval):
   - R1: `gh pr review <N> --comment --body "..."`
   - R2+: `gh pr comment <N> --body "..."` — never overwrite a prior round's review

#### Reviewer-applies-fixes

When user asks reviewer to apply fixes directly: one commit per fix, semantic message, update report with commit hash.

#### On approval ("PR approved" or equivalent)

When the user says the PR is approved, execute the full sequence without re-confirmation:
1. Apply all remaining reviewer-owned findings (one commit per fix)
2. Create GitHub issues for any deferred suggestions the user asks to track
3. Update the report: mark findings resolved with commit hashes, flip Verdict to "Ready to merge", push
4. Post the R2+ comment (`gh pr comment`) with R2 summary
5. Post the Step 8 closing comment (teaching + próximos passos)
6. Merge the PR (`gh pr merge <N> --merge`) — unless user says otherwise
7. Run **Step 9** — update PR review queue/log on develop so the post-merge state is durable

---

### Step 7 — Propagate Decisions

When a review produces an ADR or changes a contract:
1. Grep `docs/tasks/` for references to the changed interface — update affected specs
2. Find linked issues (`gh issue list`) — update issue bodies
3. Check sibling PRs in the same stack — note required changes

---

### Step 8 — Closing Comment (approval or final round)

When the PR is ready to merge — either because it was clean on first review or all findings are resolved — post a closing GitHub comment (separate from the formal review) that:

1. **States the verdict** clearly: approved, changes needed, or needs discussion
2. **Teaches, not just judges**: for each finding the dev needed to fix (or the reviewer fixed on their behalf), explain *why* the rule exists and what breaks without it. Phrase this as learning, not criticism — the goal is that the dev doesn't need the same feedback on the next PR
3. **Points to what was codified**: if convention docs were updated as a result of this review, mention the commit and section so the dev knows the rule is now official
4. **Closes the loop with next steps**: mention what unblocks from this merge (dependent PRs, tasks, or milestones that were waiting on this)

**Format**:
```
## Review — PR #<N> (Round <R>) ✅ Aprovado / 🔄 Alterações necessárias

**Report**: [link to review file]

### Resultado
<1-2 sentences: verdict and what was resolved/remains.>

### Para o dev — o que aconteceu e por que importa
<One section per non-trivial finding. For each:>
- What the rule is (concrete example: wrong vs right)
- Why the rule exists (runtime impact, not just "convention says so")
- Where it's codified if it was new

### Próximos passos
<What unblocks from this merge:>
- PR #N (task name) was waiting on this — can now be reviewed/merged
- Task XYZ moves to next phase
- Any open items deferred to follow-up issue
```

**Rules**:
- Post language matches the team's working language (Portuguese for this project)
- Keep each teaching point under ~8 lines — dense but not exhausting
- Never lecture on findings the dev got right — acknowledge what was well done
- "Próximos passos" is mandatory when sibling PRs or tasks depend on this merge

---

### Step 9 — Post-Merge Queue/Log Update

Run this **immediately after** `gh pr merge` succeeds. Skipping it leaves the queue showing the PR as "ready for review" or "blocked"; future sessions read the queue first and waste time re-deriving the merged state from `gh pr list`.

#### When this step applies

Only when the project tracks a PR review queue and/or log on develop. Detect via:

```bash
git ls-tree -r origin/develop --name-only | grep -E "docs/plans/(pr-review-queue|pr-review-log|attack-plan)"
```

If no queue/log file exists, skip Step 9 — but still mention in the closing chat summary that a queue update was N/A.

#### Execution order

1. `git checkout develop && git pull --ff-only`
2. **Queue file** (e.g., `docs/plans/pr-review-queue.md`): remove the merged PR from "Next Up" if listed; update the dependency graph node/label to reflect MERGED status; lift any "Blocked / Paused" entries whose blocker was this PR.
3. **Log file** (e.g., `docs/plans/pr-review-log.md`): mark the PR as `✅ MERGED YYYY-MM-DD (\`<merge-commit-sha>\`)` with the round at which it merged and a one-line closing summary; add a row to the "Convention Deltas" table for any convention/spec/ADR change committed during this review round; update the "Files by PR" risk table if the merged work changes the picture.
4. Commit on develop with a semantic message (`docs(plan): PR #<N> merged at R<round>`) and push.
5. Switch back to wherever you were (typically the merged PR's now-archived branch is fine to leave; it's already merged).

#### What to capture

| Item | Where | Why |
|------|-------|-----|
| Merge commit SHA | log row + queue node | enables `git show` lookup later |
| Round at merge (R1, R2, R3) | log row | tracks how many rounds the PR took |
| Reviewer-applied vs dev fixes | log row's resolution column | distinguishes process load from dev output |
| Closing comment URL | log row (optional) | quick link back to teaching content |
| Downstream PRs newly unblocked | queue's "Next Up" + dependency graph | tells next session what's reviewable now |
| Convention deltas committed | log's "Convention Deltas" table | durable cross-session record |
| Follow-up issues opened | log's "Follow-up Issues" section | so they don't slip |

#### Anti-patterns

- Don't try to make this commit on the PR branch — the PR branch is already merged; the queue/log lives on develop.
- Don't batch multiple PR merges into one queue update — one merge → one queue commit, so the audit trail aligns 1:1 with merge events.
- Don't update the queue without also lifting downstream blocks — the whole point is that the next session sees the unblock immediately.

---

## Review Termination Rules

| Round | Critical | Warnings | Suggestions |
|-------|----------|----------|-------------|
| 1 | Must fix | Must fix | Fix or defer |
| 2 | Must fix | Must fix | Defer to follow-up |
| 3+ | Must fix | Fix or defer (with rationale) | Defer to follow-up |

Hard cap: 3 rounds of code changes. After round 3, escalate to synchronous discussion.

A PR is **ready to merge** when: no critical findings, no warnings from the current round, review-induced findings resolved.

---

## Anti-Patterns

- Don't read cross-PR reviews from files on the current branch — use `gh pr list` + `git show origin/<branch>:docs/reviews/`
- Don't skip mandatory sections on verification passes — "short" means fewer findings, not missing sections
- Don't classify findings without Evidence and Downstream impact — assertions without verification are not findings
- Don't launch agents for verification passes — use Step 2.7 lightweight flow
- Don't prescribe mechanism without principle in fix guides ("use Literal" without "single source of truth")
- Don't fix a pattern in one file without grepping for it elsewhere in the diff
- Don't omit format guidance in fix guides (e.g., lazy logging `%s` vs f-strings)
- Don't attribute scope gaps to the dev without checking their actual contract (issue body, not just spec)
- Don't mark findings resolved incrementally without re-reading Verdict + Fix Guide for coherence
- Don't post to GitHub without user approval
- Don't commit review reports to develop — they belong on the PR branch
- Don't skip the pre-save section checklist (Step 4.9) — missing sections are the single most common review failure
- Don't file a Critical runtime finding without a reproducible `uv run python -c "..."` that demonstrates it — reading and believing is not evidence
- Don't verify a single line in isolation when the line has an explanatory comment — verify the full call chain the comment describes; a comment contradicting the implementation is itself a finding
- Don't stop at `gh pr merge` — Step 9 (queue/log update on develop) is the durable record; skipping it leaves the next session re-deriving merged state from `gh pr list`
