#!/usr/bin/env bash
# claude-usage.sh — Claude Code Max5x quota pill + on-demand TUI
#
# Modes:
#   (no args)   waybar JSON: {text, tooltip, class, percentage}
#   --tui       multi-line text for `watch -n 5` (Super+Shift+U keybind)
#
# Authoritative source: api.anthropic.com/api/oauth/usage with the OAuth
# bearer token from ~/.claude/.credentials.json. Returns the SAME numbers
# claude.ai/usage shows (5h utilization %, 7-day, per-model, extra_usage,
# resets_at timestamps). Token counts/burn rate from ccusage are kept for
# tooltip context but are NOT the basis of the pill % anymore (ccusage
# only sees Claude Code JSONL — claude.ai web chats are invisible to it).
#
# Fallback chain: API 200 → use API. API failure (401/500/network) → use
# ccusage's tokenCounts vs CLAUDE_TOKEN_LIMIT (legacy, may diverge from
# claude.ai). All-fail → "?" pill.
#
# Endpoint discovered 2026-05-10 via /tmp/claude-usage-probe.sh. See
# notes/areas/claude/realtime-usage/scratch/ccusage-shape.md for diagnosis.

set -eu
set -o pipefail

CREDS=~/.claude/.credentials.json
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
USAGE_CACHE="/tmp/claude-usage-api-cache.json"
USAGE_CACHE_TTL=30   # 30s — covers waybar 30s interval + watch -n 5 (6 hits)

CCUSAGE_CACHE="/tmp/claude-usage-cache.json"
CCUSAGE_DAILY_CACHE="/tmp/claude-usage-daily-cache.json"
CCUSAGE_TTL=30
CCUSAGE_PIN="ccusage@18.0.11"

# Legacy fallback (ccusage-only mode, when API unavailable). Calibrated
# in Batch A vs claude.ai but invalidated by the discovery that ccusage
# misses web chats — keep only as last-resort estimate.
LIMIT="${CLAUDE_TOKEN_LIMIT:-800000}"

MODE="${1:-pill}"

# ---------- emit helpers ----------

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

# ---------- formatters ----------

fmt_remaining_min() {
    local mins="$1"
    if (( mins <= 0 )); then printf -- '—'; return; fi
    local h=$(( mins / 60 ))
    local m=$(( mins % 60 ))
    if (( h > 0 )); then printf '%dh %02dm' "$h" "$m"
    else printf '%dm' "$m"
    fi
}

fmt_local_hm() {
    local iso="$1"
    [[ -z "$iso" || "$iso" == "null" ]] && { printf -- '--:--'; return; }
    date -d "$iso" +%H:%M 2>/dev/null || printf -- '--:--'
}

fmt_local_day_hm() {
    local iso="$1"
    [[ -z "$iso" || "$iso" == "null" ]] && { printf -- '—'; return; }
    date -d "$iso" +"%a %d/%m %H:%M" 2>/dev/null || printf -- '—'
}

fmt_tokens_short() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000) printf "%.1fM", n/1000000;
        else if (n >= 1000) printf "%.0fk", n/1000;
        else printf "%d", n;
    }'
}

fmt_tokens_full() {
    # Accept ints or floats; format with thousands separators.
    awk -v n="${1:-0}" 'BEGIN { n=int(n); s=""; sign=""; if (n<0) {sign="-"; n=-n}; while (n>=1000) { s=sprintf(",%03d%s", n%1000, s); n=int(n/1000) } printf "%s%d%s", sign, n, s }'
}

