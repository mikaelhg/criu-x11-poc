#!/bin/bash

echo "Starting apps"

export DISPLAY=127.0.0.1:1.0

Xvfb :1 -listen tcp -screen 0 1024x768x24 +extension GLX +render -noreset \
    > /dev/null 2> /dev/null < /dev/null &

xvfb_pid=$!

sleep 1

java -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar \
    > /dev/null 2> /dev/null < /dev/null &

java_pid=$!

echo "Done starting apps $java_pid $xvfb_pid"

wait $java_pid
kill $xvfb_pid
