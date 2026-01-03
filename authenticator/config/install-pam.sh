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
    # Update username in rules file
    sed "s/\"pi\"/\"$TARGET_USER\"/g" "$SCRIPT_DIR/50-cyberdeck-login.rules" > /etc/polkit-1/rules.d/50-cyberdeck-login.rules
    chmod 644 /etc/polkit-1/rules.d/50-cyberdeck-login.rules
    echo "   ✅ /etc/polkit-1/rules.d/50-cyberdeck-login.rules"
fi

# Install sudoers configuration
echo "📝 Installing sudoers configuration..."
# Update username in sudoers file
sed "s/^pi /$TARGET_USER /g" "$SCRIPT_DIR/cyberdeck-sudoers" > /etc/sudoers.d/cyberdeck-login
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

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "1. Edit your display manager's PAM config to include cyberdeck-login"
echo ""
echo "   For LightDM, add to /etc/pam.d/lightdm:"
echo "   auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth"
echo ""
echo "   For GDM, add to /etc/pam.d/gdm-password:"
echo "   auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth"
echo ""
echo "2. Restart your display manager"
echo "3. Test by running: ./test-pam-setup.sh"