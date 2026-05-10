#!/usr/bin/env bash
# claude-usage.sh — Claude Code Max5x quota pill + on-demand TUI
#
# Modes:
#   (no args)   waybar JSON: {text, tooltip, class, percentage}
#   --tui       multi-line text for `watch -n 5` (Super+Shift+U keybind)
#
# Env:
#   CLAUDE_TOKEN_LIMIT   raw (input+output) tokens per 5h window. Default 800000.
#                        Calibrated 2026-05-08 against claude.ai/usage; see
#                        ~/life/notes/areas/claude/realtime-usage/scratch/ccusage-shape.md
#
# Engine: bunx ccusage@18.0.11 blocks --active --json
# Cache:  /tmp/claude-usage-cache.json (5s TTL — keeps waybar refresh cheap)
# Metric: tokenCounts.inputTokens + tokenCounts.outputTokens ONLY
#         (cacheCreationInputTokens + cacheReadInputTokens excluded — not in claude.ai bar)

set -eu
set -o pipefail

LIMIT="${CLAUDE_TOKEN_LIMIT:-800000}"
CACHE_FILE="/tmp/claude-usage-cache.json"
DAILY_CACHE_FILE="/tmp/claude-usage-daily-cache.json"
# bunx ccusage takes 6-9s per call. TTL > waybar interval (30s) keeps the pill
# always cache-hit; TUI's `watch -n 5` reuses the same cache.
CACHE_TTL=30
CCUSAGE_PIN="ccusage@18.0.11"

MODE="${1:-pill}"

emit_pill() {
    local text="$1" tooltip="$2" cls="$3" pct="$4"
    jq -nc \
        --arg text "$text" \
        --arg tooltip "$tooltip" \
        --arg class "$cls" \
        --argjson pct "$pct" \
        '{text: $text, tooltip: $tooltip, class: $class, percentage: $pct}'
}

emit_pill_fallback() {
    emit_pill "$1" "$2" "" 0
}

emit_tui_fallback() {
    printf 'Claude Code Usage Monitor\n'
    printf '=========================\n\n'
    printf '%s\n' "$1"
}

get_blocks_json() {
    if [[ -f "$CACHE_FILE" ]]; then
        local mtime now age
        mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [[ $age -lt $CACHE_TTL ]]; then
            cat "$CACHE_FILE"
            return 0
        fi
    fi
    if ! bunx "$CCUSAGE_PIN" blocks --active --json > "$CACHE_FILE.tmp" 2>/dev/null; then
        rm -f "$CACHE_FILE.tmp"
        return 1
    fi
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    cat "$CACHE_FILE"
}

# Per-model breakdown for today (best-effort: daily ≠ block; documented limitation)
get_today_breakdown() {
    local today raw
    today=$(date +%Y-%m-%d)
    if [[ -f "$DAILY_CACHE_FILE" ]]; then
        local mtime now age
        mtime=$(stat -c %Y "$DAILY_CACHE_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [[ $age -lt $CACHE_TTL ]]; then
            raw=$(cat "$DAILY_CACHE_FILE")
        fi
    fi
    if [[ -z "${raw:-}" ]]; then
        if ! raw=$(bunx "$CCUSAGE_PIN" daily --breakdown --json 2>/dev/null); then
            return 0
        fi
        printf '%s' "$raw" > "$DAILY_CACHE_FILE"
    fi
    printf '%s' "$raw" \
      | jq -c --arg today "$today" \
            '(.daily // []) | map(select(.date == $today)) | first // empty' \
        2>/dev/null || true
}

# UTC ISO-8601 → local "HH:MM"
fmt_local_hm() {
    local iso="$1"
    [[ -z "$iso" ]] && { printf -- '--:--'; return; }
    date -d "$iso" +%H:%M 2>/dev/null || printf -- '--:--'
}

fmt_remaining() {
    local mins="$1"
    if (( mins <= 0 )); then printf -- '—'; return; fi
    local h=$(( mins / 60 ))
    local m=$(( mins % 60 ))
    if (( h > 0 )); then
        printf '%dh %02dm' "$h" "$m"
    else
        printf '%dm' "$m"
    fi
}

fmt_tokens_short() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000) printf "%.1fM", n/1000000;
        else if (n >= 1000) printf "%.0fk", n/1000;
        else printf "%d", n;
    }'
}

fmt_tokens_full() {
    printf "%'d" "$1"
}

# Try ccusage; bail out cleanly if engine fails
if ! JSON=$(get_blocks_json); then
    if [[ "$MODE" == "--tui" ]]; then
        emit_tui_fallback "ccusage failed (offline or bunx unavailable)."
    else
        emit_pill_fallback "?" "ccusage failed"
    fi
    exit 0
fi

# Pick first active, non-gap block
BLOCK=$(printf '%s' "$JSON" \
  | jq -c '(.blocks // []) | map(select((.isActive // false) and ((.isGap // false) | not))) | first // empty')

if [[ -z "$BLOCK" ]]; then
    if [[ "$MODE" == "--tui" ]]; then
        emit_tui_fallback "No active block. Start a Claude Code session to see usage."
    else
        emit_pill_fallback "—" "no active block"
    fi
    exit 0
fi

