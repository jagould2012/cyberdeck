#!/bin/bash
# test-pam-setup.sh
# Test script to verify Cyberdeck Login PAM configuration

set -e

echo "🔍 Testing Cyberdeck Login PAM Setup"
echo ""

ERRORS=0

# Check auth script
echo "Checking /usr/local/bin/cyberdeck-auth..."
if [ -x /usr/local/bin/cyberdeck-auth ]; then
    echo "   ✅ Auth script exists and is executable"
else
    echo "   ❌ Auth script missing or not executable"
    ERRORS=$((ERRORS + 1))
fi

# Check PAM helper
echo "Checking /usr/local/bin/cyberdeck-pam-helper..."
if [ -x /usr/local/bin/cyberdeck-pam-helper ]; then
    echo "   ✅ PAM helper exists and is executable"
else
    echo "   ❌ PAM helper missing or not executable"
    ERRORS=$((ERRORS + 1))
fi

# Check PAM config
echo "Checking /etc/pam.d/cyberdeck-login..."
if [ -f /etc/pam.d/cyberdeck-login ]; then
    echo "   ✅ PAM config exists"
else
    echo "   ❌ PAM config missing"
    ERRORS=$((ERRORS + 1))
fi

# Check sudoers
echo "Checking /etc/sudoers.d/cyberdeck-login..."
if [ -f /etc/sudoers.d/cyberdeck-login ]; then
    if sudo visudo -c -f /etc/sudoers.d/cyberdeck-login 2>/dev/null; then
        echo "   ✅ Sudoers config exists and is valid"
    else
        echo "   ❌ Sudoers config has syntax errors"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ⚠️  Sudoers config missing (optional)"
fi

# Check jq (required by auth script)
echo "Checking jq installation..."
if command -v jq &> /dev/null; then
    echo "   ✅ jq is installed"
else
    echo "   ❌ jq is not installed (required)"
    echo "      Install with: sudo apt install jq"
    ERRORS=$((ERRORS + 1))
fi

# Test trigger file creation
echo ""
echo "Testing trigger file mechanism..."
TRIGGER_FILE="/tmp/cyberdeck-login-trigger"
TEST_USER="${USER:-pi}"

# Create test trigger
echo "{\"user\":\"$TEST_USER\",\"timestamp\":$(date +%s)000,\"action\":\"unlock\"}" > "$TRIGGER_FILE"
chmod 600 "$TRIGGER_FILE"

if [ -f "$TRIGGER_FILE" ]; then
    echo "   ✅ Trigger file created: $TRIGGER_FILE"
    
    # Test auth script
    export PAM_USER="$TEST_USER"
    if /usr/local/bin/cyberdeck-auth 2>/dev/null; then
        echo "   ✅ Auth script accepted trigger"
    else
        echo "   ❌ Auth script rejected trigger"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "   ❌ Could not create trigger file"
    ERRORS=$((ERRORS + 1))
fi

# Cleanup
rm -f "$TRIGGER_FILE" 2>/dev/null

# Test loginctl
echo ""
echo "Testing loginctl..."
if command -v loginctl &> /dev/null; then
    echo "   ✅ loginctl available"
    if loginctl show-session 2>/dev/null | grep -q "State="; then
        echo "   ✅ Can query session state"
    else
        echo "   ⚠️  Cannot query session state (may be normal for SSH)"
    fi
else
    echo "   ⚠️  loginctl not available"
fi

echo ""
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All tests passed!"
    echo ""
    echo "The PAM configuration appears to be correct."
    echo "Next steps:"
    echo "1. Start the Cyberdeck Login server"
    echo "2. Register your iPhone"
    echo "3. Lock your screen and test authentication"
else
    echo "❌ $ERRORS test(s) failed"
    echo ""
    echo "Please fix the issues above and run this test again."
    exit 1
fi