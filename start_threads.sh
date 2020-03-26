#!/bin/bash

echo "Running unshare -> setsid"

unshare --pid --net --uts --ipc --mount --cgroup \
  --mount-proc --fork -- \
    setsid -f ./start_app.sh

echo "Done with unshare -> setsid"
