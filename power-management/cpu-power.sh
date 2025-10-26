#!/bin/bash
# CPU Power Management Script for Battery Optimization

# Set CPU governor to powersave for battery life
set_powersave() {
    echo "Setting CPU governor to powersave..."
    echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    echo "CPU governor set to powersave"
}

# Set CPU governor to performance for AC power
set_performance() {
    echo "Setting CPU governor to performance..."
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
    echo "CPU governor set to performance"
}

# Check current status
status() {
    echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    echo "Available governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)"
    echo "Current CPU frequencies:"
    grep MHz /proc/cpuinfo | head -8
}

case "$1" in
    battery|powersave)
        set_powersave
        ;;
    ac|performance)
        set_performance
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {battery|powersave|ac|performance|status}"
        echo "  battery/powersave  - Set CPU to power saving mode"
        echo "  ac/performance     - Set CPU to performance mode" 
        echo "  status             - Show current CPU power state"
        exit 1
        ;;
esac