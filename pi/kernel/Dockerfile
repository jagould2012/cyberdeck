# Dockerfile for building Kali Linux kernel with Raspberry Pi 5 config
# Modified to use 4KB page size instead of 16KB
# 
# Build: docker build -t kali-rpi5-kernel .
# Run:   docker run -it --rm -v $(pwd)/output:/output kali-rpi5-kernel
#
# This is intended for native ARM64 builds (e.g., Mac M4)
# No cross-compilation needed

FROM kalilinux/kali-rolling:latest

LABEL maintainer="Custom Kali RPi5 Kernel Builder"
LABEL description="Builds Kali Linux kernel with RPi5 config using 4KB page size"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install kernel build dependencies
RUN apt-get update && apt-get install -y \
    git \
    bc \
    bison \
    flex \
    libssl-dev \
    make \
    libc6-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libelf-dev \
    gcc \
    g++ \
    rsync \
    kmod \
    cpio \
    xz-utils \
    zstd \
    pahole \
    debhelper \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Clone the Raspberry Pi Linux kernel source (latest stable branch)
# Using rpi-6.6.y as it's the current LTS branch used by Kali
ARG KERNEL_BRANCH=rpi-6.6.y
RUN git clone --depth 1 --branch ${KERNEL_BRANCH} \
    https://github.com/raspberrypi/linux.git /build/linux

WORKDIR /build/linux

# Set architecture for native ARM64 build
ENV ARCH=arm64

# Generate the base bcm2712 (Raspberry Pi 5) defconfig
RUN make bcm2712_defconfig

# Modify the config to use 4KB pages instead of 16KB
# This is the key change requested - swap 16K pages for 4K pages
RUN sed -i 's/CONFIG_ARM64_16K_PAGES=y/# CONFIG_ARM64_16K_PAGES is not set/' .config && \
    sed -i '/# CONFIG_ARM64_4K_PAGES is not set/d' .config && \
    sed -i '/# CONFIG_ARM64_16K_PAGES is not set/a CONFIG_ARM64_4K_PAGES=y' .config

# Update the local version to indicate this is a 4K page kernel
RUN sed -i 's/CONFIG_LOCALVERSION="-v8-16k"/CONFIG_LOCALVERSION="-v8-4k-kali"/' .config

# Run olddefconfig to resolve any dependencies from the page size change
RUN make olddefconfig

# Verify the page size configuration
RUN echo "=== Verifying Page Size Configuration ===" && \
    grep -E "(ARM64_4K_PAGES|ARM64_16K_PAGES|ARM64_64K_PAGES)" .config && \
    echo "=== Configuration verified ==="

# Create build script that will be run inside the container
RUN cat > /build/build-kernel.sh << 'EOF'
#!/bin/bash
set -e

echo "=========================================="
echo "Kali Linux Kernel Build for Raspberry Pi 5"
echo "Modified: 4KB Page Size (instead of 16KB)"
echo "=========================================="
echo ""

cd /build/linux

# Get number of CPU cores for parallel build
NPROCS=$(nproc)
echo "Building with ${NPROCS} parallel jobs..."

# Build the kernel image, modules, and device tree blobs
echo "Building kernel image..."
make -j${NPROCS} Image.gz

echo "Building kernel modules..."
make -j${NPROCS} modules

echo "Building device tree blobs..."
make -j${NPROCS} dtbs

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

# If /output directory exists (mounted volume), copy artifacts there
if [ -d "/output" ]; then
    echo "Copying build artifacts to /output..."
    
    mkdir -p /output/boot/overlays
    mkdir -p /output/modules
    
    # Copy kernel image
    cp arch/arm64/boot/Image.gz /output/boot/kernel8-4k.img
    
    # Copy device tree blobs
    cp arch/arm64/boot/dts/broadcom/*.dtb /output/boot/
    cp arch/arm64/boot/dts/overlays/*.dtb* /output/boot/overlays/ 2>/dev/null || true
    cp arch/arm64/boot/dts/overlays/README /output/boot/overlays/ 2>/dev/null || true
    
    # Install modules to output directory
    make INSTALL_MOD_PATH=/output/modules modules_install
    
    # Copy the config for reference
    cp .config /output/kernel-config-4k
    
    echo ""
    echo "Artifacts copied to /output:"
    echo "  - /output/boot/kernel8-4k.img (kernel image)"
    echo "  - /output/boot/*.dtb (device tree blobs)"
    echo "  - /output/boot/overlays/ (device tree overlays)"
    echo "  - /output/modules/ (kernel modules)"
    echo "  - /output/kernel-config-4k (kernel config)"
    echo ""
    echo "To use on your Raspberry Pi 5:"
    echo "  1. Copy boot/* to /boot/firmware/ on your Pi"
    echo "  2. Copy modules/lib/modules/* to /lib/modules/ on your Pi"
    echo "  3. Add 'kernel=kernel8-4k.img' to /boot/firmware/config.txt"
    echo "  4. Reboot"
fi

echo ""
echo "Build completed successfully!"
EOF

RUN chmod +x /build/build-kernel.sh

# Create a script to show current config (useful for debugging)
RUN cat > /build/show-config.sh << 'EOF'
#!/bin/bash
echo "=== Current Kernel Configuration (Page Size Related) ==="
cd /build/linux
grep -E "(ARM64_4K_PAGES|ARM64_16K_PAGES|ARM64_64K_PAGES|LOCALVERSION)" .config
echo ""
echo "=== Full config available at: /build/linux/.config ==="
EOF

RUN chmod +x /build/show-config.sh

# Default command - show help
CMD echo "Kali RPi5 Kernel Builder (4KB Page Size)" && \
    echo "" && \
    echo "Commands:" && \
    echo "  docker run -it --rm -v \$(pwd)/output:/output <image> /build/build-kernel.sh" && \
    echo "    - Build the kernel and copy artifacts to ./output" && \
    echo "" && \
    echo "  docker run -it --rm <image> /build/show-config.sh" && \
    echo "    - Show current kernel configuration" && \
    echo "" && \
    echo "  docker run -it --rm <image> bash" && \
    echo "    - Interactive shell for manual operations" && \
    echo "" && \
    echo "  docker run -it --rm <image> make -C /build/linux menuconfig" && \
    echo "    - Run menuconfig for additional customization" && \
    echo "" && \
    /build/show-config.sh