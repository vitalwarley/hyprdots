# /learn-from - Learning Extraction from Session Activity

Extract educational insights from diary entries and session activity, generating structured learning content.

## Usage

```
/learn-from <period> [options]
```

## Periods

- `today` - Today's sessions
- `yesterday` - Previous day's sessions
- `this week` - Last 7 days
- `last week` - Previous 7-day period
- `this month` - Current month to date
- `session <id>` - Specific session (e.g., `2026-02-08-session-19`)

## Options

- `for project <name>` - Filter to specific project
- `deep` - Include web research to enrich explanations with external references

## Examples

```bash
/learn-from today
/learn-from this week for project noux
/learn-from session 2026-02-08-session-19 deep
```

## Workflow

### 1. Parse Arguments & Gather Material

- Extract period specification and optional filters
- Read matching diary entries from `~/.claude/memory/diary/`
- Read corresponding reflection files from `~/.claude/memory/reflections/` if available
- Read project SESSIONS.md or META-SESSIONS.md for additional context

### 2. Identify Learning Candidates

From each diary entry, extract items where learning occurred. Look for:

- **Design decisions** — entries in "Design Decisions Made" section indicate trade-offs the user navigated
- **Bug fixes with root causes** — understanding WHY something broke teaches debugging mental models
- **New patterns adopted** — Strategy pattern, ABC usage, migration patterns, etc.
- **Tool/library discoveries** — new dependencies, configuration approaches, CLI tricks
- **Architecture choices** — why one approach was chosen over alternatives
- **Mistakes and corrections** — the most valuable learning signal

Filter OUT:
- Routine CRUD, boilerplate, configuration
- Repeated patterns already covered in previous learnings
- Administrative work (PR creation, issue filing) unless it involved new workflow insights

### 3. Generate Learning Entries

For each identified learning candidate, produce a structured entry:

```markdown
### <Concept Title>

**Context**: What you were doing when this came up (1-2 sentences, referencing the specific session and project)

**The Decision/Discovery**: What choice was made or what was learned (the core insight)

**Why It Matters**: The underlying principle — what general knowledge does this connect to? When would you apply this again?

**Alternatives Considered**: What other approaches existed? Why were they less suitable here?

**Mental Model**: A concise framing you can carry forward (1-2 sentences that capture the transferable insight)
```

### 4. Enrich (if `deep` flag)

When `deep` is specified:
- Search web for authoritative explanations of the concepts encountered
- Add "Further Reading" links to official docs, well-known articles, or papers
- Connect the user's specific experience to established CS/engineering concepts
- Note if the user's approach aligns with or diverges from industry conventions

### 5. Write Learning File

**Location**: `~/.claude/memory/learnings/extracts/YYYY-MM-DD-<scope>.md`

Where `<scope>` is:
- Project name if filtered (e.g., `2026-02-08-noux.md`)
- `all` if unfiltered (e.g., `2026-02-08-all.md`)
- `week-WW` for weekly (e.g., `2026-02-week-06.md`)

**File structure**:

```markdown
# Learning Extract: YYYY-MM-DD

**Period**: <date range>
**Sources**: <N> diary entries from <projects>
**Learning items**: <count>

---

## Concepts & Decisions

### 1. <Title>
**Context**: ...
**The Decision/Discovery**: ...
**Why It Matters**: ...
**Alternatives Considered**: ...
**Mental Model**: ...

### 2. <Title>
...

---

## Connections to Previous Learning

- Links to previous learning files where related concepts appeared
- Shows evolution of understanding over time

## Open Questions

- Things encountered but not fully understood
- Topics worth exploring deeper in future sessions
```

### 6. Update LEARNING-LOG.md

**Location**: `/home/warley/life/LEARNING-LOG.md`

Append an index entry (reverse chronological, like META-SESSIONS.md):

```markdown
## YYYY-MM-DD

**Sources**: N sessions across <projects>
**Items extracted**: M learning entries

| # | Concept | Project | Type |
|---|---------|---------|------|
| 1 | Strategy Pattern for LLM providers | noux | architecture |
| 2 | rANOVA transform ordering | metabolomics | bug-root-cause |
| 3 | Branch-per-concern workflow | softex-cpm | process |

**Top insight**: <single most transferable learning from this batch>
```

### 7. Detect Learning Patterns (periodic)

When processing weekly or monthly periods, add a meta-section:

```markdown
## Learning Patterns: <period>

**Recurring themes**: Topics that appeared across multiple sessions
**Knowledge gaps**: Areas where decisions were uncertain or deferred
**Skill growth**: Concepts that evolved from "encountered" to "applied confidently"
**Recommended deep-dives**: Topics worth dedicated study based on frequency
```

### 8. Report to User

After generating, report:
- Number of diary entries processed
- Learning items extracted (with brief titles)
- File written (path)
- LEARNING-LOG.md updated
- Top 2-3 highlights

## Learning Type Taxonomy

Tag each learning entry with one of:

- `architecture` — system design, patterns, structural decisions
- `bug-root-cause` — debugging insights, failure mode understanding
- `tool-discovery` — new tools, libraries, CLI techniques
- `process` — workflow, collaboration, development methodology
- `domain` — subject-matter knowledge (biology, finance, etc.)
- `performance` — optimization, efficiency, resource management
- `security` — auth, permissions, vulnerability patterns

## Deduplication

Before writing, check `~/.claude/memory/learnings/extracts/` for existing entries covering the same concept. If found:
- Skip if identical
- Update if the new session adds depth or nuance (append "Revisited" section)
- Cross-reference in "Connections to Previous Learning"

## Integration with Existing Skills

```
/diary        →  raw session capture
/what-did-i-do →  activity aggregation (WHAT)
/reflect      →  pattern synthesis (WHAT RECURS)
/learn-from   →  educational extraction (WHY IT WORKS)  ← THIS SKILL
/til          →  quick learning capture (single insights)
```

The learning pipeline:
```
diary entries → /learn-from → learnings/extracts/ files → LEARNING-LOG.md
                    ↑
              reflections/ (optional enrichment)

TIL captures  → /til → learnings/til/ files
                    ↓
              (weekly /learn-from includes TIL entries)
```

## Anti-Patterns

- Don't generate learning entries for trivial/routine work
- Don't duplicate META-SESSIONS.md content — this skill answers WHY, not WHAT
- Don't create entries without a clear "Mental Model" — if there's no transferable insight, it's not a learning entry
- Don't manually edit LEARNING-LOG.md — always use this skill

## Spaced Repetition Hook (Future)

Learning files include metadata that enables a future `/review-learnings` skill:
- Each entry has a date of first encounter
- Revisited entries track reinforcement dates
- Open questions track resolution status
- This enables surfacing "stale" learnings for review
