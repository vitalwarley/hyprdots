---
name: concept-brief
description: Generate learning package with diagrams, exercises, and key mechanics for a completed milestone or pattern
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Write
---

# /concept-brief — Learning Package Generator

Generate a comprehensive learning document after a milestone lands. Targeted at the user's specific prediction gaps, not generic explanations.

## Arguments

`$ARGUMENTS` supports:
- **Milestone/pattern reference**: `A1 repository pattern`, `SSE event schemas`, `v0.2.13 Stream A`
- **Issue reference**: `#373`, `#374`

## Step 1: Gather Implementation Details

Read the actual implementation:
- `git log --oneline` for relevant commits/PRs
- `gh pr view <number> --json files,additions,deletions` for changed files
- Read key new/modified files to understand the implementation
- Read the spec/plan that guided implementation

## Step 2: Read Prediction Log

Check `docs/learning/prediction-log.md` for this milestone:
- Which predictions were WRONG
- What gap categories were identified
- These determine emphasis — spend more space on concepts the user got wrong

## Step 3: Read Existing Concept Briefs

Check `docs/learning/concepts/` for related briefs. Note connections for cross-referencing.

## Step 4: Generate Brief

Write to `docs/learning/concepts/[slug].md` (e.g., `repository-pattern.md`, `sse-event-schemas.md`).

### Structure:

```markdown
# [Pattern/Concept Name]

**Milestone**: [reference with link]
**Date**: YYYY-MM-DD
**Prediction accuracy**: X/Y ([link to prediction log entry])

---

## 1. What It Is (30 seconds)

[1 paragraph. No jargon. What does this pattern/change DO in plain terms.]

```mermaid
graph TB
    [Mermaid diagram showing the pattern in context of the Noux codebase.
     Use actual class/file names from the implementation.
     Highlight the new/changed components.]
```

## 2. Why Here, Why Now (1 minute)

[What problem existed BEFORE this change. Concrete consequences — not theoretical.
What triggered the decision. Link to the spec/decision-log entry if applicable.]

### Before
[Brief description or code snippet of the problematic state]

### After
[Brief description or code snippet of the resolved state]

## 3. The Key Mechanic (2 minutes)

[The ONE concept that, if understood, makes everything else follow.
For repositories: session lifecycle ownership.
For SSE schemas: the typed union discriminator.
For service extraction: dependency injection pattern.]

**Before:**
```python
# Minimal code showing the old way (3-8 lines, actual code from the codebase)
```

**After:**
```python
# Minimal code showing the new way (3-8 lines, actual code from the codebase)
```

**Why each change matters:**
- [Line-by-line or block-by-block annotation of WHY, not just WHAT]

## 4. Architecture in Context

```mermaid
graph TB
    [Full system diagram showing how this pattern relates to the overall architecture.
     Mark which components existed before vs added/modified.
     Show dependency arrows — what depends on this, what this depends on.
     Show data flow direction.]
```

[2-3 sentences explaining the diagram. Call out the most important dependency relationships.]

## 5. Exercises

### Exercise 1: Trace the Request
[A specific request type that flows through the new pattern.
"A user sends POST /events with a new event. Trace the request through
all layers, naming each class and method involved."]

<details>
<summary>Answer</summary>

[Step-by-step trace with class names, method names, and what happens at each step.
Include a mermaid sequence diagram if the flow involves 3+ components.]

</details>

### Exercise 2: Failure Propagation
[A specific failure scenario.
"The database is locked when EventRepository.add() is called.
Where does the exception originate? Who catches it? What does the user see?"]

<details>
<summary>Answer</summary>

[Exception flow with class names. Note: if the answer involves patterns
from a different concept brief, cross-reference it.]

</details>

### Exercise 3: Design Decision
[A "why" question about a specific choice.
"Why does BaseRepository.get_or_raise() exist separately from get()?
When would a caller prefer get() over get_or_raise()?"]

<details>
<summary>Answer</summary>

[Explanation of the trade-off. Reference the spec/decision-log if applicable.]

</details>

### Exercise 4: Connection
[How this pattern interacts with another pattern in the codebase.
"How does the repository layer interact with the domain exception pattern
from v0.2.10? What exception does get_or_raise() throw?"]

<details>
<summary>Answer</summary>

[Cross-pattern explanation. Link to related concept brief.]

</details>

## 6. Targeted Gaps

[This section ONLY appears if the user had wrong predictions for this milestone.
Each subsection addresses a specific prediction gap with deeper explanation.]

### Gap: [Category] — [What the user got wrong]

[Deeper explanation of the concept. Use different framing than the main sections.
Include a diagram if the gap was about data flow or architecture.
Address the specific misconception revealed by the wrong prediction.]

## 7. Check Yourself

1. [Self-assessment question — different from exercises, more recall-oriented]
2. [Self-assessment question]
3. [Self-assessment question]

<details>
<summary>Answers</summary>

1. [Answer]
2. [Answer]
3. [Answer]

</details>

---

## Related

- [Link to related concept briefs in this directory]
- [Link to the spec that guided this implementation]
- [Link to key source files in the codebase]
```

## Step 5: Cross-Reference

Update `docs/learning/prediction-log.md`: add a link to the new concept brief in the relevant exam entry.

## Step 6: Extract Recall Candidates

From the "Check Yourself" questions and exercise answers, identify 3-5 strong candidates for active recall and Anki cards. Note them at the bottom of the concept brief:

```markdown
<!-- recall-candidates
Q: [question]
A: [answer]
Tags: [topic], [gap-category]
Source: concepts/[this-file].md#section
---
Q: [question]
A: [answer]
Tags: [topic], [gap-category]
Source: concepts/[this-file].md#section
-->
```

These HTML comments are parsed by the `/recall` skill to source questions.

## Step 7: Present Summary

Show the user:
- Title and 1-sentence overview
- Key mechanic (1 sentence)
- Number of exercises and gap-targeted sections
- File path for later reading
- Offer to run `/recall` on this topic immediately

## Design Principles

1. **Grounded in actual code**: Every code snippet comes from the real codebase, not generic examples
2. **Gap-targeted**: Prediction misses determine emphasis — not equal coverage of everything
3. **Layered depth**: 30-second overview → 1-minute context → 2-minute mechanic → deep exercises
4. **Cross-referenced**: Always link to related briefs, specs, decision logs, and source files
5. **Self-testable**: Every section ends with a way to verify understanding
