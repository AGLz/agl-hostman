#!/bin/bash
# Script to temporarily disable ZFS alerts (use with caution!)
# Only use this if you're okay with missing ALL ZFS alerts for 60 days

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP

echo "⚠️  ATENÇÃO: Isso desabilitará TODOS os alertas do ZFS!"
echo "⚠️  Você não receberá avisos de falhas em discos, corruptions, etc."
echo ""
read -p "Continuar mesmo assim? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelado."
    exit 1
fi

echo ""
echo "🛑 Parando ZED service..."
ssh root@${HOST} "systemctl stop zfs-zed.service"
ssh root@${HOST} "systemctl disable zfs-zed.service"

echo ""
echo "✅ ZED desabilitado!"
echo ""
echo "📊 Status dos pools (sem monitoramento):"
ssh root@${HOST} "zpool list -o name,cap,health,size,free"
echo ""
echo "⚠️  Para reabilitar depois de 60 dias:"
echo "   ssh root@${HOST} 'systemctl enable zfs-zed.service && systemctl start zfs-zed.service'"
