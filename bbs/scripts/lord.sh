#!/bin/bash
NODE=$1
DOORS_DIR=/enigma-bbs/doors
GAME_DIR=$DOORS_DIR/lord
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE

mkdir -p "$DROPFILE_DIR"

if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$GAME_DIR/DOOR.SYS" 2>/dev/null
fi

cd "$GAME_DIR"

exec xvfb-run dosbox-x -conf $DOORS_DIR/dosbox.conf \
    -c "MOUNT C $GAME_DIR" \
    -c "C:" \
    -c "LORD.EXE" \
    -c "EXIT"