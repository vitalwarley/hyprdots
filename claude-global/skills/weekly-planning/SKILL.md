---
name: weekly-planning
description: Update sprint planning doc with current week's plan based on dailies, weekly ata, and issue state. Use when asked to update sprint planning, planejamento semanal, or weekly planning.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git log *), Bash(date *), Write, Edit
---

# /weekly-planning — Sources → Updated Sprint Planning Doc

Updates the sprint planning document with a compressed summary of the previous week and a detailed plan for the current week. Usually invoked after `/weekly-minutes`.

## Arguments

`$ARGUMENTS`: sprint and week (e.g., `sprint-4 week-3`) + optional additional context

## Step 0: Load Project Context

Read these files:

1. **`.claude/context/team.md`** — roster, work areas
2. **`.claude/context/meeting-config.md`** — output paths, repos, work areas, decision numbering

## Step 1: Gather Sources (in parallel)

1. **All dailies from previous week** — extract per-member progress, blockers, action items
2. **Most recent weekly ata** — extract "O que manter", "O que revisar", decisions
3. **Sprint planning doc** — current state (path from `meeting-config.md`)
4. **Open/recently closed issues** — `gh issue list --state all --limit 50`
5. **Recent comments on key issues** — for context on decisions
6. **Most recent follow-up** — for client-facing commitments
7. **Relevant sprint issues** — for scope tracking

## Step 2: Build Resolution Map

Before writing anything, build a resolution map for every blocker/pending item:

```
[item] → [status: resolved | active | stale] → [source that confirms status]
```

**Trust priority**: follow-up > weekly ata > latest daily > issue comments

Rule: Never flag something as 🔴 blocked if the resolution map shows it's resolved.

## Step 3: Compress Previous Week

Format the previous week as a **compressed table** (not prose):

```markdown
### Semana N (DD–DD/MM) — [Status: Concluída]

| Issue | Resultado | Notas |
|-------|-----------|-------|
| #XX — Description | ✅ Concluído / 🟡 Parcial / ❌ Não iniciado | Brief note |

**Migrou para semana N+1**: #XX, #YY (brief reason)
```

## Step 4: Write Current Week Plan

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

## Step 5: Update Standing Sections

Update ALL of these sections in the planning doc:

- **Escopo**: ~~Strikethrough~~ completed items with date (DD/MM)
- **Perguntas PO**: Mark resolved as `~~Pergunta?~~ → Resposta (DD/MM)`
- **Investigações**: Mark completed as `~~Investigação~~ → Resultado (DD/MM)`
- **Critérios de Sucesso**: Mark achieved with ✅ + date
- **Atribuições**: Update focus areas per team member
- **Decisões**: Add new decisions from weekly ata (numbered sequentially)

If any of these sections don't exist in the planning doc, skip them.

## Step 6: Update Risks

- ~~Strikethrough~~ resolved risks with resolution note
- Add new risks from weekly ata / issue comments
- Update mitigation status for active risks
- Validate against resolution map (don't list resolved items as active)

## Step 7: Append Changelog

Add entry at the bottom:
```
| DD/MM/YYYY | Semana N: [brief description of changes] |
```

## Step 8: Review

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
