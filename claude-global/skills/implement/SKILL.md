---
name: implement
description: Guide implementation of a new analysis or metric with pre-conditions → process → post-conditions defined before writing code, producing an audit-quality artifact
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(cd * && PYTHONPATH=. uv run python *), Bash(date *), Write, Edit, AskUserQuestion
---

# /implement — Protocol-First Analysis Implementation

Implements a new metric, pipeline script, or exploratory analysis with the audit protocol embedded from the start. Pre-conditions are verified *before* writing code; the audit doc is a natural output, not a retroactive step.

**Relationship to `/audit`**: `/implement` produces audit docs proactively during implementation. `/audit` is for re-auditing existing code (pre-`/implement` legacy, or when embeddings/checkpoints change and revalidation is needed).

**Templates**:
- Audit format: `report/sprints/week-15/twonn-audit.md`
- Global methodology: `report/methodological-preconditions-audit.md`

## Arguments

`$ARGUMENTS` should name the analysis and the question it answers, e.g.:
- `angular histograms — do trained embeddings separate kin/non-kin angularly?`
- `fisher diagnostics — what drives Fisher ratio across families?`
- `trustworthiness — does local neighborhood structure survive projection?`

---

## Step 1: Scope

1. Parse `$ARGUMENTS` for the analysis name and research question.
2. Grep codebase for existing partial implementations:
   ```bash
   grep -r "<metric_name>" src/ scripts/ analysis/
   ```
3. Classify the work:
   - **Metric**: new function in `analysis/metrics.py` + compute script
   - **Pipeline script**: new `scripts/compute_*.py` or `scripts/run_*.py`
   - **Exploratory analysis**: visualization or statistical test, may not have a single scalar output
4. Determine sprint week for output paths.

---

## Step 2: Pre-Conditions (before code)

**This step happens entirely before writing any implementation code.**

1. List all assumptions the analysis requires:
   - Embedding integrity (best checkpoints, correct extraction)
   - Data prerequisites (sample counts, label purity, deduplication)
   - Mathematical/statistical assumptions (distribution, independence, dimensionality)
   - **Upstream config compatibility** — when the analysis requires new training runs, verify the config is internally consistent *before* deploying. Common failure mode: copying a related config (e.g., same loss/aug params) but missing a dependency (e.g., custom samplers require a specific dataset class for auxiliary attributes). Check that the training config's dataset, sampler, loss, and any model-specific requirements are mutually compatible by reading the relevant class `__init__` and the sampler's attribute accesses — not just by analogy to a sibling config.
   - **Cost estimation for multi-run deploys** — when the analysis requires multiple training runs (e.g., a sweep or factorial), decompose the cost explicitly: `N_runs × per_run_wall_time × $/h`, and state whether the total is **wall-time cost (parallel)** or **cumulative cost (sequential)**. For parallel deploys, `wall_time = max(per_run_wall_time)` not `sum(...)`. Quote the number you're confident in; inflated estimates shape design decisions (e.g., "6 runs too expensive — run 3") before the user has a chance to correct them.
2. Verify each assumption against current artifacts:
   - Check `results/embedding_analysis/` for embedding metadata
   - Cross-reference with `report/methodological-preconditions-audit.md` for known gaps
   - Run diagnostic checks if needed (e.g., normality test, sample count query)
3. **If any assumption fails or is questionable**:
   - **STOP implementation**
   - Present to user: (a) what failed, (b) implications for the analysis, (c) possible alternatives
   - Wait for user decision before proceeding
4. Start the audit doc skeleton at `report/sprints/week-NN/<metric-slug>-audit.md`:
   - Fill Context section
   - Fill Pre-Conditions table with verified statuses

---

## Step 3: Implement

Write the code following existing project patterns:

- **Metrics**: add function to `analysis/metrics.py`, create `scripts/compute_<metric>.py`
- **Pipeline scripts**: create in `scripts/` following the pattern of `scripts/compute_twonn.py`
- **Exploratory**: create script in `scripts/` or `experiments/`, never implement only in a notebook

Pipeline scripts must:
- Be reproducible (`PYTHONPATH=. uv run python scripts/compute_<metric>.py`)
- Save output to `results/embedding_analysis/<metric>.json`
- Process all 5 conditions (pretrained, baseline, hcl, random_scl, random_hcl) unless scoped otherwise
- Include sample counts and metadata in the JSON output
- Include a `--diagnostics` flag that runs confound/validation checks (e.g., sample-count correlation, negative-class homogeneity, direction-of-effect) and saves results to a separate `<metric>_diagnostics.json`. Ad-hoc verification logic that would otherwise be run in throwaway Bash+Python one-liners belongs here — if a check is worth citing in the audit doc, it must be reproducible from the script.

---

## Step 4: Execute

Run the implementation:

```bash
cd src/kinship-contrastive
PYTHONPATH=. uv run python scripts/compute_<metric>.py
```

Capture:
- Output values for all conditions
- Sample counts and diagnostic indicators
- Any warnings or edge cases

If execution fails, diagnose and fix before proceeding — do not skip to post-conditions with stale or partial results.

---

## Step 5: Post-Conditions

1. **Verify results** against expectations:
   - Do values fall in a reasonable range?
   - Is the direction of effect consistent with related metrics?
   - Cross-reference with existing results if applicable (e.g., TWO-NN ordering)
2. **Confound checks**:
   - Sample-count confound: if metric scales with group size, check correlation
   - Saturation: if near theoretical max/min, state structural implication
   - Verify label purity for class-level analyses
   - Negative-class homogeneity: if the analysis partitions by group (e.g., relationship type), verify the negative class doesn't systematically differ across partitions (e.g., Kruskal-Wallis on non-kin distributions). If it does, per-group AUC differences may be artifacts of biased negative sampling.
