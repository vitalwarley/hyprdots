---
name: audit
description: Audit a metric or pipeline step with pre-conditions, process, and post-conditions — following the research flywheel protocol
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(cd * && PYTHONPATH=. uv run python *), Write, Edit
---

# /audit — Metric & Pipeline Audit

Produce a structured audit document for a metric or pipeline step, following the flywheel protocol established in this project. Covers pre-conditions (data integrity, assumptions), process (algorithmic correctness), and post-conditions (verified output values, safe claims for the paper).

**Relationship to `/implement`**: `/implement` produces audit docs proactively during implementation. `/audit` is for re-auditing existing code (pre-`/implement` legacy, or when embeddings/checkpoints change and revalidation is needed).

**Templates**:
- Global methodology: `report/methodological-preconditions-audit.md`
- Per-metric example: `report/sprints/week-15/twonn-audit.md`

## Arguments

`$ARGUMENTS` should name the metric or pipeline step, e.g.:
- `mle estimator` → audits `compute_intrinsic_dimensionality()` in `analysis/metrics.py`
- `gaussian entropy` → audits `compute_gaussian_entropy()`
- `fisher ratio` → audits per-family SVD and Fisher discriminant ratio
- `embedding extraction` → audits the full `extract_embeddings.py` pipeline

## Step 1: Locate the Implementation

Read the relevant function(s) in `analysis/metrics.py` (or the named script).
Identify:
- Inputs: what data is consumed, what format/dtype is assumed
- Algorithm: steps, thresholds, hyperparameters
- Outputs: what is returned, what files are written

## Step 2: Check Existing Audit Coverage

Read `report/methodological-preconditions-audit.md` to check if this metric
was already audited there. If so, note the existing status and focus on
what has changed or was deferred.

## Step 3: Verify Embedding Integrity

