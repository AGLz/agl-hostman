#!/bin/bash
# Script para verificar status detalhado dos backups no AGLSRV1
# Uso: ./scripts/check-backup-status.sh

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP

echo "📊 Status dos Backups - AGLSRV1"
echo "================================"
echo ""

ssh root@${HOST} << 'EOF'
echo "💾 Storage Status:"
echo "-------------------"
pvesm status | grep -E '(spark|pbs|Volid)' | while read line; do
    echo "  $line"
done

echo ""
echo "📈 Pool ZFS Status:"
echo "------------------"
zpool list -o name,cap,health,size,free | grep -E '(NAME|spark|overpower)'

echo ""
echo "📋 Backup Jobs Configurados:"
echo "---------------------------"
cat /etc/pve/jobs.cfg | grep -E '(vzdump:|enabled|schedule|vmid)' | grep -B1 -A1 'enabled 1' | grep -v '^--$'

echo ""
echo "📄 Últimos Logs de Backup:"
echo "-------------------------"
ls -lt /var/log/vzdump/*.log 2>/dev/null | head -3 | awk '{print $NF}' | while read log; do
    echo ""
    echo "=== $log ==="
    tail -2 "$log" | grep -E '(Finished|failed|ERROR|OK)'
done

echo ""
echo "⚠️  Espaço em Disco:"
echo "-------------------"
df -h /spark 2>/dev/null | tail -1

echo ""
echo "🔍 Erros Recentes:"
echo "-----------------"
journalctl --since '24 hours ago' | grep -iE '(backup.*error|vzdump.*failed)' | tail -5 || echo "  (nenhum erro encontrado)"
EOF
