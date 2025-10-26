#!/bin/bash
# Apply battery optimization settings

echo "Applying TLP battery optimizations..."

# Copy optimized settings to TLP config
echo "Backing up current TLP config..."
sudo cp /etc/tlp.conf /etc/tlp.conf.backup

echo "Applying battery optimizations to /etc/tlp.conf..."
# You'll need to manually merge these settings or replace specific sections

echo "Key settings to apply:"
echo "1. CPU governor: powersave on battery"
echo "2. CPU max performance: 30% on battery" 
echo "3. GPU DPM: battery mode"
echo "4. USB autosuspend enabled"
echo "5. WiFi power saving on battery"
echo "6. Battery charge threshold: 75-90%"

echo ""
echo "To apply these settings:"
echo "1. Edit /etc/tlp.conf"
echo "2. Copy relevant lines from tlp-battery-optimized.conf"
echo "3. Run: sudo tlp start"

echo ""
echo "Quick emergency power saving:"
echo "sudo tlp bat"