Before running anything, confirm the embeddings are from best checkpoints:
- Check `results/embedding_analysis/twonn.json` for `checkpoint_path` metadata
- If `checkpoint_path=N/A` (known gap, issue #117), cross-reference W15 revalidation
  (`report/sprints/week-15/embedding-revalidation.md`) to confirm the `.pt` files
  were re-extracted from best checkpoints

## Step 4: Recompute the Metric

Run the metric pipeline against the current embedding files and capture output.
Use or adapt the pattern from `scripts/compute_twonn.py`:

```bash
cd src/kinship-contrastive
PYTHONPATH=. uv run python scripts/compute_<metric>.py
```

If no dedicated script exists, create one in `scripts/` before running — never
audit from notebook output alone (notebooks are for study, pipelines are for
reproducible results).

Capture: output values for all 5 conditions (pretrained, baseline, hcl,
random_scl, random_hcl), sample counts, and any diagnostic indicators.

## Step 5: Cross-Reference Reports

Search for where this metric appears in reports:
```bash
grep -r "<metric_name>" report/
```

Check if reported values match recomputed values. If they differ, document the
discrepancy — do NOT edit the original report. If correction is needed, note
it as a finding in the audit.

## Step 6: Build the Audit Document

Write to `report/sprints/week-NN/<metric-slug>-audit.md`.

### Structure:

```markdown
# <Metric Name> Audit — Pre-Conditions, Process, Post-Conditions

**Date**: YYYY-MM-DD
**Scope**: `<function_name>()` in `analysis/metrics.py` [or named script]
**Reference**: `report/methodological-preconditions-audit.md` (global),
               `report/sprints/week-15/twonn-audit.md` (per-metric template)
**Verified values**: `results/embedding_analysis/<metric>.json` (recomputed YYYY-MM-DD)

---

## Context

[1-2 paragraphs: why this metric exists in the pipeline, what question it answers,
why the audit was triggered now.]

---

## Pre-Conditions

| # | Pre-condition | Status | Evidence |
|---|--------------|--------|----------|
| P1 | Embeddings from best checkpoints | ✅/⚠️/❌ | [source] |
| P2 | [Data assumption] | ✅/⚠️/❌ | [source] |
| P3 | [Numerical assumption] | ✅/⚠️/❌ | [source] |
| ... | | | |

Status key: ✅ Verified | ⚠️ Assumed/partial | ❌ Known gap

---

## Process

| # | Step | Status | Note |
|---|------|--------|------|
| E1 | [Algorithm step] | ✅/⚠️/❌ | [correctness note] |
| E2 | [Edge case handling] | ✅/⚠️/❌ | [note] |
| ... | | | |

---

## Post-Conditions (Verified Results — YYYY-MM-DD)

[Results table: all 5 conditions × relevant output values]

| # | Post-condition | Status | Evidence |
|---|---------------|--------|----------|
| Q1 | [Expected pattern across conditions] | ✅/⚠️/❌ | [value or reference] |
| Q2 | [Consistency check] | ✅/⚠️/❌ | [note] |
| ... | | | |

---

## Additional Diagnostics

[Only present if you ran beyond-template analyses (null models, sensitivity,
confound checks). Open with a scope note: which design principle triggered
each diagnostic; whether it overlaps with deferred diagnostics from prior audits.
If nothing beyond-template was run, omit this section entirely.]

---

## Known Limitations

| # | Limitation | Severity | Action |
|---|-----------|----------|--------|
| L1 | [assumption not tested] | Low/Med/High | [defer/fix/accept] |
| ... | | | |

---

## Safe Claim for SIBGRAPI

> "[One-sentence claim the paper can make, with values.]"

**Do not claim**: [what cannot be asserted and why]

---

## Reproduction

```bash
cd src/kinship-contrastive
PYTHONPATH=. uv run python scripts/compute_<metric>.py
# Output: results/embedding_analysis/<metric>.json
```

Commit: `<hash>` (YYYY-MM-DD)
```

---

## Step 7: Commit and Link

```bash
git add report/sprints/week-NN/<metric>-audit.md
git commit -m "docs: add <metric> audit (WNN)"
```

If the audit reveals a discrepancy with a published report, also create a
GitHub issue with label `investigation` describing the finding.

## Step 8: Update methodological-preconditions-audit.md (if applicable)

If the audit resolves or updates an open item in the global audit
(`report/methodological-preconditions-audit.md`), update its status row.
Mark resolved items ✅ with a reference to the new audit document.

## Design Principles

1. **Pipeline before audit**: never audit from notebook output; create a reproducible script first
2. **Immutable reports**: discrepancies are findings, not edits — create correction documents
3. **Verified numbers only**: the JSON in `results/embedding_analysis/` is the source of truth; the audit certifies it
4. **Safe claims explicit**: every audit ends with what CAN and CANNOT be claimed in the paper
5. **One audit per metric**: don't fold multiple metrics into one document — keep them linkable individually

## Additional Design Principles

6. **Check for sample-count confounds in group metrics**: if a metric has a theoretical bound
   that scales with group size (e.g., rank ≤ N−1), verify that the observed values aren't just
   tracking group size. A scatter plot of metric vs group size settles this; if correlated,
   prefer a normalized variant.
7. **Interpret metric saturation structurally**: when a metric is near its theoretical maximum,
   state what that implies about the data, not just that the value is high.
8. **One pipeline, multiple metrics — validate each separately**: a single script may produce
   several quantities that answer different questions and have different validation histories.
   Audit them independently; don't let a validated primary metric confer trust on co-computed ones.
9. **Verify label purity for class-level analyses**: when class labels are derived from a
   secondary source (pair file, metadata, external annotation), check that every sample's label
   is valid for the specific analysis task. Mixed or approximate labels inflate within-class
   scatter and bias class-separation metrics downward.
10. **Define concepts at first use in Post-Conditions**: if you introduce a term (e.g., "random
    baseline", "SNR", "normalized variant") in a Post-Conditions table or result, add a brief
    prose paragraph defining it immediately *before* that table. Do not defer the definition to
    Critical Findings — by then the reader has already encountered the unexplained term.
11. **Failing post-condition checks need narrative, not just evidence strings**: a ❌ row in the
    Q-table must include: (a) what the check was testing and why it matters, (b) why the
    threshold was chosen, (c) what the consequence is for the paper claim. ✅ rows can stay
    brief. The more unexpected the failure, the more explanation it requires.
12. **Additional Diagnostics section for beyond-template analyses**: when you run analyses that
    go beyond the fixed Pre/Process/Post template (e.g., null models, sensitivity to
    hyperparameters, confound checks), place them in a dedicated `## Additional Diagnostics`
    section after Post-Conditions. Open the section with a scope note: which design principle
    triggered each diagnostic, and whether any overlaps with deferred diagnostic gaps listed in
    prior audits (note they are separate if so).
13. **Preserve correct content when correcting a prior document**: when revising an earlier
    audit or report because one finding was wrong, identify specifically what is preserved vs.
    corrected. Do not replace whole sections if only one claim is wrong. A brief note like
    "Definition preserved; causal interpretation corrected" in the updated section header
    prevents accidental removal of still-valid content.
