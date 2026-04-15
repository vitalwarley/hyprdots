---
name: report
description: Incrementally aggregate sprint results into the current week's experiments-results.md — run periodically during the week, not only at week end
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(cd * && PYTHONPATH=. uv run python *), Bash(date *), Write, Edit
---

# /report — Sprint Results Aggregator

Incrementally updates the running sprint report (`report/sprints/week-NN/experiments-results.md`) with new results, audit findings, and session activity since the last update. Run it any time after completing a meaningful unit of work — not only at week end.

**Design intent**: the report grows throughout the sprint. Each `/report` call adds a chronology entry, updates the Status vs Plan table, and appends new analysis sections. The report is always in a readable, citable state.

## Arguments

`$ARGUMENTS` supports:

| Input | Behavior |
|-------|----------|
| *(empty)* | Aggregate **current session only** into running sprint report |
| `--all` | Aggregate all work since last report update (gap-fill across sessions) |
| `--init` | Create a new sprint report for week N (see §Init Mode) |
| `section <name>` | Update only the named section (e.g., `section hypothesis`) |

---

## Step 0: Determine Sprint Context

```bash
date +%Y-%m-%d
```

Identify the current sprint week:
- Read `plans/sprints/` for a week plan matching the current date range
- Or infer from the most recent `report/sprints/week-NN/` directory
- Sprint runs **Wednesday → Tuesday** (aligned with advisor meeting cadence)

Read the existing sprint report if it exists:
```
report/sprints/week-NN/experiments-results.md
```

If it does not exist, switch to **§Init Mode**.

---

## Step 1: Identify What Is New

**Scope rule**: by default (no args), aggregate only the **current conversation session** — work the user and Claude did together in this exchange. Do NOT pull in commits from other sessions even if they postdate the last report update. Use `--all` explicitly to gap-fill across sessions.

Gather evidence of work done in the current session. Run in parallel:

```bash
# commits since last report update
git log --oneline --since="$(git log --format='%ai' -- report/sprints/week-NN/experiments-results.md | head -1)" -- src/ scripts/ analysis/ results/

# new or modified result files
git diff --name-only HEAD~10 -- results/embedding_analysis/

# new audit documents this sprint
ls report/sprints/week-NN/
```

Also read any diary entries for the current sprint period if relevant context is missing from git.

---

## Step 2: Update Session Chronology (§2)

Add a row to the `## 2. Session Chronology` table for each session since the last update:

```markdown
| Apr DD (Day) | <one-line description of what was done> | <key outputs: files, commits, issues> |
```

Keep entries concise — one row per session, not per task. Link to output documents where they exist.

---

## Step 3: Update Status vs Plan (§N)

For each item in the Status vs Plan table:
- Mark `✅ Done` if the corresponding result JSON, audit doc, or commit exists
- Leave `⏳ Pending` if not yet done
- Add new rows for work done this session that was not previously tracked

Verify done items against actual artifacts — do not mark done from memory alone.

---

## Step 4: Append New Analysis Sections

For each new result or analysis completed this session:

1. **Check if the result has a verified JSON** in `results/embedding_analysis/`. If not, note it as preliminary.
2. **Check if an audit doc with a Safe Claim section exists** for the metric (produced by `/implement` or `/audit`). If not, the result cannot carry a safe claim — mark as `⏳ Pending verification`.
3. **Add a new subsection** under the appropriate parent (Corrective Track, Forward Track, Metric Audits, etc.) — or create a new top-level section if the work doesn't fit existing sections.
4. **Add tables** in the format established by W15: conditions × metrics, with a Safe claim line.

Never edit existing verified content — only append. If a prior result was wrong, create a correction subsection and link from the original.

---

## Step 5: Update Hypothesis Summary (§N)

If any analysis this session resolves or opens a hypothesis:
- Change verdict from `❓ Open` → `✅ Confirmed` or `❌ Rejected`
- Add a row for any new hypothesis that emerged
- Update Key Evidence column with the specific value and source

---

## Step 6: Update Next Priorities (§N Next)

Revise the priority list based on:
- What was just completed (remove from list or mark done)
- What the advisor asked for in the last meeting
- What open audit gaps (Diagnostic Gaps D1–D5 style) are now unblocked

---

## Step 7: Update Changelog

Add a row:
```markdown
| YYYY-MM-DD | <brief description of what was added this update> |
```

---

## Step 8: Commit

```bash
git add report/sprints/week-NN/experiments-results.md
git commit -m "docs: update W<NN> report — <one-line summary of additions>"
```

---

## §Init Mode — New Sprint Report

When `--init` is passed or no report exists for the current week:

1. **Determine week number** from the sprint start date
2. **Create directory**: `report/sprints/week-NN/`
3. **Copy the W15 report as template** (`report/sprints/week-15/experiments-results.md`) — strip all specific content, keep structure
4. **Populate the header** (Sprint issue link, period dates, author)
5. **Pre-populate §13 Status vs Plan** from the sprint plan in `plans/sprints/week-NN/` if it exists
6. **Pre-populate §2 Session Chronology** with the advisor meeting row (from the week's ata if it exists)
7. **Set §16 Next** from the previous sprint's §16 (carry-over items)
8. **Commit**: `docs: init W<NN> sprint report`

### Report Template Structure

```
# Week NN Experiments & Analysis Report

## TL;DR          ← fill at end of sprint, not at init
## 1. Sprint Context
## 2. Session Chronology
## 3. Advisor Meeting — Month DD (link to ata)
## 4. [Analysis sections — added incrementally]
...
## N. Hypothesis Summary
## N+1. Delta Tables
## N+2. Metric Audits
## N+3. Protocols and Flywheels Codified  ← only if new patterns emerged
## N+4. Meta — Working Style             ← only at sprint end
## N+5. Status vs Plan
## N+6. Issues Resolved
## N+7. Changelog
## N+8. Next (W<NN+1>)
```

---

## Design Principles

1. **Incremental, not batch**: run after each meaningful session, not only at week end — the report is always readable
2. **Artifacts first**: only add a result to the report if the backing JSON exists and the audit doc contains a Safe Claim section; preliminary findings go in a "Pending verification" note, not in a table
3. **Never edit verified content**: if a prior value was wrong, append a correction subsection — don't overwrite; the audit trail is the value
4. **Status vs Plan is the ground truth**: mark items done against actual file existence, not recollection
5. **TL;DR last**: fill the TL;DR block at the end of the sprint, not at init — it summarizes what actually happened, not what was planned
6. **Section numbers follow content**: number sections sequentially as they're added; don't pre-allocate numbers for sections that don't exist yet
