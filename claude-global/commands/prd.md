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

### 3. Research (if needed)

If the feature involves unfamiliar libraries, patterns, or APIs:
- Search web for current best practices
- Check existing codebase for similar patterns
- Read relevant dependency docs

### 4. Generate Spec File

**Location**: `docs/plans/<feature-name>.md` (in the project directory, not life/)

**Structure**:

```markdown
# <Feature Name>

**Created**: YYYY-MM-DD
**Issue**: #N (if applicable)
**Status**: Draft

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

## Design

### Approach

Describe the chosen approach in 1-2 paragraphs. Reference existing patterns in the codebase.

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| ... | ... | ... |

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| ... | create/modify | ... |

## Build Order

1. **Step 1**: Description → creates X, modifies Y
2. **Step 2**: Description → depends on step 1
3. **Step 3**: Description → can parallel with step 2

## Test Strategy

- Unit tests for: ...
- Integration tests for: ...
- Manual verification: ...

## Open Questions

- [ ] Question that needs answering during implementation
```

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
- **Respect existing patterns**: Read the codebase before proposing architecture
- **Spec is a living document**: Mark it Draft → Approved → Implementing → Done
- **Build order matters**: Dependencies between steps must be explicit
- **Test strategy upfront**: Not an afterthought

## Anti-Patterns

- Don't generate a 500-line spec without user input — this is brainstorming, not monologuing
- Don't propose architecture without reading existing code
- Don't skip the "Out of Scope" section — scope creep starts here
- Don't create GitHub issues without user confirmation
