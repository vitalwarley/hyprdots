---
name: log
description: Append a session summary to the vault daily log, or write notes to other vault folders with explicit instructions
allowed-tools: Read, Glob, Grep, Bash(date *), Write, Edit
---

# /log — Session → Vault Daily Log

Appends a concise summary of the current Claude Code session to the vault's daily note. Optionally accepts instructions to write notes elsewhere in the vault.

## Arguments

`$ARGUMENTS` supports:
- **(empty)** — summarize session, append to today's daily log
- **Custom instructions** — e.g., `diagnostic note in areas/health/`, `insight to inbox/`, `update areas/bjj/tracking.md with...`

## Step 0: Read Vault Instructions

**Always** read `~/life/notes/CLAUDE.md` (vault instructions) before deciding anything. This gives you:
- Vault structure and conventions
- Daily log format (`## Log` section, timestamp blocks, tag taxonomy)
- Note types, templates, routing rules
- SOPs and area definitions

Also read `~/life/notes/.claude/CLAUDE.md` if it exists (may have local skill context).

## Step 1: Determine Mode

Parse `$ARGUMENTS`:

| Input | Mode | Action |
|-------|------|--------|
| Empty or session-related | **daily-log** | Summarize session → append to `## Log` |
| Mentions a vault path or folder | **custom-target** | Write note to specified location |
| Mentions a specific area/project | **custom-target** | Route to the appropriate vault file |

## Step 2a: Daily Log Mode

### Summarize the Session

Reflect on the conversation history. Extract:
- **What was done**: files created/edited, decisions made, problems solved
- **Key outcomes**: features built, bugs fixed, knowledge captured
- **Notable insights**: anything the user would want to recall later

### Calibrate Length

| Session size | Summary |
|-------------|---------|
| Quick task (1-3 exchanges) | 1 line with tag |
| Medium session (4-15 exchanges) | 2-4 sub-bullets |
| Deep session (15+ exchanges, multiple topics) | Short paragraph or 4-6 sub-bullets, grouped by topic |

### Write to Daily Note

1. Get today's date: `date +%Y-%m-%d` and `date +%H:%M`
2. Read `~/life/notes/inbox/journal/YYYY-MM-DD.md`. If it doesn't exist, create with template:

```markdown
---
created: YYYY-MM-DD
type: daily
---

## Plan

-

## Log

%%
Estrutura de cada bloco: ações primeiro, depois insights (#log/insight), depois TODOs.
Um bullet = um assunto. Tag no fim do bullet de abertura ou do bullet relevante.
%%

## Review

### Plan vs Reality

| Planejado | Resultado | Nota |
|---|---|---|

### Observações

-
```

3. Append to `## Log` at the correct chronological position using the **Edit tool** (not Write). The daily note uses **tab indentation** — match exactly (tab for sub-bullets, two tabs for sub-sub-bullets):

```
- HH:MM
	- Sessão Claude Code (PROJETO): resumo do que foi feito. #log/ai
		- sub-detalhe se necessário
```

4. Apply tags per vault conventions:
   - Always: `#log/ai`
   - Add domain tags based on session content: `#log/work/PROJECT`, `#log/study`, `#log/practice/TYPE`, etc.
   - Add `#log/insight` to sub-bullets that are insights

### Identify the Project

Determine the project context from:
- The current working directory (basename or project name)
- The git repo name
- Files that were edited

Use this to set the project reference in the log entry (e.g., "Sessão Claude Code (life repo)", "Sessão Claude Code (toledo)").

## Step 2b: Custom Target Mode

When `$ARGUMENTS` specifies a non-default destination:

1. Read vault CLAUDE.md to understand the target location's conventions.
2. Read the target file if it exists (to append correctly, not overwrite).
3. Write the note following the target's format:
   - **Areas** (`areas/*.md`): append to `## Tasks` or appropriate section
   - **Projects** (`projects/*.md`): append to relevant section
   - **Inbox** (`inbox/`): create a fleeting note with frontmatter
   - **Other paths**: use best judgment from vault conventions

### Routing Examples

| Instruction | Target | Action |
|------------|--------|--------|
| `diagnostic note in areas/health/` | `areas/health/health.md` or `areas/health/sleep-diagnostic.md` | Append diagnostic findings |
| `insight to zettelkasten` | Suggest using `/zettel` skill instead | Better tool exists |
| `update bjj tracking` | `areas/bjj/tracking.md` | Append session data |
| `note about X in inbox` | `inbox/X.md` | Create fleeting note |

If the target is ambiguous, read the vault structure to resolve. If still unclear, ask the user.

## Step 3: Confirm

Output a 1-line confirmation:
- Daily log: "Logged to `inbox/journal/YYYY-MM-DD.md` at HH:MM."
- Custom: "Written to `path/to/file.md`."

## Design Principles

1. **Fire-and-forget**: no questions in daily-log mode — infer everything from session context
2. **Vault-native**: always read vault CLAUDE.md first; respect all conventions (tags, structure, wikilinks)
3. **Proportional**: summary length matches session depth — never over-document a quick fix
4. **Chronologically correct**: insert at the right timestamp position, not blindly at the end
5. **Non-destructive**: always append, never overwrite existing log entries
