#!/bin/bash
set -e
SSH_OPTS="-o ConnectTimeout=5 -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa"
HOST=root@100.107.113.33

# Find the LXC PID for CT117 via the PVE host
LXC_PID=$(ssh $SSH_OPTS -o ProxyCommand="tailscale nc %h %p" $HOST 'pgrep -f "lxc-start.*117" | head -1')
echo "LXC PID: $LXC_PID"

if [ -z "$LXC_PID" ]; then
    echo "ERROR: Could not find LXC PID for CT117"
    exit 1
fi

# Restart cloudflared inside CT117 namespace
ssh $SSH_OPTS -o ProxyCommand="tailscale nc %h %p" $HOST "nsenter -t $LXC_PID -m -p -- /bin/bash -c 'systemctl restart cloudflared; sleep 3; systemctl status cloudflared'" 2>&1
echo "DONE"
