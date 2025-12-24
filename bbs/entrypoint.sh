#!/bin/bash

# If password injection is needed, copy and modify just main.ini
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

# If no arguments passed, default to sbbs
if [ $# -eq 0 ]; then
    exec /sbbs/exec/sbbs
else
    # Run whatever command was passed
    exec "$@"
fi