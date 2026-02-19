Perform a strict read-only investigation of the codebase. No modifications, no suggestions, no implementation — only gather and document understanding.

**Investigation target**: `$ARGUMENTS`

## 0. Mode Enforcement

You are in **RESEARCH MODE**. The following actions are FORBIDDEN:
- Modifying any file (Edit, Write, NotebookEdit)
- Suggesting fixes or implementations
- Creating branches or commits
- Running commands that change state (only read-only commands allowed)

If you catch yourself about to suggest a fix, STOP. Document the observation as a finding instead.

## 1. Scope the Investigation

Parse `$ARGUMENTS` to determine investigation type:

**If a component/module name** (e.g., "AI service", "event extraction"):
- Glob for relevant files
- Map the dependency graph (what calls what)
- Identify entry points and exit points

**If a behavior/bug description** (e.g., "why events lose timezone"):
- Trace the data flow from origin through persistence to consumption
- Document the actual shapes at each boundary (read the code, don't assume)

**If a broad area** (e.g., "authentication", "API layer"):
- Map all files involved
- Document public interfaces and contracts
- Identify patterns and inconsistencies

## 2. Gather Context

Run in parallel as applicable:

```bash
# Recent changes in the area
git log --oneline -20 -- <relevant-paths>

# Related test coverage
find <relevant-paths> -name "*test*" -o -name "*spec*"

# Open issues mentioning the area
gh issue list --search "<keywords>" --limit 10
```

Read CLAUDE.md, relevant docs/plans/, and docs/architecture/ for documented decisions about this area.

## 3. Deep Read

Read all relevant source files. For each file, document:
- **Purpose**: What this file does (1 line)
- **Key functions/classes**: Names and responsibilities
- **Dependencies**: What it imports/calls
- **Contracts**: Input/output shapes at boundaries (Pydantic schemas, TypeScript interfaces)

## 4. Present Findings

Structure the output as:

```markdown
## Research: <topic>

### File Map
| File | Purpose | Lines |
|------|---------|-------|

### Data Flow
(mermaid diagram if applicable — graph LR for pipelines, graph TB for call hierarchies)

### Key Observations
- Numbered list of factual findings (no opinions, no suggestions)

### Boundary Contracts
- Document actual types/shapes at each API boundary found

### Questions
- Things that are unclear from reading the code alone
- Inconsistencies between code and documentation

### Related
- Relevant diary entries (check ~/.claude/memory/diary/)
- Related GitHub issues
- Existing docs/plans/ that touch this area
```

## 5. User Decision Point

After presenting findings, ask:
- "What would you like to do with these findings?"
- Offer: continue researching deeper, move to planning, or end here

Do NOT proceed to implementation. Research mode ends when the user explicitly moves to another phase.
