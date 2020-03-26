#!/bin/bash

ifconfig lo up

sleep 1

ifconfig lo > /tmp/net.log

#echo "Starting apps"

export DISPLAY=127.0.0.1:99.0

#echo "Starting "

Xvfb :99 -screen 0 1024x768x24 -noreset \
        -listen inet -nolisten unix -nolisten local \
    > /dev/null 2> /dev/null < /dev/null &
#    > /tmp/xvfb.log 2> /tmp/xvfb.err < /dev/null &

xvfb_pid=$!

sleep 1

java -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar \
    > /dev/null 2> /dev/null < /dev/null &
#    > /tmp/app.log 2> /tmp/app.err < /dev/null &

java_pid=$!

#echo "Done starting apps $java_pid $xvfb_pid"

wait $java_pid
kill $xvfb_pid
