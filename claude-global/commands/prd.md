# /prd - Product Requirements Document Generator

Brainstorm and iterate on requirements for a feature before writing any code. Produces a structured spec file that downstream commands (`/next`, `/resume`) can consume.

## Usage

```
/prd <description or issue number>
```

## Examples

```bash
/prd Add dark mode toggle to settings
/prd #42
/prd Refactor auth to support OAuth providers
```

## Workflow

### 1. Gather Context

**If issue number provided**:
```bash
gh issue view <number> --json title,body,labels,milestone
```

**If description provided**: Use it as the starting point.

**Always**: Read the project's CLAUDE.md and existing `docs/plans/` to understand conventions and architecture.

### 2. Interactive Brainstorming

Present the user with structured questions using AskUserQuestion. Cover:

- **Scope**: What's in and out of scope? What's the minimum viable version?
- **Users**: Who uses this? What's their workflow?
- **Constraints**: Performance requirements? Compatibility? Deadlines?
- **Dependencies**: What existing code/APIs does this touch?
- **Risks**: What could go wrong? What's uncertain?

Do NOT generate a wall of questions. Ask 2-3 at a time, iterate based on answers.

### 3. Research (always for non-trivial features)

Even for "simple" features, research prevents reinventing patterns that have known best practices:

- **Web search** for current (2025-2026) industry best practices for the specific pattern (e.g., "runtime configuration FastAPI", "settings UI UX patterns")
- **Framework precedents**: How do Django, Spring Boot, Rails solve this? What's the canonical pattern?
- **Existing codebase**: Grep for similar patterns already in the project — reuse over reinvention
- **Cite sources** in a `docs/research/<feature>.md` artifact linked from the PRD

The research doc should be concise and decision-oriented — not a literature review. Structure: options table → recommendation → sources.

### 4. Generate Spec File

**Location**: `docs/plans/<feature-name>.md` (in the project directory, not life/)

**Structure**:

```markdown
# <Feature Name>

**Created**: YYYY-MM-DD
**Issue**: #N (if applicable)
**Status**: Draft
**Research**: [link to docs/research/<feature>.md if produced]
**Attack Plan**: [link to docs/plans/<feature>-attack.md when created]

## Problem Statement

1-2 sentences. What problem does this solve? Why now?

## Requirements

### Must Have
- [ ] Requirement 1
- [ ] Requirement 2

### Nice to Have
- [ ] Optional requirement

### Out of Scope
- Explicitly excluded items

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ... | ... | ... |

Only decisions that constrain the solution space (storage choice, API shape, UI pattern).
Not implementation details (file structure, build steps, test fixtures).

## User Flow

Mermaid diagram or bullet list showing user-facing interactions.

## Acceptance Criteria

- [ ] Observable, testable behavior the feature must satisfy
- [ ] Written from the user's or API consumer's perspective
- [ ] Not how to test — what to verify

## Open Questions

- [ ] Unresolved requirement-level questions (not implementation questions)
```

**What does NOT belong in the PRD** (put these in the attack plan instead):

- Architecture/approach details (module patterns, dependency wiring)
- Design philosophy analysis (Ousterhout, etc.)
- Files to create/modify
- Build order / waves
- Test strategy (unit/integration/fixtures)
- Concurrency model, sequence diagrams of internal flows
- Code-level concerns (constructor signatures, caching strategies)

The PRD owns **what** and **why**. The attack plan (`/attack-plan`) owns **how**.

### 5. Review with User

Present the generated spec and ask for feedback. Iterate until approved. Mark status as "Approved" when confirmed.

### 6. Optionally Create GitHub Issues

If the project uses GitHub issues with milestones (like noux):

```bash
gh issue create --title "Step 1 title" --body "..." --milestone "<milestone>"
```

Only do this if user confirms. Some projects don't use issues.

## Design Principles

- **Iterate, don't dump**: Short questions, build understanding incrementally
- **Research before designing**: Even simple features have known best practices — find them
- **Respect existing patterns**: Read the codebase before proposing architecture; grep for precedents
- **Verify every claim**: File paths, function names, caching behavior — all must match current code
- **PRD = requirements contract**: Stable, reviewed by stakeholders. Implementation details change often and belong in the attack plan
- **Spec is a living document**: Mark it Draft → Approved → Implementing → Done
- **Acceptance criteria over test strategy**: The PRD says what to verify; the attack plan says how to test it

## Anti-Patterns

- Don't generate a 500-line spec without user input — this is brainstorming, not monologuing
- Don't propose architecture without reading existing code
- Don't skip the "Out of Scope" section — scope creep starts here
- Don't create GitHub issues without user confirmation
- Don't put implementation details in the PRD — no build order, no file lists, no test fixtures, no code-level design. These belong in `/attack-plan`
