#!/bin/bash
#
# deploy.sh - Deploy custom 4KB page size kernel to Raspberry Pi 5
#
# Usage: ./deploy.sh <user> <ip>
# Example: ./deploy.sh kali 192.168.1.100
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -ne 2 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <user> <ip>"
    echo ""
    echo "Arguments:"
    echo "  user    SSH username on the Raspberry Pi (e.g., kali, pi, root)"
    echo "  ip      IP address of the Raspberry Pi (e.g., 192.168.1.100)"
    echo ""
    echo "Example:"
    echo "  $0 kali 192.168.1.100"
    exit 1
fi

USER="$1"
IP="$2"

# SSH ControlMaster settings for connection reuse (avoids multiple password prompts)
SSH_CONTROL_PATH="/tmp/ssh-deploy-$$"
SSH_OPTS="-o ControlMaster=auto -o ControlPath=${SSH_CONTROL_PATH} -o ControlPersist=60"

# Cleanup function to close SSH control connection
cleanup() {
    ssh -o ControlPath="${SSH_CONTROL_PATH}" -O exit "${USER}@${IP}" 2>/dev/null || true
    rm -f "${SSH_CONTROL_PATH}" 2>/dev/null || true
}
trap cleanup EXIT

# Validate IP format (basic check)
if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: Invalid IP address format: ${IP}${NC}"
    exit 1
fi

# Check if output directory exists and has required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}Error: Output directory not found: ${OUTPUT_DIR}${NC}"
    echo "Please run the kernel build first."
    exit 1
fi

if [ ! -f "$OUTPUT_DIR/boot/kernel8-4k.img" ]; then
    echo -e "${RED}Error: Kernel image not found: ${OUTPUT_DIR}/boot/kernel8-4k.img${NC}"
    echo "Please run the kernel build first."
    exit 1
fi

if [ ! -d "$OUTPUT_DIR/modules/lib/modules" ]; then
    echo -e "${RED}Error: Kernel modules not found: ${OUTPUT_DIR}/modules/lib/modules${NC}"
    echo "Please run the kernel build first."
    exit 1
fi

# Get the kernel version from the modules directory
KERNEL_VERSION=$(ls "$OUTPUT_DIR/modules/lib/modules/" | head -n 1)
if [ -z "$KERNEL_VERSION" ]; then
    echo -e "${RED}Error: Could not determine kernel version from modules directory${NC}"
    exit 1
fi

echo "==========================================="
echo -e "${GREEN}Kali RPi5 Kernel Deployment (4KB Pages)${NC}"
echo "==========================================="
echo ""
echo "Target:         ${USER}@${IP}"
echo "Kernel version: ${KERNEL_VERSION}"
echo "Source:         ${OUTPUT_DIR}"
echo ""

# Test SSH connectivity (allow password prompt)
echo -e "${YELLOW}Testing SSH connectivity...${NC}"
echo "(You may be prompted for your password - you'll only need to enter it once)"
if ! ssh ${SSH_OPTS} -o ConnectTimeout=10 "${USER}@${IP}" "echo 'SSH connection successful'"; then
    echo -e "${RED}Error: Cannot connect to ${USER}@${IP}${NC}"
    echo "Please check:"
    echo "  - The Raspberry Pi is powered on and connected to the network"
    echo "  - SSH is enabled on the Raspberry Pi"
    echo "  - The username and IP address are correct"
    exit 1
fi

echo -e "${GREEN}SSH connection verified${NC}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}WARNING: This will:${NC}"
echo "  1. Copy the new kernel image to /boot/firmware/"
echo "  2. Copy device tree blobs to /boot/firmware/"
echo "  3. Copy device tree overlays to /boot/firmware/overlays/"
echo "  4. Copy kernel modules to /lib/modules/"
echo "  5. Update /boot/firmware/config.txt to use the new kernel"
echo "  6. Run depmod to update module dependencies"
echo "  7. Reboot the Raspberry Pi"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting deployment...${NC}"
echo ""

