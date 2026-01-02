#!/bin/bash

# If password injection is needed, copy and modify just main.ini
# This must be done as root for the bind mount to work
if [ -n "$SYSOP_PASSWORD" ] && [ "$SYSOP_PASSWORD" != "changeme" ]; then
    if [ -f /sbbs/ctrl/main.ini ]; then
        # Copy main.ini to a temp location, modify it, then bind mount over original
        cp /sbbs/ctrl/main.ini /tmp/main.ini
        
        # Replace sysop password (first password= line only)
        sed -i '0,/^password=/{s/^password=.*/password='"$SYSOP_PASSWORD"'/}' /tmp/main.ini
        echo "Sysop password configured from environment"
        
        # Replace BBS name if env var is set
        if [ -n "$BBS_NAME" ] && [ "$BBS_NAME" != "My BBS" ]; then
            sed -i 's/^name=.*/name='"$BBS_NAME"'/' /tmp/main.ini
            echo "BBS name configured from environment"
        fi
        
        # Mount the modified file over the original (container only, doesn't affect host)
        mount --bind /tmp/main.ini /sbbs/ctrl/main.ini
    fi
fi

# ARM64 fix: SpiderMonkey 1.8.5 uses NaN-boxing with 47-bit pointers.
# On ARM64 Linux, memory may be allocated at addresses requiring 48+ bits,
# causing segfaults in the JS engine. Using setarch --addr-compat-layout
# forces the kernel to use the legacy memory layout that keeps allocations
# in the lower address range where 47-bit pointers work correctly.
run_cmd() {
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        exec setarch "$ARCH" --addr-compat-layout gosu sbbs "$@"
    else
        exec gosu sbbs "$@"
    fi
}

# If no arguments passed, default to sbbs
if [ $# -eq 0 ]; then
    run_cmd /sbbs/exec/sbbs
else
    # Run whatever command was passed
    run_cmd "$@"
fi