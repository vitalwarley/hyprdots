#!/bin/bash
# UserPromptSubmit hook (once): adaptive session onboarding router.
# Gathers signals, outputs a pre-formatted onboarding message for Claude to relay.
# Calls session-recall.sh as a module for learning signals.
# Performance budget: <3s total.

# --- Context detection ---
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
    exit 0
fi

PROJECT_NAME=$(basename "$PROJECT_ROOT")
HAS_CLAUDE_MD=false
HAS_LEARNING=false
HAS_PLANS=false

[[ -f "$PROJECT_ROOT/CLAUDE.md" || -f "$PROJECT_ROOT/.claude/CLAUDE.md" ]] && HAS_CLAUDE_MD=true
[[ -d "$PROJECT_ROOT/docs/learning" ]] && HAS_LEARNING=true
[[ -d "$PROJECT_ROOT/docs/plans" ]] && HAS_PLANS=true

TIER=1
$HAS_CLAUDE_MD && TIER=2
($HAS_LEARNING || $HAS_PLANS) && [[ "$TIER" -ge 2 ]] && TIER=3

# Collect signals into variables
STALE_LINE=""
LEARN_LINE=""
RESUME_LINE=""
NEXT_LINE=""
MAINTAIN_LINE=""
MISSING_LINES=""
PROJECT_CMDS=""

