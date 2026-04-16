---
name: follow-up
version: 1.0.0
description: Generate a client-facing follow-up document for stakeholder meetings from daily/weekly minutes and project data. Use when asked to create follow-up, prepare client follow-up, or generate progress slides.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git log *), Bash(date *), Write, Edit
---

# /follow-up — Project Data → Client-Facing Follow-up

Generates a client-facing follow-up document for stakeholder meetings. Transforms internal meeting minutes and project data into professional, team-level progress reports.

## Arguments

`$ARGUMENTS`: meeting date + sprint/week (e.g., `2026-03-28 sprint-4 week-2`)

## Step 0: Load Project Context

Read these files:

1. **`.claude/context/team.md`** — roster (for removal of individual names), language
2. **`.claude/context/meeting-config.md`** — output paths, repos, decision numbering, work areas

Also check for project-specific references:
3. **`.claude/skills/follow-up/references/template.md`** — project-specific slide structure (if exists)
4. **`.claude/skills/follow-up/references/transformation-rules.md`** — project-specific KEEP/REMOVE/TRANSFORM rules (if exists)

If project-specific references don't exist, use the universal rules below.

## Step 1: Gather Context

Read in parallel:
- Daily minutes from the week (all available)
- Previous follow-up document (for decision numbering continuity **and** to identify what is already known to the stakeholder — do not repeat achievements already featured there)
- Sprint overview / planning doc
- Git activity (`git log --oneline --since="1 week ago"`)
- Architecture/reference docs if needed

For every issue referenced in the daily minutes, check:
- **State** (`gh issue view N --json state`) — closed issues are completed, not pending
- **Last comment** — may reveal implementation status not yet in the ata (e.g., "done, waiting for review")

## Step 2: Ask User for Additional Context

- Confirm meeting date, sprint ID, week number
- Ask about specific topics to highlight
- Ask if there are dashboard screenshots or diagrams to include

## Step 3: Apply Transformation Rules

### Universal Transformation Rules

**KEEP**:
- Timeline and sprint structure
- Team-level achievements (NOT individual)
- Diagrams (architecture, data flow, ER models)
- Dashboard screenshots
- Pending decisions requiring stakeholder input
- Next-week objectives
- Max 3 obstacles (most impactful)

**REMOVE**:
- Individual names (transform to team/area references)
- Internal team dynamics: vacations, coverage arrangements, dev availability — never in client-facing slides
- Meta-commentary about process
- Internal learnings / retrospective insights
- Code-level technical details (SQL queries, configs)
- GitHub metrics (PRs, commits)
- Internal TODOs
- Story points / estimation details
- Achievements already featured in the previous follow-up — not news to the stakeholder

**TRANSFORM**:
- Per-person updates → team themes by area
- Technical details → 1-2 bullet executive summary
- Issue discussion threads → numbered decisions
- Blocker details → impact statement + resolution status

**Tone**: Professional, concise, client-appropriate. Portuguese (pt-BR).

## Step 4: Generate Document

Format: Plain markdown where each H2 = 1 slide. Target 12-16 slides.

```markdown
# Follow-up Sprint X — Semana Y
**Data**: DD/MM/YYYY

## Roteiro
(Bullet list of what will be covered)

## Cronograma
(Sprint timeline with current position)

## Sprint X — Semanas
(Overview of weeks in this sprint)

## Progresso — Conquistas
(Team-level achievements grouped by theme/area)
(Split into 2-3 slides if needed)

## [Architecture/Data Diagrams]
(Mermaid diagrams if applicable)

## Decisões Pendentes
(Only decisions requiring stakeholder input — numbered continuing from previous follow-up)

## Obstáculos
(Max 3, with impact and mitigation status)

## Próxima Semana
(Objectives for next week by area)
```

## Step 5: Save

Write to output path from `meeting-config.md`.

## Step 6: Review with User

Present document. Highlight:
- Decisions requiring stakeholder confirmation
- Items removed vs kept (brief summary)
- Suggested diagram updates

## Step 7: Slidev Conversion (Optional)

If user requests presentation format:
1. Check for `references/slidev-rules.md` in project skill directory
2. If exists, follow project-specific Slidev rules
3. If not, convert using standard rules:
   - Add Slidev frontmatter (dark theme)
   - Add `---` slide separators
   - Wrap mermaid diagrams in centered divs with dark theme init
   - Save as separate `-slidev.md` file

## Step 8: Post-Meeting Additions (Optional)

If user reports decisions/actions from the meeting:
1. Append "Adições pós-reunião" section
2. Update both plain md and slidev md (parity rule)
