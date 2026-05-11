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
# resets_at timestamps).
#
# Fallback chain: API 200 → use API. API failure (401/500/network) → fall
# back to ccusage's tokenCounts vs CLAUDE_TOKEN_LIMIT (legacy estimate;
# ccusage only sees Claude Code JSONL so it misses claude.ai web chats).
# All-fail → "?" pill. ccusage is only invoked on the fallback path.
#
# Endpoint discovered 2026-05-10 via /tmp/claude-usage-probe.sh. See
# notes/areas/claude/realtime-usage/scratch/ccusage-shape.md for diagnosis.

set -eu
set -o pipefail

CREDS=~/.claude/.credentials.json
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
USAGE_CACHE="/tmp/claude-usage-api-cache.json"
USAGE_FAIL_LOCK="/tmp/claude-usage-api-fail.lock"
# Refresh API only every 5 min — the endpoint rate-limits aggressively
# (HTTP 429 with no useful Retry-After). Pill remains responsive because
# we serve from cache between refreshes.
USAGE_CACHE_TTL=300
# Stale cache is preferred over ccusage fallback for up to 1h. After 1h
# without a successful refresh, drop to ccusage with the legacy 800k
# limit. This makes transient outages (network blip, 429 burst) invisible.
STALE_MAX_SECS=3600
# After a refresh failure (any cause), don't re-attempt for this long.
# Lets a 429 cool off; lets a network blip not pin every poll trying.
RETRY_BACKOFF_SECS=300

# Sliding-window trail of (timestamp, utilization) tuples. Each successful
# API refresh appends one line. Used to derive a "recent burn rate" that
# reacts to model switches (e.g., Opus → Sonnet) within a few refreshes,
# instead of being dragged forever by the cumulative-from-window-start
# average. TSV: <epoch_secs>\t<utilization_pct>.
TRAIL_FILE="/tmp/claude-usage-trail.tsv"
TRAIL_RETAIN_SECS=3600        # drop entries older than this on each append
TRAIL_WINDOW_SECS=1800        # 30min sliding window for recent-rate calc
TRAIL_MIN_SPAN_SECS=300       # need at least this much elapsed in-window
TRAIL_MIN_POINTS=2            # need at least this many points in-window

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

fmt_age() {
    local s="${1:-0}"
    if (( s < 60 )); then printf '%ds' "$s"
    elif (( s < 3600 )); then printf '%dm' $((s/60))
    else printf '%dh%02dm' $((s/3600)) $(((s%3600)/60))
    fi
}

