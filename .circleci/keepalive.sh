#!/bin/bash
echo $$ > /tmp/keepalive.pid # keep this so that it can be killed from other command
while true; do
  echo "." && sleep 300
done