fmt_pct_1() { awk -v n="${1:-0}" 'BEGIN { printf "%.1f", n }'; }
fmt_money_2() { awk -v n="${1:-0}" 'BEGIN { printf "%.2f", n }'; }
fmt_int() { awk -v n="${1:-0}" 'BEGIN { printf "%d", n }'; }
# extra_usage amounts come in MINOR UNITS (BRL centavos, USD cents).
# Returns "X.YYY,ZZ" with comma decimal + period thousands (BR convention).
fmt_minor_units_br() {
    awk -v n="${1:-0}" 'BEGIN {
        v = n / 100.0
        ipart = int(v)
        fpart = int((v - ipart) * 100 + 0.5)
        s = ""
        sign = ""
        if (ipart < 0) { sign = "-"; ipart = -ipart }
        do {
            chunk = ipart % 1000
            ipart = int(ipart / 1000)
            if (ipart > 0) s = sprintf(".%03d%s", chunk, s)
            else s = sprintf("%d%s", chunk, s)
        } while (ipart > 0)
        printf "%s%s,%02d", sign, s, fpart
    }'
}

iso_to_epoch() {
    local iso="$1"
    [[ -z "$iso" || "$iso" == "null" ]] && { echo 0; return; }
    date -d "$iso" +%s 2>/dev/null || echo 0
}

minutes_until() {
    local iso="$1"
    local target_epoch now_epoch
    target_epoch=$(iso_to_epoch "$iso")
    now_epoch=$(date +%s)
    if (( target_epoch == 0 || target_epoch <= now_epoch )); then
        echo 0
    else
        echo $(( (target_epoch - now_epoch) / 60 ))
    fi
}

# ---------- API source ----------

