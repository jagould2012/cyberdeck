# Kali Linux Kernel Builder for Raspberry Pi 5 (4KB Pages)

This Dockerfile creates a build environment for compiling the Kali Linux kernel with
the Raspberry Pi 5 configuration, modified to use **4KB page size** instead of the
default 16KB page size.

## Why 4KB Page Size?

The Raspberry Pi 5 (BCM2712) kernel defaults to 16KB pages for improved performance
in certain workloads. However, some software and use cases require or benefit from
4KB pages:

- Better memory efficiency for applications with small allocations
- Compatibility with software that assumes 4KB pages
- Reduced memory fragmentation in some scenarios
- Required for certain virtualization and container workloads

## Prerequisites

- Docker installed on your Mac M4 (or other ARM64 system)
- At least 20GB of free disk space
- Internet connection for downloading kernel source

## Quick Start

### 1. Build the Docker image

```bash
docker build -t kali-rpi5-kernel .
```

This will:
- Pull the latest Kali Linux rolling release
- Install all kernel build dependencies
- Clone the Raspberry Pi Linux kernel source (rpi-6.6.y branch)
- Apply the bcm2712_defconfig (Raspberry Pi 5)
- Modify the config to use 4KB pages

### 2. Build the kernel

```bash
mkdir -p output
docker run -it --rm -v $(pwd)/output:/output kali-rpi5-kernel /build/build-kernel.sh
```

This will compile the kernel and copy the artifacts to `./output/`:
- `boot/kernel8-4k.img` - The kernel image
- `boot/*.dtb` - Device tree blobs
- `boot/overlays/` - Device tree overlays
- `modules/lib/modules/<version>/` - Kernel modules
- `kernel-config-4k` - The kernel configuration used

### 3. Install on Raspberry Pi 5

1. Copy the kernel and DTBs:
   ```bash
   sudo cp output/boot/kernel8-4k.img /boot/firmware/
   sudo cp output/boot/*.dtb /boot/firmware/
   sudo cp -r output/boot/overlays/* /boot/firmware/overlays/
   ```

2. Install the modules:
   ```bash
   sudo cp -r output/modules/lib/modules/* /lib/modules/
   sudo depmod -a
   ```

3. Configure boot to use the new kernel:
   ```bash
   echo "kernel=kernel8-4k.img" | sudo tee -a /boot/firmware/config.txt
   ```

4. Reboot:
   ```bash
   sudo reboot
   ```

5. Verify after reboot:
   ```bash
   uname -r  # Should show the new kernel version with -v8-4k-kali suffix
   getconf PAGESIZE  # Should return 4096 (4KB)
   ```

## Additional Commands

### View current configuration
```bash
docker run -it --rm kali-rpi5-kernel /build/show-config.sh
```

### Interactive shell
```bash
docker run -it --rm kali-rpi5-kernel bash
```

### Run menuconfig for additional customization
```bash
docker run -it --rm -v $(pwd)/output:/output kali-rpi5-kernel \
    bash -c "cd /build/linux && make menuconfig && /build/build-kernel.sh"
```

### Use a different kernel branch
```bash
docker build --build-arg KERNEL_BRANCH=rpi-6.12.y -t kali-rpi5-kernel .
```

## Configuration Changes

The only modification made to the stock `bcm2712_defconfig` is:

| Setting | Original | Modified |
|---------|----------|----------|
| `CONFIG_ARM64_16K_PAGES` | `y` | not set |
| `CONFIG_ARM64_4K_PAGES` | not set | `y` |
| `CONFIG_LOCALVERSION` | `"-v8-16k"` | `"-v8-4k-kali"` |

## Build Time

On a Mac M4:
- Docker image build: ~5-10 minutes
- Kernel compilation: ~15-30 minutes (depending on CPU cores)

## Troubleshooting

### Build fails with out of memory
Increase Docker's memory allocation in Docker Desktop settings.

### Modules don't load after installation
Run `sudo depmod -a` and ensure the module directory name matches `uname -r`.

### Kernel panic on boot
The 4KB page size kernel may not be compatible with all Raspberry Pi 5 
configurations. You can revert by removing `kernel=kernel8-4k.img` from 
`/boot/firmware/config.txt` (edit the SD card on another computer if needed).

## References

- [Raspberry Pi Linux Kernel](https://github.com/raspberrypi/linux)
- [Kali ARM Build Scripts](https://gitlab.com/kalilinux/build-scripts/kali-arm)
- [Raspberry Pi Kernel Documentation](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)