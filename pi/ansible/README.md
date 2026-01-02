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

3. **Configure BBS locally first** (if deploying Synchronet BBS):
   ```bash
   cd ../bbs
   ./install.sh           # Configure BBS (interactive - set up name, settings)
   ./update-msg-colors.sh # Apply Cyberdeck grayscale theme
   ./copy-ans.sh          # Copy ANSI art to text/
   ```

4. **Build and export BBS Docker image** (required before deployment):
   ```bash
   cd ../bbs
   docker compose build
   docker save bbs-synchronet:latest | gzip > bbs-synchronet.tar.gz
   ```
   This builds the amd64 image locally (much faster than building under QEMU on ARM) and exports it for distribution to target hosts. The resulting file is ~300-500MB.

   The ansible playbook copies the pre-configured `ctrl/`, `text/`, and `xtrn/` directories plus the Docker image to the target hosts.

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
   # Just the test VM (include localhost for BBS tarball creation)
   ansible-playbook site.yml --limit "localhost,test-vm" -K

   # Just physical Pis
   ansible-playbook site.yml --limit "localhost,pi" -K

   # Single host
   ansible-playbook site.yml --limit "localhost,cyberdeck-pi1" -K
   ```

## Directory Structure

```
project/
├── bbs/                     # Synchronet BBS (configure locally first)
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── install.sh           # Run first - interactive setup
│   ├── update-msg-colors.sh # Run second - apply theme
│   ├── copy-ans.sh          # Run third - copy ANSI art
│   ├── bbs-synchronet.tar.gz # Docker image (created by docker save)
│   ├── ctrl/                # Generated config (after install.sh)
│   ├── text/                # ANSI screens and menus
│   └── xtrn/                # External programs/doors
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

# Portainer (Docker web UI)
ansible-playbook playbooks/portainer.yml -K

# SDR software
ansible-playbook playbooks/sdr-base.yml -K
ansible-playbook playbooks/sdrpp.yml -K
ansible-playbook playbooks/urh.yml -K
ansible-playbook playbooks/sdrangel.yml -K

# Custom menu categories
ansible-playbook playbooks/menu.yml -K

# Synchronet BBS (requires local setup first - see Prerequisites)
# NOTE: Must include localhost in limit for tarball creation
ansible-playbook playbooks/bbs.yml -K --limit "localhost,test-vm"
ansible-playbook playbooks/bbs.yml -K --limit "localhost,pi"
ansible-playbook playbooks/bbs.yml -K  # All hosts

# Reboot hosts
ansible-playbook playbooks/reboot.yml --limit test-vm
```

### BBS Deployment Note

The BBS deployment requires two things before running the playbook:

1. **Configure the BBS locally** (interactive setup):
   ```bash
   cd ../bbs
   ./install.sh           # Configure BBS settings
   ./update-msg-colors.sh # Apply Cyberdeck theme
   ./copy-ans.sh          # Copy ANSI art
   ```

2. **Build and export the Docker image**:
   ```bash
   cd ../bbs
   docker compose build
   docker save bbs-synchronet:latest | gzip > bbs-synchronet.tar.gz
   ```

The `bbs.yml` playbook requires `localhost` to be included in the limit because it creates a tarball locally before copying to remote hosts. Always use one of these patterns:

```bash
# Deploy to specific host (include localhost)
ansible-playbook playbooks/bbs.yml -K --limit "localhost,test-vm"

# Deploy to all Pis (include localhost)
ansible-playbook playbooks/bbs.yml -K --limit "localhost,pi"

# Deploy to all hosts (no limit needed)
ansible-playbook playbooks/bbs.yml -K
```

**Why pre-build the image?** The BBS runs in an amd64 container (for Synchronet compatibility). Building under QEMU emulation on ARM hosts takes 30-60+ minutes. Pre-building on your Mac/x86 machine takes ~5 minutes and the image is distributed to all hosts.

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
| Portainer | all | Docker web UI at https://localhost:9443 |
| SDR Base | all | Dependencies, udev rules for RTL-SDR/HackRF/Airspy |
| SDR++ | all | SDR receiver software |
| URH | all | Protocol analyzer |
| SDRAngel | all | Full-featured SDR suite (requires `.deb`) |
| Menu | all | Custom Kali menu categories (17-SDR, 18-Docker) |
| BBS | pi1, test-vm | Synchronet BBS (container runs); pi2 staged only |

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