# Compact gap format for the projection lockout. Inputs in minutes; output
# uses no spaces so the pill suffix stays tight (e.g. "-51m", "-1h23m").
fmt_gap_compact() {
    local mins="${1:-0}"
    (( mins < 0 )) && mins=0
    if (( mins < 60 )); then printf '%dm' "$mins"
    else printf '%dh%02dm' $((mins/60)) $((mins%60))
    fi
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

# Returns 0 if we should attempt to refresh the API cache now; 1 otherwise.
# Skips if cache is still fresh OR if the recent fail-lock hasn't cooled.
should_refresh_api() {
    local now
    now=$(date +%s)
    if [[ -f "$USAGE_CACHE" ]]; then
        local age=$(( now - $(stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0) ))
        (( age < USAGE_CACHE_TTL )) && return 1
    fi
    if [[ -f "$USAGE_FAIL_LOCK" ]]; then
        local lock_age=$(( now - $(stat -c %Y "$USAGE_FAIL_LOCK" 2>/dev/null || echo 0) ))
        (( lock_age < RETRY_BACKOFF_SECS )) && return 1
    fi
    return 0
}

# Fetch /api/oauth/usage with bearer token; on success update cache and
# clear fail-lock. On failure (any cause: network, 401, 429, malformed),
# touch fail-lock to suppress retries for RETRY_BACKOFF_SECS.
try_refresh_api() {
    [[ -f "$CREDS" ]] || { touch "$USAGE_FAIL_LOCK"; return 1; }
    local token body http_code
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null) || { touch "$USAGE_FAIL_LOCK"; return 1; }
    [[ -n "$token" ]] || { touch "$USAGE_FAIL_LOCK"; return 1; }
    # Capture HTTP code separately so 4xx/5xx are treated as failures even
    # when curl itself "succeeds" (gets a response).
    local tmp; tmp=$(mktemp)
    http_code=$(curl -sS --max-time 6 -o "$tmp" -w '%{http_code}' \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-usage-pill/1.0" \
        "$USAGE_URL" 2>/dev/null) || true
    if [[ "$http_code" != "200" ]]; then
        rm -f "$tmp"
        touch "$USAGE_FAIL_LOCK"
        return 1
    fi
    body=$(cat "$tmp"); rm -f "$tmp"
    if ! printf '%s' "$body" | jq -e '.five_hour.utilization' >/dev/null 2>&1; then
        touch "$USAGE_FAIL_LOCK"
        return 1
    fi
    printf '%s' "$body" > "$USAGE_CACHE"
    rm -f "$USAGE_FAIL_LOCK"
    # Trail: append (now, util) and trim to the retain window. Filtering
    # via awk in-place avoids a separate cron — the file stays bounded.
    local util_now now_epoch cutoff
    util_now=$(printf '%s' "$body" | jq -r '.five_hour.utilization // 0' 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    printf '%d\t%s\n' "$now_epoch" "$util_now" >> "$TRAIL_FILE"
    cutoff=$(( now_epoch - TRAIL_RETAIN_SECS ))
    awk -v cutoff="$cutoff" '$1 >= cutoff' "$TRAIL_FILE" > "$TRAIL_FILE.tmp" 2>/dev/null \
        && mv "$TRAIL_FILE.tmp" "$TRAIL_FILE"
    return 0
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
#
# Tiered selection (in order of preference):
#   1. Fresh API cache  (age < USAGE_CACHE_TTL, set USE_API=1, USE_API_STALE=0)
#   2. Stale API cache  (age < STALE_MAX_SECS,  set USE_API=1, USE_API_STALE=1)
#   3. ccusage fallback (no usable API at all,  set USE_API=0)
#   4. Idle             (both sources unusable but cache file exists with
#                        valid content, USE_IDLE=1) — split into two sub-tiers
#                        depending on whether the cached window still applies.
#   5. Hard fail        (no cache at all OR cache unparseable AND ccusage
#                        empty) — emits "?"
#
# Tiers 1–3 cover transient failures without dropping into misleading numbers.
# Tier 4 (idle) is the common case when Claude Code has been unused for hours:
# the OAuth bearer rotates with Claude Code use, so a multi-hour gap lets it
# expire — API returns 401, fail-lock pins the failure, cache ages past
# STALE_MAX_SECS, and ccusage has no active block to report. Without tier 4,
# the user wakes up to "?" every morning. With tier 4, the pill carries
# enough context that the user can tell "idle" from "broken" at a glance.

API_JSON=""
USE_API=0
USE_API_STALE=0
CACHE_AGE_SECS=0
USE_IDLE=0
IDLE_WINDOW_VALID=0          # 1 if cached resets_at is still in the future
IDLE_CACHED_UTIL=""          # cached five_hour.utilization (only when window valid)

if should_refresh_api; then
    try_refresh_api || true
fi

if [[ -f "$USAGE_CACHE" ]]; then
    CACHE_AGE_SECS=$(( $(date +%s) - $(stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0) ))
    if (( CACHE_AGE_SECS < STALE_MAX_SECS )); then
        API_JSON=$(cat "$USAGE_CACHE")
        if printf '%s' "$API_JSON" | jq -e '.five_hour.utilization' >/dev/null 2>&1; then
            USE_API=1
            (( CACHE_AGE_SECS >= USAGE_CACHE_TTL )) && USE_API_STALE=1
        else
            API_JSON=""
        fi
    fi
fi

# ccusage is only consulted when the API is unavailable. With the API
# healthy, skipping the 6-9s `bunx ccusage` call keeps each poll cheap.
CC_BLOCK=""
if (( USE_API == 0 )); then
    if CC_JSON=$(get_ccusage_active 2>/dev/null); then
        CC_BLOCK=$(printf '%s' "$CC_JSON" \
          | jq -c '(.blocks // []) | map(select((.isActive // false) and ((.isGap // false) | not))) | first // empty' 2>/dev/null || true)
    fi
fi

# Idle detection: if neither tier 1–3 has anything to show but the cache
# file is still readable, use it as an "idle" snapshot. The cached
# resets_at decides whether we still trust the cached %:
#   - resets_at > now : cached window has not yet ended → cached % is the
#                       current state by definition (nothing's been spent
#                       since); show it with an idle marker.
#   - resets_at <= now: previous window has elapsed; current % is unknown.
#                       Pill drops the digit and shows a reset marker.
if (( USE_API == 0 )) && [[ -z "$CC_BLOCK" ]] && [[ -f "$USAGE_CACHE" ]]; then
    IDLE_CACHE_JSON=$(cat "$USAGE_CACHE" 2>/dev/null || true)
    if [[ -n "$IDLE_CACHE_JSON" ]] && printf '%s' "$IDLE_CACHE_JSON" | jq -e '.five_hour.utilization' >/dev/null 2>&1; then
        USE_IDLE=1
        API_JSON="$IDLE_CACHE_JSON"  # tooltip uses it for 7d/per-model/extra context
        idle_resets_iso=$(jq -r '.five_hour.resets_at // empty' <<<"$IDLE_CACHE_JSON")
        idle_resets_epoch=$(iso_to_epoch "$idle_resets_iso")
        if (( idle_resets_epoch > $(date +%s) )); then
            IDLE_WINDOW_VALID=1
            IDLE_CACHED_UTIL=$(jq -r '.five_hour.utilization // 0' <<<"$IDLE_CACHE_JSON")
        fi
    fi
fi

# Hard-fail: no usable source AND no cache to fall back on (true breakage).
if (( USE_API == 0 )) && [[ -z "$CC_BLOCK" ]] && (( USE_IDLE == 0 )); then
    if [[ "$MODE" == "--tui" ]]; then
        emit_tui_fallback "Both API (api.anthropic.com/api/oauth/usage) and ccusage failed, and no cache to fall back on. Check network + token: $CREDS"
    else
        emit_pill_fallback "?" "API + ccusage both failed; no cache to fall back on"
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
    if (( USE_API_STALE == 1 )); then
        SOURCE_LABEL="api stale ($(fmt_age "$CACHE_AGE_SECS"))"
    else
        SOURCE_LABEL="api"
    fi
elif (( USE_IDLE == 1 )); then
    # Idle: cache exists but is older than STALE_MAX_SECS AND ccusage has
    # no active block. Sub-divide on whether the cached 5h window is still
    # in effect; the cached % is the current state only if it is.
    RESETS_5H=$(jq -r '.five_hour.resets_at // empty' <<<"$API_JSON")
    SEVEN_DAY_PCT=$(jq -r '.seven_day.utilization // empty' <<<"$API_JSON")
    SEVEN_DAY_RESETS=$(jq -r '.seven_day.resets_at // empty' <<<"$API_JSON")
    OPUS_PCT=$(jq -r '.seven_day_opus.utilization // empty' <<<"$API_JSON")
    SONNET_PCT=$(jq -r '.seven_day_sonnet.utilization // empty' <<<"$API_JSON")
    EXTRA_ENABLED=$(jq -r '.extra_usage.is_enabled // false' <<<"$API_JSON")
    EXTRA_LIMIT=$(jq -r '.extra_usage.monthly_limit // 0' <<<"$API_JSON")
    EXTRA_USED=$(jq -r '.extra_usage.used_credits // 0' <<<"$API_JSON")
    EXTRA_PCT=$(jq -r '.extra_usage.utilization // 0' <<<"$API_JSON")
    EXTRA_CCY=$(jq -r '.extra_usage.currency // ""' <<<"$API_JSON")
    # LAST_KNOWN_UTIL is what was cached. We always show it in the tooltip
    # (it's the only honest data we have). We only mirror it into PCT_FRAC
    # / PCT_INT when the cached window is still current.
    LAST_KNOWN_UTIL=$(jq -r '.five_hour.utilization // 0' <<<"$API_JSON")
    if (( IDLE_WINDOW_VALID == 1 )); then
        PCT_FRAC="$LAST_KNOWN_UTIL"
        PCT_INT=$(printf '%.0f' "$PCT_FRAC")
        REMAINING_MIN=$(minutes_until "$RESETS_5H")
    else
        PCT_FRAC=0
        PCT_INT=0
        REMAINING_MIN=0
    fi
    SOURCE_LABEL="idle ($(fmt_age "$CACHE_AGE_SECS") since last refresh)"
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

if (( USE_IDLE == 1 )); then
    # Idle suppresses threshold-based class colors entirely — the digit
    # (when shown) is from before the gap; coloring it as a real warning
    # would re-introduce the confusion B1 is trying to fix.
    CLASS="idle"
else
    if (( PCT_INT < 60 )); then
        CLASS=""
    elif (( PCT_INT <= 85 )); then
        CLASS="warning"
    else
        CLASS="critical"
    fi
    # Layer a staleness/fallback marker on the threshold class so user-style.css
    # can dim or annotate it. Space-joined, waybar applies each as a separate
    # CSS class.
    if (( USE_API == 0 )); then
        CLASS="${CLASS:+$CLASS }fallback"
    elif (( USE_API_STALE == 1 )); then
        CLASS="${CLASS:+$CLASS }stale"
    fi
fi

ETA_STR=$(fmt_remaining_min "$REMAINING_MIN")

# ---------- T3-lite: in-window linear burn forecast ----------
#
# Two projections, both single-window and linear:
#
#   CUM (cumulative, full window):
#     burn = utilization / elapsed_min            # average since window start
#     projected = utilization * 300 / elapsed_min
#   REC (recent, sliding 30min window of trail):
#     burn = (util_newest - util_oldest) / span_min
#     projected = utilization + burn * remaining_min
#
# CUM is stable but slow to react to mid-window model switches. REC reacts
# within a few API refreshes once trail has ≥2 points spanning ≥5 min.
# Pill uses REC when available, else CUM. Tooltip shows both labeled.
#
# Suppressed for ccusage fallback (window misalignment) and during the
# first 5min elapsed (a couple of minutes' burst extrapolates to absurd
# values). Stale cache annotates source age.

# CUM (cumulative-rate) projection — always computed when API is healthy.
CUM_PROJECTED_PCT=""
CUM_EXHAUSTS_AT_HM=""
CUM_GAP_STR=""

# REC (recent-rate) projection — computed when trail has enough points.
REC_PROJECTED_PCT=""
REC_EXHAUSTS_AT_HM=""
REC_GAP_STR=""
REC_RATE=""             # %/min slope across the sliding window
REC_WINDOW_LABEL=""     # e.g. "27m" — actual span used

# Primary projection chosen for the pill (REC wins if available).
PROJECTED_PCT=""
EXHAUSTS_AT_HM=""
EXHAUSTS_GAP_STR=""
PRIMARY_KIND=""         # "rec" | "cum" | "" (none)
PROJECT_NOTE=""
PROJECT_TOO_EARLY=0

if (( USE_API == 1 )) && (( USE_IDLE == 0 )); then
    ELAPSED_MIN=$(( 300 - REMAINING_MIN ))
    if (( ELAPSED_MIN < 5 )); then
        PROJECT_TOO_EARLY=1
    elif (( REMAINING_MIN > 0 )); then
        # --- CUM: cumulative rate from window start ---
        CUM_PROJECTED_PCT=$(awk -v u="$PCT_FRAC" -v e="$ELAPSED_MIN" 'BEGIN { printf "%.1f", u * 300.0 / e }')
        if awk -v p="$CUM_PROJECTED_PCT" 'BEGIN { exit (p >= 100) ? 0 : 1 }' \
           && awk -v u="$PCT_FRAC" 'BEGIN { exit (u > 0) ? 0 : 1 }'; then
            cum_min_to_exh=$(awk -v u="$PCT_FRAC" -v e="$ELAPSED_MIN" 'BEGIN { v = (100 - u) * e / u; if (v < 0) v = 0; printf "%d", v + 0.5 }')
            cum_exh_epoch=$(( $(date +%s) + cum_min_to_exh * 60 ))
            CUM_EXHAUSTS_AT_HM=$(date -d "@$cum_exh_epoch" +%H:%M 2>/dev/null || printf -- '--:--')
            CUM_GAP_STR="-$(fmt_gap_compact $(( REMAINING_MIN - cum_min_to_exh )))"
        fi

        # --- REC: sliding-window slope over the trail file ---
        if [[ -f "$TRAIL_FILE" ]]; then
            now_epoch=$(date +%s)
            cutoff=$(( now_epoch - TRAIL_WINDOW_SECS ))
            in_window=$(awk -v c="$cutoff" '$1 >= c' "$TRAIL_FILE")
            n_in=$(printf '%s' "$in_window" | grep -c . || true)
            if (( n_in >= TRAIL_MIN_POINTS )); then
                read -r oldest_ts oldest_util <<< "$(printf '%s' "$in_window" | head -1)"
                read -r newest_ts newest_util <<< "$(printf '%s' "$in_window" | tail -1)"
                span_s=$(( newest_ts - oldest_ts ))
                if (( span_s >= TRAIL_MIN_SPAN_SECS )); then
                    REC_RATE=$(awk -v du="$newest_util" -v u0="$oldest_util" -v ds="$span_s" \
                        'BEGIN { printf "%.4f", (du - u0) / (ds / 60.0) }')
                    REC_WINDOW_LABEL="$(( span_s / 60 ))m"
                    if awk -v r="$REC_RATE" 'BEGIN { exit (r > 0) ? 0 : 1 }'; then
                        REC_PROJECTED_PCT=$(awk -v u="$PCT_FRAC" -v r="$REC_RATE" -v rm="$REMAINING_MIN" \
                            'BEGIN { printf "%.1f", u + r * rm }')
                        if awk -v p="$REC_PROJECTED_PCT" 'BEGIN { exit (p >= 100) ? 0 : 1 }'; then
                            rec_min_to_exh=$(awk -v u="$PCT_FRAC" -v r="$REC_RATE" \
                                'BEGIN { v = (100 - u) / r; if (v < 0) v = 0; printf "%d", v + 0.5 }')
                            rec_exh_epoch=$(( now_epoch + rec_min_to_exh * 60 ))
                            REC_EXHAUSTS_AT_HM=$(date -d "@$rec_exh_epoch" +%H:%M 2>/dev/null || printf -- '--:--')
                            REC_GAP_STR="-$(fmt_gap_compact $(( REMAINING_MIN - rec_min_to_exh )))"
                        fi
                    else
                        # Negative or zero rate: utilization flat or dropping.
                        # Project just the current %; never an exhaust.
                        REC_PROJECTED_PCT="$PCT_FRAC"
                    fi
                fi
            fi
        fi

        # --- Pick primary for the pill: REC if computed, else CUM ---
        if [[ -n "$REC_PROJECTED_PCT" ]]; then
            PROJECTED_PCT="$REC_PROJECTED_PCT"
            EXHAUSTS_AT_HM="$REC_EXHAUSTS_AT_HM"
            EXHAUSTS_GAP_STR="$REC_GAP_STR"
            PRIMARY_KIND="rec"
            PROJECT_NOTE="(recent ${REC_WINDOW_LABEL}, linear)"
        elif [[ -n "$CUM_PROJECTED_PCT" ]]; then
            PROJECTED_PCT="$CUM_PROJECTED_PCT"
            EXHAUSTS_AT_HM="$CUM_EXHAUSTS_AT_HM"
            EXHAUSTS_GAP_STR="$CUM_GAP_STR"
            PRIMARY_KIND="cum"
            PROJECT_NOTE="(full window, linear)"
        fi
        if (( USE_API_STALE == 1 )) && [[ -n "$PROJECT_NOTE" ]]; then
            PROJECT_NOTE="${PROJECT_NOTE%)}, from data $(fmt_age "$CACHE_AGE_SECS") old)"
        fi
    fi
fi

# ccusage's local view used to be shown as tooltip enrichment, but its 5h
# block windowing doesn't align with the API's, so the numbers misled
# more than they helped. Kept only as the fallback PCT source above.

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
    if (( USE_IDLE == 1 )); then
        idle_age_str=$(fmt_age "$CACHE_AGE_SECS")
        printf 'Status:       idle — no Claude Code activity for %s\n\n' "$idle_age_str"
        if (( IDLE_WINDOW_VALID == 1 )); then
            printf '5h window:    [%s] %5.1f%%   (still active, no spend since last refresh)\n' "$bar" "$PCT_FRAC"
            printf '              resets %s   (in %s)\n\n' "$(fmt_local_hm "$RESETS_5H")" "$ETA_STR"
        else
            printf '5h window:    —     (previous window ended; current window unknown)\n'
            printf '              last known: %.1f%% at reset %s\n\n' "$LAST_KNOWN_UTIL" "$(fmt_local_hm "$RESETS_5H")"
        fi
        if [[ -n "$SEVEN_DAY_PCT" ]]; then
            printf '7-day:        %5.1f%%   (resets %s, cached)\n' "$SEVEN_DAY_PCT" "$(fmt_local_day_hm "$SEVEN_DAY_RESETS")"
        fi
        [[ -n "$SONNET_PCT" ]] && printf '  Sonnet:     %5.1f%%\n' "$SONNET_PCT"
        [[ -n "$OPUS_PCT" ]]   && printf '  Opus:       %5.1f%%\n' "$OPUS_PCT"
        if [[ "$EXTRA_ENABLED" == "true" ]]; then
            printf '\nExtra usage:  %s %s spent / %s %s  (%.1f%%, cached)\n' \
                "$EXTRA_CCY" "$(fmt_minor_units_br "$EXTRA_USED")" \
                "$EXTRA_CCY" "$(fmt_minor_units_br "$EXTRA_LIMIT")" "$EXTRA_PCT"
        fi
        printf '\nResume Claude Code to refresh the pill.\n'
        printf 'Last refresh: %s ago   (cache TTL: API %ss)\n' "$idle_age_str" "$USAGE_CACHE_TTL"
        exit 0
    fi
    if (( USE_API == 1 )); then
        printf '5h window:    [%s] %5.1f%%\n' "$bar" "$PCT_FRAC"
        if (( USE_API_STALE == 1 )); then
            printf '              resets %s   (in %s)   [stale %s]\n' "$(fmt_local_hm "$RESETS_5H")" "$ETA_STR" "$(fmt_age "$CACHE_AGE_SECS")"
        else
            printf '              resets %s   (in %s)\n' "$(fmt_local_hm "$RESETS_5H")" "$ETA_STR"
        fi
        if (( PROJECT_TOO_EARLY == 1 )); then
            printf '              Projected: (too early to project)\n'
        elif [[ -n "$PROJECTED_PCT" ]]; then
            printf '              Projected (full window): ~%s%%' "${CUM_PROJECTED_PCT:-${PCT_FRAC}}"
            [[ -n "$CUM_EXHAUSTS_AT_HM" ]] && printf ' → exh %s (%s)' "$CUM_EXHAUSTS_AT_HM" "$CUM_GAP_STR"
            printf '\n'
            if [[ -n "$REC_PROJECTED_PCT" ]]; then
                printf '              Projected (recent %s): ~%s%%' "$REC_WINDOW_LABEL" "$REC_PROJECTED_PCT"
                [[ -n "$REC_EXHAUSTS_AT_HM" ]] && printf ' → exh %s (%s)' "$REC_EXHAUSTS_AT_HM" "$REC_GAP_STR"
                printf '\n'
            fi
        fi
        printf '\n'
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

    printf 'Last refresh: %s   (cache TTL: API %ss)\n' "$(date +%H:%M:%S)" "$USAGE_CACHE_TTL"
    exit 0
fi

# ---------- Pill output ----------

# Icon: Nerd Font MDI "creation" (sparkle, U+F0674). Anthropic doesn't have
# its own Nerd Font glyph; sparkle matches Claude.ai's UI aesthetic. Built
# via printf '\U' escape because high-codepoint Unicode literals don't
# survive the editing toolchain reliably. Swap to '\Uf06a9' for robot (󰚩)
# or any other MDI codepoint.
PILL_ICON=$(printf '\Uf0674')
# Staleness / fallback / idle markers in the pill text:
#   fresh         : "  47% · 1h 48m"
#   stale Xm      : "  47% · 1h 48m  ·5m"            (cache served from API but not refreshed)
#   ccusage       : "  47% · 1h 48m  CC"             (last-resort; misleads vs claude.ai)
#   exhausts soon : "  82% · 1h 12m  →exh 14:35"     (linear projection ≥ 100% before reset)
#   idle (valid)  : "  47%  idle 9h"                 (cached window not yet ended → digit still meaningful)
#   idle (reset)  : "  —  idle 9h"                   (cached window elapsed → no current digit to honestly show)
if (( USE_IDLE == 1 )); then
    idle_age_str=$(fmt_age "$CACHE_AGE_SECS")
    if (( IDLE_WINDOW_VALID == 1 )); then
        PILL_TEXT="${PILL_ICON}  ${PCT_INT}%  idle ${idle_age_str}"
    else
        PILL_TEXT="${PILL_ICON}  —  idle ${idle_age_str}"
    fi
else
    if (( USE_API == 0 )); then
        PILL_SUFFIX="  CC"
    elif (( USE_API_STALE == 1 )); then
        PILL_SUFFIX="  ·$(fmt_age "$CACHE_AGE_SECS")"
    else
        PILL_SUFFIX=""
    fi
    [[ -n "$EXHAUSTS_AT_HM" ]] && PILL_SUFFIX="${PILL_SUFFIX}  →exh ${EXHAUSTS_AT_HM} (${EXHAUSTS_GAP_STR})"
    PILL_TEXT="${PILL_ICON}  ${PCT_INT}% · ${ETA_STR}${PILL_SUFFIX}"
fi

build_tooltip() {
    local resets_5h_hm resets_7d_hm
    local seven_day_str sonnet_str opus_str extra_pct_str
    resets_5h_hm=$(fmt_local_hm "$RESETS_5H")
    resets_7d_hm=$(fmt_local_day_hm "$SEVEN_DAY_RESETS")
    seven_day_str=$(fmt_pct_1 "$SEVEN_DAY_PCT")
    sonnet_str=$(fmt_pct_1 "$SONNET_PCT")
    opus_str=$(fmt_pct_1 "$OPUS_PCT")
    extra_pct_str=$(fmt_pct_1 "$EXTRA_PCT")

    local lines=()
    if (( USE_IDLE == 1 )); then
        local idle_age_str
        idle_age_str=$(fmt_age "$CACHE_AGE_SECS")
        lines+=("Idle — Claude Code not used for ${idle_age_str}")
        if (( IDLE_WINDOW_VALID == 1 )); then
            lines+=("5h window (still active): ${PCT_FRAC}%  resets ${resets_5h_hm}  (in ${ETA_STR})")
            lines+=("This % is from the last refresh ${idle_age_str} ago; no spend since.")
        else
            lines+=("Previous 5h window has ended (was: ${LAST_KNOWN_UTIL}% at reset ${resets_5h_hm}).")
            lines+=("Current window: unknown — resume Claude Code to refresh.")
        fi
    elif (( USE_API == 1 )); then
        if (( USE_API_STALE == 1 )); then
            lines+=("5h: ${PCT_FRAC}%  resets ${resets_5h_hm}  (in ${ETA_STR})  [stale $(fmt_age "$CACHE_AGE_SECS")]")
        else
            lines+=("5h: ${PCT_FRAC}%  resets ${resets_5h_hm}  (in ${ETA_STR})")
        fi
        if (( PROJECT_TOO_EARLY == 1 )); then
            lines+=("Projected: (too early to project)")
        elif [[ -n "$PROJECTED_PCT" ]]; then
            # Always show the cumulative-rate line (stable baseline).
            local cum_label="Projected (full window): ~${CUM_PROJECTED_PCT:-${PCT_FRAC}}%"
            [[ -n "$CUM_EXHAUSTS_AT_HM" ]] && cum_label+=" → exh ${CUM_EXHAUSTS_AT_HM} (${CUM_GAP_STR})"
            lines+=("$cum_label")
            # Add the recent-rate line when the trail had enough points.
            if [[ -n "$REC_PROJECTED_PCT" ]]; then
                local rec_label="Projected (recent ${REC_WINDOW_LABEL}): ~${REC_PROJECTED_PCT}%"
                [[ -n "$REC_EXHAUSTS_AT_HM" ]] && rec_label+=" → exh ${REC_EXHAUSTS_AT_HM} (${REC_GAP_STR})"
                lines+=("$rec_label")
            fi
        fi
    else
        lines+=("5h: ${PCT_FRAC}%  (legacy ccusage estimate — no recent API data)")
    fi
    [[ -n "$SEVEN_DAY_PCT" ]] && lines+=("7d: ${seven_day_str}%  resets ${resets_7d_hm}")
    [[ -n "$SONNET_PCT" ]]    && lines+=("  Sonnet: ${sonnet_str}%")
    [[ -n "$OPUS_PCT" ]]      && lines+=("  Opus:   ${opus_str}%")
    if [[ "$EXTRA_ENABLED" == "true" ]]; then
        lines+=("Extra: ${extra_pct_str}%  ${EXTRA_CCY} $(fmt_minor_units_br "$EXTRA_USED")/$(fmt_minor_units_br "$EXTRA_LIMIT")")
    fi
    lines+=("")
    lines+=("source: ${SOURCE_LABEL}")
    printf '%s\n' "${lines[@]}"
}

TOOLTIP=$(build_tooltip)

emit_pill "$PILL_TEXT" "$TOOLTIP" "$CLASS" "$PCT_INT"
