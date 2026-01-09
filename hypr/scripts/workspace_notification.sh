#!/bin/bash

# Workspace Window Notification Script
# Monitors Hyprland events and sends notifications when windows open in different workspaces

HYPRLAND_INSTANCE_SIGNATURE="$HYPRLAND_INSTANCE_SIGNATURE"

# Function to send notification
send_notification() {
    local window_title="$1"
    local workspace="$2"
    local window_class="$3"

    # Send desktop notification
    notify-send -u normal -t 3000 \
        -a "Hyprland" \
        "Window opened in Workspace $workspace" \
        "$window_title"

    # Optional: play a sound (uncomment if you have a sound file)
    # paplay /usr/share/sounds/freedesktop/stereo/message.oga &
}

# Get current active workspace
get_active_workspace() {
    hyprctl activeworkspace -j | jq -r '.id'
}

# Monitor Hyprland events
handle_event() {
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
        # Parse the event
        event_type=$(echo "$line" | cut -d'>' -f1)
        event_data=$(echo "$line" | cut -d'>' -f2-)

        # Handle window open events
        if [[ "$event_type" == "openwindow" ]]; then
            # Parse event data: address,workspace,class,title
            window_address=$(echo "$event_data" | cut -d',' -f1)
            window_workspace=$(echo "$event_data" | cut -d',' -f2)
            window_class=$(echo "$event_data" | cut -d',' -f3)
            window_title=$(echo "$event_data" | cut -d',' -f4-)

            # Get the currently active workspace
            active_workspace=$(get_active_workspace)

            # If window opened in a different workspace, notify
            if [[ "$window_workspace" != "$active_workspace" ]]; then
                send_notification "$window_title" "$window_workspace" "$window_class"
            fi
        fi

        # Handle movewindow events (when windows are moved to different workspaces)
        if [[ "$event_type" == "movewindow" ]]; then
            # Parse event data: address,workspace
            window_address=$(echo "$event_data" | cut -d',' -f1)
            window_workspace=$(echo "$event_data" | cut -d',' -f2)

            # Get the currently active workspace
            active_workspace=$(get_active_workspace)

            # If window was moved to a different workspace, notify
            if [[ "$window_workspace" != "$active_workspace" ]]; then
                # Get window info
                window_info=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$window_address\")")
                window_title=$(echo "$window_info" | jq -r '.title // "Unknown"')
                window_class=$(echo "$window_info" | jq -r '.class // "Unknown"')

                if [[ -n "$window_title" && "$window_title" != "null" ]]; then
                    send_notification "$window_title" "$window_workspace" "$window_class"
                fi
            fi
        fi
    done
}

# Main execution
main() {
    # Check if socat is installed
    if ! command -v socat &> /dev/null; then
        echo "Error: socat is not installed. Please install it first."
        exit 1
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install it first."
        exit 1
    fi

    # Start event monitoring
    handle_event
}

# Run the script
main
