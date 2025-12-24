### Pi Setup

* Download a Kali Linux image and flash to SD card with Raspi Imager
* Boot the Raspberry Pi
* Install the rpi-imager

```
wget http://archive.raspberrypi.org/debian/pool/main/r/rpi-imager/rpi-imager_2.0.1_arm64.deb
sudo dpkg -i rpi-imager_2.0.1_arm64.deb
sudo rpi-imager &
```

* Use the rpi-imager to install Kali Linux to the nvme drive
* Remove the SD card and reboot
* Run the following to set default in the config.txt

```
# Prevent GPU/system from sleeping when HDMI unplugged
CONFIG_FILE="/boot/firmware/config.txt"
[ ! -f "$CONFIG_FILE" ] && CONFIG_FILE="/boot/config.txt"

# Add HDMI hotplug force settings and fan
echo "
# Keep system awake without monitor
hdmi_force_hotplug=1
hdmi_blanking=0

# Enable fan
dtoverlay=gpio-fan" | sudo tee -a "$CONFIG_FILE"

# Disable any suspend/sleep targets
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Disable console blanking (add to kernel cmdline)
CMDLINE_FILE="/boot/firmware/cmdline.txt"
[ ! -f "$CMDLINE_FILE" ] && CMDLINE_FILE="/boot/cmdline.txt"

# Add consoleblank=0 if not already present
if ! grep -q "consoleblank=0" "$CMDLINE_FILE"; then
    sudo sed -i 's/$/ consoleblank=0/' "$CMDLINE_FILE"
fi

# Reboot
sudo reboot
```

* Fix the WiFi MAC if two boards have the same address (on one device)

```
echo '[connection]
wifi.cloned-mac-address=<alternate mac>' | sudo tee -a /etc/NetworkManager/NetworkManager.conf && sudo systemctl restart NetworkManager
```


### Other Setup

* Cleanup network managers and make sure mDNS works:

```
# Stop and disable conflicting services
sudo systemctl disable --now netplan-wpa-wlan0.service
sudo systemctl mask netplan-wpa-wlan0.service
sudo systemctl disable --now systemd-networkd
sudo systemctl mask systemd-networkd
sudo systemctl disable --now systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service
sudo systemctl disable --now NetworkManager-wait-online.service

# Backup and remove existing netplan configs
sudo mkdir -p /etc/netplan/backup
sudo mv /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null

# Create NetworkManager netplan config
echo "network:
  version: 2
  renderer: NetworkManager" | sudo tee /etc/netplan/01-networkmanager.yaml

# Apply netplan
sudo netplan generate

# Ensure NetworkManager is enabled
sudo systemctl unmask NetworkManager
sudo systemctl enable NetworkManager

# Enable avahi-daemon
sudo systemctl unmask avahi-daemon
sudo systemctl enable avahi-daemon

# Remove old host keys
sudo rm /etc/ssh/ssh_host_*

# Regenerate new unique keys
sudo dpkg-reconfigure openssh-server

# Restart SSH
sudo systemctl restart ssh

# Reboot
sudo reboot
```

* Edit `/etc/NetworkManager/NetworkManager.conf` and set `managed=true`

```
sudo systemctl restart NetworkManager
```

* Enable mDNS / Avahi

```
sudo systemctl enable avahi-daemon.service
sudo systemctl start avahi-daemon.service
```

* Install ssh key (from MacOS)

```
ssh-copy-id <ip>
```

* Disable sleep modes

```
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo reboot
```

* Install Docker

```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker jonathan
```

### Kernel (Optional)

The default kernel that ships with Kali images for Raspberry Pi uses a page size of 16Kb. You can check this by running:

```
getconf PAGESIZE
```

For many applications this is fine, but some software is built around a standard of 4Kb page sizes (for example, many node modules like Sharp - see bbs project in this repo). 

The [kernel](./kernel) contains a Dockerfile and scripts to create a build of the standard Raspberry Pi 5 Kali kernel, with one modification, setting the page size to 4Kb.

This will affect system performance and should only be considered to make legacy software function correctly.