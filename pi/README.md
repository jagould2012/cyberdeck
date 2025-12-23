### Pi Setup

* Download a Kali Linux image and flash to SD card with Raspi Imager
* Boot the Raspberry Pi
* Add the following to the /boot/firmware/config.txt

```
dtoverlay=gpio-fan
dtparam=pciex1
dtoverlay=rpi-5-pcie
```

* Reboot
* Install the rpi-imager

```
wget http://archive.raspberrypi.org/debian/pool/main/r/rpi-imager/rpi-imager_2.0.1_arm64.deb
sudo dpkg -i rpi-imager_2.0.1_arm64.deb
sudo rpi-imager &
```

* Use the rpi-imager to install Kali Linux to the nvme drive
* Remove the SD card and reboot


### Install Docker

```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker kali
```

### Kernel (Optional)

The default kernel that ships with Kali images for Raspberry Pi uses a page size of 16Kb. You can check this by running:

```
getconf PAGESIZE
```

For many applications this is fine, but some software is built around a standard of 4Kb page sizes (for example, many node modules like Sharp - see bbs project in this repo). 

The [kernel](./kernel) contains a Dockerfile and scripts to create a build of the standard Raspberry Pi 5 Kali kernel, with one modification, setting the page size to 4Kb.

This will affect system performance and should only be considered to make legacy software function correctly.