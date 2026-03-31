---
name: weekly-minutes
description: Generate retrospective weekly meeting minutes from sprint issue notes and VTT transcript. Use when asked to generate weekly minutes, ata da weekly, or format weekly retrospective.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git log *), Bash(date *), Write, Edit
---

# /weekly-minutes — Sprint Notes + VTT → Weekly Retrospective Minutes

Generates structured weekly retrospective minutes by merging sprint issue live notes (primary source) with VTT transcript enrichment (secondary).

## Arguments

`$ARGUMENTS`: sprint issue URL or number + VTT file path + date + sprint/week (e.g., `#85 docs/meetings/weekly.vtt 2026-03-28 sprint-4 week-2`)

## Step 0: Load Project Context

Read these files:

1. **`.claude/context/team.md`** — roster, ASR corrections, handles
2. **`.claude/context/meeting-config.md`** — output paths, repos, posting rules

If missing, ask the user.

## Step 1: Retrieve Sprint Issue Notes

1. Read the sprint issue (via `gh issue view` or `gh api`)
2. Extract the lead's live notes — these are the **authoritative source**
3. Identify discussion themes, decisions, action items

## Step 2: Parse VTT Transcript

1. Apply ASR corrections from `team.md`
2. Extract nuance, tone, and details not in the written notes
3. VTT **enriches** the notes — it does not replace them

## Step 3: Merge Sources

- Lead's notes = base structure
- VTT adds: exact quotes, attribution clarity, discussion nuance
- When sources conflict, lead's notes take precedence

## Step 4: Cross-Reference with Project Context

1. Read dailies from the week (extract patterns, recurring blockers)
2. Read sprint planning doc (compare plan vs actual)
3. Check issue states (what closed this week, what's still open)

## Step 5: Generate Formatted Minutes

Structure (Portuguese) — **retrospective-focused, NOT status report**:

```markdown
# Ata da Weekly — YYYY-MM-DD

**Sprint**: X | **Semana**: Y | **Data**: DD/MM/YYYY

## Participantes

| Nome | Presente |
|------|----------|
| ... | ✅/❌ |

## O que manter

### [Theme 1]
- Detail...

### [Theme 2]
- Detail...

## O que revisar

### [Theme 1]
- Detail + proposed action...

### [Theme 2]
- Detail + proposed action...

## Decisões

1. [Decision description] — [rationale]
2. ...

## Reconhecimentos

- [Person/team]: [what they did well]

## Referências

- [Links to relevant issues, docs, PRs]
```

**Important**: NO "Relatos por Membro" section — individual work is already captured in dailies.

## Step 6: Save

Write to the output path from `meeting-config.md`.

## Step 7: Review

Present to user. Highlight decisions and items for "O que revisar".

## Step 8: Post Summary to Sprint Issue

1. Find the existing raw weekly comment on the sprint issue
2. Edit it to add a summary + link to the generated ata
3. Format: brief summary (3-5 bullets) + link to full ata
