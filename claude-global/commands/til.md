# /til - Quick Learning Capture

Capture learning insights from current chat context with automatic project tagging.

## Usage

```bash
# Extract from current chat context (primary)
/til

# Override with explicit description
/til Custom insight text here

# Add extra tags
/til #performance #optimization
```

## Workflow

### 1. Extract Learning from Context

**Primary mode** (no arguments): Analyze recent chat messages to identify the key learning:
- Look for explanations, discoveries, bug fixes, insights
- Identify the "aha moment" or transferable knowledge
- Extract as a concise title (1 line) + optional details (2-3 lines)

**Override mode** (with arguments): Use provided text as the learning description.

### 2. Detect Project Context

Auto-detect current project:
```bash
# Try git repo name first
REPO=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename)

# Fall back to directory name
if [ -z "$REPO" ]; then
  REPO=$(basename "$PWD")
fi
```

Tag entries with `Project: <name>` for cross-project queries.

### 3. Auto-Tag from Content

If no explicit # tags in input, auto-detect from learning content:

**Keywords to tags**:
- `linux, arch, systemd, bash, zsh` → `#linux #ops`
- `git, vim, tmux, docker` → `#tool-name`
- `python, rust, typescript, go` → `#language-name`
- `memory, performance, cpu, optimization` → `#performance`
- `postgres, mysql, redis, sqlite` → `#database`
- `api, http, rest, graphql` → `#api`

Always include: `#project-name`

### 4. Primary Storage (Global)

**Location**: `~/.claude/memory/learnings/til/YYYY-MM-DD.md`

**File structure** (create if doesn't exist):
```markdown
# TIL: YYYY-MM-DD

Quick learning captures from across projects.

---
```

**Entry format** (append):
```markdown
## HH:MM - <Learning Title>

**Project**: <project-name>

<Optional details or context>

<Code snippet if extracted from chat>

Tags: #tag1 #tag2 #project-name

---
```

### 5. Optional Local Copy

If current repo has `.claude/TIL.md`, append a simplified version:

```markdown
## YYYY-MM-DD (create header if doesn't exist)

**<Learning Title>**
- <Details if any>
- Tags: #tag1 #tag2
```

### 6. Report Back

```
✅ TIL Entry Captured

**Source**: Chat context (last 5 messages)
**Project**: noux
**Location**: ~/.claude/memory/learnings/til/2026-02-14.md

---
## 14:23 - Linux available memory is the real health metric

**Project**: life

Linux "used" includes buff/cache (disk cache). Check "available" instead — it shows what apps can actually use. Buff/cache is opportunistic and self-releases when needed.

```bash
free -h  # Check "available" column
```

Tags: #linux #memory #ops #life

---

Local copy: .claude/TIL.md ✓
```

## Integration with /learn-from

TIL entries serve as lightweight captures. At end of week:

```bash
/learn-from this week
```

Will include TIL entries in structured extraction if they represent significant learnings. Output goes to `~/.claude/memory/learnings/extracts/`.

## Edge Cases

- **Empty context**: Prompt user for description if no learning detected
- **Multi-project session**: Use most recent project context
- **System-level learning**: Tag as `Project: system` if not in a repo
- **Code blocks in chat**: Extract and include in TIL entry

## File Management

- Daily TIL files accumulate indefinitely (small, searchable)
- Query: `grep -r "postgres" ~/.claude/memory/learnings/til/`
- View today: `cat ~/.claude/memory/learnings/til/$(date +%Y-%m-%d).md`

## Anti-Patterns

- Don't require confirmation → instant capture, show after
- Don't over-structure → keep it lightweight
- Don't force categorization → tags emerge naturally
- Don't duplicate → check if similar entry exists today first
