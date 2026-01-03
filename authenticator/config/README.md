# Cyberdeck Login PAM Configuration

This directory contains the PAM module and scripts needed to enable passwordless login triggered by the Cyberdeck Login server.

## Overview

The PAM (Pluggable Authentication Modules) integration allows the server to unlock your Linux session without requiring a password. This works by:

1. The server writes a trigger file when authentication succeeds
2. A PAM module checks for this trigger file
3. If valid, the session is unlocked without password

## Installation

### Method 1: Using the PAM Helper Script

This is the simpler approach that works with most Linux systems.

1. **Copy the helper script**

   ```bash
   sudo cp cyberdeck-pam-helper.sh /usr/local/bin/cyberdeck-pam-helper
   sudo chmod 755 /usr/local/bin/cyberdeck-pam-helper
   sudo chown root:root /usr/local/bin/cyberdeck-pam-helper
   ```

2. **Install the PAM configuration**

   ```bash
   sudo cp cyberdeck-login /etc/pam.d/cyberdeck-login
   ```

3. **Add sudoers entry** (allows trigger without password)

   ```bash
   echo "pi ALL=(ALL) NOPASSWD: /usr/local/bin/cyberdeck-pam-helper" | sudo tee /etc/sudoers.d/cyberdeck-login
   sudo chmod 440 /etc/sudoers.d/cyberdeck-login
   ```

### Method 2: Using pam_exec

For systems that support `pam_exec`:

1. **Copy the auth script**

   ```bash
   sudo cp cyberdeck-auth.sh /usr/local/bin/cyberdeck-auth
   sudo chmod 755 /usr/local/bin/cyberdeck-auth
   ```

2. **Configure PAM for your display manager**

   Add to `/etc/pam.d/lightdm` (or `gdm`, `sddm`, etc.):

   ```
   auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth
   ```

   Place this line BEFORE other auth lines.

### Method 3: Using loginctl (systemd)

For systems using systemd-logind, the server can unlock sessions directly:

```bash
loginctl unlock-sessions
```

This is already implemented in the server and requires no additional PAM configuration, but you need to:

1. Ensure the user running the server has permission to unlock sessions
2. Add polkit rule for passwordless unlock

Create `/etc/polkit-1/rules.d/50-cyberdeck-login.rules`:

```javascript
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.lock-sessions" ||
        action.id == "org.freedesktop.login1.unlock-sessions") {
        if (subject.user == "pi") {
            return polkit.Result.YES;
        }
    }
});
```

## Files

### cyberdeck-auth.sh

Authentication script that checks for valid trigger file:

```bash
#!/bin/bash
TRIGGER_FILE="/tmp/cyberdeck-login-trigger"

if [ -f "$TRIGGER_FILE" ]; then
    # Verify file is recent (within last 10 seconds)
    FILE_AGE=$(($(date +%s) - $(stat -c %Y "$TRIGGER_FILE")))
    if [ $FILE_AGE -lt 10 ]; then
        # Verify correct user
        TRIGGER_USER=$(cat "$TRIGGER_FILE" | jq -r '.user')
        if [ "$PAM_USER" = "$TRIGGER_USER" ]; then
            rm -f "$TRIGGER_FILE"
            exit 0  # Success - allow login
        fi
    fi
    rm -f "$TRIGGER_FILE"
fi

exit 1  # Fail - require normal auth
```

### cyberdeck-pam-helper.sh

Helper that can be called to unlock the session:

```bash
#!/bin/bash
# Unlock sessions via loginctl
loginctl unlock-sessions

# Also try D-Bus method for GNOME
dbus-send --session --type=method_call \
    --dest=org.gnome.ScreenSaver \
    /org/gnome/ScreenSaver \
    org.gnome.ScreenSaver.SetActive \
    boolean:false 2>/dev/null

exit 0
```

### cyberdeck-login (PAM config)

```
#%PAM-1.0
auth    sufficient   pam_exec.so quiet /usr/local/bin/cyberdeck-auth
auth    include      system-auth
```

## Security Considerations

⚠️ **Warning**: This bypasses normal password authentication. Ensure:

1. **Physical security**: Only deploy on devices in secure locations
2. **BLE range**: Remember BLE has ~10m range - anyone within range with your phone could authenticate
3. **Key protection**: Protect the private key on your iPhone
4. **Trigger file**: The trigger file is created with mode 600 and short validity window
5. **Audit logging**: Consider enabling PAM audit logging

## Troubleshooting

### Authentication not working

1. Check trigger file is being created:
   ```bash
   ls -la /tmp/cyberdeck-login-trigger
   ```

2. Check PAM logs:
   ```bash
   sudo journalctl -u lightdm  # or your display manager
   ```

3. Test auth script manually:
   ```bash
   echo '{"user":"pi","timestamp":1234567890}' > /tmp/cyberdeck-login-trigger
   PAM_USER=pi /usr/local/bin/cyberdeck-auth && echo "Success" || echo "Failed"
   ```

### Permission denied

Ensure scripts are owned by root and have correct permissions:

```bash
sudo chown root:root /usr/local/bin/cyberdeck-*
sudo chmod 755 /usr/local/bin/cyberdeck-*
```

### Display manager specific issues

Different display managers require different PAM configurations:

- **LightDM**: `/etc/pam.d/lightdm`
- **GDM**: `/etc/pam.d/gdm-password`
- **SDDM**: `/etc/pam.d/sddm`
- **XDM**: `/etc/pam.d/xdm`

## Testing

Run the test script to verify your setup:

```bash
./test-pam-setup.sh
```

This will:
1. Check required files exist
2. Verify permissions
3. Test trigger file creation
4. Simulate authentication flow