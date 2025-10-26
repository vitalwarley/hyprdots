#!/bin/bash

# Start GNOME keyring daemon and export environment variables
eval $(gnome-keyring-daemon --start --components=secrets,pkcs11,ssh)
export SSH_AUTH_SOCK
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID 