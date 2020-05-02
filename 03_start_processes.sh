#!/usr/bin/setsid /bin/bash

## NOTICE THE SETSID ON THE FIRST LINE, WITHOUT THAT SETSID THIS DOESN'T WORK!!!

DUMP_DIR=/data/dump
export DCONF_PROFILE=/data/dconf

rm -f /tmp/.X99-lock
export DISPLAY=127.0.0.1:99.0

Xvfb :99 -screen 0 1024x768x24 \
        +extension GLX +render -noreset \
        -listen inet -nolisten unix -nolisten local \
    > /dev/null 2> /dev/null < /dev/null &
#    > /tmp/xvfb.log 2> /tmp/xvfb.err < /dev/null &

xvfb_pid=$!

sleep 1

java -XX:-UsePerfData -Xmx32m \
  -jar build/libs/app.jar \
    > /dev/null 2> /dev/null < /dev/null &
#    > /tmp/app.log 2> /tmp/app.err < /dev/null &

java_pid=$!

#echo "Done starting apps $java_pid $xvfb_pid"

wait $java_pid
kill $xvfb_pid
