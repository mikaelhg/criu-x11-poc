#!/bin/bash

# Pull up 127.0.0.1

ifconfig lo up

sleep 1

# Make sure that our process group leader's PID is 10001
# so that when we restore the process, our initial script's
# PIDs won't stomp on this script's PIDs

echo 10000 > /proc/sys/kernel/ns_last_pid

# Create a new process group leader for our processes

setsid -fw ./03_start_processes.sh

