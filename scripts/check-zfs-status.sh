#!/bin/bash
# Script to check ZFS pool status and alert configuration

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP

echo "📊 Status dos Pools ZFS - AGLSRV1"
echo "================================"
echo ""

ssh root@${HOST} "zpool list -o name,cap,health,size,free,alloc"

echo ""
echo "🔧 Configuração ZED:"
echo "-------------------"
ssh root@${HOST} "systemctl status zfs-zed.service | head -5"

echo ""
ssh root@${HOST} "grep -E '(EMAIL_ADDR|NOTIFY_INTERVAL)' /etc/zfs/zed.d/zed.rc"

echo ""
echo "📧 Email de destino:"
ssh root@${HOST} "grep ZED_EMAIL_ADDR /etc/zfs/zed.d/zed.rc"

echo ""
echo "📈 Espaço disponível:"
echo "-------------------"
ssh root@${HOST} "zpool list -o name,cap,free | grep -E '(overpower|spark)'"
