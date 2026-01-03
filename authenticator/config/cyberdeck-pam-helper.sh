#!/bin/bash
# cyberdeck-pam-helper.sh
# Helper script to unlock sessions
# Can be called with sudo by the Docker container

set -e

# Get target user from argument or default
TARGET_USER="${1:-pi}"

echo "Cyberdeck Login: Unlocking session for $TARGET_USER"

# Method 1: loginctl (systemd-logind)
if command -v loginctl &> /dev/null; then
    loginctl unlock-sessions 2>/dev/null && {
        logger -t cyberdeck-login "Session unlocked via loginctl"
        echo "Unlocked via loginctl"
    }
fi

# Method 2: GNOME Screensaver (D-Bus)
if command -v dbus-send &> /dev/null; then
    # Get the user's D-Bus session
    USER_ID=$(id -u "$TARGET_USER" 2>/dev/null)
    if [ -n "$USER_ID" ]; then
        DBUS_ADDR="unix:path=/run/user/$USER_ID/bus"
        
        # Try GNOME screensaver
        DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" dbus-send \
            --session \
            --type=method_call \
            --dest=org.gnome.ScreenSaver \
            /org/gnome/ScreenSaver \
            org.gnome.ScreenSaver.SetActive \
            boolean:false 2>/dev/null && {
            logger -t cyberdeck-login "Session unlocked via GNOME D-Bus"
            echo "Unlocked via GNOME D-Bus"
        }
        
        # Try freedesktop screensaver
        DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" dbus-send \
            --session \
            --type=method_call \
            --dest=org.freedesktop.ScreenSaver \
            /org/freedesktop/ScreenSaver \
            org.freedesktop.ScreenSaver.SetActive \
            boolean:false 2>/dev/null && {
            logger -t cyberdeck-login "Session unlocked via freedesktop D-Bus"
            echo "Unlocked via freedesktop D-Bus"
        }
        
        # Try KDE screensaver
        DBUS_SESSION_BUS_ADDRESS="$DBUS_ADDR" dbus-send \
            --session \
            --type=method_call \
            --dest=org.kde.screensaver \
            /ScreenSaver \
            org.kde.screensaver.SetActive \
            boolean:false 2>/dev/null && {
            logger -t cyberdeck-login "Session unlocked via KDE D-Bus"
            echo "Unlocked via KDE D-Bus"
        }
    fi
fi

# Method 3: xdotool simulation (if X11)
if command -v xdotool &> /dev/null && [ -n "$DISPLAY" ]; then
    # Simulate key press to wake up
    DISPLAY=:0 xdotool key Return 2>/dev/null || true
fi

logger -t cyberdeck-login "Session unlock completed for $TARGET_USER"
exit 0