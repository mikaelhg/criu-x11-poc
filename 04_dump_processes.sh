#!/bin/bash

TARGET_PID=$(pgrep -f 03_start)
DUMP_DIR=/data/dump
TTY_CODE=$(python3 tty_code.py $TARGET_PID)

rm "$DUMP_DIR"/*

echo "$TTY_CODE" > $DUMP_DIR/tty_code.txt

criu dump -t "$TARGET_PID" -D $DUMP_DIR \
  -j -v4 -o dump.log \
  --external "$TTY_CODE" --tcp-established \
    && echo OK
