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
# Ata do Daily — YYYY-MM-DD

**Sprint**: X | **Semana**: Y | **Data**: DD/MM/YYYY

## Participantes

| Nome | Presente |
|------|----------|
| ... | ✅/❌ |

## Resumo por Membro

### [Name]
- **O que fez**: ...
- **O que vai fazer**: ...
- **Bloqueadores**: ...

(repeat for each member)

## Notas do Lead

### Ações e Decisões

| # | Ação/Decisão | Responsável | Status |
|---|-------------|------------|--------|
| 1 | ... | ... | 🟡/🟢/🔴 |

### Follow-ups Recorrentes

| Item | Status | Desde |
|------|--------|-------|
| ... | 🟡/🟢/🔴/⚪/🆕 | DD/MM |

## Contexto do Projeto
(brief note on sprint phase, upcoming milestones)
```

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
