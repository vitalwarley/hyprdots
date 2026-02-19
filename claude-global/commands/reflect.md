---
description: Analyze diary entries to identify patterns and propose CLAUDE.md updates
---

# Reflect on Diary Entries and Synthesize Insights

Analyze multiple diary entries to identify recurring patterns, synthesize insights, and propose updates to CLAUDE.md.

## Parameters

The user can provide:
- **Date range**: "from YYYY-MM-DD to YYYY-MM-DD" or "last N days"
- **Entry count**: "last N entries" (e.g., "last 10 entries")
- **Project filter**: "for project [name]" (optional)
- **Pattern filter**: "related to [keyword]" (e.g., "related to testing")

If no parameters are provided, default to analyzing the **last 10 diary entries**.

## Steps

### 1. Check Processed Entries Log

Read `~/.claude/memory/reflections/processed.log` to find already-processed diary entries.
- Format: `[diary-filename] | [reflection-date] | [reflection-filename]`
- If file doesn't exist, all entries are unprocessed
- Create the file if it doesn't exist: `touch ~/.claude/memory/reflections/processed.log`

### 2. Locate and Filter Diary Entries

- Directory: `~/.claude/memory/diary/`
- Entries named: `YYYY-MM-DD-session-N.md`
- List all entries sorted by date (newest first)
- **Exclude already-processed entries** unless user requests re-analysis
- Apply date range, count, project, or pattern filters as specified

### 3. Read and Parse Entries

Read each diary entry, paying special attention to:
- User Preferences Observed
- Design Decisions Made
- Solutions Applied (what works well)
- Challenges Encountered (what to avoid)

### 4. Read Current CLAUDE.md

Read `~/.claude/CLAUDE.md` to understand existing rules. This is CRITICAL for detecting violations and avoiding duplicates.

### 5. Analyze for Patterns

- **Frequency analysis**: What preferences/patterns appear in multiple entries?
- **Consistency check**: Are preferences consistent or contradictory?
- **Context awareness**: Do patterns apply globally or to specific project types?
- **Abstraction level**: Can specific instances be generalized into rules?
- **Rule violation detection**: Check if diary entries show violations of EXISTING CLAUDE.md rules
  - Look in "Challenges Encountered", "User Preferences Observed" sections
  - Violations mean the existing rule needs STRENGTHENING

### 6. Generate Reflection Document

Save to `~/.claude/memory/reflections/YYYY-MM-reflection-N.md`:

```markdown
# Reflection: [Date Range or "Last N Entries"]

**Generated**: YYYY-MM-DD HH:MM:SS
**Entries Analyzed**: [count]
**Date Range**: [first-date] to [last-date]
**Projects**: [list or "All projects"]

## Summary
[2-3 paragraph overview of key insights]

## CRITICAL: Rule Violations Detected
[ONLY if violations found]
**Rule**: [existing rule]
**Violation Pattern**: [how it appeared]
**Strengthening Action**: [specific changes]

## Patterns Identified

### Persistent Preferences (2+ occurrences)
1. **[Name]** (X/Y entries)
   - **Observation**: [what was preferred]
   - **Confidence**: High/Medium/Low
   - **CLAUDE.md rule**: `- [succinct actionable rule]`

### Design Decisions That Worked
1. **[Name]**
   - **What worked**: [description]
   - **When to use**: [context]
   - **CLAUDE.md rule** (if generalizable): `- [rule]`

### Anti-Patterns to Avoid
1. **[Name]** (X/Y entries)
   - **What failed**: [description]
   - **What to do instead**: [alternative]
   - **CLAUDE.md rule**: `- avoid X, use Y instead`

### Cross-Project Knowledge Transfer
1. **[Topic]** (from [project] → relevant to [project(s)])
   - **Finding**: [what was discovered]
   - **Broader relevance**: [how it applies beyond original context]

## Notable Mistakes and Learnings
- **Mistake**: [what went wrong]
  - **Learning**: [what was learned]
  - **Prevention**: [how to avoid]

## One-Off Observations
- [Single-occurrence items, not patterns yet]

## Proposed CLAUDE.md Updates

[Succinct bullet points, imperative tone, one line per rule]

### Section: [Category]
```markdown
- [actionable rule 1]
- [actionable rule 2]
```

## Metadata
- **Diary entries analyzed**: [filenames]
- **Projects covered**: [list]
```

### 7. Update CLAUDE.md

**Priority 1**: Strengthen violated rules (modify existing, don't just append)
**Priority 2**: Add new rules (succinct bullet points, grouped by section)

### 8. Update Processed Log

Append to `~/.claude/memory/reflections/processed.log`:
```
[diary-filename] | [YYYY-MM-DD] | [reflection-filename]
```

### 9. Present Summary

- Highlight any rule violations detected and how rules were strengthened
- Show reflection filename and location
- List CLAUDE.md sections updated
- Confirm processed.log updated

## Pattern Recognition Principles

1. **Frequency**: 2+ occurrences before calling it a "pattern"
   - Strong: 3+ with consistency
   - Emerging: 2 occurrences
   - One-off: document but don't add to CLAUDE.md
2. **Context**: universal vs project-specific vs tool-specific
3. **Consistency**: flag contradictory preferences for user review
4. **Actionability**: only propose rules Claude can actually follow
5. **Succinctness**: each CLAUDE.md rule = ONE line, imperative tone, no explanations

## Handling Processed Entries

- Default: skip already-processed entries
- User overrides: "include all entries", "reprocess [filename]", "last N including processed"

## Downstream Consumers

Reflections are consumed by:
- **`/next`** — reads the latest reflection to surface anti-patterns, design decisions, and cross-project learnings relevant to the next task
- **Future sessions** — manual reference via `~/.claude/memory/reflections/`

Write the "Anti-Patterns to Avoid", "Design Decisions That Worked", and "Cross-Project Knowledge Transfer" sections with this in mind — keep entries self-contained and scannable so `/next` can extract relevant items without needing the full diary context.

## Error Handling

- No diary entries: inform user, suggest running `/diary` or waiting for auto-diary
- All entries processed: inform user
- Fewer than 3 entries: proceed but note low pattern confidence
- Malformed entries: skip and document which had issues
