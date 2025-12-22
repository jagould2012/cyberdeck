#!/bin/bash
NODE=$1

DOORS_DIR=/enigma-bbs/doors
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE

mkdir -p $DROPFILE_DIR

if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$DOORS_DIR/tw2002/DOOR.SYS" 2>/dev/null
fi

cd $DOORS_DIR/tw2002
su - bbs -c "dosemu -dumb -E 'LREDIR D: LINUX\FS$DOORS_DIR' -E 'D:' -E 'CD TW2002' -E 'TW2002.EXE /N$NODE' -E 'exitemu'"

exit 0