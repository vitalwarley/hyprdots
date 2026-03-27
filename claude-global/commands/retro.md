# /retro - Session Retrospective

Synchronous session review: identify what went wrong, what went well, pending actions, and improvements to workflows, skills, and memory. Produces a structured output in conversation — no async diary or file generation.

## Usage

```
/retro [focus]
```

## Focus (optional)

- **(empty)** — full session retrospective (default)
- `workflow` — focus on process/workflow issues only
- `skills` — focus on skill/command improvements only
- `memory` — focus on what should be remembered for future sessions

## Workflow

### 1. Gather session context

Scan the conversation history for:
- **Mistakes**: moments where the user corrected you or you had to redo work
- **Friction**: points where you went back and forth unnecessarily
- **Successes**: approaches the user validated or that worked on first try
- **Decisions**: choices made during the session that should inform future work
- **Pending work**: tasks started but not completed, follow-ups mentioned

### 2. Build the retrospective

Present the following structure directly in conversation (no file output):

#### What went wrong

| # | Issue | Impact | Root cause |
|---|-------|--------|------------|
| 1 | Short description | What it cost (time, rework, user frustration) | Why it happened |

For each issue, classify the root cause:
- **Memory violation**: guidance exists in memory/CLAUDE.md but wasn't followed
- **Skill gap**: the skill/command lacks guidance for this scenario
- **Process gap**: no workflow exists for this situation
- **Judgment error**: had the information, made the wrong call

#### What went well

Bullet list of approaches that worked. Be specific — "bot comment verification was thorough" not "review went well". Include approaches the user validated even silently (accepted without pushback).

#### Pending actions

| Action | Status | Owner | Priority |
|--------|--------|-------|----------|
| Description | Open/Blocked/Deferred | You/Claude/Next session | High/Medium/Low |

#### Proposed improvements

Group by type:
- **Skill updates**: changes to commands/skills in `~/.claude/commands/` or `~/.claude/skills/`
- **Memory entries**: new feedback/user/project memories to save
- **Convention updates**: changes to project CLAUDE.md, convention docs, or templates
- **Workflow changes**: process improvements not captured by the above

For each improvement, state:
1. What to change
2. What session event triggered it
3. Whether to apply now or defer

### 3. Act on approved improvements

After presenting the retrospective, ask the user which improvements to apply. Then execute them:
- **Memory entries**: save immediately
- **Skill updates**: edit the skill file
- **Convention updates**: commit to the appropriate branch
- **Workflow changes**: update CLAUDE.md or relevant docs

Do NOT apply improvements without user approval. Present first, act second.

## Design Principles

- **Synchronous**: everything happens in conversation, no background agents or file generation
- **Actionable**: every "what went wrong" has a root cause classification and proposed fix
- **Honest**: don't minimize mistakes or inflate successes
- **Scoped**: only this session — not a general project review
- **Efficient**: the retro itself should take 2-5 minutes, not dominate the session

## Anti-Patterns

- Don't generate a diary entry — use `/diary` for that
- Don't write a review report — this is about process, not code
- Don't propose improvements for things that already work
- Don't list generic "things to remember" — be specific about what triggered each learning
- Don't auto-apply improvements — present, get approval, then act
