#!/bin/bash

docker run -it --rm \
  -w /app \
  -v "$(pwd):/app" \
  -v /tmp/data/dump:/data/dump \
  -v /lib/modules:/lib/modules:ro \
  --privileged \
  --tmpfs /run \
  criu-x11-poc:latest bash
