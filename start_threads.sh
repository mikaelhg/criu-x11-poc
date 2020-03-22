#!/bin/bash

echo "Running unshare -> setsid"

unshare --pid --ipc --mount --cgroup --mount-proc --fork --
  sh -c 'setsid -f ./start_app.sh'

echo "Done with unshare -> setsid"
