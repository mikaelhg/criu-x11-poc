#!/bin/bash

docker run -it --rm \
  -w /app \
  -v $(pwd):/app \
  -v /tmp/data/dump:/data/dump \
  -v /tmp/data/tmp-java:/tmp/java \
  -v /lib/modules:/lib/modules:ro \
  --privileged \
  --tmpfs /run \
  ess-criu:latest bash
