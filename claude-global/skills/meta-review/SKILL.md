---
name: meta-review
description: Audit workflow efficiency by analyzing diaries and reflections for recurring errors, wasted effort, instruction drift, and automation opportunities
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(python *), Write
---

# /meta-review — Workflow Audit and Token Optimization

Analyze diary entries and reflections to produce actionable workflow change proposals.

## Arguments

`$ARGUMENTS` supports:
- **Time window**: `last week` (default), `last month`, `deep` (all entries)
- **Project filter**: `for project <name>`
- **Focus**: `errors`, `drift`, `automation`, `efficiency` — run one category only

Examples: `/meta-review`, `/meta-review last month`, `/meta-review deep for project noux`, `/meta-review errors`

## Step 1: Run Preprocessor

Execute the preprocessing script to load and filter diary/reflection data:

```bash
python ~/.claude/skills/meta-review/scripts/preprocess.py $ARGUMENTS
```

This outputs JSON with all filtered diary sections and reflection sections. Save the output to a variable for analysis.

If `diary_count` is 0: report "No diary entries found for the requested window. Try `/meta-review last month` or `/meta-review deep`." and stop.

## Step 2: Load Active CLAUDE.md Rules

Read all applicable CLAUDE.md files:
- Always: `~/.claude/CLAUDE.md`
- If inside a project with its own CLAUDE.md: read that too

Extract all rules as a flat list for drift analysis.

## Step 3: Check Prior Reviews

Read `~/.claude/memory/reviews/` for existing meta-review files. If a recent review overlaps with the current date range, focus on new entries since that review.

## Step 4: Analyze

Run all four analyses (or only the focused one if `focus` is set):

### 4a. Error Recurrence

From diary `Challenges Encountered` + `Solutions Applied` sections and reflection `CRITICAL: Rule Violations Detected` + `Notable Mistakes and Learnings` sections:
- Group challenges by similarity (same root cause, same tool, same failure class)
- Count frequency across sessions
- For each recurring error (2+ occurrences): state error class, list affected sessions, identify root cause, check if a CLAUDE.md rule addresses it, propose fix

### 4b. Instruction Drift

From CLAUDE.md rules + reflection violations + diary `Design Decisions Made` and `User Preferences Observed`:
- Rules violated in reflections → "needs strengthening"
- Diary decisions contradicting a rule → "conflicting"
- Rules never referenced in any diary/reflection → "dormant" (flag for review, not removal)
- Diary preferences not captured in CLAUDE.md → "missing rule"

### 4c. Automation Candidates

From diary `Actions Taken` + `Work Summary`:
- Identify manual steps repeated in 3+ sessions
- For each: count frequency, classify as hook/skill/rule candidate, draft definition

### 4d. Session Efficiency

From diary metadata (section lengths, challenge count, tool diversity):
- Score effort-to-outcome ratio per session
- Flag high-effort/low-outcome sessions
- Identify patterns (project? task type? scope?)
- Identify what makes efficient sessions efficient

## Step 5: Generate Report

Save to `~/.claude/memory/reviews/YYYY-MM-DD-meta-review.md` using this structure:

```markdown
# Meta-Review: Workflow Audit

**Generated**: YYYY-MM-DD
**Period**: [date range]
**Sessions Analyzed**: [count]
**Projects Covered**: [list]
**Focus**: [all | specific category]

## Executive Summary

- [3-5 bullet points: most important findings]

## Error Recurrence

### [CRITICAL/WARNING] [Error Class Name]
- **Frequency**: N sessions ([dates])
- **Root Cause**: [description]
- **Current Rule**: [existing rule or "none"]
- **Proposed Fix**: [new rule / hook / process change]

## Instruction Drift

### Rules Needing Attention
| Rule | Status | Action |
|------|--------|--------|
| [rule text] | violated / dormant / conflicting | [strengthen / remove / investigate] |

### Missing Rules
- [preference observed but not codified]

## Automation Candidates

### [Candidate Name]
- **Frequency**: N sessions
- **Type**: hook / skill / rule
- **Draft**: [definition]

## Session Efficiency

### Inefficient Patterns
- **Pattern**: [description]
- **Sessions**: [list]
- **Mitigation**: [proposal]

### Efficient Patterns
- **Pattern**: [description]
- **What makes it work**: [factors]

## Proposed Changes Summary

### CLAUDE.md Edits
[diff-style: lines to add/modify/remove]

### New Hooks
[hook definitions if any]

### New Skills
[skill proposals if any]

## Metadata
- **Diary entries analyzed**: [filenames]
- **Reflections analyzed**: [filenames]
- **CLAUDE.md files read**: [paths]
```

## Step 6: Present Summary

Show the user:
1. Executive summary (3-5 bullets)
2. Top 3 findings by severity
3. Report file path

If CLAUDE.md changes are proposed, ask whether to apply them now or defer. Do NOT auto-apply.

## Design Principles

1. **Evidence-based**: Every finding cites specific sessions/reflections
2. **Actionable**: Every finding ends with a concrete proposal
3. **Conservative**: "dormant" not "obsolete" — dormancy may mean a rule works well
4. **Non-destructive**: Never modify CLAUDE.md without explicit user approval
5. **Cumulative**: Check prior reviews in `~/.claude/memory/reviews/` to avoid restating resolved issues
