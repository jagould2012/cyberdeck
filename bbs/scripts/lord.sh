#!/bin/bash
# LORD (Legend of the Red Dragon) door script for ENiGMA BBS
# Usage: lord.sh <node_number>

NODE=$1
DOORS_DIR=/enigma-bbs/doors
GAME_DIR=$DOORS_DIR/lord
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE

mkdir -p "$DROPFILE_DIR"

# Convert dropfile to DOS format and copy to game directory
if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$GAME_DIR/DOOR.SYS" 2>/dev/null
fi

cd "$GAME_DIR"

# Run DOSBox-X in TTF mode for proper ANSI display
exec dosbox-x -conf $DOORS_DIR/dosbox.conf \
    -c "MOUNT D $DOORS_DIR" \
    -c "D:" \
    -c "CD LORD" \
    -c "LORD.EXE" \
    -c "EXIT" 2>/dev/null