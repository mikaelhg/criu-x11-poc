#!/bin/bash

unshare --pid --net --uts --ipc --mount --cgroup --mount-proc --fork ./02_start_threads.sh
