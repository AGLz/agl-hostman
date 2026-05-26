#!/usr/bin/env bash
# CT188 (Tailscale): Pi-hole LAN 192.168.0.102 via eth0 — table 52 tem 192.168.0.0/24 via tailscale0.
set -euo pipefail
PIHOLE_LAN="${PIHOLE_LAN:-192.168.0.102}"
LAN_IF="${LAN_IF:-eth0}"
ip route replace "${PIHOLE_LAN}" dev "${LAN_IF}" table 52
