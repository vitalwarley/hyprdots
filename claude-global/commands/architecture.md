Explore architectural decisions through structured scenario analysis. Produces an Architecture Decision Record (ADR) with evaluated options, trade-offs, and a recommendation.

**Architecture question**: `$ARGUMENTS`

## 0. Scope the Decision

Parse `$ARGUMENTS` to identify:
- **The decision to make**: What architectural choice is on the table?
- **The trigger**: Why now? What changed or what's upcoming that forces this decision?

If `$ARGUMENTS` is vague, use AskUserQuestion to clarify scope before proceeding.

## 1. Gather Context

Read the codebase to understand current architecture:

- Read CLAUDE.md, docs/architecture/, docs/plans/ for existing decisions
- Check `docs/decision-log.md` for related prior decisions
- Read the code areas affected by this decision
- Check existing patterns — what conventions are already established?

```bash
# Related issues or discussions
gh issue list --search "<keywords>" --limit 10
```

## 2. Research Current Practices

Search for industry best practices relevant to this decision:

- WebSearch for current (2026) approaches to the problem
- Prioritize official documentation and vendor guidance
- Check Context7 for library-specific documentation if applicable

Document sources — every option must have evidence behind it.

## 3. Generate Options

Identify 2-4 realistic options. For each option:

| Dimension | Evaluate |
|-----------|----------|
| **Approach** | What is it? 2-3 sentence description |
| **Fits existing patterns?** | How well does it align with current codebase conventions? |
| **Complexity** | Implementation effort (low/medium/high) |
| **Maintenance burden** | Ongoing cost after implementation |
| **Scalability** | How it handles growth |
| **Risks** | What could go wrong? |
| **Reversibility** | How hard to undo if it doesn't work out? |

Do NOT fabricate advantages. If an option has no clear benefit over another, say so.

## 4. Scenario Testing

For the top 2-3 options, walk through concrete scenarios relevant to the project:

- **Normal operation**: How does it work day-to-day?
- **Growth scenario**: What happens at 10x current scale?
- **Failure scenario**: What breaks and how do you recover?
- **Evolution scenario**: How does this constrain or enable future features from the roadmap?

Reference the roadmap at docs/vision/roadmap.md if it exists.

## 5. Present ADR

Write the analysis using this format:

```markdown
# ADR: <Decision Title>

**Date**: YYYY-MM-DD
**Status**: Proposed
**Trigger**: <Why this decision is needed now>

## Context

<Current state and the problem or opportunity>

## Options

### Option A: <Name>

<Description, trade-offs, evidence>

**Pros**: ...
**Cons**: ...
**Sources**: [linked references]

### Option B: <Name>

<Description, trade-offs, evidence>

**Pros**: ...
**Cons**: ...
**Sources**: [linked references]

## Comparison

| Dimension | Option A | Option B |
|-----------|----------|----------|
| Complexity | ... | ... |
| Maintenance | ... | ... |
| Scalability | ... | ... |
| Reversibility | ... | ... |
| Fits codebase | ... | ... |

## Scenario Analysis

### Normal Operation
...

### Growth (10x)
...

### Failure Mode
...

## Recommendation

<Which option and why. Be direct.>

## Open Questions

- [ ] Questions that need answers before finalizing

## Approval

- [ ] Reviewed by: <user>
- [ ] Decision: Accepted / Rejected / Deferred
```

## 6. User Decision Point

Present the ADR in the conversation. Ask:
- Does the analysis cover the right options?
- Is the recommendation aligned with project priorities?
- Should this be saved to `docs/architecture/` or `docs/decision-log.md`?

Do NOT proceed to implementation. Architecture exploration ends with a decision, not code.