3. **Effect sizes**: report Cohen's d (or equivalent standardized measure) alongside any raw mean difference — raw Δ is uninterpretable without variance context
3. **Formulate safe claim**:
   - **Rigorous** (well-defined metrics): specific values, clear direction, statistical backing
     > "Contrastive training expands local manifold dimensionality (7.3→8.5d)"
   - **Soft-claim** (exploratory analyses): observed pattern with explicit caveats
     > "Angular distribution suggests cluster separation in trained conditions, pending statistical test for significance"
   - **Exclusion** (when metric fails): state why it's excluded and what alternative to use
     > "MLE ID excluded in favour of TWO-NN due to strong k-dependency (7.8–21.2 range)"

---

## Step 6: Finalize Audit Doc

Complete the audit doc at `report/sprints/week-NN/<metric-slug>-audit.md` using the same structure as `/audit`.

**Before writing**: if any scripts were dispatched as background tasks, estimate wall time upfront — `N_samples × N_passes × ~inference_time_per_sample`. If > 5 min, state the estimate explicitly so the user knows what to expect.

**Before committing**: do a consistency pass — verify every Process table row marked ⚠️ or ❌ is an intentional gap, not a stale placeholder from a background task that has since completed. Cross-check each pending row against its corresponding results section. A ⚠️ "Running" row with a completed results section below it is a doc inconsistency.


```markdown
# <Metric Name> Audit — Pre-Conditions, Process, Post-Conditions

**Date**: YYYY-MM-DD
**Scope**: `<function_name>()` in `analysis/metrics.py` [or named script]
**Reference**: `report/methodological-preconditions-audit.md` (global)
**Verified values**: `results/embedding_analysis/<metric>.json` (computed YYYY-MM-DD)

---

## Context
[1-2 paragraphs: what question this analysis answers, why it was implemented now]

---

## Data Distribution
[Table of group sizes and balance — always present when the analysis partitions data by group.
Include totals and note any imbalances or low-count groups that affect interpretation.]

---

## Pre-Conditions
| # | Pre-condition | Status | Evidence |
|---|--------------|--------|----------|
| P1 | [condition] | ✅/⚠️/❌ | [source] |

Status key: ✅ Verified | ⚠️ Assumed/partial | ❌ Known gap

---

## Pseudocode
[Algorithm summary: inputs → transformations → outputs, 10-20 lines max.
Makes the analysis reproducible at a glance without reading the full script.]

---

## Process
| # | Step | Status | Note |
|---|------|--------|------|
| E1 | [algorithm step] | ✅/⚠️/❌ | [correctness note] |

---

## Post-Conditions (Verified Results — YYYY-MM-DD)
[Results table: conditions × output values]

| # | Post-condition | Status | Evidence |
|---|---------------|--------|----------|
| Q1 | [expected pattern] | ✅/⚠️/❌ | [value or reference] |

---

## Known Limitations
| # | Limitation | Severity | Action |
|---|-----------|----------|--------|
| L1 | [assumption not tested] | Low/Med/High | [defer/fix/accept] |

---

## Safe Claim for SIBGRAPI
> "[Claim with values — rigorous or soft depending on analysis type]"

**Do not claim**: [what cannot be asserted and why]

---

## Figures
[List all figures produced, one per line. Omit this section if the analysis produces no figures.]
- `results/embedding_analysis/figures/<figure>.png` — [one-line description of what it shows]

---

## Reproduction
```bash
cd src/kinship-contrastive
PYTHONPATH=. uv run python scripts/compute_<metric>.py
# Output: results/embedding_analysis/<metric>.json
```
Commit: `<hash>` (YYYY-MM-DD)
```

Fill all sections from Steps 2–5. Do not leave placeholder text. Apply the consistency pass above before proceeding to Step 7.

---

## Step 7: Commit

Stage and commit all outputs together:

```bash
git add scripts/compute_<metric>.py analysis/metrics.py  # if modified
git add results/embedding_analysis/<metric>.json
git add report/sprints/week-NN/<metric-slug>-audit.md
git commit -m "feat: implement <metric> with audit (WNN)"
```

If the analysis resolves an open item in `report/methodological-preconditions-audit.md`, update its status row and include in the commit.

---

## Design Principles

1. **Pre-conditions before code**: verify assumptions first — code that's correct but built on wrong assumptions wastes time
2. **Stop on failed assumptions**: when a pre-condition fails, present the problem and alternatives to the user — do not proceed silently or work around it
3. **Same audit format**: output is identical to `/audit` docs — `/report` treats them interchangeably
4. **Pipeline, not notebook**: all implementations must be reproducible scripts, never notebook-only
5. **Claim type matches analysis type**: rigorous metrics get rigorous claims; exploratory analyses get soft-claims with explicit caveats — do not overstate exploratory findings
6. **Single commit**: code + results + audit doc ship together — no partial states
7. **Inherit `/audit` principles**: all 13 design principles from `/audit` apply to the audit doc produced here
8. **Cross-wave comparisons use relational, not absolute, checks**: when an audit compares a metric to a prior wave under a different infrastructural regime (sampler on/off, optimizer change, dataset update), a common-cause shift can lift or drop both arms uniformly. Absolute-value tolerance (e.g., "AUC within 0.005 of prior wave") will misfire. Prefer:
   - **Δ(h−z)** or other within-space gaps (structural-cap signatures survive level shifts)
   - **DiD and within-wave baselines** (`metric_waveN − anchor_waveN` vs `metric_waveM − anchor_waveM`)
   - **Ratios** when scale, not level, is the invariant
   The classifier function encodes within-wave defaults — when the auto-label disagrees with the relational reading, state this explicitly in Known Limitations ("classifier label ≠ narrative verdict") and pin the narrative to the relational evidence.
