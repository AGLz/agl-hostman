#!/bin/sh
# Mata meshagents com RSS > 1024 MiB (host). RSS em KiB: 1048576 KiB ~ 1 GiB.
ps aux | awk '/meshagent/ && !/awk|mesh-kill/ && $6+0 > 1048576 {print $2}' | sort -u | xargs -r -n1 kill -9
