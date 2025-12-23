#!/bin/bash

# Copy default content to mounted volumes if empty
if [ ! -d /enigma-bbs/mods/themes ] || [ -z "$(ls -A /enigma-bbs/mods/themes 2>/dev/null)" ]; then
    cp -r /enigma-bbs-defaults/mods/. /enigma-bbs/mods/
fi

if [ -z "$(ls -A /enigma-bbs/art 2>/dev/null)" ]; then
    cp -r /enigma-bbs-defaults/art/. /enigma-bbs/art/
fi

exec "$@"