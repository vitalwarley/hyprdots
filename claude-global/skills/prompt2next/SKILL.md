---
name: prompt2next
description: Generate a self-contained prompt for a fresh Claude Code session, scoped to a slice the user names (e.g., a batch group, a single task, a milestone). Captures context from the current session — decisions, artifacts, constraints — so the next session can cold-start without re-deriving anything.
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(date *), Bash(pwd), Bash(ls *), Write
---

# /prompt2next — Bootstrap Prompt for a Future Session

Produces a paste-ready prompt for a new Claude Code session. The prompt is self-contained: a cold-start session reading it should know **what to do, what to read, what's already decided, and what's out of scope** — without needing the current conversation.

Use when the current session has produced a plan (or made decisions) that need execution in one or more follow-up sessions, and you want each follow-up to start with full context.

## Arguments

`$ARGUMENTS` = name of the slice the prompt should target. Examples:
- `com batching` — execute the planned batch grouping; first batch by default
- `batch A` / `batch B` / `batch 1` — a specific batch group
- `T2` / `task T2` — a single task from a numbered breakdown
- `wave 1` — a wave from an attack plan
- `forecasting only` — a thematic slice
- `(empty)` — ask the user which slice to scope; offer top candidates inferred from session

## Workflow

### 1. Identify the source plan

Scan the recent session for the canonical artifact the slice refers to. Likely locations (check in this order):
1. Files created/edited this session (`Write`/`Edit` calls) — recent plan, spec, attack plan, design doc
2. `notes/areas/<x>/plan.md`, `docs/plans/*.md`, `docs/features/*/PLAN.md`, `attack-plan.md`
3. The hub file referenced — `notes/areas/<x>/<x>.md`, `README.md` of a project area

If multiple candidates, ask which one. If none, ask the user to point to the plan/spec.

### 2. Resolve the slice

Map `$ARGUMENTS` to a concrete subset of the plan:

| Argument shape | Resolution |
|---|---|
| `com batching` / `with batching` | Read the plan's batching/grouping section; pick **first batch** unless user says otherwise. Mention how to continue (next batch via `/prompt2next batch B` etc.) |
| `batch X` / `wave N` | The named group |
| `T<N>` / `task T<N>` | The single task |
| Theme word (e.g., `forecasting`) | Tasks/sections matching the theme |
| Empty | Present 2-4 inferred slices via AskUserQuestion-style numbered list |

Confirm understanding to the user in one line before generating: *"Targeting <slice> from <plan path>. Batches/tasks to include: <list>."*

### 3. Gather context to embed

Pull these from the session and project state:

- **Working dir**: `pwd` at session start (or wherever the plan lives)
- **Branch**: `git branch --show-current` (if relevant)
- **Plan path(s)**: absolute path(s) the new session must read first
- **Hub path(s)**: any companion hub/area file
- **Decisions already made**: from session — extract bullet decisions, env vars chosen, tool selection, naming conventions, plan numbers
- **Constraints**: anti-patterns/rules from CLAUDE.md the new session must respect (cite paths, don't restate)
- **Out of scope**: tasks/batches NOT in this slice (so the new session doesn't drift)
- **Success criteria**: definition of done for this slice (concrete files/states/commits)

### 4. Compose the prompt

The prompt is **raw markdown content** with this structure:

```markdown
# Session: <slice name>

**Working dir**: <abs path>
**Branch**: <branch> (or `main` / N/A)
**Date context**: <today's date>

## Read first (in order)
1. <plan path> — full plan, especially section "<X>" for this slice
2. <hub path> — current status table + decisions
3. <CLAUDE.md path> — project conventions (read fully)

## Goal
<1-2 sentences: what this session must produce, scoped to slice>

## Context already decided (do not re-litigate)
- <decision 1 from prior session>
- <decision 2>
- ...

## Tasks (this session)
1. **<Task ID>** — <one line>
   - Output: <concrete artifact / file / command working>
   - Done when: <observable signal>
2. **<Task ID>** — ...
3. ...

## Out of scope (other sessions)
- <batch/task not included> — handled by `/prompt2next <slice>` later

## Success criteria for this session
- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] Status table in <hub path> updated for completed tasks
- [ ] Commits pushed to <repo> (if applicable)

## How to continue after this session
Run `/prompt2next <next slice name>` to generate the next session's prompt.
```

**File contract**:
- The file saved to disk must contain ONLY the raw content above — starting with `# Session: ...`, no outer ` ``` ` wrapper. The file is consumed by `cat` and pasted into the next session; an outer fence would leak into the new session as literal backticks.
- First line of the file is `# Session: <slice name>` — not ` ``` `.
- Last line of the file is the last bullet/sentence of "How to continue" — not ` ``` `.
- A `head -1 /tmp/prompt-*.md` should return the H1, never a fence.

### 5. Save to /tmp

Always save the prompt to `/tmp/prompt-<slug>-<YYYY-MM-DD>.md` automatically (no confirmation needed). If the user wants a different location (e.g., `notes/areas/.../prompts/`), accept their path and save there instead.

### 6. Chat output (strict)

**The chat output of this skill is exactly one line: `Execute <absolute-path>`.** Nothing else — no preamble, no slice confirmation, no echo of the prompt content, no usage hints, no surrounding prose.

Example:
```
Execute /tmp/prompt-update-preview-19-05-2026-05-12.md
```

Why this exact shape: the user copies the line as-is into a fresh Claude Code session. The next Claude sees `Execute <path>` and reads the file directly. Any extra text in chat is friction (user has to clean the paste) and signals the skill doesn't trust its own file output.

Do NOT add:
- Slice/plan confirmation (already inferred during the run; the file itself states it)
- "Saved to..." wording (redundant with `Execute`)
- Copy hints (`xclip ...`) — the user knows their own clipboard workflow
- A fenced block — output is a single line, not a code snippet

## Design principles

- **Cold-start ready**: a session that has never seen the prior conversation must be able to execute. No "as we discussed" — restate or cite.
- **Slice-discipline**: list what's *out* of scope explicitly. Drift is the failure mode.
- **Cite, don't duplicate**: link to the plan/CLAUDE.md by path; don't paste their contents into the prompt.
- **Observable done**: success criteria are checkable (file exists, command runs, table updated) — not vague ("feature works").
- **Chained-friendly**: prompts mention how to bootstrap the next session, so a single user can pipeline batched work.

## Anti-patterns

- Don't generate a recap of the conversation — generate **forward-looking instructions** for the next session
- Don't fabricate task IDs that aren't in the plan; if the plan has no IDs, name tasks by deliverable
- Don't omit "out of scope" — that's the section that prevents the next session from doing too much
- Don't re-explain decisions; cite them as decided, with location ("see plan.md > Decisões")
- Don't prescribe a model (Sonnet/Opus) — the user picks at session start

## Related skills

- `/next` — read the current branch's state and propose next task; complementary (uses doc state, not session context)
- `/attack-plan` — break a spec into autonomous-runnable waves; `/prompt2next wave 1` natural follow-up
- `/run-autonomous` — fire-and-forget; use when the prompt is small enough to autopilot, not when human iteration is expected
