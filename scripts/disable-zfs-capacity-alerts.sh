#!/bin/bash
# Script to reduce ZFS capacity alert frequency
# Run on AGLSRV1 to reduce email spam while keeping critical alerts

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP

echo "🔧 Ajustando alertas ZFS no AGLSRV1..."
echo ""

# Opção 1: Aumentar intervalo para 24 horas (1x por dia)
echo "📊 Aumentando intervalo de notificação de 1h para 24h..."
ssh root@${HOST} "cp /etc/zfs/zed.d/zed.rc /etc/zfs/zed.d/zed.rc.backup-$(date +%Y%m%d)"
ssh root@${HOST} "sed -i 's/ZED_NOTIFY_INTERVAL_SECS=3600/ZED_NOTIFY_INTERVAL_SECS=86400/' /etc/zfs/zed.d/zed.rc"
ssh root@${HOST} "systemctl restart zfs-zed.service"

echo ""
echo "✅ Configuração atualizada!"
echo ""
echo "📈 Status atual:"
ssh root@${HOST} "zpool list -o name,cap,health,size,free"
echo ""
echo "🔍 Configuração ZED:"
ssh root@${HOST} "grep -E '(EMAIL_ADDR|NOTIFY_INTERVAL)' /etc/zfs/zed.d/zed.rc"
echo ""
echo "📝 Backup salvo em: /etc/zfs/zed.d/zed.rc.backup-$(date +%Y%m%d)"
echo ""
echo "⚠️ Para restaurar original:"
echo "   ssh root@${HOST} 'cp /etc/zfs/zed.d/zed.rc.backup-* /etc/zfs/zed.d/zed.rc && systemctl restart zfs-zed.service'"
