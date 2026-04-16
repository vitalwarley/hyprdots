---
name: weekly-planning
version: 1.1.0
description: Update sprint planning doc with current week's plan based on project sources and issue state. Portable: adapts to team (daily/weekly minutes) and solo research (experiment results + audit docs) workflows via .claude/context/meeting-config.md. Use when asked to update sprint planning, planejamento semanal, or weekly planning.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git log *), Bash(date *), Write, Edit
---

# /weekly-planning — Sources → Updated Sprint Planning Doc

Updates the sprint planning document with a compressed summary of the previous week and a detailed plan for the current week.

**Portable**: adapts to any project via `.claude/context/` files. If context files are absent, falls back to CLAUDE.md ambient context and defaults to `workflow_type = "team"`.

## Arguments

`$ARGUMENTS`: week identifier (e.g., `week-17`, `sprint-4 week-3`) + optional additional context

## Step 0: Verify current date

Run `date` and record the result. Use this date for **all timestamps** in the document — changelog entries, strikethrough annotations, criterion completions. Never infer the date from filenames, conversation context, or system-injected `currentDate`.

## Step 1: Load Project Context

Read these files if they exist:

1. **`.claude/context/team.md`** — roster, work areas
2. **`.claude/context/meeting-config.md`** — output paths, workflow type, work areas
3. **`.claude/skills/weekly-planning/references/workflow-override.md`** — project-specific step overrides (if exists)

**Fallback**: if context files don't exist, read CLAUDE.md for ambient project config — look for `## Sprint Planning`, `## Workflow`, or `## Meeting Config` sections. Assume `workflow_type = "team"`.

Extract from `meeting-config.md` when present:
- `workflow_type` — `"team"` (default) or `"research"`
- Sprint planning path / output doc path
- Results report path (for research projects)
- Work areas list (for table structure in Step 5)

## Step 2: Gather Sources (in parallel)

**If `workflow_type = "team"`:**
1. **All dailies from previous week** — extract per-member progress, blockers, action items
2. **Most recent weekly ata** — extract "O que manter", "O que revisar", decisions
3. **Sprint planning doc** — current state (path from `meeting-config.md`)
4. **Open/recently closed issues** — `gh issue list --state all --limit 50`
5. **Recent comments on key issues** — for context on decisions
6. **Most recent follow-up** — for client-facing commitments
7. **Relevant sprint issues** — for scope tracking

**If `workflow_type = "research"`:**
1. **Previous week's experiments-results.md** — extract completed items, open questions, status table
2. **Open-questions doc from previous week** — extract priority matrix and pending items
3. **Audit docs already created this week** — extract completed work
4. **Open/recently closed issues** — `gh issue list --state all --limit 50`
5. **Submission roadmap doc** — extract current week's expected deliverables
6. **Previous week's execution plan** — for migrated items and risks

## Step 3: Build Resolution Map

Before writing anything, build a resolution map for every blocker/pending item:

```
[item] → [status: resolved | active | stale] → [source that confirms status]
```

**Trust priority**: follow-up > weekly ata > latest daily > issue comments

Rule: Never flag something as 🔴 blocked if the resolution map shows it's resolved.

## Step 4: Compress Previous Week

Format the previous week as a **compressed table** (not prose):

```markdown
### Semana N (DD–DD/MM) — [Status: Concluída]

| Issue | Resultado | Notas |
|-------|-----------|-------|
| #XX — Description | ✅ Concluído / 🟡 Parcial / ❌ Não iniciado | Brief note |

**Migrou para semana N+1**: #XX, #YY (brief reason)
```

## Step 5: Write Current Week Plan

Structure with tables per work area (from `meeting-config.md`):

```markdown
### Semana N (DD–DD/MM) — [Objective in 1 line]

**Objetivos**: 1-2 sentences summarizing the week's focus.

#### [Work Area 1]

| Issue | Tarefa | Responsável | Prioridade |
|-------|--------|------------|------------|
| #XX | Description | Name | Alta/Média/Baixa |

#### [Work Area 2]
...
```

Mark aspirational items as "stretch goal".

**Research projects** (`workflow_type = "research"`): create a **new** `execution-plan.md` at the week's path (e.g., `plans/sprints/week-NN/execution-plan.md`) — each week is a standalone doc. Include a mermaid Gantt chart for the week's distribution. Team projects update an existing planning doc in-place.

## Step 6: Update Standing Sections

Update ALL of these sections in the planning doc:

- **Escopo**: ~~Strikethrough~~ completed items with date (DD/MM)
- **Perguntas PO**: Mark resolved as `~~Pergunta?~~ → Resposta (DD/MM)`
- **Investigações**: Mark completed as `~~Investigação~~ → Resultado (DD/MM)`
- **Critérios de Sucesso**: Mark achieved with ✅ + date
- **Atribuições**: Update focus areas per team member
- **Decisões**: Add new decisions from weekly ata (numbered sequentially)

If any of these sections don't exist in the planning doc, skip them.

## Step 7: Update Risks

- ~~Strikethrough~~ resolved risks with resolution note
- Add new risks from weekly ata / issue comments
- Update mitigation status for active risks
- Validate against resolution map (don't list resolved items as active)

## Step 8: Append Changelog

Add entry at the bottom:
```
| DD/MM/YYYY | Semana N: [brief description of changes] |
```

## Step 9: Review

Present to user:
- Summary of what changed
- Items that migrated to next week (and why)
- New risks or decisions added
- Any standing sections that seem stale

## Principles

1. **Substitution, not accumulation** — planning doc stays lean
2. **Single source of truth** for "what's happening now"
3. **Traceability** — link to issues, atas, follow-ups
4. **Conservative planning** — flag aspirational items as stretch
5. **Tables over prose** — always structured data
6. **Verify before flagging** — check resolution map
7. **Update everything or nothing** — all stale sections must be updated
8. **Consistent conventions** — strikethrough + date applied uniformly
