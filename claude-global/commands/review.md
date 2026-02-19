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

### 2. Launch Parallel Analysis Agents

Use the Task tool to launch these agents **in parallel**:

**a. Code Review** (pr-review-toolkit:code-reviewer)
- Check adherence to project CLAUDE.md guidelines
- Style consistency, naming conventions
- Identify potential bugs or logic errors

**b. Silent Failure Hunt** (pr-review-toolkit:silent-failure-hunter)
- Identify swallowed errors, empty catch blocks
- Check for inappropriate fallback behavior
- Flag missing error propagation

**c. Type Design Analysis** (pr-review-toolkit:type-design-analyzer)
- Only if new types/interfaces are introduced
- Review encapsulation and invariant expression
- Skip if no new types in diff

**d. Comment Quality** (pr-review-toolkit:comment-analyzer)
- Only if significant comments/docstrings were added
- Check accuracy against implementation
- Skip if no meaningful comment changes

### 3. Synthesize Report

Combine all agent outputs into a single structured report.

**Report format** (output directly to conversation):

```markdown
# Review Report

**Scope**: <what was reviewed>
**Files**: <count> files, <additions>+/<deletions>-
**Date**: YYYY-MM-DD

## Summary

<2-3 sentence overall assessment>

## Findings

### Critical (must fix before merge)
- **[file:line]** Description of issue

### Warnings (should fix)
- **[file:line]** Description of concern

### Suggestions (nice to have)
- **[file:line]** Improvement opportunity

## Agent Reports

### Code Quality
<Summarized findings from code-reviewer>

### Error Handling
<Summarized findings from silent-failure-hunter>

### Type Design
<Summarized findings from type-design-analyzer, or "No new types introduced">

### Comment Quality
<Summarized findings from comment-analyzer, or "No significant comment changes">

## Verdict

[ ] Ready to merge
[ ] Needs changes (see Critical findings)
[ ] Needs discussion (see Open Questions)

## Fix Guide (if Critical or Warning findings exist)

For each fixable finding, provide:
1. **File and line** — exact location
2. **What to change** — concrete fix description (not just "consider improving")
3. **Why** — what breaks or degrades without the fix

Example:
> **[src/api/auth.py:42]** Replace bare `except:` with `except ValueError:` — current code swallows all exceptions including KeyboardInterrupt.
```

### 4. Optionally Save Report

If reviewing a branch or PR (not just local changes), offer to save:

**Location**: `docs/reviews/YYYY-MM-DD-<branch-or-pr>.md`

Only save if user confirms — most reviews are consumed immediately.

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

## Anti-Patterns

- Don't review files that weren't changed — focus on the diff
- Don't run all 4 agents if the change is 5 lines — use judgment
- Don't block on suggestions — only Critical findings are blockers
- Don't duplicate what CI already catches (lint, format, type-check)
