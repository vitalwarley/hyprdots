#!/bin/bash

# Script to move a specific window to another workspace
# Usage: move_window_to_workspace.sh [window_class_or_title] [workspace]
#        OR: move_window_to_workspace.sh [workspace]

# Check if only one argument provided (assuming it's the workspace number)
if [ $# -eq 1 ]; then
    # If only one argument is provided, assume it's the workspace and use active window
    TARGET_WORKSPACE="$1"
    WINDOW_QUERY="active"
elif [ $# -eq 2 ]; then
    # If two arguments, use them as window query and workspace
    WINDOW_QUERY="$1"
    TARGET_WORKSPACE="$2"
else
    echo "Usage: $0 [window_class_or_title] [workspace]"
    echo "       OR: $0 [workspace]  (moves active window)"
    echo "Example: $0 \"firefox\" 2"
    echo "Example: $0 3  (moves active window to workspace 3)"
    exit 1
fi

# Check if the target workspace is valid
if ! [[ "$TARGET_WORKSPACE" =~ ^[0-9]+$ ]] && [[ "$TARGET_WORKSPACE" != "special" ]]; then
    echo "Error: Workspace must be a number or 'special'"
    exit 1
fi

# Handle active window case
if [ "$WINDOW_QUERY" == "active" ]; then
    # Get the active window information
    ACTIVE_WINDOW_INFO=$(hyprctl activewindow -j)
    
    # Check if there's an active window
    if [ "$ACTIVE_WINDOW_INFO" = "{}" ]; then
        echo "No active window found"
        exit 1
    fi
    
    # Extract the window address
    ACTIVE_WINDOW_ADDRESS=$(echo "$ACTIVE_WINDOW_INFO" | jq -r '.address')
    
    # If window is part of a group, we need to get all addresses from the group
    GROUPED_INFO=$(echo "$ACTIVE_WINDOW_INFO" | jq -r '.grouped')
    
    # Move only the active window
    RESULT=$(hyprctl dispatch movetoworkspacesilent "$TARGET_WORKSPACE,$ACTIVE_WINDOW_ADDRESS" 2>&1)
    
    # Check for errors in the result
    if [[ "$RESULT" == *"Window not found"* ]]; then
        echo "Failed to move window - Window not found"
        exit 1
    else
        echo "Moved active window to workspace $TARGET_WORKSPACE"
        exit 0
    fi
fi

# For non-active window case, find windows matching the query
WINDOW_ADDRESSES=$(hyprctl clients -j | jq -r '.[] | select(.class | test("'"$WINDOW_QUERY"'"; "i")) // select(.title | test("'"$WINDOW_QUERY"'"; "i")) | .address')

if [ -z "$WINDOW_ADDRESSES" ]; then
    echo "No windows matching '$WINDOW_QUERY' found"
    exit 1
fi

# Move each matching window
SUCCESS=0
for WINDOW_ADDRESS in $WINDOW_ADDRESSES; do
    RESULT=$(hyprctl dispatch movetoworkspacesilent "$TARGET_WORKSPACE,$WINDOW_ADDRESS" 2>&1)
    
    # Check for errors in the result
    if [[ "$RESULT" == *"Window not found"* ]]; then
        echo "Failed to move window ($WINDOW_ADDRESS) - Window not found"
    else
        echo "Moved window ($WINDOW_ADDRESS) to workspace $TARGET_WORKSPACE"
        SUCCESS=1
    fi
done

if [ $SUCCESS -eq 1 ]; then
    exit 0
else
    exit 1
fi