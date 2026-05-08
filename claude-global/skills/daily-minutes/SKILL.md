---
name: daily-minutes
description: Parse a Teams VTT transcript and generate structured daily meeting minutes (ata). Use when asked to generate daily minutes, ata do daily, or parse daily transcript.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git log *), Bash(date *), Write, Edit
---

# /daily-minutes — VTT Transcript → Daily Meeting Minutes

Parses a Microsoft Teams VTT transcript and generates a structured daily standup ata in Portuguese (pt-BR).

## Arguments

`$ARGUMENTS`: VTT file path + date + sprint/week identifier (e.g., `docs/meetings/transcript.vtt 2026-03-28 sprint-4 week-2`)

## Step 0: Load Project Context

Read these files to configure project-specific behavior:

1. **`.claude/context/team.md`** — roster, ASR correction map, GitHub handles, language settings
2. **`.claude/context/meeting-config.md`** — output paths, repos tracked, status emojis, issue posting rules

If either file is missing, ask the user to provide the team roster and output path convention.

## Step 1: Parse Transcript

1. Read the VTT file
2. Apply ASR corrections from `team.md` (correction map section)
3. Identify speakers and attribute segments correctly
4. When attribution is ambiguous, use context (topic being discussed, previous/next segments) to disambiguate

## Step 1A: Review Past Atas

1. Glob for recent daily atas in the output directory (same sprint, previous days)
2. Extract recurring follow-ups and their status
3. Track status progression using emojis from `meeting-config.md`

## Step 1B: Check Recent Follow-ups

1. Check for recent follow-up documents or sprint reports (paths from `meeting-config.md`)
2. Cross-reference with action items from past dailies

## Step 2: Cross-Reference with Project Context

1. Read sprint planning doc, open issues, recent issue comments
2. Match discussed topics with known issues/tasks
3. Note any decisions made or blockers raised

## Step 3: Generate Formatted Minutes

Structure (Portuguese):

```markdown
# Daily — YYYY-MM-DD

**Sprint N — Semana Y** | **Dia Z de W** | **HH:MM–HH:MM**

## Participantes

| Nome | Equipe | Presente |
|------|--------|----------|
| ... | ... | ✅/❌ |

## Contexto do Projeto

[Operational context — NOT a summary. Describe the current state the team is working in:
sprint phase, what changed since last daily, constraints active (e.g. Bruno available only until Friday),
key unblocks or new blockers. 1–3 sentences. Do NOT summarize what each person did.]

## Resumo por Membro

### [Name] (@handle)

- **O que fez**: ...
- **O que vai fazer**: ...
- **Bloqueadores**: ...

(repeat for each member)

## Notas do Lead

### Ações e Decisões

| # | Ação/Decisão | Responsável | Status |
|---|-------------|------------|--------|
| 1 | ... | ... | 🟡/🟢/🔴 |

### Follow-ups do sprint (evolução)

#### Dashboard (tdb-version-dashboard)

| ID | Item | Ref | [prev date] | [today date] | Próxima ação |
|----|------|-----|-------------|--------------|--------------|
| DXX | ... | #N | 🟡 | 🟡/🟢/🔴/⚪/🆕 | ... |

**Contexto de issues**:

[List only open issues referenced in the table above. One line each:
`- [#N](url) — título curto — estado atual em 1 frase`
Do NOT list closed issues here.]

#### OCR (edgebr/toledo-ia)

| ID | Item | Ref | [prev date] | [today date] | Próxima ação |
|----|------|-----|-------------|--------------|--------------|
```

## Step 3A: Tracker Carryover Rules

When deciding which follow-ups to bring into today's tables:

- **🟢 in the previous daily?** → Drop. Green resolves once and does not propagate to the next daily; past atas hold the history.
- **Already addressed in the most recent follow-up document?** → Drop (the follow-up is the closure record for stakeholders); reconciliation should be done by the follow-up skill, not duplicated here.
- **Issue closed since last daily?** → Drop the row; do not include "issue closed" as a status update.
- **Out-of-scope items** (different program/cycle, not relevant to current sprint) → Drop, regardless of last status.
- **Validated by PO since last daily?** → Mark 🟢 in today's column with the validation note; will not carry forward.
- **New decisions cravadas hoje** → Mark 🟢 only when fully decided + actionable; otherwise 🟡.

The carryover table answers **"what is still open or moved today?"** — never **"what was the full history?"**.

## Step 4: Save

Write to the output path defined in `meeting-config.md`. Create directories if needed.

## Step 5: Review

Present the generated ata to the user for review. Highlight:
- Any uncertain speaker attributions
- New follow-ups identified
- Decisions that may need stakeholder confirmation

## Step 6: Commit and Push

After user approval:
```bash
git add <ata-file>
git commit -m "docs(meetings): add daily ata YYYY-MM-DD sprint X week Y"
git push
```

## Step 7: Post to Issues (if configured)

If `meeting-config.md` defines multiple repos:
1. Split content by repo scope
2. Post condensed summary + link to the appropriate sprint issue
3. Tag relevant devs with @handles
4. Never post the full ata — only summary + link
