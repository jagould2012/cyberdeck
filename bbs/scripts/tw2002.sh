#!/bin/bash
NODE=$1
DOORS_DIR=/enigma-bbs/doors
GAME_DIR=$DOORS_DIR/tw2002
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE

mkdir -p "$DROPFILE_DIR"

if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$GAME_DIR/DOOR.SYS" 2>/dev/null
fi

cd "$GAME_DIR"
exec box86 /usr/local/bin/dosbox-x -conf /enigma-bbs/doors/dosbox.conf -c "MOUNT D $DOORS_DIR" -c "D:" -c "CD TW2002" -c "TW2002.EXE" -c "EXIT"