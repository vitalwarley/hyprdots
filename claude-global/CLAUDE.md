## Claude Code Config Layout
- **MCP servers** → `~/.claude.json` (global, user scope) or `.mcp.json` (project scope) — `settings.json` accepts the field but CLI ignores it
- **Everything else** (hooks, permissions, plugins, statusLine) → `~/.claude/settings.json`
- **Per-project permissions** → `<project>/.claude/settings.local.json`
- Agent SDK (Claudian, etc.) reads MCP servers from `~/.claude.json` — same as CLI

## Claude Tooling (commands, skills, hooks)
- **Source of truth**: `~/life/2-areas/dev-tools/hyprdots/claude-global/commands/`, `.../skills/`, `.../hooks/` — to find or edit any command/skill/hook, go here directly (don't search ~/.claude/ with find/readlink)
- all commands (`~/.claude/commands/`), skills (`~/.claude/skills/`), hooks (`~/.claude/hooks/`), and `~/.claude/CLAUDE.md` itself are symlinks to `~/life/2-areas/dev-tools/hyprdots/claude-global/` — source of truth is git-tracked there
- **commit and push rule**: when editing any of these files, commit and push in the **hyprdots repo** (`~/life/2-areas/dev-tools/hyprdots/`), never in `~/.claude/` or `~/life/` — those paths are symlinks, not repos
- systemd user units (`~/.config/systemd/user/`) are symlinks to `~/life/2-areas/dev-tools/hyprdots/.config/systemd/user/` — same git-tracked pattern
- to edit: use Edit tool (follows symlink, edits the versioned file directly)
- if Write tool is used on a command/skill/hook, it replaces the symlink with a plain file — must re-create the symlink afterward: `ln -sf <hyprdots-path> <global-path>`
- canonical layout: `docs/workflows/auto-diary.md` documents the full hook/skill wiring

## System & Docker
- user runs Arch Linux (pacman, rolling-release) — never assume Debian/Ubuntu package management
- Add "2>&1" to docker logs commands to capture both stdout and stderr
- docker-compose up -V (renew anonymous volumes) when container dependencies change — stale volumes cause phantom "module not found"
- shell scripts matching project names in delimited files: use awk with field-specific matching, not grep — grep matches across all columns and overcounts
- Always run python with 'uv run' first.
- Dockerfile: use `--no-editable` for pip install in containers — editable installs cached in named volumes survive code restructuring and cause stale imports
- Arch rolling-release breakage: trace the full env var chain (global config → session/process overrides → runtime behavior) before proposing fixes; partial overrides cause cascading issues

## Documentation Standards
- prefer comprehensive technical docs with practical examples, code snippets, and authoritative references over brief summaries
- structure: use tiered approach (glossary definitions → executive summaries → deep technical guides)
- include cross-references between related documents using relative paths
- for comparisons: use tables for technical options, features, trade-offs
- when editing docs/decisions, preserve existing content — add new options alongside, never replace original analysis
- save research as markdown artifacts (e.g., docs/discovery/) — never leave research only in conversation
- Portuguese for team-facing communication (GitHub comments, sprint reports, internal docs); English for code and technical documentation
- learning docs (`docs/learning/`) must always include mermaid diagrams to visualize concepts — sequence diagrams for async flows, flowcharts for decision logic, etc.

## Research & Decision-Making
- for architecture/design decisions, perform web searches for current (2026) industry best practices
- prioritize Microsoft Learn and official vendor documentation, then validate with community sources
- always cite authoritative sources in documentation
- document critical technical decisions in decision-log.md with: Context → Options (multiple) with Trade-offs → Industry Recommendation → Approval Checkboxes
- link decision log entries to detailed technical documentation

## Git & PR Workflow
- use conventional commit format for git commits ONLY: feat:, fix:, docs:, chore:, refactor:, test:
- conventional commit prefixes are NOT for GitHub issue titles — use plain imperative verbs ("Add", "Fix", "Remove")
- always include "Co-Authored-By: Claude <model> <noreply@anthropic.com>" using the actual model name (e.g., "Claude Opus 4.6", "Claude Sonnet 4.5")
- use heredoc for multi-line messages: git commit -m "$(cat <<'EOF' ... EOF)"
- create feature branches for significant work (migrations, refactorings, new features)
- always run pre-push/pre-commit validation before committing — catch issues locally, not in CI
- pre-commit bypass (`--no-verify`) acceptable only when failures are exclusively in unchanged code; document reason in commit or PR
- read project-specific development guidelines (commit format, PR template, branch naming) before any git operation — project conventions override global rules
- separate branches per concern: never mix documentation, tooling, and feature changes in one branch
- when creating PRs from feature branches, explicitly verify and pass `--base` to avoid targeting wrong branch
- GitHub user-attachment images require authentication — use `gh api <url>` to download them, not `curl` or `WebFetch` (both get 404)
- edit PR review body: `gh api repos/{owner}/{repo}/pulls/{pr}/reviews/{review_id} --method PUT --field body="..."`
- stacked PRs + `gh pr merge --delete-branch` cascade-CLOSES (not rebases) every child PR whose base was the deleted branch. Closed PRs in this state cannot be reopened (`reopenPullRequest` errors when base branch is gone) nor have their base changed. **Before merging a parent with `--delete-branch`, retarget every child's base to the eventual ancestor (usually `main`) via `gh pr edit <child> --base main`.** Or merge without `--delete-branch` and clean branches manually after the whole stack lands. Recovery if it happens: re-create the closed PR from the same head branch with `gh pr create --base main` (preserves the work; original PR stays closed with cross-link comment).

## Diagnostic Protocol
- when a bug involves data shape mismatch (wrong fields, missing keys, unexpected structure): trace the data from origin through persistence to consumption BEFORE proposing any fix — the fix should address why the shapes diverge, not just which property to read
- when proposing a fix, explicitly state whether it addresses the symptom or the structural cause; if symptom-only, present the structural fix as the recommended approach
- when a fix involves changing how one side reads data to match the other side's format: verify a typed contract enforces the format; if none exists, adding the contract is the primary fix

## Review & Fix Guide Principles
- before acting on any iterative artifact (review round 2+, spec revision, follow-up PR), load the prior state first — re-deriving context from scratch is slower and risks contradicting decided points
- fix suggestions must state the **principle** being violated, not just the mechanism to apply — "single source of truth" is durable, "use Literal" is fragile and may be wrong if an enum already exists
- when a fix changes a pattern in one file, grep the codebase for the same anti-pattern — partial fixes create new inconsistencies (e.g., fixing `datetime.now()` → `datetime.now(UTC)` in one file but not another)
- review error handling by **scope** (what's inside the try block) not just **handler** (what's in the except) — unrelated operations sharing a try block cause misattributed failures
- on iterative reviews, classify every new finding by origin: pre-existing (missed before), review-induced (caused by a prior fix guide), or genuinely new — this surfaces review process failures
- never suggest an implementation without verifying it exists in types/docs/source — a fix guide the dev follows literally that introduces a new bug is a review failure
- scope completeness and code quality are orthogonal — always read the spec before assessing code quality. A PR with perfect code that misses half the requirements is still critically incomplete. Spec-first → code-second.
- before attributing scope gaps to the dev, check their actual contract (issue body vs spec) — if the issue was never updated after the spec was enriched, the gap is process-caused, not dev negligence
- after applying reviewer fixes or updating finding statuses, re-read Verdict + Fix Guide for coherence — incremental updates without a consistency pass create empty verdicts and stale fix guides
- operational learnings from retros go in the relevant skill definition, not in memory — memory is for user/project context, skills are for repeatable process rules

## Code Quality & Style
- python: use type hints, Pydantic Settings, dataclasses, enums for type safety
- python: use environment variables for configuration (not hardcoded paths)
- python: establish consistent patterns project-wide once chosen
- python: type: ignore must be inline on the code line; rationale comment on the line above
- architecture: for pluggable systems, use Strategy Pattern with ABC base classes
- fix deprecation warnings in code being modified — don't defer them
- prefer reusing existing functions/modules over writing new implementations
- python: keep `__init__.py` minimal — never eagerly import heavyweight dependencies
- python: prefer Python over complex bash/jq for non-trivial JSON processing
- avoid LLM-style jargon in output: no "Key Insight:", "Novel", "Smart", or marketing-speak — use neutral technical language

## Testing Principles
- regression-first: write a failing test that reproduces the bug BEFORE fixing it — no bug fix without a red-then-green test
- test behaviors not methods: name tests after what the code does (`test_rejects_degenerate_polygon`), not what method it calls (`test_post_init`)
- one invariant, one test, with `match=` on `pytest.raises` — pins the test to the specific validation
- pyramid for pure domain (heavy unit), trophy for interface layers (heavy integration) — choose per layer, not globally
- automate conventions as architectural fitness functions (`tests/architecture/`) — frozen dataclass checks, dependency direction, export completeness
- property-based testing (Hypothesis) for mathematical/geometric code — properties like "invariant to input ordering" subsume specific examples
- domain tests need zero infrastructure — if a domain test imports a web framework, the dependency direction is wrong
- mock only at architectural boundaries (repository ports) — never mock domain objects
- separate deterministic pipeline (exact assertions, fast CI) from stochastic model (behavioral tests with tolerance, GPU CI)
- full research: `~/life/docs/researches/testing-principles-research.md`; per-project strategy: `docs/research/testing-strategy.md`

## Workflow & Efficiency
- CLAUDE.md: keep concise — dense index linking to canonical docs, not a reference manual
- CLAUDE.md vs MEMORY.md: if it contradicts/updates something already in CLAUDE.md → update CLAUDE.md directly; if it's a project-level process any Claude session should follow → CLAUDE.md; if it's about how I interact with this specific user → memory
- **per-project session history**: auto-diary writes `.claude/memory.md` in each project — a numbered list of diary files with one-line summaries; read it first when asked about past sessions, then read the linked diary for full context
- before debugging from scratch, search diaries for similar past issues — environment/config problems are almost always recurring
- diaries are point-in-time snapshots, not authoritative — when they contradict current state, verify and promote confirmed facts to CLAUDE.md via /reflect
- read files to understand current state before editing
- make incremental changes and verify before committing
- use TodoWrite for complex tasks with 3+ steps
- read multiple potentially useful files in parallel when gathering context
- for large changes, use multiple small targeted edits; re-read files between edits to ensure accuracy
- tutorials: verify feasibility of steps before documenting; provide alternatives for permission-gated actions
- scope management: when context is limited, defer execution and create verification checklists for future sessions
- large documents: extract progressively with verification steps, don't attempt all at once
- progress estimates: be conservative; always include explicit "what's pending" alongside completion claims
- confirm scope boundaries (current work vs future work) before starting planning tasks
- when creating source-aligned content (presentations, reviews), read the specific source section first — never generate from general knowledge
- when building enumerative lists, explicitly ask "what am I missing?" rather than presenting as complete
- verify technical claims (bug fixes, performance improvements) with reproducible tests before documenting in PRs/issues
- before applying any suggestion that introduces a new property, method, or API call, verify it exists in the actual types/docs/source — grep installed packages, check official docs, or read the source; never trust suggested identifiers without checking. This includes bot review suggestions: treat review comments as unverified claims
- PR review: before agreeing with bot comments, verify the claim against actual code and cross-environment config (docker-compose.*, k8s/*, .env.example); never propose restricting a permission without confirming no code path needs it; check official docs for tools/plugins before suggesting config changes
- do not ask for confirmation when the current plan already specifies the action — only confirm at irreversible decision points (merge, deploy, delete)
- Claude Code hooks inject context, not trigger actions — use explicit commands (/menu, /next) for behavior that must present content to the user
- autonomous agents: embed critical rules in task prompts directly — CLAUDE.md context has lower salience than immediate instructions
- autonomous agents: detect changes with git diff + git diff --cached + git ls-files --others — any positive triggers phase continuation
- GitHub issues: update issue body when decisions change — comments are evolution log, not source of truth
- weekly doc sync: when specs and implementation diverge, update spec first then propagate to dependent docs (attack plan → issues → data-sources)
- lint auto-fix: review diffs for side-effect imports and architectural wiring before accepting
- MCP GitHub tools are unreliable (wrong names, 401 credentials) — prefer `gh` CLI for all GitHub operations; inspect available MCP tools before calling
- Obsidian vault (`~/life/notes/`): when session has local filesystem access (working dir inside `~/life/` or `/tmp`), use Read/Edit/Write/Glob/Grep directly on vault paths — do NOT use Obsidian MCP tools, which add overhead. MCP tools are for the vault Claudian plugin (sandboxed, cannot access filesystem)
- documentation: design for dual consumers (AI agent context injection + human team navigation) — single source of truth per topic
- multi-source synthesis (minutes, follow-ups, reports): after initial draft, self-audit each claim against its specific source — plausible-but-wrong items are the most damaging errors

## Learning Protocol

When the learning output style is active, do NOT ask the user to write code. The user learns through discussion, prediction, and recall — not implementation.

### Socratic Teaching Rule
When studying a plan/concept with the user: NEVER deliver the answer immediately after asking a question. Instead:
1. Ask the question
2. Wait for the user's attempt
3. If the user asks for explanation, give progressive hints — not the full answer
4. Only deliver the complete explanation when the user explicitly asks for it or after they've attempted reasoning
This applies to all conceptual questions, not just spec discussions.

**Application**: During plan review sessions, after asking a clarifying question (e.g., "Why `asyncio.create_task` over `BackgroundTasks`?"), wait for the user's response. Do NOT immediately answer your own question and continue with analysis. If the user asks "Explique", provide a concise explanation with 1-2 progressive hints, not the full answer. Only give the complete explanation when they explicitly ask for it (e.g., "Me explica por completo").

### Spec Discussion Protocol
When the user directs you to write a spec or plan:
1. Before writing, ask 1-2 targeted questions about what they expect at specific technical layers — force them to articulate a mental model
2. Surface assumptions you are making on their behalf ("I am assuming X — correct?")
3. Flag when their direction contradicts existing code patterns
4. After writing, present a **Decision Summary** (see below), separate from the full spec

### Decision Summary
After completing any spec, plan, or significant design document, present:
```
**Decisions in this spec:**
1. [Decision] — [trade-off / why it matters]
2. [Decision] — [trade-off / why it matters]
3. [Decision] — [trade-off / why it matters]
```
The user engages with the summary (2 minutes). The full spec exists for implementation use. If a decision reveals a gap in the user's understanding, note it for the prediction exam.

### Prediction Exam Integration
Prediction exams happen AFTER launching autonomous implementation — never as a gate. The flow:
1. Spec discussion → Decision Summary → user approves
2. Launch autonomous runner (e.g., `/run-autonomous`, `claude-ready` label)
3. Present prediction exam via AskUserQuestion (user answers while bot implements)
4. When PR arrives, grade predictions against actual diff → log to `docs/learning/prediction-log.md`
See `/predict` skill for full workflow.

### Insight Targeting
★ Insights should focus on:
- Concepts the user previously predicted incorrectly (check prediction-log.md)
- Patterns being applied for the first time in the codebase
- Connections between current work and architectural decisions
Avoid generic programming insights the user likely already knows.

### Session Onboarding Protocol
Use `/menu` to see project context and available actions. It runs `session-router.sh` which gathers signals (learning, git state, PRs, milestones, diary backlog, scaffolding gaps) and presents a formatted menu grouped by intent: Learn > Resume > Next > Create > Maintain.
- If user picks a menu option: invoke the corresponding command/skill
- If user sends a direct task: proceed without the menu
- "Skip" or equivalent: proceed without action

## Visual Communication
- use mermaid diagrams (not ASCII art)
- data pipelines: horizontal flow (graph LR)
- system architecture: vertical flow (graph TB)
- timelines: use Gantt charts for parallel work streams

## Life Repo Sync
- `~/life/notes/areas/life.md` is a vault-visible mirror of the life repo structure (projects, areas, scripts) — the vault Claudian is sandboxed and cannot read outside `notes/`
- when adding/removing projects in `1-projects/`, areas in `2-areas/`, or making significant structural changes to the life repo, update the corresponding tables in `notes/areas/life.md` to keep it in sync

## Project-Specific Patterns
- Toledo TDB Dashboard: use Feature Teams model (parallel vertical features) not sequential phases
- Toledo TDB Dashboard: maintain running count of decisions across documents (e.g., "24→25 decisions")
- RAG/AI systems: provide interactive test scripts in scripts/interactive/ for manual validation
- scientific projects: use environment variables for parametrized source locations (reproducibility)
- scientific projects: validate outputs against thesis/reference after every pipeline change
- ML pipelines: verify inference preprocessing (image size, normalization) matches training configuration before trusting outputs
- LLM tool calling: use decorator-based schema generation from function signatures, not hand-written JSON schemas
- RAG: skip vector DB when knowledge base fits in context window — use direct context injection with keyword matching
- data validation: prefer explicit whitelists over heuristics for enum classification
- multi-person milestones: create explicit responsibility matrix before parallel execution
- ML experiments: after extracting artifacts (embeddings, checkpoints, metrics), validate with sanity checks (tensor norms, shapes, value ranges) before downstream analysis