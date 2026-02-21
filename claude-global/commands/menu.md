Session onboarding menu. Gathers project signals and presents available actions.

## Workflow

1. Run the session router to gather fresh signals:
```bash
bash ~/.claude/hooks/session-router.sh
```

2. The script outputs a pre-formatted markdown message starting with `ONBOARDING:`. Output everything after that prefix verbatim to the user — do not reformat or summarize.

3. Wait for user direction. If the user picks an option, invoke the corresponding command/skill. If they provide a direct task, proceed with it. "Skip" or equivalent: proceed without action.
