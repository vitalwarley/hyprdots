---
name: predict
description: Generate prediction exam for an implementation milestone, present via AskUserQuestion, grade against actual PR diff after completion
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), AskUserQuestion, Edit, Write
---

# /predict — Prediction Exam

Generate prediction exams AFTER launching autonomous implementation. The user answers while the bot implements. Grading happens when the PR arrives.

## Arguments

`$ARGUMENTS` supports:
- **Milestone/issue reference**: `A1`, `#373`, `v0.2.13 Stream A`
- **Grade mode**: `grade A1`, `grade #373` — grade a previously recorded exam against the actual diff
- **Review**: `review` — show prediction accuracy trends from the log

## Phase: Generate Exam

### Step 1: Gather Context

Read the relevant spec/plan/issue:
- If milestone reference: find the plan document in `docs/plans/` and the relevant spec in `docs/architecture/`
- If issue number: `gh issue view $NUMBER --json title,body`
- If stream reference: read the milestone plan and identify all issues in that stream

Understand:
- Files that will be created or modified
- Patterns being applied
- Key architectural decisions
- Dependencies and ordering constraints
- Expected test impact

### Step 2: Read Previous Prediction Gaps

Check `docs/learning/prediction-log.md` for recurring gap categories. If certain categories appear in 3+ previous exams, increase question weight on those areas.

Gap categories: `data-flow`, `pattern-mechanics`, `architecture`, `api-boundaries`, `session-lifecycle`, `test-strategy`, `file-impact`, `naming-conventions`

### Step 3: Generate Questions

Create 3-5 questions with this distribution:
- **60% multiple-choice** — select correct options from plausible alternatives
- **20% numeric/quantitative** — file count, method count, line change estimate
- **20% open-ended** — explain why, trace a flow, predict a consequence

Question design:
- Each question tests understanding of a **different layer** (data model, service, API, frontend, test)
- Include **context scaffolding** — explain the current state before asking the prediction
- Multiple-choice distractors should be plausible misconceptions (e.g., wrong layer ownership, incorrect lifecycle)
- Open-ended questions should be answerable in 1-3 sentences
- At least one question should target a recurring gap category (if any exist)

### Step 4: Present via AskUserQuestion

Present questions in batches of 1-4 (AskUserQuestion limit).

For **multiple-choice**: use options directly. Include 2-4 choices with descriptions explaining what each implies.

For **numeric**: frame as multiple-choice with ranges, plus Other for exact prediction.

For **open-ended**: use a question with descriptive options representing common approaches/answers. The user selects the closest match or uses Other for their specific reasoning.

Example structure:
```
Question: "The BaseRepository will provide generic CRUD methods. Which layer will own db.commit() — the repository or the service?"
Options:
- "Repository — commit per operation" (description: each add/delete commits immediately)
- "Service — commit per business transaction" (description: services group multiple repo calls under one commit)
- "Route — commit via dependency" (description: FastAPI dependency handles commit/rollback)
```

Record all answers with the question text.

### Step 5: Log Predictions (Pre-Grading)

Append to `docs/learning/prediction-log.md`:

```markdown
---

## YYYY-MM-DD — [Milestone/Issue Title]

**Status**: Pending
**Issue/PR**: [link]

| # | Question | Type | Prediction | Correct | Gap |
|---|----------|------|------------|---------|-----|
| 1 | [question text] | mc/numeric/open | [user's answer] | TBD | TBD |
| 2 | ... | ... | ... | TBD | TBD |
```

## Phase: Grade Exam

Triggered by `/predict grade <reference>`.

### Step 1: Find Prediction Entry

Read `docs/learning/prediction-log.md`, find the entry matching the reference. Verify status is "Pending".

### Step 2: Read Actual Implementation

- Find the PR: `gh pr list --search "<reference>" --json number,title,url,files`
- Read the diff: `gh pr diff <number>`
- Or if already merged: `git log --oneline` + `git diff <before>..<after>`

### Step 3: Grade Each Prediction

For each question:
1. Compare the user's prediction against what actually happened
2. Mark as **CORRECT** or **WRONG**
3. For WRONG predictions, write a specific 1-2 sentence explanation of what actually happened and why
4. Categorize the gap: `data-flow`, `pattern-mechanics`, `architecture`, `api-boundaries`, `session-lifecycle`, `test-strategy`, `file-impact`, `naming-conventions`

### Step 4: Update Log

Update the entry in `docs/learning/prediction-log.md`:
- Change Status to `Graded`
- Fill in Correct and Gap columns
- Add accuracy percentage
- Add a `### Gaps` subsection listing each wrong prediction with explanation

```markdown
**Status**: Graded — 3/5 correct (60%)

| # | Question | Type | Prediction | Correct | Gap |
|---|----------|------|------------|---------|-----|
| 1 | [question] | mc | Service layer | CORRECT | — |
| 2 | [question] | numeric | 12 files | WRONG | file-impact |

### Gaps
- **Q2 (file-impact)**: Predicted 12 files, actual was 7. Overestimated because [reason]. The repository layer is additive — existing service files are not modified in Phase 1.
```

### Step 5: Present Results

Show the user:
- Score (X/Y correct, percentage)
- Each wrong prediction with explanation
- Recurring gap categories (if this category appeared in previous exams)
- Mermaid diagram if any gap involves architecture or data flow understanding

### Step 6: Feed Forward

- Flag any gap category appearing in 3+ exams as **persistent gap** — this should trigger a dedicated concept brief section and increased recall frequency
- Update the entry with cross-references to generated concept briefs

## Phase: Review Trends

Triggered by `/predict review`.

### Step 1: Parse Full Log

Read `docs/learning/prediction-log.md`. Extract all graded entries.

### Step 2: Compute Trends

- Overall accuracy over time (should trend upward)
- Accuracy by gap category (identifies persistent weak areas)
- Accuracy by question type (mc vs numeric vs open)
- Number of persistent gaps (3+ occurrences)

### Step 3: Present

Show:
- Accuracy trend (table or description — e.g., "60% → 70% → 80% over 3 milestones")
- Top 3 weak categories with occurrence count
- Recommendation: what the next concept brief or recall session should focus on
