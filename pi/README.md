# Cyberdeck Raspberry Pi Setup

Automated setup for Raspberry Pi devices running Kali Linux with SDR software stack, Docker, and Synchronet BBS.

## Quick Start

### 1. Flash Kali Linux

1. Download a Kali Linux ARM64 image
2. Flash to SD card with Raspberry Pi Imager
3. Boot the Raspberry Pi
4. (Optional) Install to NVMe:
   ```bash
   wget http://archive.raspberrypi.org/debian/pool/main/r/rpi-imager/rpi-imager_2.0.1_arm64.deb
   sudo dpkg -i rpi-imager_2.0.1_arm64.deb
   sudo rpi-imager &
   ```
5. Use rpi-imager to install Kali Linux to the NVMe drive
6. Remove the SD card and reboot

Recommended at this point to install available updates:

```
sudo apt-get update && sudo apt upgrade -y && sudo apt dist-upgrade -y && sudo reboot
```

### 2. Initial Network Setup

Before running Ansible, ensure the Pi is accessible:

```bash
# Install your SSH key (from Mac/controller)
ssh-copy-id kali@<pi-ip-address>
```

### 3. Run Ansible Playbooks

From the `ansible/` directory on your controller machine:

```bash
# Install dependencies
ansible-galaxy collection install -r requirements.yml

# Run full setup on all hosts
ansible-playbook site.yml -K

# Or target specific hosts (include localhost for BBS deployment)
ansible-playbook site.yml -K --limit "localhost,cyberdeck-pi1"

# Or run individual playbooks
ansible-playbook playbooks/docker-install.yml -K --limit cyberdeck-pi1
```

## What Gets Installed

The Ansible playbooks configure:

- **System Configuration**
  - Boot config (HDMI hotplug, fan control, USB power)
  - Custom hostname
  - WiFi MAC override (for duplicate MAC issues)
  - SSH host key regeneration
  - Sleep/suspend disabled

- **Networking**
  - NetworkManager as primary network manager
  - mDNS/Avahi for `.local` hostname resolution
  - Conflicting services disabled (netplan, systemd-networkd)

- **Docker**
  - Docker CE with compose plugin
  - QEMU user-mode emulation for cross-architecture containers
  - Portainer web UI

- **SDR Software**
  - SDR++ (sdrpp)
  - Universal Radio Hacker (urh)
  - SDRAngel (sdrangel)
  - Base SDR dependencies and udev rules

- **Synchronet BBS**
  - Pre-built Docker container
  - ARM64 native build with SpiderMonkey fix

## Directory Structure

```
pi/
├── ansible/           # Ansible playbooks and configuration
│   ├── inventory.yml  # Host definitions
│   ├── site.yml       # Main orchestration playbook
│   └── playbooks/     # Individual playbooks
├── bbs/               # Synchronet BBS Docker setup
├── sdrangel/          # SDRAngel Docker builder
└── kernel/            # Custom kernel build (optional)
```

## Inventory

Edit `ansible/inventory.yml` to configure your hosts:

```yaml
raspberry_pis:
  children:
    pi:
      hosts:
        cyberdeck-pi1:
          ansible_host: 10.0.0.100
          custom_hostname: cyberdeck-pi1
        cyberdeck-pi2:
          ansible_host: 10.0.0.101
          custom_hostname: cyberdeck-pi2
          wifi_mac_override: "AA:BB:CC:DD:EE:FF"  # Optional
```

## Custom Kernel (Optional)

The default Kali kernel for Raspberry Pi uses 16KB page sizes. Some software requires 4KB pages (e.g., certain Node.js modules like Sharp).

Check your current page size:
```bash
getconf PAGESIZE
```

If you need 4KB pages, see the `kernel/` directory for a Dockerfile that builds a custom kernel. Note: This affects system performance and should only be used when necessary.

## Troubleshooting

### Network Issues

If mDNS isn't working:

```bash
# Check avahi is running
sudo systemctl status avahi-daemon

# Check NetworkManager is managing interfaces
nmcli device status
```

## Manual Commands Reference

While Ansible handles everything, here are useful manual commands:

```bash
# Reboot a host
ansible-playbook playbooks/reboot.yml -K --limit cyberdeck-pi1

# Check BBS status
ssh cyberdeck-pi1.local "docker logs -f SynchronetBBS"

# Connect to BBS
ssh -p 10022 cyberdeck-pi1.local
```