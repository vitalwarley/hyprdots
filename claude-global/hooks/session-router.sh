#!/bin/bash
# UserPromptSubmit hook (once): adaptive session onboarding router.
# Gathers signals, outputs structured [TAG] lines for Claude to synthesize.
# Calls session-recall.sh as a module for learning signals.
# Performance budget: <3s total. Uses background subshells for parallel gh calls.

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

# Temp dir for parallel results
TMPDIR_SIGNALS=$(mktemp -d)
trap "rm -rf $TMPDIR_SIGNALS" EXIT

# ============================================
# Launch parallel gh API calls as backgrounded
# ============================================
BRANCH=$(git branch --show-current 2>/dev/null)

if command -v gh &>/dev/null; then
    # PR info for current branch
    (
        PR_JSON=$(gh pr list --author @me --head "$BRANCH" --json number,title,reviewDecision --limit 1 2>/dev/null)
        if [[ -n "$PR_JSON" && "$PR_JSON" != "[]" ]]; then
            PR_NUM=$(echo "$PR_JSON" | grep -oP '"number":\s*\K\d+' | head -1)
            PR_TITLE=$(echo "$PR_JSON" | grep -oP '"title":\s*"\K[^"]+' | head -1)
            REVIEW=$(echo "$PR_JSON" | grep -oP '"reviewDecision":\s*"\K[^"]+' | head -1)
            echo "num=$PR_NUM" > "$TMPDIR_SIGNALS/pr"
            echo "title=$PR_TITLE" >> "$TMPDIR_SIGNALS/pr"
            echo "review=$REVIEW" >> "$TMPDIR_SIGNALS/pr"
        fi
    ) &

    # Milestone info + top issues
    if [[ "$TIER" -ge 2 && -d "$PROJECT_ROOT/docs/plans" ]]; then
        (
            MS_JSON=$(gh api repos/{owner}/{repo}/milestones --jq '[.[] | select(.state=="open")] | sort_by(.due_on) | .[0] | {title, open_issues, closed_issues, number}' 2>/dev/null)
            if [[ -n "$MS_JSON" ]]; then
                MS_TITLE=$(echo "$MS_JSON" | grep -oP '"title":\s*"\K[^"]+')
                MS_OPEN=$(echo "$MS_JSON" | grep -oP '"open_issues":\s*\K\d+')
                MS_CLOSED=$(echo "$MS_JSON" | grep -oP '"closed_issues":\s*\K\d+')
                MS_NUM=$(echo "$MS_JSON" | grep -oP '"number":\s*\K\d+')
                if [[ -n "$MS_TITLE" && -n "$MS_NUM" ]]; then
                    MS_TOTAL=$((MS_OPEN + MS_CLOSED))
                    echo "title=$MS_TITLE" > "$TMPDIR_SIGNALS/milestone"
                    echo "open=$MS_OPEN" >> "$TMPDIR_SIGNALS/milestone"
                    echo "total=$MS_TOTAL" >> "$TMPDIR_SIGNALS/milestone"
                    # Fetch all open issues from this milestone
                    gh issue list --milestone "$MS_TITLE" --state open --limit 50 --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null > "$TMPDIR_SIGNALS/issues"
                    # Fetch done milestone titles (full) for plan cross-reference
                    # "done" = closed with issues, OR open with 0 open and >0 closed
                    gh api repos/{owner}/{repo}/milestones --method GET -f state=all -f per_page=100 --jq '.[] | select((.state=="closed" and .closed_issues>0) or (.open_issues==0 and .closed_issues>0)) | .title' 2>/dev/null > "$TMPDIR_SIGNALS/done_milestones"
                fi
            fi
        ) &
    fi
fi

# ============================================
# Non-network signals (fast, no parallelism needed)
# ============================================

