## System & Docker
- user runs Arch Linux (pacman, rolling-release) — never assume Debian/Ubuntu package management
- Add "2>&1" to docker logs commands to capture both stdout and stderr
- Always run python with 'uv run' first.

## Documentation Standards
- prefer comprehensive technical docs with practical examples, code snippets, and authoritative references over brief summaries
- structure: use tiered approach (glossary definitions → executive summaries → deep technical guides)
- include cross-references between related documents using relative paths
- for comparisons: use tables for technical options, features, trade-offs
- when editing docs/decisions, preserve existing content — add new options alongside, never replace original analysis
- save research as markdown artifacts (e.g., docs/discovery/) — never leave research only in conversation
- Portuguese for team-facing communication (GitHub comments, sprint reports, internal docs); English for code and technical documentation

## Research & Decision-Making
- for architecture/design decisions, perform web searches for current (2026) industry best practices
- prioritize Microsoft Learn and official vendor documentation, then validate with community sources
- always cite authoritative sources in documentation
- document critical technical decisions in decision-log.md with: Context → Options (multiple) with Trade-offs → Industry Recommendation → Approval Checkboxes
- maintain running count of decisions across documents (e.g., "24→25 decisions")
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

## Workflow & Efficiency
- CLAUDE.md: keep concise — dense index linking to canonical docs, not a reference manual
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
- before applying any suggestion that introduces a new property, method, or API call, verify it exists in the actual types/docs/source — grep installed packages, check official docs, or read the source; never trust suggested identifiers without checking

## Visual Communication
- use mermaid diagrams (not ASCII art)
- data pipelines: horizontal flow (graph LR)
- system architecture: vertical flow (graph TB)
- timelines: use Gantt charts for parallel work streams

## Project-Specific Patterns
- Toledo TDB Dashboard: use Feature Teams model (parallel vertical features) not sequential phases
- RAG/AI systems: provide interactive test scripts in scripts/interactive/ for manual validation
- scientific projects: use environment variables for parametrized source locations (reproducibility)
- scientific projects: validate outputs against thesis/reference after every pipeline change
- ML pipelines: verify inference preprocessing (image size, normalization) matches training configuration before trusting outputs
- LLM tool calling: use decorator-based schema generation from function signatures, not hand-written JSON schemas
- RAG: skip vector DB when knowledge base fits in context window — use direct context injection with keyword matching