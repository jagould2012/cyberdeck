#!/bin/bash
# install-pam.sh
# Installation script for Cyberdeck Login PAM configuration
# Run with sudo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${1:-pi}"

echo "🔐 Installing Cyberdeck Login PAM configuration"
echo "   Target user: $TARGET_USER"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (sudo ./install-pam.sh)"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
if command -v apt &> /dev/null; then
    apt install -y jq xdotool > /dev/null 2>&1 && echo "   ✅ Dependencies installed" || echo "   ℹ️  Dependencies already installed"
elif command -v yum &> /dev/null; then
    yum install -y jq xdotool > /dev/null 2>&1 && echo "   ✅ Dependencies installed" || echo "   ℹ️  Dependencies already installed"
elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm jq xdotool > /dev/null 2>&1 && echo "   ✅ Dependencies installed" || echo "   ℹ️  Dependencies already installed"
else
    echo "   ⚠️  Could not install dependencies automatically. Please install jq and xdotool manually."
fi

# Install auth script
echo "📝 Installing auth script..."
cp "$SCRIPT_DIR/cyberdeck-auth.sh" /usr/local/bin/cyberdeck-auth
chmod 755 /usr/local/bin/cyberdeck-auth
chown root:root /usr/local/bin/cyberdeck-auth
echo "   ✅ /usr/local/bin/cyberdeck-auth"

# Install PAM helper
echo "📝 Installing PAM helper..."
cp "$SCRIPT_DIR/cyberdeck-pam-helper.sh" /usr/local/bin/cyberdeck-pam-helper
chmod 755 /usr/local/bin/cyberdeck-pam-helper
chown root:root /usr/local/bin/cyberdeck-pam-helper
echo "   ✅ /usr/local/bin/cyberdeck-pam-helper"

# Install PAM config
echo "📝 Installing PAM configuration..."
cp "$SCRIPT_DIR/cyberdeck-login" /etc/pam.d/cyberdeck-login
chmod 644 /etc/pam.d/cyberdeck-login
chown root:root /etc/pam.d/cyberdeck-login
echo "   ✅ /etc/pam.d/cyberdeck-login"

# Install polkit rules
if [ -d "/etc/polkit-1/rules.d" ]; then
    echo "📝 Installing polkit rules..."
    cat > /etc/polkit-1/rules.d/50-cyberdeck-login.rules << EOF
// Polkit rules for Cyberdeck Login
// Only affects session lock/unlock for cyberdeck-login user
polkit.addRule(function(action, subject) {
    if (subject.user == "$TARGET_USER") {
        if (action.id == "org.freedesktop.login1.lock-sessions" ||
            action.id == "org.freedesktop.login1.unlock-sessions" ||
            action.id == "org.freedesktop.login1.lock-session" ||
            action.id == "org.freedesktop.login1.unlock-session") {
            return polkit.Result.YES;
        }
    }
    return null;
});
EOF
    chmod 644 /etc/polkit-1/rules.d/50-cyberdeck-login.rules
    echo "   ✅ /etc/polkit-1/rules.d/50-cyberdeck-login.rules"
fi

# Generate and install sudoers configuration
echo "📝 Installing sudoers configuration..."
cat > /etc/sudoers.d/cyberdeck-login << EOF
# Sudoers configuration for Cyberdeck Login
# Auto-generated for user: $TARGET_USER

# Allow user to run the PAM helper without password
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/local/bin/cyberdeck-pam-helper

# Allow the helper to run loginctl without password
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/loginctl unlock-sessions
$TARGET_USER ALL=(ALL) NOPASSWD: /bin/loginctl unlock-sessions
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/loginctl unlock-session *
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/loginctl activate *
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/loginctl terminate-session *

# Allow xdotool with lightdm's X authority for auto-submit (specific commands)
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/env DISPLAY\=\:0 XAUTHORITY\=/var/lib/lightdm/.Xauthority /usr/bin/xdotool mousemove *
$TARGET_USER ALL=(ALL) NOPASSWD: /usr/bin/env DISPLAY\=\:0 XAUTHORITY\=/var/lib/lightdm/.Xauthority /usr/bin/xdotool key *
EOF
chmod 440 /etc/sudoers.d/cyberdeck-login
chown root:root /etc/sudoers.d/cyberdeck-login

# Validate sudoers syntax
if visudo -c -f /etc/sudoers.d/cyberdeck-login; then
    echo "   ✅ /etc/sudoers.d/cyberdeck-login"
else
    echo "   ❌ Sudoers syntax error, removing file"
    rm -f /etc/sudoers.d/cyberdeck-login
    exit 1
fi

# Detect and configure display manager
echo ""
echo "📝 Configuring display manager..."

PAM_LINE="auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth"
DM_CONFIGURED=false

# Function to add PAM line if not present
add_pam_line() {
    local pam_file="$1"
    local dm_name="$2"
    
    if [ -f "$pam_file" ]; then
        if grep -q "cyberdeck-auth" "$pam_file"; then
            echo "   ℹ️  $dm_name already configured"
        else
            # Add after the first auth line
            sed -i "0,/^auth/s//auth sufficient pam_exec.so quiet \/usr\/local\/bin\/cyberdeck-auth\n&/" "$pam_file"
            echo "   ✅ Configured $dm_name ($pam_file)"
        fi
        DM_CONFIGURED=true
        return 0
    fi
    return 1
}

# Try each display manager in order of likelihood

# LightDM (Kali default, Raspberry Pi, many others)
if [ -f "/etc/pam.d/lightdm" ]; then
    add_pam_line "/etc/pam.d/lightdm" "LightDM"
fi

# GDM (GNOME)
if [ -f "/etc/pam.d/gdm-password" ]; then
    add_pam_line "/etc/pam.d/gdm-password" "GDM"
fi

# SDDM (KDE)
if [ -f "/etc/pam.d/sddm" ]; then
    add_pam_line "/etc/pam.d/sddm" "SDDM"
fi

# XDM
if [ -f "/etc/pam.d/xdm" ]; then
    add_pam_line "/etc/pam.d/xdm" "XDM"
fi

# LXDM
if [ -f "/etc/pam.d/lxdm" ]; then
    add_pam_line "/etc/pam.d/lxdm" "LXDM"
fi

# Kali-specific: Also configure login and common-auth for console
if [ -f "/etc/pam.d/login" ]; then
    add_pam_line "/etc/pam.d/login" "Console Login"
fi

# Screen lockers

# XScreenSaver
if [ -f "/etc/pam.d/xscreensaver" ]; then
    add_pam_line "/etc/pam.d/xscreensaver" "XScreenSaver"
fi

# light-locker (LightDM locker)
if [ -f "/etc/pam.d/light-locker" ]; then
    add_pam_line "/etc/pam.d/light-locker" "light-locker"
fi

# i3lock
if [ -f "/etc/pam.d/i3lock" ]; then
    add_pam_line "/etc/pam.d/i3lock" "i3lock"
fi

# GNOME Screensaver
if [ -f "/etc/pam.d/gnome-screensaver" ]; then
    add_pam_line "/etc/pam.d/gnome-screensaver" "GNOME Screensaver"
fi

if [ "$DM_CONFIGURED" = false ]; then
    echo "   ⚠️  No supported display manager found"
    echo ""
    echo "   Manually add this line to your display manager's PAM config:"
    echo "   $PAM_LINE"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Restart your display manager or reboot"
echo "2. Test by running: ./test-pam-setup.sh"