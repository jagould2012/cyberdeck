#!/bin/bash
# Build SDRAngel arm64 .deb package using Docker
# Run this on your Mac (Apple Silicon)
#
# Usage: ./build.sh
#
# The resulting .deb will be copied to ../ansible/files/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ANSIBLE_FILES_DIR="../ansible/files"

# Create output directory
mkdir -p output

echo "=== Building SDRAngel arm64 .deb package ==="
echo "This will take 30-60 minutes on Apple Silicon..."
echo ""

# Build the Docker image
echo "Building Docker image..."
docker build --platform linux/arm64 -t sdrangel-builder .

# Run the container to extract the .deb
echo ""
echo "Extracting .deb package..."
docker run --rm --platform linux/arm64 -v "$(pwd)/output:/output" sdrangel-builder

DEB_FILE=$(ls output/*.deb 2>/dev/null | head -1)

if [ -z "$DEB_FILE" ]; then
    echo "ERROR: No .deb file found in output/"
    exit 1
fi

echo ""
echo "=== Build complete ==="
echo "Package: $DEB_FILE"

# Copy to ansible files directory
if [ -d "$ANSIBLE_FILES_DIR" ] || mkdir -p "$ANSIBLE_FILES_DIR"; then
    cp "$DEB_FILE" "$ANSIBLE_FILES_DIR/sdrangel_arm64.deb"
    echo ""
    echo "Copied to: $ANSIBLE_FILES_DIR/sdrangel_arm64.deb"
    echo ""
    echo "You can now run the ansible playbook:"
    echo "  cd ../ansible"
    echo "  ansible-playbook site.yml -K"
else
    echo ""
    echo "To install on Raspberry Pi manually:"
    echo "  scp $DEB_FILE user@pi-hostname:~/"
    echo "  ssh user@pi-hostname 'sudo apt install -f ./sdrangel_*.deb'"
fi