# Fetch /api/oauth/usage with bearer token. Cache 30s.
# Output JSON to stdout, return 0. On any failure, return non-zero.
get_api_usage() {
    if [[ -f "$USAGE_CACHE" ]]; then
        local mtime now age
        mtime=$(stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [[ $age -lt $USAGE_CACHE_TTL ]]; then
            cat "$USAGE_CACHE"
            return 0
        fi
    fi
    [[ -f "$CREDS" ]] || return 1
    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null) || return 1
    [[ -n "$token" ]] || return 1
    # 6s timeout — pill must not block waybar render.
    local body
    if ! body=$(curl -sS --max-time 6 \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-usage-pill/1.0" \
            "$USAGE_URL" 2>/dev/null); then
        return 1
    fi
    # Sanity check it's the shape we expect.
    if ! printf '%s' "$body" | jq -e '.five_hour.utilization' >/dev/null 2>&1; then
        return 1
    fi
    printf '%s' "$body" > "$USAGE_CACHE"
    printf '%s' "$body"
}

# ---------- ccusage (enrichment) ----------

get_ccusage_active() {
    if [[ -f "$CCUSAGE_CACHE" ]]; then
        local mtime now age
        mtime=$(stat -c %Y "$CCUSAGE_CACHE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [[ $age -lt $CCUSAGE_TTL ]]; then
            cat "$CCUSAGE_CACHE"
            return 0
        fi
    fi
    if ! bunx "$CCUSAGE_PIN" blocks --active --json > "$CCUSAGE_CACHE.tmp" 2>/dev/null; then
        rm -f "$CCUSAGE_CACHE.tmp"
        return 1
    fi
    mv "$CCUSAGE_CACHE.tmp" "$CCUSAGE_CACHE"
    cat "$CCUSAGE_CACHE"
}

# ---------- pick path ----------

API_JSON=""
if API_JSON=$(get_api_usage); then
    USE_API=1
else
    USE_API=0
fi

CC_JSON=""
CC_BLOCK=""
if CC_JSON=$(get_ccusage_active 2>/dev/null); then
    CC_BLOCK=$(printf '%s' "$CC_JSON" \
      | jq -c '(.blocks // []) | map(select((.isActive // false) and ((.isGap // false) | not))) | first // empty' 2>/dev/null || true)
fi

# Hard-fail: neither source available.
if (( USE_API == 0 )) && [[ -z "$CC_BLOCK" ]]; then
    if [[ "$MODE" == "--tui" ]]; then
        emit_tui_fallback "Both API (api.anthropic.com/api/oauth/usage) and ccusage failed. Check network + token expiry: $CREDS"
    else
        emit_pill_fallback "?" "API + ccusage both failed"
    fi
    exit 0
fi

# ---------- assemble pill values ----------

# Initialize all optional fields so `set -u` is safe whichever branch runs.
RESETS_5H=""
SEVEN_DAY_PCT=""
SEVEN_DAY_RESETS=""
OPUS_PCT=""
SONNET_PCT=""
EXTRA_ENABLED="false"
EXTRA_LIMIT=0
EXTRA_USED=0
EXTRA_PCT=0
EXTRA_CCY=""

if (( USE_API == 1 )); then
    PCT_FRAC=$(jq -r '.five_hour.utilization // 0' <<<"$API_JSON")
    PCT_INT=$(printf '%.0f' "$PCT_FRAC")
    RESETS_5H=$(jq -r '.five_hour.resets_at // empty' <<<"$API_JSON")
    REMAINING_MIN=$(minutes_until "$RESETS_5H")

    SEVEN_DAY_PCT=$(jq -r '.seven_day.utilization // empty' <<<"$API_JSON")
    SEVEN_DAY_RESETS=$(jq -r '.seven_day.resets_at // empty' <<<"$API_JSON")
    OPUS_PCT=$(jq -r '.seven_day_opus.utilization // empty' <<<"$API_JSON")
    SONNET_PCT=$(jq -r '.seven_day_sonnet.utilization // empty' <<<"$API_JSON")

    EXTRA_ENABLED=$(jq -r '.extra_usage.is_enabled // false' <<<"$API_JSON")
    EXTRA_LIMIT=$(jq -r '.extra_usage.monthly_limit // 0' <<<"$API_JSON")
    EXTRA_USED=$(jq -r '.extra_usage.used_credits // 0' <<<"$API_JSON")
    EXTRA_PCT=$(jq -r '.extra_usage.utilization // 0' <<<"$API_JSON")
    EXTRA_CCY=$(jq -r '.extra_usage.currency // ""' <<<"$API_JSON")
    SOURCE_LABEL="api"
else
    # Legacy ccusage-derived pct
    INPUT=$(jq -r '.tokenCounts.inputTokens // 0' <<<"$CC_BLOCK")
    OUTPUT=$(jq -r '.tokenCounts.outputTokens // 0' <<<"$CC_BLOCK")
    USAGE=$(( INPUT + OUTPUT ))
    PCT_INT=$(( USAGE * 100 / LIMIT ))
    PCT_FRAC=$(awk -v u="$USAGE" -v l="$LIMIT" 'BEGIN { printf "%.1f", (u*100.0)/l }')
    REMAINING_MIN=$(jq -r '.projection.remainingMinutes // 0' <<<"$CC_BLOCK")
    SEVEN_DAY_PCT=""
    SEVEN_DAY_RESETS=""
    OPUS_PCT=""
    SONNET_PCT=""
    EXTRA_ENABLED="false"
    SOURCE_LABEL="ccusage-fallback"
fi

if (( PCT_INT < 60 )); then
    CLASS=""
elif (( PCT_INT <= 85 )); then
    CLASS="warning"
else
    CLASS="critical"
fi

ETA_STR=$(fmt_remaining_min "$REMAINING_MIN")

# ---------- ccusage enrichment values (always optional) ----------

if [[ -n "$CC_BLOCK" ]]; then
    CC_INPUT=$(jq -r '.tokenCounts.inputTokens // 0' <<<"$CC_BLOCK")
    CC_OUTPUT=$(jq -r '.tokenCounts.outputTokens // 0' <<<"$CC_BLOCK")
    CC_CACHE_READ=$(jq -r '.tokenCounts.cacheReadInputTokens // 0' <<<"$CC_BLOCK")
    CC_CACHE_CREATE=$(jq -r '.tokenCounts.cacheCreationInputTokens // 0' <<<"$CC_BLOCK")
    CC_START=$(jq -r '.startTime // ""' <<<"$CC_BLOCK")
    CC_END=$(jq -r '.endTime // ""' <<<"$CC_BLOCK")
    CC_BURN_IND=$(jq -r '.burnRate.tokensPerMinuteForIndicator // 0' <<<"$CC_BLOCK")
    CC_COST=$(jq -r '.costUSD // 0' <<<"$CC_BLOCK")
    CC_MODELS=$(jq -r '(.models // []) | join(", ")' <<<"$CC_BLOCK")
    CC_ENTRIES=$(jq -r '.entries // 0' <<<"$CC_BLOCK")
    CC_HAS=1
else
    CC_HAS=0
fi

# ---------- TUI output ----------

if [[ "$MODE" == "--tui" ]]; then
    bar_full=$(( PCT_INT > 100 ? 25 : (PCT_INT * 25 / 100) ))
    (( bar_full < 0 )) && bar_full=0
    (( bar_full > 25 )) && bar_full=25
    bar_empty=$(( 25 - bar_full ))
    bar=""
    for ((i=0; i<bar_full; i++)); do bar+="█"; done
    for ((i=0; i<bar_empty; i++)); do bar+="░"; done

    printf 'Claude Code Usage Monitor   (source: %s)\n' "$SOURCE_LABEL"
    printf '======================================================\n\n'
    if (( USE_API == 1 )); then
        printf '5h window:    [%s] %5.1f%%\n' "$bar" "$PCT_FRAC"
        printf '              resets %s   (in %s)\n\n' "$(fmt_local_hm "$RESETS_5H")" "$ETA_STR"
        if [[ -n "$SEVEN_DAY_PCT" ]]; then
            printf '7-day:        %5.1f%%   (resets %s)\n' "$SEVEN_DAY_PCT" "$(fmt_local_day_hm "$SEVEN_DAY_RESETS")"
        fi
        [[ -n "$OPUS_PCT" ]]   && printf '  Opus:       %5.1f%%\n' "$OPUS_PCT"   || printf '  Opus:        —    (no data)\n'
        [[ -n "$SONNET_PCT" ]] && printf '  Sonnet:     %5.1f%%\n' "$SONNET_PCT" || printf '  Sonnet:      —    (no data)\n'
        printf '\n'
        if [[ "$EXTRA_ENABLED" == "true" ]]; then
            printf 'Extra usage:  %s %s spent / %s %s  (%.1f%%)\n\n' \
                "$EXTRA_CCY" "$(fmt_minor_units_br "$EXTRA_USED")" \
                "$EXTRA_CCY" "$(fmt_minor_units_br "$EXTRA_LIMIT")" "$EXTRA_PCT"
        fi
    else
        printf '5h window:    [%s] %5.1f%%   (legacy ccusage estimate — claude.ai may differ)\n\n' "$bar" "$PCT_FRAC"
    fi

    if (( CC_HAS == 1 )); then
        printf 'Claude Code activity (local — web chats not included):\n'
        printf '  Tokens:     in %s / out %s   (cache excluded)\n' "$(fmt_tokens_full "$CC_INPUT")" "$(fmt_tokens_full "$CC_OUTPUT")"
        printf '  Burn:       %s tok/min\n' "$(fmt_tokens_full "$(printf '%.0f' "$CC_BURN_IND")")"
        printf '  Cost:       $%.2f\n' "$CC_COST"
        printf '  Entries:    %s\n' "$CC_ENTRIES"
        printf '  Models:     %s\n\n' "${CC_MODELS:-—}"
        printf '  Cache (info, not counted in quota):\n'
        printf '    reads:    %s\n'  "$(fmt_tokens_full "$CC_CACHE_READ")"
        printf '    creation: %s\n\n' "$(fmt_tokens_full "$CC_CACHE_CREATE")"
    fi

    printf 'Last refresh: %s   (cache TTL: API %ss / ccusage %ss)\n' "$(date +%H:%M:%S)" "$USAGE_CACHE_TTL" "$CCUSAGE_TTL"
    exit 0
fi

# ---------- Pill output ----------

# Icon: Nerd Font MDI "creation" (sparkle, U+F0674). Anthropic doesn't have
# its own Nerd Font glyph; sparkle matches Claude.ai's UI aesthetic. Built
# via printf '\U' escape because high-codepoint Unicode literals don't
# survive the editing toolchain reliably. Swap to '\Uf06a9' for robot (󰚩)
# or any other MDI codepoint.
PILL_ICON=$(printf '\Uf0674')
PILL_TEXT="${PILL_ICON}  ${PCT_INT}% · ${ETA_STR}"

build_tooltip() {
    local resets_5h_hm resets_7d_hm cc_start_hm cc_end_hm cc_burn_int
    local seven_day_str sonnet_str opus_str extra_pct_str cc_cost_str
    local extra_used_int extra_limit_int
    resets_5h_hm=$(fmt_local_hm "$RESETS_5H")
    resets_7d_hm=$(fmt_local_day_hm "$SEVEN_DAY_RESETS")
    cc_start_hm=$(fmt_local_hm "$CC_START")
    cc_end_hm=$(fmt_local_hm "$CC_END")
    cc_burn_int=$(printf '%.0f' "${CC_BURN_IND:-0}")
    seven_day_str=$(fmt_pct_1 "$SEVEN_DAY_PCT")
    sonnet_str=$(fmt_pct_1 "$SONNET_PCT")
    opus_str=$(fmt_pct_1 "$OPUS_PCT")
    extra_pct_str=$(fmt_pct_1 "$EXTRA_PCT")
    cc_cost_str=$(fmt_money_2 "${CC_COST:-0}")
    extra_used_int=$(fmt_int "$EXTRA_USED")
    extra_limit_int=$(fmt_int "$EXTRA_LIMIT")

    local lines=()
    if (( USE_API == 1 )); then
        lines+=("5h: ${PCT_FRAC}%  resets ${resets_5h_hm}  (in ${ETA_STR})")
    else
        lines+=("5h: ${PCT_FRAC}%  (legacy ccusage estimate)")
    fi
    [[ -n "$SEVEN_DAY_PCT" ]] && lines+=("7d: ${seven_day_str}%  resets ${resets_7d_hm}")
    [[ -n "$SONNET_PCT" ]]    && lines+=("  Sonnet: ${sonnet_str}%")
    [[ -n "$OPUS_PCT" ]]      && lines+=("  Opus:   ${opus_str}%")
    if [[ "$EXTRA_ENABLED" == "true" ]]; then
        lines+=("Extra: ${extra_pct_str}%  ${EXTRA_CCY} $(fmt_minor_units_br "$EXTRA_USED")/$(fmt_minor_units_br "$EXTRA_LIMIT")")
    fi
    if (( CC_HAS == 1 )); then
        lines+=("")
        lines+=("Claude Code (local):")
        lines+=("  in:  $(fmt_tokens_short "$CC_INPUT")")
        lines+=("  out: $(fmt_tokens_short "$CC_OUTPUT")")
        lines+=("  burn: $(fmt_tokens_short "$cc_burn_int")/min")
        lines+=("  cost: \$${cc_cost_str}")
        lines+=("  models: ${CC_MODELS:-—}")
        lines+=("  cache r:$(fmt_tokens_short "$CC_CACHE_READ") c:$(fmt_tokens_short "$CC_CACHE_CREATE")")
    fi
    lines+=("")
    lines+=("source: ${SOURCE_LABEL}")
    printf '%s\n' "${lines[@]}"
}

TOOLTIP=$(build_tooltip)

emit_pill "$PILL_TEXT" "$TOOLTIP" "$CLASS" "$PCT_INT"
