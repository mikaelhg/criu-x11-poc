#!/bin/bash

DUMP_DIR=/data/dump
TTY_CODE=$(cat $DUMP_DIR/tty_code.txt)

criu restore -D $DUMP_DIR \
  -d \
  -v4 \
  -o restore.log \
  --inherit-fd "fd[1]:$TTY_CODE" \
  --tcp-established \
    && echo OK