# --- Git local state ---
UNCOMMITTED_FILES=$(git status --porcelain 2>/dev/null)
UNCOMMITTED_COUNT=0
[[ -n "$UNCOMMITTED_FILES" ]] && UNCOMMITTED_COUNT=$(echo "$UNCOMMITTED_FILES" | wc -l | tr -d ' ')
UNCOMMITTED_NAMES=""
if [[ "$UNCOMMITTED_COUNT" -gt 0 ]]; then
    UNCOMMITTED_NAMES=$(echo "$UNCOMMITTED_FILES" | awk '{print $NF}' | head -5 | tr '\n' ', ' | sed 's/,$//')
    [[ "$UNCOMMITTED_COUNT" -gt 5 ]] && UNCOMMITTED_NAMES="$UNCOMMITTED_NAMES (+$((UNCOMMITTED_COUNT - 5)) more)"
fi
LAST_COMMIT_MSG=$(git log -1 --format='%s' 2>/dev/null)
LAST_COMMIT_HASH=$(git log -1 --format='%h' 2>/dev/null)
LAST_COMMIT_STAT=$(git diff --stat HEAD~1..HEAD 2>/dev/null | tail -1 | sed 's/^ *//')
LAST_COMMIT_FILES=$(git diff --name-only HEAD~1..HEAD 2>/dev/null | tr '\n' ', ' | sed 's/,$//')