INPUT=$(jq -r '.tokenCounts.inputTokens // 0' <<<"$BLOCK")
OUTPUT=$(jq -r '.tokenCounts.outputTokens // 0' <<<"$BLOCK")
CACHE_READ=$(jq -r '.tokenCounts.cacheReadInputTokens // 0' <<<"$BLOCK")
CACHE_CREATE=$(jq -r '.tokenCounts.cacheCreationInputTokens // 0' <<<"$BLOCK")
START_TIME=$(jq -r '.startTime // ""' <<<"$BLOCK")
END_TIME=$(jq -r '.endTime // ""' <<<"$BLOCK")
REMAINING_MIN=$(jq -r '.projection.remainingMinutes // 0' <<<"$BLOCK")
BURN_IND=$(jq -r '.burnRate.tokensPerMinuteForIndicator // 0' <<<"$BLOCK")
COST=$(jq -r '.costUSD // 0' <<<"$BLOCK")
MODELS_CSV=$(jq -r '(.models // []) | join(", ")' <<<"$BLOCK")
ENTRIES=$(jq -r '.entries // 0' <<<"$BLOCK")

USAGE=$(( INPUT + OUTPUT ))
PCT_INT=$(( USAGE * 100 / LIMIT ))
PCT_FRAC=$(awk -v u="$USAGE" -v l="$LIMIT" 'BEGIN { printf "%.1f", (u*100.0)/l }')

if (( PCT_INT < 60 )); then
    CLASS=""
elif (( PCT_INT <= 85 )); then
    CLASS="warning"
else
    CLASS="critical"
fi

START_HM=$(fmt_local_hm "$START_TIME")
END_HM=$(fmt_local_hm "$END_TIME")
ETA_STR=$(fmt_remaining "$REMAINING_MIN")
USAGE_FMT=$(fmt_tokens_full "$USAGE")
LIMIT_FMT=$(fmt_tokens_full "$LIMIT")
USAGE_SHORT=$(fmt_tokens_short "$USAGE")
LIMIT_SHORT=$(fmt_tokens_short "$LIMIT")
BURN_INT=$(printf '%.0f' "$BURN_IND")
BURN_FMT=$(fmt_tokens_short "$BURN_INT")

if [[ "$MODE" == "--tui" ]]; then
    bar_full=$(( PCT_INT > 100 ? 25 : (PCT_INT * 25 / 100) ))
    (( bar_full < 0 )) && bar_full=0
    (( bar_full > 25 )) && bar_full=25
    bar_empty=$(( 25 - bar_full ))
    bar=""
    for ((i=0; i<bar_full; i++)); do bar+="█"; done
    for ((i=0; i<bar_empty; i++)); do bar+="░"; done

    printf 'Claude Code Usage  (Max5x · ~%s tok / 5h window)\n' "$LIMIT_SHORT"
    printf '======================================================\n\n'
    printf 'Active block:    %s → %s  (5h rolling window)\n' "$START_HM" "$END_HM"
    printf 'Remaining:       %s\n' "$ETA_STR"
    printf 'Entries:         %s\n\n' "$ENTRIES"
    printf 'Quota:           [%s] %s%%\n' "$bar" "$PCT_FRAC"
    printf 'Tokens:          %s / %s  (input+output, cache excluded)\n' "$USAGE_FMT" "$LIMIT_FMT"
    printf '  input          %s\n' "$(fmt_tokens_full "$INPUT")"
    printf '  output         %s\n' "$(fmt_tokens_full "$OUTPUT")"
    printf 'Burn rate:       %s tok/min  (claude.ai-aligned indicator)\n' "$(fmt_tokens_full "$BURN_INT")"
    printf 'Block cost:      $%.2f\n\n' "$COST"
    printf 'Cache (info, NOT counted in %% quota):\n'
    printf '  reads          %s\n' "$(fmt_tokens_full "$CACHE_READ")"
    printf '  creation       %s\n\n' "$(fmt_tokens_full "$CACHE_CREATE")"
    printf 'Models in block: %s\n' "${MODELS_CSV:-—}"

    DAILY=$(get_today_breakdown || true)
    if [[ -n "${DAILY:-}" && "$DAILY" != "null" ]]; then
        printf '\nToday so far (daily breakdown — best-effort, ≠ block):\n'
        jq -r '.modelBreakdowns // [] | .[] |
            "  \(.modelName | tostring | (. + "                        ")[0:24])  in:\(.inputTokens // 0)  out:\(.outputTokens // 0)  $\(.cost // 0 | . * 100 | floor / 100)"' \
            <<<"$DAILY" 2>/dev/null || true
    fi

    printf '\nLast refresh:    %s  (cache TTL: %ss)\n' "$(date +%H:%M:%S)" "$CACHE_TTL"
    exit 0
fi

# ----- Pill mode -----
PILL_TEXT="${PCT_INT}% · ${ETA_STR}"

TOOLTIP=$(printf 'Block: %s → %s (Max5x)\nUsage: %s / %s tok  (%s%%)\n  in:  %s\n  out: %s\nBurn:  %s tok/min\nETA:   %s\nCost:  $%.2f\n\nModels: %s\n\nCache (not in %%):\n  reads:  %s\n  create: %s' \
    "$START_HM" "$END_HM" \
    "$USAGE_SHORT" "$LIMIT_SHORT" "$PCT_FRAC" \
    "$(fmt_tokens_full "$INPUT")" \
    "$(fmt_tokens_full "$OUTPUT")" \
    "$BURN_FMT" \
    "$ETA_STR" \
    "$COST" \
    "${MODELS_CSV:-—}" \
    "$(fmt_tokens_short "$CACHE_READ")" \
    "$(fmt_tokens_short "$CACHE_CREATE")")

emit_pill "$PILL_TEXT" "$TOOLTIP" "$CLASS" "$PCT_INT"
