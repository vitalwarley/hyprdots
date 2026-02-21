---
name: recall
description: Active recall session with spaced repetition logic. Sources from concept briefs and prediction gaps. Exports to Anki via AnkiConnect.
allowed-tools: Read, Glob, Grep, Bash(curl *), Bash(git *), AskUserQuestion, Edit, Write
---

# /recall — Active Recall & Anki Export

Interactive recall sessions that source questions from concept briefs and prediction gaps. Supports spaced repetition logic and Anki card export.

## Arguments

`$ARGUMENTS` supports:
- **Empty** (default): auto-select questions from recent learning
- `session`: questions from current session's topics only
- `anki`: export pending questions to Anki deck (no interactive session)
- `anki after`: run interactive session, then export new cards
- `topic <name>`: focused recall on a specific topic (e.g., `topic repository pattern`)
- `review`: show recall performance summary

## Step 1: Source Questions

### Auto-select (default)

1. Read `docs/learning/prediction-log.md` — extract WRONG predictions
2. Scan `docs/learning/concepts/*.md` — extract recall candidates from HTML comments:
   ```
   <!-- recall-candidates
   Q: ...
   A: ...
   Tags: ...
   Source: ...
   -->
   ```
3. Read "Check Yourself" sections from concept briefs
4. Check recall history in prediction-log.md (look for `### Recall Session` entries)

Priority order (spaced repetition):
1. Questions answered wrong in the last 7 days (immediate reinforcement)
2. Questions never asked in recall (new material)
3. Questions answered correctly but not reviewed in 14+ days (retention check)
4. Questions answered correctly 3+ times (low priority — learned)

Select 3-5 questions per session.

### Session mode

1. Identify topics discussed in the current conversation (read conversation context)
2. Generate 2-3 questions about those specific topics
3. Include at least one question connecting the current topic to a previous concept brief
4. If no concept briefs exist for the current topic, generate questions from first principles

### Topic mode

1. Find the concept brief matching the topic in `docs/learning/concepts/`
2. Extract all recall candidates and Check Yourself questions
3. Add prediction log gaps for this topic
4. Present all relevant questions (up to 5)

## Step 2: Interactive Session

Present questions **one at a time** using back-and-forth discussion:

### For each question:

1. **Ask** — present the question clearly, with context if needed
2. **Wait** — use AskUserQuestion with options that represent common answers:
   - 2-4 answer options (one correct, others are plausible misconceptions)
   - Other option always available for free-form answers
3. **Evaluate** — compare their answer to the correct answer:
   - **Correct**: confirm briefly, add one nuance or connection they might not have considered
   - **Partially correct**: acknowledge what's right, clarify the gap
   - **Incorrect**: explain the correct answer, then ask a follow-up probing question to deepen understanding
4. **Diagram** — generate a mermaid diagram when:
   - The question involves architecture or data flow
   - The user's answer reveals a structural misunderstanding
   - Visualizing the concept would aid understanding

### Discussion principles:
- Never just say "wrong" — always explain WHY the correct answer is correct
- Connect answers to the actual codebase ("In Noux, this is in `backend/noux/repositories/base.py`")
- If the user struggles with a concept, simplify and re-approach from a different angle
- Encourage the user to reason through the answer, not just recall it

## Step 3: Record Results

Append to `docs/learning/prediction-log.md`:

```markdown

### Recall Session: YYYY-MM-DD

| # | Question | Source | Result | Notes |
|---|----------|--------|--------|-------|
| 1 | [question] | [concept-brief/prediction-log] | correct/wrong | [gap if wrong] |
| 2 | ... | ... | ... | ... |

**Score**: X/Y correct
**Weak areas**: [gap categories that appeared]
**Follow-up**: [recommended next recall focus]
```

## Step 4: Anki Export

Triggered automatically after an interactive session (offer via AskUserQuestion: "Export N new cards to Anki?") or manually with `anki` argument.

### Check AnkiConnect

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"version","version":6}'
```

If AnkiConnect is not running, report: "AnkiConnect not available. Start Anki with AnkiConnect plugin, then retry with `/recall anki`."

### Ensure Deck Exists

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"createDeck","version":6,"params":{"deck":"Noux"}}'
```

### Create Cards

For each recall question (from this session + any unexported from concept briefs):

```bash
curl -sf http://localhost:8765 -X POST -d '{
  "action": "addNote",
  "version": 6,
  "params": {
    "note": {
      "deckName": "Noux",
      "modelName": "Basic",
      "fields": {
        "Front": "<b>[Question]</b><br><br>[Context if needed — e.g., pattern name, codebase area]",
        "Back": "[Answer]<br><br><i>Source: [concept brief path or prediction log reference]</i><br><i>Code: [relevant file path in codebase]</i>"
      },
      "tags": ["noux", "[topic-slug]", "[gap-category]"]
    }
  }
}'
```

Card design principles:
- Front: question + minimal context (pattern name, codebase area)
- Back: answer + source reference + code location
- Tags: project name + topic + gap category
- One card per question (fine granularity)

### Report

After export:
- Number of cards created
- Number of duplicates skipped (AnkiConnect rejects duplicate fronts)
- Any errors

## Step 5: Feedback Loop

After each session:
- Questions answered wrong → increase priority for next recall (will appear sooner)
- Questions answered correctly 3+ times across sessions → mark as "learned" in the log (reduce frequency, but never fully remove)
- New gaps discovered during discussion → note as candidates for the next concept brief
- Recurring gaps across sessions → flag as persistent gap, recommend targeted concept brief

## Phase: Review Performance

Triggered by `/recall review`.

### Parse All Recall Sessions

Read all `### Recall Session` entries from `docs/learning/prediction-log.md`.

### Compute Metrics

- Overall recall accuracy over time
- Accuracy by topic/concept brief
- Accuracy by gap category
- Number of "learned" questions (correct 3+ times)
- Number of persistent gaps (wrong 3+ times)
- Time between first encounter and "learned" status

### Present

- Accuracy trend summary
- Topics with strongest/weakest recall
- Recommended next actions (which concept brief to review, what to focus recall on)
- Total Anki cards exported

## Design Principles

1. **Conversational**: Back-and-forth discussion, not a quiz with right/wrong stamps
2. **Adaptive**: Question selection based on past performance, not random
3. **Connected**: Every answer references actual code locations and concept briefs
4. **Visual**: Mermaid diagrams generated on-the-fly for architectural concepts
5. **Exportable**: Everything funnels to Anki for long-term retention
6. **Non-blocking**: Sessions are 5-10 minutes, not exhaustive reviews
