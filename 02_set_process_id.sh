#!/bin/bash

# shellcheck disable=SC2068

echo 10000 > /proc/sys/kernel/ns_last_pid
exec $@
