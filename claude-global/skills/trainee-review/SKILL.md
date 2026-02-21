---
name: trainee-review
description: Review trainee/junior developer notebooks and analysis scripts with detailed methodology critique, producing a REVIEW.md artifact for learning
---

# /trainee-review — Notebook & Analysis Review for Trainees

Structured review workflow for tech leads supervising trainee/junior ML engineers. Produces a co-located review folder with REVIEW.md, jupytext conversion, extracted charts, and a PT-BR PR comment.

## Arguments

`$ARGUMENTS` supports:
- **PR reference**: `pr <number>` or `<PR-URL>` — the PR to review
- **Issue reference**: `issue <number>` or `<issue-URL>` — related issue(s)
- **Verdict**: `merge`, `request-changes`, or `comment` (default: `comment`)

Examples:
```
/trainee-review pr 33 issue 628
/trainee-review https://github.com/edgebr/toledo-ia-python/pull/33 merge
/trainee-review pr 45 request-changes
```

## Step 1: Gather Context

1. Fetch PR details: title, body, branch, files, commits
2. Fetch related issue(s): title, body, acceptance criteria
3. Identify the target notebook(s) or script(s) from the PR file list
4. Checkout the PR branch (or stay on current if already there)

Output: List of files to review, issue context, author name.

## Step 2: Create Review Folder

Determine the review folder location based on where the notebook/script lives:

```
<parent-dir>/review-<issue-number>-<short-topic>/
```

Example: `notebooks/analysis/containers/batch_analysis/review-307-043-cd-scientific-method/`

Create:
- `README.md` — context (PR link, issue link, author, review date, file index)
- `pyproject.toml` — uv environment with jupytext dependency

## Step 3: Convert & Extract

For each `.ipynb` file in the PR:

1. **Convert to .py** via jupytext:
   ```bash
   uv run --no-project --with jupytext jupytext --to py:percent <notebook> -o <output>.py
   ```

2. **Move the notebook** into the review folder for co-location

3. **Extract chart images** from notebook cell outputs:
   ```python
   import json, base64
   # For each code cell with image/png output, decode and save as .png
   ```

## Step 4: Read and Analyze

Read the full notebook content (both code and markdown cells). For each analysis section, evaluate:

### Scientific Method (if applicable)
- **Question/Problem**: Is it specific, testable, and well-scoped?
- **Hypothesis**: Proper H0/H1 formulation? Falsifiable? Quantitative thresholds?
- **Method**: Does the method match the hypothesis? (e.g., non-linear hypothesis → non-linear test)
- **Conclusion**: Supported by evidence? Overreaching? Acknowledges limitations?

### Statistical Rigor
- Are p-values reported alongside correlation coefficients?
- Is the distinction between statistical and practical significance made?
- Are confidence intervals or error bands shown?
- Multiple comparisons correction if many tests?
- Appropriate tests for the data type (continuous/categorical/ordinal)?

### Code Quality
- Reproducibility: hardcoded paths? environment variables? random seeds?
- Performance: unnecessary loops? repeated I/O?
- Correctness: duplicate metrics? unused imports? silent error suppression?
- Style: consistent with project linting rules?

### Visualization Quality
- Overplotting handled? (density plots, transparency, hexbins)
- Axes labeled and scaled appropriately?
- Reference lines and annotations present?
- Consistent styling across panels?

### Domain-Specific (ML/CV)
- Global vs local image properties (whole image vs ROI/bounding box)
- Failure case analysis (non-detections, low-confidence outliers)
- Model configuration consistency (input size, thresholds, max_det)

## Step 5: Write REVIEW.md

Use this structure:

```markdown
# Review: <Notebook Name>

**PR**: [#N](url) — "title"
**Issue**: [#N](url) — "title"
**Author**: Name (@handle)
**Reviewer**: Warley (assisted by Claude <model>)
**Date**: YYYY-MM-DD

---

## Executive Summary
<2-3 sentences>

---

## Scoring Matrix

| Criterion | Score | Notes |
|---|:---:|---|
| Scientific structure (Q→H→M→C) | X/10 | ... |
| Statistical rigor | X/10 | ... |
| Hypothesis formulation | X/10 | ... |
| Conclusion validity | X/10 | ... |
| Code quality | X/10 | ... |
| Visualization quality | X/10 | ... |
| Reproducibility | X/10 | ... |
| **Overall** | **X/10** | ... |

---

## Detailed Findings

### 1. What is Done Right
<Specific praise with references>

### 2. Statistical Issues (Critical)
<Numbered findings with **Fix** recommendations>

### 3. Hypothesis Formulation Issues
<H0/H1 misuse, unfalsifiable hypotheses, missing thresholds>

### 4. Interpretation Issues
<Overreaching conclusions, correlation≠causation, dataset range limitations>

### 5. Code Quality Issues
<Reproducibility, performance, correctness>

### 6. Visualization Issues
<Overplotting, scale, chart type choices>

---

## Summary of Required Changes

### Must Fix (Blocking)
<Numbered list>

### Should Fix (Important)
<Numbered list>

### Nice to Have (Improvements)
<Numbered list>

---

## Educational Notes for the Author
<Concepts explained at trainee/junior level — statistical significance,
effect sizes, common pitfalls, domain-specific guidance>

---

## Verdict
**<Merge / Request changes / Comment only>**. <Justification>
```

## Step 6: Post PR Comment (PT-BR)

Post a review comment on the PR **in Portuguese** with:
1. Summary of what was done right
2. Key findings (top 3-5 points)
3. Link to REVIEW.md for full details
4. Verdict and action

Use `gh pr review <number> --comment --body "..."`.

## Step 7: Handle Issues (if instructed)

If the user specifies issues to close or comment on:
- Comment on each issue in PT-BR summarizing what was delivered
- Close issues if verdict is `merge`
- Reference the PR and REVIEW.md in comments

## Step 8: Commit and Push

```bash
git add <review-folder>/
# Remove old/deprecated notebooks if applicable
git commit --no-verify -m "docs: add review for <issue> <topic>

Co-Authored-By: Claude <model> <noreply@anthropic.com>"
git push
```

Use `--no-verify` only when pre-commit failures are in auto-generated jupytext code (not in review artifacts). Document the reason in the commit message.

## Design Principles

1. **Educational, not punitive**: The review is a learning artifact, not a gate. Even when requesting changes, frame findings as growth opportunities.
2. **Evidence-based scoring**: Every score in the matrix links to specific findings in the detailed section.
3. **Actionable fixes**: Every finding includes a concrete **Fix** recommendation, not just "consider improving."
4. **PT-BR for humans, English for artifacts**: PR comments and issue updates in Portuguese. REVIEW.md and code in English.
5. **Co-located artifacts**: Everything lives next to the reviewed notebook — no separate review repo.
6. **Calibrated expectations**: Adjust rigor expectations to the author's level (trainee vs junior vs mid). A trainee's first scientific method notebook deserves encouragement alongside critique.
