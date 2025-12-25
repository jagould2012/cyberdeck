#!/bin/bash
set -e
mkdir -p output
docker run -it --rm -v $(pwd)/output:/output kali-rpi5-kernel /build/build-kernel.sh