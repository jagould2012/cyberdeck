# Ansible Raspberry Pi Setup

Ansible playbooks for automating Raspberry Pi Kali Linux setup and configuration, including SDR software.

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

2. **Build SDRAngel package first** (if you want SDRAngel):
   ```bash
   cd ../sdrangel
   ./build.sh
   ```
   This builds the arm64 `.deb` on your Mac and copies it to `ansible/files/`. See `../sdrangel/README.md` for details.

### On target hosts:

1. Ensure SSH is enabled. If not, connect via console and run:
   ```bash
   sudo apt update
   sudo apt install -y openssh-server
   sudo systemctl enable ssh
   sudo systemctl start ssh
   ```

2. Copy SSH keys from your control machine:
   ```bash
   ssh-copy-id jonathan@cyberdeck-pi1.local
   ssh-copy-id jonathan@cyberdeck-pi2.local
   ssh-copy-id parallels@10.211.55.5
   ```

## Quick Start

1. Test connectivity:
   ```bash
   ansible all -m ping
   ```

2. Run the full setup on all hosts:
   ```bash
   ansible-playbook site.yml -K
   ```

3. Or run on specific hosts:
   ```bash
   # Just the test VM
   ansible-playbook site.yml --limit test-vm -K

   # Just physical Pis
   ansible-playbook site.yml --limit pi

   # Single host
   ansible-playbook site.yml --limit cyberdeck-pi1
   ```

## Directory Structure

```
project/
├── sdrangel/                # SDRAngel .deb builder (run this first)
│   ├── Dockerfile
│   ├── build.sh
│   └── README.md
└── ansible/                 # This directory
    ├── ansible.cfg
    ├── inventory.yml
    ├── site.yml
    ├── files/
    │   └── sdrangel_arm64.deb  # Created by ../sdrangel/build.sh
    ├── group_vars/
    ├── host_vars/
    └── playbooks/
```

## Sudo Password

If a host requires a sudo password, add `-K` (or `--ask-become-pass`):
```bash
ansible-playbook site.yml -K
```

To configure passwordless sudo on a host, connect via SSH and run:
```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

## Inventory Groups

| Group | Description | Hosts |
|-------|-------------|-------|
| `raspberry_pis` | All hosts | cyberdeck-pi1, cyberdeck-pi2, test-vm |
| `pi` | Physical Raspberry Pis | cyberdeck-pi1, cyberdeck-pi2 |
| `vm` | Virtual machines | test-vm |

Hardware-specific tasks (HDMI, fan, boot config) only run on the `pi` group.

## Hosts

| Host | Group | User | Hostname | Notes |
|------|-------|------|----------|-------|
| cyberdeck-pi1 | pi | jonathan | cyberdeck-pi1 | |
| cyberdeck-pi2 | pi | jonathan | cyberdeck-pi2 | WiFi MAC override |
| test-vm | vm | parallels | cyberdeck-testvm | Skips hardware tasks |

## SDR Software

| Software | Install Method | Notes |
|----------|----------------|-------|
| SDR++ | Prebuilt `.deb` from GitHub | Fast install |
| URH | pip install | Universal Radio Hacker |
| SDRAngel | Local `.deb` from `../sdrangel/` | Build on Mac first |

## Individual Playbooks

Run specific playbooks as needed:

```bash
# Boot configuration (pi group only)
ansible-playbook playbooks/boot-config.yml

# Network setup
ansible-playbook playbooks/network-setup.yml

# Set hostname
ansible-playbook playbooks/hostname.yml

# Docker installation
ansible-playbook playbooks/docker-install.yml -K

# SDR software
ansible-playbook playbooks/sdr-base.yml -K
ansible-playbook playbooks/sdrpp.yml -K
ansible-playbook playbooks/urh.yml -K
ansible-playbook playbooks/sdrangel.yml -K

# Reboot hosts
ansible-playbook playbooks/reboot.yml --limit test-vm
```

## What Gets Configured

| Component | Hosts | Description |
|-----------|-------|-------------|
| Hostname | all | Set via hostnamectl, updated in /etc/hosts |
| HDMI | pi only | Force hotplug, disable blanking |
| Fan | pi only | GPIO fan overlay enabled |
| USB | pi only | Max current enabled |
| Console | pi only | Blanking disabled (kernel cmdline) |
| Sleep | all | All sleep targets masked |
| Network | all | NetworkManager as renderer |
| mDNS | all | Avahi daemon enabled |
| SSH | all | Host keys generated if missing |
| Docker | all | CE + Compose plugin installed |
| SDR Base | all | Dependencies, udev rules for RTL-SDR/HackRF/Airspy |
| SDR++ | all | SDR receiver software |
| URH | all | Protocol analyzer |
| SDRAngel | all | Full-featured SDR suite (requires `.deb`) |

## Customization

### Adding a new host

Edit `inventory.yml` and add to the appropriate group:

```yaml
pi:
  hosts:
    cyberdeck-pi3:
      ansible_host: cyberdeck-pi3.local
      custom_hostname: cyberdeck-pi3
```

### Adding a WiFi MAC override

Add `wifi_mac_override` to the host in `inventory.yml`:

```yaml
cyberdeck-pi2:
  ansible_host: cyberdeck-pi2.local
  custom_hostname: cyberdeck-pi2
  wifi_mac_override: "DE:AD:BE:EF:CA:FE"
```

## Troubleshooting

### Connection Issues
```bash
# Test SSH connection
ssh jonathan@cyberdeck-pi1.local

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

### SDRAngel not installing
Make sure you built the `.deb` first:
```bash
cd ../sdrangel
./build.sh
```

## Notes

- Playbooks are idempotent - safe to run multiple times
- SSH keys only generated if they don't exist
- Docker group membership requires logout/login to take effect
- A reboot may be required after boot configuration changes on Pis
- SDRAngel requires building the `.deb` first (see `../sdrangel/README.md`)