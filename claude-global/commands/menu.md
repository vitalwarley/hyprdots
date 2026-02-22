Session onboarding menu. Gathers project signals and presents available actions.

## Workflow

1. Run the session router to gather fresh signals:
```bash
bash ~/.claude/hooks/session-router.sh
```

2. The script outputs a message starting with `SESSION_CONTEXT:` followed by structured `[TAG]` signal lines. Your task: **parse these signals and synthesize a contextual onboarding summary** with the following guidelines:

   - **Group by intent**: Learn → Resume → Next → Create → Maintain (shown in priority order)
   - **Stale warning first**: If `[STALE]` present, lead with the warning and include the last session summary
   - **Resume context**: Show branch, last commit message + hash + diff stat (what changed), and if `[RESUME_PR]` exists show PR title + review status
   - **Next items**: Describe the milestone and list ALL `[NEXT_ISSUE]` lines
   - **Learn**: Name the gap categories, count of gaps/exams/briefs
   - **Maintain**: Show unprocessed diary count + date range, reflect status
   - **Create**: Show plan count. Group `[CREATE_PLAN]` lines by phase (v0.2.x = completed stabilization, v0.3.x = upcoming features). Summarize what the latest plans cover
   - **Missing**: Only if gaps exist, list what's needed
   - **Project-Cmds**: Include project-specific commands if available, with brief descriptions
   - **End with**: "What would you like to do?"

3. Structure your response as a markdown section with the format from the spec (see below). Make it rich enough that the user can make a decision without running extra commands.

4. Wait for user direction. If they pick a menu option, invoke the corresponding command/skill. If they provide a direct task, proceed with it. If they say "Skip" or equivalent, proceed without action.

## Example synthesis (what you should output to the user)

```markdown
## Session context — noux (tier 3)

**Stale**: Last session 45 days ago (2026-01-07). Last: "Debugged SSE streaming timeout issue." Consider `/research` to re-orient before diving in.

**Learn**: 3 prediction gaps (data-flow, architecture). 1 pending exam. 2 briefs with recall candidates.
> `/recall` for active recall session

**Resume**: On `develop`, last commit `a7f3c21` cleaned up the session-recall hook and local resume-dev command (2 files changed, 80 deletions). 2 uncommitted files: src/components/Chat.tsx, backend/models.py.
PR #372 "Optimize event indexing" — changes requested, needs attention.
> `/resume-dev` to continue from last session

**Next**: Milestone v0.2.14 — 3/5 issues open:
- #210 Add /meta-review skill for workflow audit
- #190 Add PWA support for mobile installability
- #163 Align Event model with learning event schema
> `/next` to pick up next planned task

**Create**: 15 plans across v0.2.x (stabilization: backend refactor, frontend test quality, architectural standardization) and v0.3.x (feature spirals: foundation, depth, intelligence). Next planned work is v0.3.0 — seed data, review surface, AI intelligence.
> `/prd` for requirements, `/architecture` for design decisions

**Maintain**: 10 diary entries unprocessed (Feb 20–21). Last /reflect was 4 days ago (Feb 18).
> `/reflect` to synthesize patterns

What would you like to do?
```
