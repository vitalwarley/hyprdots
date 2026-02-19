Perform a structured refactoring of the specified code area. Follows a disciplined workflow: understand first, plan the changes, execute incrementally, validate continuously.

**Refactoring target**: `$ARGUMENTS`

## 0. Pre-Flight

Verify preconditions before starting:

```bash
git status
git stash list
```

- If there are uncommitted changes unrelated to this refactoring, STOP. Ask the user to commit or stash them first.
- If `$ARGUMENTS` is empty, STOP. Ask what to refactor.

## 1. Understand Current State

**Read before changing.** Gather full context on the target area:

- Read all files involved in `$ARGUMENTS`
- Read tests covering those files
- Read CLAUDE.md for relevant coding guidelines
- Check `git log --oneline -15 -- <target-files>` for recent changes
- Search for callers/consumers: who depends on the code being refactored?

Document:
- **What the code does** (not what it should do)
- **Test coverage**: which behaviors are verified, which are not
- **Dependents**: what breaks if the interface changes

Present this understanding to the user before proceeding.

## 2. Define Refactoring Goal

State explicitly:
- **What changes**: the structural transformation (e.g., "extract service class", "split module", "rename and reorganize")
- **What stays the same**: external behavior that must be preserved
- **Success criteria**: how to verify the refactoring worked (tests pass, types check, no behavior change)

Use TodoWrite to create the step-by-step plan. Each step should be independently committable.

## 3. Verify Safety Net

Before any code changes:

Run the project's test suite for the affected area. Check CLAUDE.md for the project's test and validation commands.

If no test commands are documented, detect from project structure:
- Python: `pytest <relevant-tests> -x -v` (or `uv run pytest` if uv is used)
- TypeScript/JavaScript: `npm test` or `npx jest`
- Check for validation scripts: `scripts/pre-push*.sh`, `Makefile`, CI config

If tests fail BEFORE refactoring, STOP. Report the failures — don't refactor broken code.

## 4. Execute Incrementally

For each step in the plan:

1. **Make the change** — one structural transformation per step
2. **Run tests** — must pass after every step
3. **Run type check** — catch contract violations immediately
4. **Mark step complete** in TodoWrite

Rules:
- Every changed line must trace to the refactoring goal. No drive-by fixes.
- If a test breaks, fix the test only if the refactoring intentionally changed the behavior. Otherwise, revert the step and reassess.
- If you discover the refactoring needs a different approach mid-execution, STOP. Present the discovery and revised plan to the user.

## 5. Final Validation

After all steps complete:

Run the project's full validation suite (lint + typecheck + tests). Check CLAUDE.md for the exact command.

If the refactoring touched API boundaries, verify both sides are updated.

## 6. Report

Present a summary:

```markdown
## Refactoring Complete: <target>

### Changes
| File | Action | What Changed |
|------|--------|-------------|

### Behavior Preserved
- [ ] All existing tests pass
- [ ] Type checking passes
- [ ] Lint passes
- [ ] No API boundary changes (or both sides updated)

### Structural Improvements
- Numbered list of what improved and why

### Follow-Up
- Any tech debt discovered but intentionally not addressed (out of scope)
```

Wait for user to review before committing. Do NOT auto-commit.
