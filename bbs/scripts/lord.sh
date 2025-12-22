#!/bin/bash
NODE=$1

DOORS_DIR=/enigma-bbs/doors
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE

mkdir -p $DROPFILE_DIR

if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$DOORS_DIR/lord/DOOR.SYS" 2>/dev/null
fi

cd $DOORS_DIR/lord
su - bbs -c "dosemu -dumb -E 'LREDIR D: LINUX\FS$DOORS_DIR' -E 'D:' -E 'CD LORD' -E 'LORD.EXE' -E 'exitemu'"

exit 0