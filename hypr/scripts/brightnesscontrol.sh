#!/usr/bin/env bash

# Wrapper script for brightness control that also handles external monitors via DDC/CI
# Calls the original HyDE script for internal display and uses ddcutil for external monitors

HYDE_SCRIPT="${HOME}/.local/lib/hyde/brightnesscontrol.sh"
BRIGHTNESS_VCP=10

# Get step value (default 5)
step=${BRIGHTNESS_STEPS:-5}
step="${2:-$step}"

# Adjust external monitors using ddcutil (runs in background to avoid delay)
adjust_external_monitors() {
    local action="$1"
    local step="$2"

    # Check if ddcutil is available
    command -v ddcutil >/dev/null 2>&1 || return

    # Get list of display numbers that support DDC/CI
    local displays
    displays=$(ddcutil detect 2>/dev/null | grep -oP '(?<=Display )\d+')

    for display in $displays; do
        (
            # Get current brightness
            local current
            current=$(ddcutil getvcp $BRIGHTNESS_VCP --display "$display" 2>/dev/null | grep -oP 'current value =\s*\K\d+')

            [[ -z "$current" ]] && exit

            local new_value
            if [[ "$action" == "i" ]]; then
                new_value=$((current + step))
                ((new_value > 100)) && new_value=100
            else
                new_value=$((current - step))
                ((new_value < 0)) && new_value=0
            fi

            ddcutil setvcp $BRIGHTNESS_VCP "$new_value" --display "$display" 2>/dev/null
        ) &
    done
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
