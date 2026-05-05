#!/usr/bin/env bash

# Wrapper script for brightness control that also handles external monitors via DDC/CI
# Calls the original HyDE script for internal display and uses ddcutil for external monitors

HYDE_SCRIPT="${HOME}/.local/lib/hyde/brightnesscontrol.sh"
BRIGHTNESS_VCP=10
DISPLAYS_CACHE="${XDG_RUNTIME_DIR:-/tmp}/ddcutil-displays"
DISPLAYS_CACHE_TTL=3600
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/ddcutil-brightness.lock"

# Get step value (default 5)
step=${BRIGHTNESS_STEPS:-5}
step="${2:-$step}"

# Cache ddcutil detect output — the i2c probe is slow (~1s) and runs every keypress otherwise
get_displays() {
    if [[ -f "$DISPLAYS_CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$DISPLAYS_CACHE") < DISPLAYS_CACHE_TTL )); then
        cat "$DISPLAYS_CACHE"
        return
    fi
    ddcutil detect 2>/dev/null | grep -oP '(?<=Display )\d+' | tee "$DISPLAYS_CACHE"
}

# Adjust external monitors using ddcutil's relative setvcp; serialize with flock so
# rapid keybinding auto-repeat queues instead of racing on read-modify-write.
adjust_external_monitors() {
    local action="$1"
    local step="$2"
    local sign="-"
    [[ "$action" == "i" ]] && sign="+"

    command -v ddcutil >/dev/null 2>&1 || return

    (
        flock -x 9
        for display in $(get_displays); do
            ddcutil setvcp $BRIGHTNESS_VCP "$sign" "$step" --display "$display" --noverify 2>/dev/null
        done
    ) 9>"$LOCK_FILE" &
}

case $1 in
i | -i)
    adjust_external_monitors "i" "$step"
    ;;
d | -d)
    adjust_external_monitors "d" "$step"
    ;;
esac

# Call the original HyDE script for internal display
exec "$HYDE_SCRIPT" "$@"
