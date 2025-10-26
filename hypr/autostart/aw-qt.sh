#!/bin/bash

# Wait for system to be fully initialized
sleep 5

# Try to remove problematic Wayland client library if it exists
if [ -f "/opt/activitywatch/libwayland-client.so.0" ]; then
    rm -f /opt/activitywatch/libwayland-client.so.0 2>/dev/null || echo "Could not remove Wayland client library. You may need to remove it manually."
fi

# Start aw-qt with X11 backend to avoid Wayland issues
QT_QPA_PLATFORM=xcb aw-qt > ~/.local/share/activitywatch/aw-qt.log 2>&1 &

# Store the PID
echo $! > ~/.local/share/activitywatch/aw-qt.pid

# Check if the process is still running after a few seconds
sleep 3
if ! kill -0 $(cat ~/.local/share/activitywatch/aw-qt.pid) 2>/dev/null; then
    echo "aw-qt failed to start properly. Check ~/.local/share/activitywatch/aw-qt.log for details."
    exit 1
fi 