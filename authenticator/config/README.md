# Cyberdeck Login PAM Configuration

This directory contains the PAM module and scripts needed to enable passwordless login triggered by the Cyberdeck Login server.

## Quick Install

```bash
sudo ./install-pam.sh <username>
```

For example:
```bash
sudo ./install-pam.sh parallels
```

The script will:
1. Install required dependencies (jq)
2. Install authentication scripts
3. Configure PAM for your display manager
4. Set up sudoers and polkit rules

### Supported Display Managers

The install script auto-detects and configures:
- **LightDM** (Kali, Raspberry Pi OS, Xubuntu)
- **GDM** (GNOME/Ubuntu)
- **SDDM** (KDE)
- **LXDM**, **XDM**

And screen lockers:
- XScreenSaver
- light-locker
- i3lock
- GNOME Screensaver

## After Installation

1. **Restart your display manager or reboot**

   ```bash
   sudo systemctl restart lightdm
   # or
   sudo reboot
   ```

2. **Verify installation**

   ```bash
   ./test-pam-setup.sh
   ```

## How It Works

1. iPhone app sends signed authentication via BLE
2. Server verifies signature against registered public keys
3. Server writes a trigger file to `/tmp/cyberdeck-login-trigger`
4. PAM module detects trigger file and allows passwordless login
5. Server also calls `loginctl unlock-sessions` for immediate unlock

## Files Installed

| File | Location | Purpose |
|------|----------|---------|
| `cyberdeck-auth` | `/usr/local/bin/` | PAM authentication script |
| `cyberdeck-pam-helper` | `/usr/local/bin/` | Session unlock helper |
| `cyberdeck-login` | `/etc/pam.d/` | PAM configuration |
| `cyberdeck-login` | `/etc/sudoers.d/` | Passwordless sudo rules |
| `50-cyberdeck-login.rules` | `/etc/polkit-1/rules.d/` | Polkit rules for session unlock |

## Uninstall

```bash
sudo rm /usr/local/bin/cyberdeck-auth
sudo rm /usr/local/bin/cyberdeck-pam-helper
sudo rm /etc/pam.d/cyberdeck-login
sudo rm /etc/sudoers.d/cyberdeck-login
sudo rm /etc/polkit-1/rules.d/50-cyberdeck-login.rules
```

You'll also need to manually remove the PAM line from your display manager config (e.g., `/etc/pam.d/lightdm`).

## Security Considerations

⚠️ **Important**: This bypasses normal password authentication.

- **Physical security**: Only deploy on devices in secure locations
- **BLE range**: Bluetooth has ~10m range - proximity provides some security
- **Key protection**: Protect the private key on your iPhone
- **Trigger file**: Created with mode 600 and 10-second validity window
- **Registration**: Keys must be manually approved by copying to `registered/` folder

---

## Appendix: Manual Configuration

If the install script doesn't work for your setup, you can configure PAM manually.

### Manual PAM Configuration

Add this line to your display manager's PAM file (before other auth lines):

```
auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth
```

**PAM file locations by display manager:**

| Display Manager | PAM File |
|-----------------|----------|
| LightDM | `/etc/pam.d/lightdm` |
| GDM | `/etc/pam.d/gdm-password` |
| SDDM | `/etc/pam.d/sddm` |
| XDM | `/etc/pam.d/xdm` |
| LXDM | `/etc/pam.d/lxdm` |
| Console | `/etc/pam.d/login` |

### Alternative: Using pam_exec Directly

For systems that support `pam_exec`:

1. Copy the auth script:
   ```bash
   sudo cp cyberdeck-auth.sh /usr/local/bin/cyberdeck-auth
   sudo chmod 755 /usr/local/bin/cyberdeck-auth
   ```

2. Add to your display manager's PAM file:
   ```
   auth sufficient pam_exec.so quiet /usr/local/bin/cyberdeck-auth
   ```

### Alternative: Using loginctl Only

For systems using systemd-logind, the server can unlock sessions directly without PAM configuration:

1. Create polkit rule `/etc/polkit-1/rules.d/50-cyberdeck-login.rules`:
   ```javascript
   polkit.addRule(function(action, subject) {
       if (action.id == "org.freedesktop.login1.lock-sessions" ||
           action.id == "org.freedesktop.login1.unlock-sessions") {
           if (subject.user == "your-username") {
               return polkit.Result.YES;
           }
       }
   });
   ```

2. The server will call `loginctl unlock-sessions` on successful auth.

Note: This method only works for unlocking, not for initial login.

### Manual Sudoers Configuration

Create `/etc/sudoers.d/cyberdeck-login`:

```
your-username ALL=(ALL) NOPASSWD: /usr/local/bin/cyberdeck-pam-helper
your-username ALL=(ALL) NOPASSWD: /usr/bin/loginctl unlock-sessions
```

Set permissions:
```bash
sudo chmod 440 /etc/sudoers.d/cyberdeck-login
```

### Testing PAM Manually

```bash
# Create test trigger
echo '{"user":"your-username","timestamp":'$(date +%s)'000,"action":"unlock"}' > /tmp/cyberdeck-login-trigger

# Test auth script
PAM_USER=your-username /usr/local/bin/cyberdeck-auth && echo "Success" || echo "Failed"
```

### Debugging

Check PAM logs:
```bash
sudo journalctl -u lightdm -f
# or
sudo tail -f /var/log/auth.log
```

Enable verbose PAM logging by changing `quiet` to `debug` in the PAM line:
```
auth sufficient pam_exec.so debug /usr/local/bin/cyberdeck-auth
```