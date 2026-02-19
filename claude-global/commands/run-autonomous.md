# /run-autonomous - Fire-and-Forget Autonomous Claude Session

Launch a sandboxed Claude session in the background using Docker. The current session continues while the autonomous agent works independently on a shallow clone.

The autonomous run is a **tool**, not a session — it does NOT get its own diary entry. The parent session (this one) captures the autonomous work in its own diary, just like a test run or build.

## Usage

```
/run-autonomous <prompt> [options]
```

## Arguments

- `$ARGUMENTS` — the prompt and optional flags

## Examples

```bash
/run-autonomous Fix all failing tests in src/
/run-autonomous Implement issue #42 --max-turns 30
/run-autonomous Refactor auth module to use Strategy pattern --max-turns 20 --base develop
/run-autonomous Run the full test suite and fix any failures --project ~/life/1-projects/noux
```

## Workflow

### 1. Parse Arguments

Extract from `$ARGUMENTS`:
- **Prompt**: everything that isn't a flag
- **--max-turns N**: turn limit (default: 10)
- **--project PATH**: project directory (default: current working directory)
- **--base BRANCH**: PR target branch (auto-detected from git remote HEAD if omitted)

**Issue number detection**: If the prompt is a bare number (e.g., `130`) or `#N` pattern, treat it as a GitHub issue reference:

```bash
# Fetch issue details to build the prompt
gh issue view 130 --json title,body,labels
```

Construct the prompt from the issue: `"Implement issue #130: <title>\n\n<body>"`

This allows shorthand like `/run-autonomous 130` instead of requiring `/run-autonomous Implement issue #130`.

**Batch mode**: If the prompt contains multiple bare numbers or `#N` patterns (e.g., `195 184` or `#195 #184`), treat each as a separate issue to launch in parallel:

```bash
# Examples:
/run-autonomous 195 184 --max-turns 20 --base develop
/run-autonomous #195 #184 --base develop
```

- `--max-turns` applies to each issue individually
- `--base` applies to all issues
- Fetch all issues in parallel (parallel `gh issue view` calls)
- Validate Docker once before launching (not per-issue)
- **Check capacity before launching**: run `~/life/scripts/claude-autonomous/max-concurrent.sh` to get the recommended max concurrent agents based on available memory. If fewer agents are recommended than issues requested, split into waves and inform the user (e.g., "5 issues requested, memory allows 3 concurrent — launching wave 1 of 2"). Launch wave 2 after wave 1 completes.
- Launch all `run.sh` calls as parallel `run_in_background: true` Bash calls in a single message (up to the capacity limit)

### 2. Validate

Before launching:

```bash
# Verify Docker is available
docker info >/dev/null 2>&1 || { echo "Docker not running"; exit 1; }

# Verify the image exists (or offer to build)
docker image inspect claude-autonomous >/dev/null 2>&1
```

If the image doesn't exist, inform the user:
```
Image 'claude-autonomous' not found. Build it first:
  docker build -t claude-autonomous ~/life/scripts/claude-autonomous/
```

### 3. Launch in Background

Use the Bash tool with `run_in_background: true`:

```bash
~/life/scripts/claude-autonomous/run.sh "<project-dir>" "<prompt>" --max-turns <N> --base <branch>
```

This runs the full `run.sh` script which handles:
- **Shallow clone** from remote — fully isolated repo, user's checkout untouched
- **New branch** creation (`claude/<slug>-<date>`)
- **Frontend dep pre-install** — if `frontend/package.json` exists, runs `npm ci` via Docker before agent starts (saves agent turns)
- **Two-phase workflow** (see below)
- Docker container lifecycle (detached mode for live logging)
- Mounting clone dir (rw), `~/.claude/` (rw), `~/.config/gh` (ro), `~/.ssh` (ro)
- `--dangerously-skip-permissions` inside the container
- Live logging to `/tmp/claude-auto-*-{implement,review,fix,rereview,commit}.log` (streamable via `tail -f`)
- Full log dump to `/tmp/claude-auto-*-{phase}-full.log` (guaranteed complete)
- **Safe cleanup** — clone preserved if no commits were made (uncommitted work recoverable)

#### Three-Phase Workflow with Bounded Re-Review

Each autonomous run executes up to five Claude invocations:

