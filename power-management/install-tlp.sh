#!/bin/bash
# TLP Installation and Setup Script

echo "Installing TLP..."
sudo pacman -S tlp tlp-rdw

echo "Enabling TLP service..."
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

# Mask conflicting services
echo "Disabling conflicting power management services..."
sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket

echo "TLP installation complete!"
echo "Run 'tlp-stat -s' to check status"
echo "Edit /etc/tlp.conf for custom settings"