# Step 1: Copy kernel image
echo "[1/6] Copying kernel image..."
scp ${SSH_OPTS} "$OUTPUT_DIR/boot/kernel8-4k.img" "${USER}@${IP}:/tmp/"
ssh ${SSH_OPTS} "${USER}@${IP}" "sudo cp /tmp/kernel8-4k.img /boot/firmware/"

# Step 2: Copy device tree blobs
echo "[2/6] Copying device tree blobs..."
scp ${SSH_OPTS} "$OUTPUT_DIR"/boot/*.dtb "${USER}@${IP}:/tmp/"
ssh ${SSH_OPTS} "${USER}@${IP}" "sudo cp /tmp/*.dtb /boot/firmware/"

# Step 3: Copy device tree overlays
echo "[3/6] Copying device tree overlays..."
if [ -d "$OUTPUT_DIR/boot/overlays" ] && [ "$(ls -A "$OUTPUT_DIR/boot/overlays" 2>/dev/null)" ]; then
    # Create a tarball of overlays to speed up transfer
    tar -czf /tmp/overlays.tar.gz -C "$OUTPUT_DIR/boot" overlays
    scp ${SSH_OPTS} /tmp/overlays.tar.gz "${USER}@${IP}:/tmp/"
    ssh ${SSH_OPTS} "${USER}@${IP}" "sudo tar --no-same-owner -xzf /tmp/overlays.tar.gz -C /boot/firmware/ && rm /tmp/overlays.tar.gz"
    rm /tmp/overlays.tar.gz
else
    echo "   (No overlays to copy)"
fi

# Step 4: Copy kernel modules
echo "[4/6] Copying kernel modules (this may take a moment)..."
# Create a tarball of modules to speed up transfer
tar -czf /tmp/modules.tar.gz -C "$OUTPUT_DIR/modules/lib/modules" "$KERNEL_VERSION"
scp ${SSH_OPTS} /tmp/modules.tar.gz "${USER}@${IP}:/tmp/"
ssh ${SSH_OPTS} "${USER}@${IP}" "sudo tar --no-same-owner -xzf /tmp/modules.tar.gz -C /lib/modules/ && rm /tmp/modules.tar.gz"
rm /tmp/modules.tar.gz

# Step 5: Update config.txt
echo "[5/6] Updating boot configuration..."
ssh ${SSH_OPTS} "${USER}@${IP}" "
    if grep -q '^kernel=' /boot/firmware/config.txt; then
        sudo sed -i 's/^kernel=.*/kernel=kernel8-4k.img/' /boot/firmware/config.txt
        echo '   Updated existing kernel= line'
    else
        echo 'kernel=kernel8-4k.img' | sudo tee -a /boot/firmware/config.txt > /dev/null
        echo '   Added kernel=kernel8-4k.img to config.txt'
    fi
"

# Step 6: Run depmod
echo "[6/6] Running depmod..."
ssh ${SSH_OPTS} "${USER}@${IP}" "sudo depmod -a ${KERNEL_VERSION}"

# Clean up temp files on Pi
ssh ${SSH_OPTS} "${USER}@${IP}" "rm -f /tmp/kernel8-4k.img /tmp/*.dtb 2>/dev/null || true"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "The Raspberry Pi will now reboot..."
echo ""
echo -e "${YELLOW}NOTE: The Pi's IP address may change after reboot if using DHCP.${NC}"
echo "      If you can't connect, check your router/DHCP server for the new IP."
echo ""
echo "After reboot, verify with:"
echo "  ssh ${USER}@<ip> 'uname -r && getconf PAGESIZE'"
echo ""
echo "Expected output:"
echo "  ${KERNEL_VERSION}"
echo "  4096"
echo ""

# Reboot
ssh ${SSH_OPTS} "${USER}@${IP}" "sudo reboot" || true

echo -e "${GREEN}Reboot command sent. The Pi should be back online in about 30-60 seconds.${NC}"