```
Phase 1: Implement → Phase 2: Review → Phase 3: Fix → Phase 2b: Re-review → Commit
```

**Phase 1 — Implement** (full `--max-turns` budget):
- Reads the issue, writes code, gets lint passing
- Does NOT commit, push, or create PR
- Leaves changes staged/unstaged for phase 2

**Phase 2 — Review** (`--max-turns / 3`):
- Fresh read-only Claude invocation — does NOT modify code
- Verifies contract correctness: field names, type shapes, Pydantic↔TypeScript parity
- Verifies test fixtures match actual data shapes
- Checks no untyped dicts at API boundaries
- Writes structured findings file (BLOCKING / NON-BLOCKING) to `.claude-review/`

**Phase 3 — Fix** (`--max-turns / 3`, skipped if no BLOCKING findings):
- Reads the findings file, fixes each BLOCKING issue
- Runs validation (`scripts/pre-push-quick.sh`)
- Does NOT commit

**Phase 2b — Re-review** (`--max-turns / 4`, scoped to fix delta only):
- Reviews only the changes introduced by Phase 3 (not the full changeset)
- Same checklist, writes to a separate findings file

**Commit** (`--max-turns / 4`):
- If Phase 2b found BLOCKING issues: fixes them first (max 1 iteration), then commits
- Otherwise: commits directly
- Includes NON-BLOCKING findings in the PR body under "Review Notes"
- Unresolvable BLOCKING findings noted as "Known Issues" in PR body

**Why separate invocations?** The reviewer must not fix its own findings. Separating review (read-only) from fix (write) enforces honest reporting — the reviewer has no incentive to minimize findings.

### 4. Report to User

After launching, immediately report.

**Single issue** — full detail block:

```
Autonomous session launched in background.

  Project:    <path>
  Clone:      /tmp/claude-auto-<timestamp>-clone
  Branch:     claude/<slug>-<date>
  Base:       <base-branch>
  Prompt:     <prompt>
  Phase 1:    implement (<N> turns)
  Phase 2:    review (<N/3> turns)
  Phase 3:    fix (<N/3> turns)
  Phase 2b:   re-review (<N/4> turns)
  Commit:     (<N/4> turns)

Monitor:  tail -f /tmp/claude-auto-<timestamp>-implement.log
          tail -f /tmp/claude-auto-<timestamp>-review.log
Stop:     docker stop claude-auto-<timestamp>-implement
          docker stop claude-auto-<timestamp>-review
Results:  gh pr list --search "claude/"
```

**Batch mode** — one summary table, monitor commands after:

```
Launched 2 autonomous sessions.

| Issue | Log | Container |
|-------|-----|-----------|
| #195 (receipt pending fix) | /tmp/claude-auto-<ts1>.log | claude-auto-<ts1> |
| #184 (remove success banner) | /tmp/claude-auto-<ts2>.log | claude-auto-<ts2> |

Base: develop | Max turns: 20 each
Results: gh pr list --search "claude/"
```

Then continue the current conversation normally.

### 5. Ingest Results (when run completes)

When the user asks about or checks on the autonomous run:

```bash
# Check if container is still running
docker ps --filter "name=claude-auto" --format "{{.Names}} {{.Status}}"

# Tail recent log output
tail -20 /tmp/claude-auto-*.log

# Check the PR created by the autonomous run
gh pr list --search "claude/"
```

Summarize the autonomous run's output (from the log) as part of the current session's context. This naturally flows into the current session's diary via auto-diary.

## Design Principles

- **Non-blocking**: Launch and return immediately — never wait for completion
- **Isolated**: Shallow clone ensures user's checkout is untouched
- **Observable**: Log file streams live via `tail -f`
- **Stoppable**: Container name provided for `docker stop`
- **PR-oriented**: Every run produces a branch + PR for review
- **Safe cleanup**: Clone preserved when no commits exist (uncommitted work recoverable)
- **No own diary**: Autonomous runs are tools, not sessions — the parent session owns the diary
- **Current session continues**: User keeps working while autonomous agent runs

## Anti-Patterns

- Don't block waiting for the container to finish — that defeats the purpose
- Don't use this for quick tasks — just do them in the current session
- Don't forget to review the PR before merging autonomous output
- Don't generate a diary entry for the autonomous run — it's captured by the parent session