# --- Staleness + last diary summary ---
DIARY_INDEX="$HOME/.claude/memory/diary/INDEX.md"
DIARY_DIR="$HOME/.claude/memory/diary"
STALE_DAYS=""
STALE_DATE=""
STALE_SUMMARY=""
if [[ -f "$DIARY_INDEX" ]]; then
    LAST_DIARY_LINE=$(awk -F'|' -v p="$PROJECT_NAME" 'BEGIN{IGNORECASE=1} {gsub(/^ +| +$/,"",$4)} $4 ~ p' "$DIARY_INDEX" | tail -1)
    LAST_DATE=$(echo "$LAST_DIARY_LINE" | cut -d'|' -f2 | tr -d ' ')
    if [[ -n "$LAST_DATE" ]]; then
        LAST_EPOCH=$(date -d "$LAST_DATE" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        if [[ -n "$LAST_EPOCH" ]]; then
            DAYS_AGO=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
            if [[ "$DAYS_AGO" -ge 30 ]]; then
                STALE_DAYS="$DAYS_AGO"
                STALE_DATE="$LAST_DATE"
                # Extract 1-line summary from last diary entry
                LAST_DIARY_FILE=$(echo "$LAST_DIARY_LINE" | grep -oP '\[.*?\]\(\K[^)]+' | head -1)
                if [[ -n "$LAST_DIARY_FILE" ]]; then
                    FULL_PATH="$DIARY_DIR/$LAST_DIARY_FILE"
                    if [[ -f "$FULL_PATH" ]]; then
                        STALE_SUMMARY=$(grep -m1 '^## Summary' -A1 "$FULL_PATH" 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')
                        [[ -z "$STALE_SUMMARY" ]] && STALE_SUMMARY=$(grep -m1 '^\*\*Summary\*\*' "$FULL_PATH" 2>/dev/null | sed 's/\*\*Summary\*\*:\s*//')
                    fi
                fi
            fi
        fi
    fi
fi

# --- Learning signals (with gap categories) ---
LEARN_GAPS=0
LEARN_EXAMS=0
LEARN_BRIEFS_RC=0
LEARN_GAP_CATS=""
if [[ "$TIER" -ge 3 && "$HAS_LEARNING" == true ]]; then
    PREDICTION_LOG="$PROJECT_ROOT/docs/learning/prediction-log.md"
    LEARN_OUTPUT=$(bash ~/.claude/hooks/session-recall.sh 2>/dev/null)
    if [[ -n "$LEARN_OUTPUT" ]]; then
        LEARN_GAPS=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ unresolved prediction gaps' | grep -oP '^\d+')
        LEARN_EXAMS=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ pending exams' | grep -oP '^\d+')
        LEARN_BRIEFS_RC=$(echo "$LEARN_OUTPUT" | grep -oP '\d+ briefs with recall candidates' | grep -oP '^\d+')
        LEARN_GAPS=${LEARN_GAPS:-0}; LEARN_EXAMS=${LEARN_EXAMS:-0}; LEARN_BRIEFS_RC=${LEARN_BRIEFS_RC:-0}
        if [[ "$LEARN_GAPS" -gt 0 && -f "$PREDICTION_LOG" ]]; then
            LEARN_GAP_CATS=$(grep -B2 "| WRONG |" "$PREDICTION_LOG" 2>/dev/null | grep -oP '`\K[^`]+' | sort -u | tr '\n' ', ' | sed 's/,$//')
        fi
    fi
fi

# --- Maintenance: use processed.log for accurate reflect cutoff ---
MAINTAIN_UNPROCESSED=0
MAINTAIN_DATE_RANGE=""
MAINTAIN_REFLECT_STATUS=""
if [[ "$TIER" -ge 2 && -f "$DIARY_INDEX" ]]; then
    REFLECTIONS_DIR="$HOME/.claude/memory/reflections"
    PROCESSED_LOG="$REFLECTIONS_DIR/processed.log"

    if [[ -f "$PROCESSED_LOG" ]]; then
        # Get the actual last-processed date from processed.log
        REFLECT_DATE=$(tail -1 "$PROCESSED_LOG" | cut -d'|' -f2 | tr -d ' ')
        if [[ -n "$REFLECT_DATE" ]]; then
            REFLECT_EPOCH=$(date -d "$REFLECT_DATE" +%s 2>/dev/null)
            NOW_EPOCH=$(date +%s)
            DAYS_SINCE_REFLECT=$(( (NOW_EPOCH - ${REFLECT_EPOCH:-$NOW_EPOCH}) / 86400 ))
            MAINTAIN_REFLECT_STATUS="$DAYS_SINCE_REFLECT days since last /reflect ($REFLECT_DATE)"

            # Count unprocessed: diary entries for THIS project after cutoff date
            # Match on project column (field 3) only, not summaries
            UNPROCESSED_DATES=$(awk -F'|' -v d="$REFLECT_DATE" -v p="$PROJECT_NAME" '
                BEGIN { IGNORECASE=1 }
                { gsub(/ /,"",$2); gsub(/^ +| +$/,"",$4) }
                $4 ~ p && $2 > d { print $2 }
            ' "$DIARY_INDEX")
            if [[ -n "$UNPROCESSED_DATES" ]]; then
                MAINTAIN_UNPROCESSED=$(echo "$UNPROCESSED_DATES" | wc -l | tr -d ' ')
                FIRST_UNPROC=$(echo "$UNPROCESSED_DATES" | head -1)
                LAST_UNPROC=$(echo "$UNPROCESSED_DATES" | tail -1)
                F_DISPLAY=$(date -d "$FIRST_UNPROC" +"%b %-d" 2>/dev/null)
                L_DISPLAY=$(date -d "$LAST_UNPROC" +"%b %-d" 2>/dev/null)
                if [[ "$F_DISPLAY" == "$L_DISPLAY" ]]; then
                    MAINTAIN_DATE_RANGE="$F_DISPLAY"
                else
                    MAINTAIN_DATE_RANGE="$F_DISPLAY–$L_DISPLAY"
                fi
            fi
        fi
    else
        # No processed.log — reflect has never been run
        MAINTAIN_REFLECT_STATUS="never run"
        # All project diary entries are unprocessed
        UNPROCESSED_DATES=$(awk -F'|' -v p="$PROJECT_NAME" '
            BEGIN { IGNORECASE=1 }
            { gsub(/ /,"",$2); gsub(/^ +| +$/,"",$4) }
            $4 ~ p { print $2 }
        ' "$DIARY_INDEX")
        if [[ -n "$UNPROCESSED_DATES" ]]; then
            MAINTAIN_UNPROCESSED=$(echo "$UNPROCESSED_DATES" | wc -l | tr -d ' ')
            FIRST_D=$(echo "$UNPROCESSED_DATES" | head -1)
            LAST_D=$(echo "$UNPROCESSED_DATES" | tail -1)
            F_DISPLAY=$(date -d "$FIRST_D" +"%b %-d" 2>/dev/null)
            L_DISPLAY=$(date -d "$LAST_D" +"%b %-d" 2>/dev/null)
            if [[ "$F_DISPLAY" == "$L_DISPLAY" ]]; then
                MAINTAIN_DATE_RANGE="$F_DISPLAY"
            else
                MAINTAIN_DATE_RANGE="$F_DISPLAY–$L_DISPLAY"
            fi
        fi
    fi
fi

# Plans are processed after `wait` (needs closed_milestones from gh subshell)

# --- Scaffolding gaps ---
MISSING_ITEMS=""
$HAS_CLAUDE_MD || MISSING_ITEMS="${MISSING_ITEMS}CLAUDE.md, "
$HAS_LEARNING || MISSING_ITEMS="${MISSING_ITEMS}docs/learning/, "
$HAS_PLANS || MISSING_ITEMS="${MISSING_ITEMS}docs/plans/, "
MISSING_ITEMS=$(echo "$MISSING_ITEMS" | sed 's/, $//')

# --- Project commands ---
PROJECT_CMDS=""
PROJECT_CMDS_DIR="$PROJECT_ROOT/.claude/commands"
if [[ -d "$PROJECT_CMDS_DIR" ]]; then
    # Output command name + first line (description) for each
    for f in "$PROJECT_CMDS_DIR"/*.md; do
        [[ -f "$f" ]] || continue
        CMD_NAME=$(basename "$f" .md)
        CMD_DESC=$(head -1 "$f" | sed 's/^#* *//')
        PROJECT_CMDS="${PROJECT_CMDS}${CMD_NAME}: ${CMD_DESC}\n"
    done
fi

# ============================================
# Wait for background gh calls to complete
# ============================================
wait

# ============================================
# Output structured [TAG] lines
# ============================================

echo "SESSION_CONTEXT: Synthesize the following signals into a concise onboarding summary for the user. For each section, provide enough context that the user can pick an action without running a separate command. End with 'What would you like to do?'"
echo ""
echo "[TIER] $TIER $PROJECT_NAME"

# --- STALE ---
if [[ -n "$STALE_DAYS" ]]; then
    echo "[STALE] days=$STALE_DAYS date=$STALE_DATE summary=\"$STALE_SUMMARY\""
fi

# --- LEARN ---
if [[ "$TIER" -ge 3 ]] && [[ "$LEARN_GAPS" -gt 0 || "$LEARN_EXAMS" -gt 0 || "$LEARN_BRIEFS_RC" -gt 0 ]]; then
    echo "[LEARN] gaps=$LEARN_GAPS exams=$LEARN_EXAMS briefs_rc=$LEARN_BRIEFS_RC gap_categories=\"$LEARN_GAP_CATS\""
fi

# --- RESUME ---
echo "[RESUME] branch=$BRANCH last_commit=\"$LAST_COMMIT_HASH $LAST_COMMIT_MSG\" last_commit_stat=\"$LAST_COMMIT_STAT\" last_commit_files=\"$LAST_COMMIT_FILES\" uncommitted=$UNCOMMITTED_COUNT uncommitted_files=\"$UNCOMMITTED_NAMES\""
if [[ -f "$TMPDIR_SIGNALS/pr" ]]; then
    PR_NUM=$(grep '^num=' "$TMPDIR_SIGNALS/pr" | cut -d= -f2-)
    PR_TITLE=$(grep '^title=' "$TMPDIR_SIGNALS/pr" | cut -d= -f2-)
    PR_REVIEW=$(grep '^review=' "$TMPDIR_SIGNALS/pr" | cut -d= -f2-)
    echo "[RESUME_PR] number=$PR_NUM title=\"$PR_TITLE\" review=$PR_REVIEW"
fi

# --- NEXT ---
if [[ -f "$TMPDIR_SIGNALS/milestone" ]]; then
    MS_TITLE=$(grep '^title=' "$TMPDIR_SIGNALS/milestone" | cut -d= -f2-)
    MS_OPEN=$(grep '^open=' "$TMPDIR_SIGNALS/milestone" | cut -d= -f2-)
    MS_TOTAL=$(grep '^total=' "$TMPDIR_SIGNALS/milestone" | cut -d= -f2-)
    echo "[NEXT] milestone=\"$MS_TITLE\" open=$MS_OPEN total=$MS_TOTAL"
    if [[ -f "$TMPDIR_SIGNALS/issues" && -s "$TMPDIR_SIGNALS/issues" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && echo "[NEXT_ISSUE] $line"
        done < "$TMPDIR_SIGNALS/issues"
    fi
fi

# --- CREATE (process plans after wait, needs closed_milestones) ---
PLAN_COUNT=0
PLAN_DONE_COUNT=0
PLAN_ACTIVE_DETAILS=""
PLAN_DONE_NAMES=""
if [[ "$HAS_PLANS" == true ]]; then
    for f in "$PROJECT_ROOT/docs/plans/"*.md; do
        [[ -f "$f" ]] || continue
        FNAME=$(basename "$f" .md)
        [[ "$FNAME" == "README" ]] && continue
        PLAN_COUNT=$((PLAN_COUNT + 1))
        PLAN_TITLE=$(grep -m1 '^#' "$f" 2>/dev/null | sed 's/^#* *//')
        PLAN_VER=$(echo "$FNAME" | grep -oP '^v[\d.]+')
        IS_DONE=false
        if [[ -f "$TMPDIR_SIGNALS/done_milestones" && -n "$PLAN_VER" ]]; then
            grep -q "^${PLAN_VER}[^0-9.]" "$TMPDIR_SIGNALS/done_milestones" 2>/dev/null && IS_DONE=true
        fi
        if [[ "$IS_DONE" == true ]]; then
            PLAN_DONE_COUNT=$((PLAN_DONE_COUNT + 1))
            PLAN_DONE_NAMES="${PLAN_DONE_NAMES}${PLAN_VER}, "
        else
            PLAN_ACTIVE_DETAILS="${PLAN_ACTIVE_DETAILS}${FNAME}: ${PLAN_TITLE}\n"
        fi
    done
fi
PLAN_ACTIVE_COUNT=$((PLAN_COUNT - PLAN_DONE_COUNT))
PLAN_DONE_NAMES=$(echo "$PLAN_DONE_NAMES" | sed 's/, $//')
echo "[CREATE] has_plans=$HAS_PLANS plan_count=$PLAN_COUNT done=$PLAN_DONE_COUNT active=$PLAN_ACTIVE_COUNT done_versions=\"$PLAN_DONE_NAMES\""
if [[ -n "$PLAN_ACTIVE_DETAILS" ]]; then
    echo -e "$PLAN_ACTIVE_DETAILS" | while IFS= read -r line; do
        [[ -n "$line" ]] && echo "[CREATE_PLAN] $line"
    done
fi

# --- MAINTAIN ---
if [[ "$MAINTAIN_UNPROCESSED" -gt 0 || -n "$MAINTAIN_REFLECT_STATUS" ]]; then
    echo "[MAINTAIN] unprocessed=$MAINTAIN_UNPROCESSED date_range=\"$MAINTAIN_DATE_RANGE\" reflect_status=\"$MAINTAIN_REFLECT_STATUS\""
fi

# --- MISSING ---
if [[ -n "$MISSING_ITEMS" ]]; then
    echo "[MISSING] $MISSING_ITEMS"
fi

# --- PROJECT-CMDS ---
if [[ -n "$PROJECT_CMDS" ]]; then
    echo -e "[PROJECT_CMDS]\n$PROJECT_CMDS"
fi