# --- Staleness ---
DIARY_INDEX="$HOME/.claude/memory/diary/INDEX.md"
if [[ -f "$DIARY_INDEX" ]]; then
    LAST_DATE=$(grep -i "$PROJECT_ROOT\|$PROJECT_NAME" "$DIARY_INDEX" | tail -1 | cut -d'|' -f2 | tr -d ' ')
    if [[ -n "$LAST_DATE" ]]; then
        LAST_EPOCH=$(date -d "$LAST_DATE" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        if [[ -n "$LAST_EPOCH" ]]; then
            DAYS_AGO=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
            [[ "$DAYS_AGO" -ge 30 ]] && STALE_LINE="Last session was $DAYS_AGO days ago ($LAST_DATE). Consider \`/research\` to re-orient before diving in."
        fi
    fi
fi

# --- Learning signals ---
if [[ "$TIER" -ge 3 && "$HAS_LEARNING" == true ]]; then
    LEARN_OUTPUT=$(bash ~/.claude/hooks/session-recall.sh 2>/dev/null)
    if [[ -n "$LEARN_OUTPUT" ]]; then
        GAPS=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ unresolved prediction gaps' | grep -oP '^\d+')
        EXAMS=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ pending exams' | grep -oP '^\d+')
        BRIEFS_RC=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ briefs with recall candidates' | grep -oP '^\d+')
        GAPS=${GAPS:-0}; EXAMS=${EXAMS:-0}; BRIEFS_RC=${BRIEFS_RC:-0}
        PARTS=""
        [[ "$GAPS" -gt 0 ]] && PARTS="$GAPS unresolved prediction gaps"
        [[ "$EXAMS" -gt 0 ]] && PARTS="${PARTS:+$PARTS, }$EXAMS pending exams"
        [[ "$BRIEFS_RC" -gt 0 ]] && PARTS="${PARTS:+$PARTS, }$BRIEFS_RC briefs with recall candidates"
        [[ -n "$PARTS" ]] && LEARN_LINE="$PARTS"
    fi
fi

# --- Resume signals ---
BRANCH=$(git branch --show-current 2>/dev/null)
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
RESUME_PARTS=""

if command -v gh &>/dev/null; then
    PR_JSON=$(gh pr list --author @me --head "$BRANCH" --json number,title,statusCheckRollup,reviewDecision,comments --limit 1 2>/dev/null)
    if [[ -n "$PR_JSON" && "$PR_JSON" != "[]" ]]; then
        PR_NUM=$(echo "$PR_JSON" | grep -oP '"number":\s*\K\d+' | head -1)
        if [[ -n "$PR_NUM" ]]; then
            CI_STATUS=$(gh pr checks "$PR_NUM" --json state --jq '.[].state' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "unknown")
            REVIEW_COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/$PR_NUM/comments" --jq 'length' 2>/dev/null || echo "0")
            RESUME_PARTS="PR #$PR_NUM open on $BRANCH (CI $CI_STATUS, $REVIEW_COMMENTS review comments)"
        fi
    fi
fi

if [[ -n "$RESUME_PARTS" ]]; then
    RESUME_LINE="$RESUME_PARTS, $UNCOMMITTED uncommitted files"
else
    RESUME_LINE="branch: ${BRANCH:-detached}, $UNCOMMITTED uncommitted files, no open PRs"
fi

# --- Plan/milestone ---
if [[ "$TIER" -ge 2 && -d "$PROJECT_ROOT/docs/plans" ]]; then
    if command -v gh &>/dev/null; then
        MILESTONE_JSON=$(gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.state=="open") | {title, open_issues, closed_issues}' 2>/dev/null | head -1)
        if [[ -n "$MILESTONE_JSON" ]]; then
            MS_TITLE=$(echo "$MILESTONE_JSON" | grep -oP '"title":\s*"\K[^"]+')
            MS_OPEN=$(echo "$MILESTONE_JSON" | grep -oP '"open_issues":\s*\K\d+')
            MS_CLOSED=$(echo "$MILESTONE_JSON" | grep -oP '"closed_issues":\s*\K\d+')
            if [[ -n "$MS_TITLE" ]]; then
                MS_TOTAL=$((MS_OPEN + MS_CLOSED))
                NEXT_LINE="milestone $MS_TITLE has $MS_OPEN/$MS_TOTAL issues open"
            fi
        fi
    fi
fi

# --- Maintenance ---
if [[ "$TIER" -ge 2 && -f "$DIARY_INDEX" ]]; then
    REFLECTIONS_DIR="$HOME/.claude/memory/reflections"
    LAST_REFLECT=""
    [[ -d "$REFLECTIONS_DIR" ]] && LAST_REFLECT=$(ls -1t "$REFLECTIONS_DIR"/*.md 2>/dev/null | head -1)

    if [[ -n "$LAST_REFLECT" ]]; then
        REFLECT_DATE=$(basename "$LAST_REFLECT" | grep -oP '^\d{4}-\d{2}-\d{2}')
        REFLECT_EPOCH=$(date -d "$REFLECT_DATE" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        DAYS_SINCE_REFLECT=$(( (NOW_EPOCH - REFLECT_EPOCH) / 86400 ))
        UNPROCESSED=$(grep -i "$PROJECT_ROOT\|$PROJECT_NAME" "$DIARY_INDEX" | awk -F'|' -v d="$REFLECT_DATE" '{gsub(/ /,"",$2); if ($2 > d) count++} END {print count+0}')
        if [[ "$UNPROCESSED" -gt 0 || "$DAYS_SINCE_REFLECT" -gt 7 ]]; then
            MAINTAIN_LINE="$UNPROCESSED diary entries unprocessed, $DAYS_SINCE_REFLECT days since last /reflect"
        fi
    else
        TOTAL_DIARIES=$(grep -ci "$PROJECT_ROOT\|$PROJECT_NAME" "$DIARY_INDEX" 2>/dev/null || echo "0")
        [[ "$TOTAL_DIARIES" -gt 0 ]] && MAINTAIN_LINE="$TOTAL_DIARIES diary entries unprocessed, never reflected"
    fi
fi

# --- Scaffolding gaps ---
$HAS_CLAUDE_MD || MISSING_LINES="${MISSING_LINES}- CLAUDE.md: project conventions, coding guidelines -> create with project context\n"
$HAS_LEARNING || MISSING_LINES="${MISSING_LINES}- docs/learning/: prediction tracking, active recall -> create dir + add prediction-log.md\n"
$HAS_PLANS || MISSING_LINES="${MISSING_LINES}- docs/plans/: milestone tracking, /next integration -> /prd to create first plan\n"

# --- Project commands ---
PROJECT_CMDS_DIR="$PROJECT_ROOT/.claude/commands"
if [[ -d "$PROJECT_CMDS_DIR" ]]; then
    PROJECT_CMDS=$(ls -1 "$PROJECT_CMDS_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | tr '\n' ', ' | sed 's/,$//')
fi

# ============================
# Output pre-formatted message
# ============================

echo "ONBOARDING: Present the following session context to the user as your first response. Output it verbatim in markdown, then ask 'What would you like to do?'"
echo ""
echo "## Session context — $PROJECT_NAME (tier $TIER)"
echo ""

# Staleness warning first
if [[ -n "$STALE_LINE" ]]; then
    echo "**Warning**: $STALE_LINE"
    echo ""
fi

# Learn group
if [[ -n "$LEARN_LINE" && "$TIER" -ge 3 ]]; then
    echo "**Learn**: $LEARN_LINE"
    echo "> \`/recall\` for active recall session"
    echo ""
fi

# Resume group
echo "**Resume**: $RESUME_LINE"
echo "> \`/resume-dev\` to continue from last session"
echo ""

# Next group
if [[ -n "$NEXT_LINE" ]]; then
    echo "**Next**: $NEXT_LINE"
    echo "> \`/next\` to pick up next planned task"
    echo ""
fi

# Create group (always in git repos)
echo "**Create**: start new feature or design work"
echo "> \`/prd\` for requirements, \`/architecture\` for design decisions"
echo ""

# Maintain group
if [[ -n "$MAINTAIN_LINE" ]]; then
    echo "**Maintain**: $MAINTAIN_LINE"
    echo "> \`/reflect\` to synthesize patterns"
    echo ""
fi

# Missing scaffolding
if [[ -n "$MISSING_LINES" ]]; then
    echo "**This project could benefit from:**"
    echo -e "$MISSING_LINES"
fi

# Project commands
if [[ -n "$PROJECT_CMDS" ]]; then
    echo "**Project commands**: $PROJECT_CMDS"
    echo ""
fi

echo "What would you like to do?"
