#!/bin/bash
NODE=$1
DOORS_DIR=/enigma-bbs/doors
GAME_DIR=$DOORS_DIR/lord
DROPFILE_DIR=$DOORS_DIR/dropfiles/node$NODE
PORT=$((5000 + NODE))

mkdir -p "$DROPFILE_DIR"

if [ -f "$DROPFILE_DIR/DOOR.SYS" ]; then
    unix2dos -n "$DROPFILE_DIR/DOOR.SYS" "$GAME_DIR/DOOR.SYS" 2>/dev/null
fi

cd "$GAME_DIR"

# Start DOSBox in background
xvfb-run -a dosbox-x -conf $DOORS_DIR/dosbox.conf \
    -c "MOUNT C $GAME_DIR" \
    -c "MOUNT D $DOORS_DIR/fossil" \
    -c "D:\\BNU.COM /L0:still" \
    -c "C:" \
    -c "LORD.EXE" \
    -c "EXIT" 2>/dev/null &

sleep 2

# Connect to serial port
exec socat - TCP:127.0.0.1:$PORT