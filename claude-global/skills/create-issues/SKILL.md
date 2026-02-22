---
name: create-issues
description: Create GitHub issues from execution plan steps. Reads wave/step definitions and creates autonomous-ready issues with acceptance criteria.
allowed-tools: Read, Glob, Grep, Bash(gh *), Bash(git *), AskUserQuestion, Write, Edit
---

# /create-issues — Plan to GitHub Issues

Create GitHub issues from execution plan steps. Each issue is formatted for autonomous execution via `/run-autonomous`.

## Arguments

`$ARGUMENTS` supports:
- **All**: (no args or `all`) — create issues for all steps in the plan
- **Wave**: `wave 1`, `wave 2` — create issues for a specific wave only
- **Step**: `1a`, `2d`, `3b` — create a single issue for one step
- **Plan path**: `docs/plan/mvp-chatbot-waves.md` — explicit path to plan file

## Workflow

### Step 1: Locate Execution Plan

```bash
# If path provided, use it directly
# Otherwise, search for plan files
find docs/plan* docs/plans -name "*.md" -type f 2>/dev/null
```

If multiple plans found, ask user which one to use.

Read the plan completely. Also read project CLAUDE.md for:
- Branch naming conventions
- Commit message format
- Label conventions
- Milestone references

### Step 2: Parse Steps

Extract from the plan's step table(s):

| Field | Source |
|---|---|
| Step ID | `Step` column (e.g., `1a`, `2d`) |
| Title | Bold text in `Description` column |
| Body | Full description text |
| Type | `Type` column → maps to label |
| Max Turns | `Max Turns` column |
| Wave | Which wave the step belongs to |
| Dependencies | From build order diagram or parallelism table |

### Step 3: Format Issue Body

For each step, generate the issue body using this template:

```markdown
## Context

[1-2 sentences from the plan's context section explaining WHY this step matters]

## Spec

[Full description from the step table, preserving:]
- Behavioral specification (Given/Does/System does)
- Edge cases with specific input→behavior pairs
- File paths

## Acceptance Criteria

[Extract checkboxes from the step description]
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

## Files Likely Affected

[Extract file paths mentioned in the description]
- `path/to/file1.py`
- `path/to/file2.py`

## Verification

[Extract from the plan's Verification section — items relevant to this step]
- [ ] Verification check 1
- [ ] Verification check 2

If the plan has a global `## Verification` section, map each check to the step(s) it validates. If a check spans multiple steps, include it in the last step of the chain.

## Dependencies

[From build order: which steps/issues must merge first]

## Autonomous Execution

Max turns: {max_turns}

```bash
/run-autonomous #THIS_ISSUE --max-turns {max_turns} --base main
```

After the autonomous run creates a PR, verify the acceptance criteria and verification checks above before merging.

---
📋 Generated from [{plan_filename}]({relative_path}) — Step {step_id}
```

### Step 4: Determine Labels and Milestone

**Labels** (create if they don't exist):
- Type: `type` column → `feature`, `refactor`, `fix`, `test`, `script`, `chore`
- Wave: `wave:1`, `wave:2`, etc.
- `autonomous-ready`

**Milestone**: Extract from plan title or ask user.

### Step 5: Confirm Before Creating

Present a summary table to the user:

```
Issues to create:
| Step | Title | Labels | Depends On |
|------|-------|--------|------------|
| 1a | Template + builder per-angel | feature, wave:1 | — |
| 1b | Generator + CLI per-angel | feature, wave:2 | #1a |
```

Ask: "Create these N issues? (labels and milestone will be created if needed)"

### Step 6: Create Issues

For each confirmed step:

```bash
gh issue create \
  --title "Step {id}: {title}" \
  --body "$(cat <<'EOF'
{formatted_body}
EOF
)" \
  --label "{labels}" \
  --milestone "{milestone}"
```

After creation, collect issue numbers and update the plan file:
- Replace `TBD` in the step table with actual issue numbers
- Update `/run-autonomous` commands in the Execution Commands section with real issue numbers

### Step 7: Summary

Output a summary with:
- List of created issues with URLs
- Updated execution commands ready for copy-paste
- Any warnings (missing labels, no milestone, etc.)

## Design Principles

- **Idempotent**: If an issue for a step already exists (matched by title prefix `Step {id}:`), skip it and report
- **Plan is source of truth**: Issue body is derived from plan, not invented
- **Autonomous-ready**: Every issue body must include acceptance criteria and file list
- **Minimal labels**: Only create labels that don't exist yet
- **Update plan after creation**: Keep plan file in sync with actual issue numbers

## Anti-Patterns

- Don't create issues without user confirmation
- Don't modify the step descriptions — transfer them faithfully
- Don't create duplicate issues for the same step
- Don't guess dependencies — only use what the plan explicitly states
