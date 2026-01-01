# Ansible Raspberry Pi Setup

Ansible playbooks for automating Raspberry Pi Kali Linux setup and configuration.

## Prerequisites

### On your control machine (Mac/Linux):

1. Install Ansible:
   ```bash
   # macOS
   brew install ansible
   
   # Ubuntu/Debian
   sudo apt install ansible
   
   # pip
   pip install ansible
   ```

2. Copy your SSH key to the Pi:
   ```bash
   ssh-copy-id kali@<pi-ip-address>
   ```

### On the Raspberry Pi:

- Kali Linux installed on NVMe drive (per README instructions)
- SSH enabled and accessible
- Network connectivity

## Quick Start

1. Clone/copy this directory to your control machine

2. Copy SSH keys to the Pis:
   ```bash
   ssh-copy-id kali@cyberdeck-pi1.local
   ssh-copy-id kali@cyberdeck-pi2.local
   ```

3. Test connectivity:
   ```bash
   ansible all -m ping
   ```

4. Run the full setup on both hosts:
   ```bash
   ansible-playbook site.yml
   ```

   Or run on a specific host:
   ```bash
   ansible-playbook site.yml --limit cyberdeck-pi1
   ```

## Test VM

A test VM is included to validate configurations before deploying to real hardware.

### Setup Test VM

1. Update `inventory.yml` with your VM's IP:
   ```yaml
   test-vm:
     ansible_host: 192.168.1.200
   ```

2. Copy SSH key:
   ```bash
   ssh-copy-id kali@<vm-ip>
   ```

### Test with Pi1 Configuration
```bash
ansible-playbook playbooks/test-vm.yml -e "test_config=pi1"
```

### Test with Pi2 Configuration
```bash
ansible-playbook playbooks/test-vm.yml -e "test_config=pi2"
```

The test VM automatically:
- Loads the selected Pi's configuration (MAC address, custom settings)
- Skips hardware-specific tasks (HDMI, fan) since `is_vm: true`
- Runs all other setup tasks normally

## Project Structure

```
ansible-pi-setup/
├── ansible.cfg              # Ansible configuration
├── inventory.yml            # Host inventory (pi1, pi2, test-vm)
├── site.yml                 # Main playbook (runs all)
├── group_vars/
│   ├── all.yml              # Variables for all hosts
│   ├── pi1_config.yml       # Pi1-specific configuration
│   ├── pi2_config.yml       # Pi2-specific configuration
│   └── test_vms.yml         # Test VM settings (is_vm: true)
├── host_vars/
│   └── test-vm.yml          # Test VM host variables
├── playbooks/
│   ├── boot-config.yml      # HDMI, fan, sleep settings
│   ├── network-setup.yml    # NetworkManager & mDNS
│   ├── ssh-hostkeys.yml     # Regenerate SSH keys
│   ├── disable-sleep.yml    # Mask sleep targets
│   ├── docker-install.yml   # Install Docker CE
│   ├── wifi-mac-override.yml # Override WiFi MAC
│   ├── reboot.yml           # Reboot utility
│   └── test-vm.yml          # Test VM with pi1/pi2 config
├── templates/               # Jinja2 templates (if needed)
└── files/                   # Static files (if needed)
```

## Configuration Groups

The inventory uses configuration groups to manage Pi-specific settings:

| Group | Hosts | Configuration |
|-------|-------|---------------|
| `pi1_config` | cyberdeck-pi1 | Original WiFi MAC |
| `pi2_config` | cyberdeck-pi2 | Alternate WiFi MAC |
| `test_vms` | test-vm | VM mode (skips hardware tasks) |

Add host-specific settings to `group_vars/pi1_config.yml` or `group_vars/pi2_config.yml`.

## Individual Playbooks

Run specific playbooks as needed:

### Boot Configuration
Configures HDMI hotplug, fan control, and disables console blanking.
```bash
ansible-playbook playbooks/boot-config.yml
```

### Network Setup
Cleans up conflicting network services, configures NetworkManager, and enables mDNS.
```bash
ansible-playbook playbooks/network-setup.yml
```

### SSH Host Keys
Regenerates SSH host keys (useful when cloning SD cards).
```bash
ansible-playbook playbooks/ssh-hostkeys.yml
```
> ⚠️ After running, update your local `~/.ssh/known_hosts`:
> ```bash
> ssh-keygen -R <pi-ip-address>
> ```

### Disable Sleep
Masks all sleep/suspend/hibernate targets.
```bash
ansible-playbook playbooks/disable-sleep.yml
```

### Docker Installation
Installs Docker CE with compose plugin.
```bash
ansible-playbook playbooks/docker-install.yml
```
> After installation, log out and back in for docker group membership to take effect.

### WiFi MAC Override
Use when two Pis have the same WiFi MAC address.
```bash
ansible-playbook playbooks/wifi-mac-override.yml -e "wifi_mac_override=AA:BB:CC:DD:EE:FF"
```

Or define per-host in `host_vars/pi2.yml`:
```yaml
wifi_mac_override: "AA:BB:CC:DD:EE:FF"
```

### Reboot
Safely reboots and waits for hosts to come back online.
```bash
ansible-playbook playbooks/reboot.yml
```

## Running on Specific Hosts

```bash
# All production Pis (excludes test-vm)
ansible-playbook site.yml

# Single Pi
ansible-playbook site.yml --limit cyberdeck-pi1

# Test VM with specific config
ansible-playbook playbooks/test-vm.yml -e "test_config=pi2"

# All hosts including test-vm (careful!)
ansible-playbook site.yml --limit "raspberry_pis:test_vms"
```

## Customization

### Adding Docker Users

Edit `group_vars/all.yml`:
```yaml
docker_users:
  - kali
  - another_user
```

### Changing Default User

Edit `inventory.yml`:
```yaml
vars:
  ansible_user: kali  # Change to your username
```

## Troubleshooting

### Connection Issues
```bash
# Test SSH connection
ssh kali@<pi-ip>

# Test Ansible connectivity
ansible all -m ping -vvv
```

### Check Playbook Syntax
```bash
ansible-playbook site.yml --syntax-check
```

### Dry Run
```bash
ansible-playbook site.yml --check --diff
```

### Verbose Output
```bash
ansible-playbook site.yml -vvv
```

## What Gets Configured

| Component | Configuration |
|-----------|--------------|
| HDMI | Force hotplug, disable blanking |
| Fan | GPIO fan overlay enabled |
| USB | Max current enabled |
| Sleep | All sleep targets masked |
| Console | Blanking disabled (kernel cmdline) |
| Network | NetworkManager as renderer |
| mDNS | Avahi daemon enabled |
| SSH | New host keys generated |
| Docker | CE + Compose plugin installed |

## Notes

- The playbooks are idempotent - safe to run multiple times
- A reboot is required after boot configuration changes
- SSH keys regeneration will require updating your `known_hosts`
- Docker group membership requires logout/login to take effect
