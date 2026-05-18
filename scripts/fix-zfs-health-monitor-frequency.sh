#!/bin/bash
# Script para reduzir frequência de alertas do zfs-health-monitor
# Altera intervalo de 5 minutos para 24 horas (1 email por dia)

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP
CONFIG_FILE="/etc/zfs-protection/monitor-config.conf"
BACKUP_FILE="/etc/zfs-protection/monitor-config.conf.backup-$(date +%Y%m%d)"

echo "🔧 Ajustando zfs-health-monitor no AGLSRV1..."
echo ""

# Fazer backup
echo "📦 Criando backup da configuração..."
ssh root@${HOST} "cp ${CONFIG_FILE} ${BACKUP_FILE}"

# Alterar CHECK_INTERVAL de 300 para 86400 (24 horas)
echo "📊 Alterando CHECK_INTERVAL de 5 min para 24 horas..."
ssh root@${HOST} "sed -i 's/^CHECK_INTERVAL=300/CHECK_INTERVAL=86400/' ${CONFIG_FILE}"

# Alterar ALERT_RATE_LIMIT de 300 para 86400 (24 horas)
echo "📧 Alterando ALERT_RATE_LIMIT de 5 min para 24 horas..."
ssh root@${HOST} "sed -i 's/^ALERT_RATE_LIMIT=300/ALERT_RATE_LIMIT=86400/' ${CONFIG_FILE}"

# Desabilitar alertas de alta capacidade para WARNING (manter CRITICAL)
echo "⚠️  Desabilitando alertas de WARNING para alta capacidade..."
ssh root@${HOST} "sed -i 's/^NOTIFY_ON_HIGH_CAPACITY=true/NOTIFY_ON_HIGH_CAPACITY=false/' ${CONFIG_FILE}"

echo ""
echo "✅ Configuração atualizada!"
echo ""

# Mostrar configuração alterada
echo "🔍 Nova configuração:"
ssh root@${HOST} "grep -E '(CHECK_INTERVAL|ALERT_RATE_LIMIT|NOTIFY_ON_HIGH_CAPACITY)' ${CONFIG_FILE}"
echo ""

# Restartar serviço
echo "🔄 Restartando serviço zfs-health-monitor..."
ssh root@${HOST} "systemctl restart zfs-health-monitor.service"

# Verificar status
echo ""
echo "📊 Status do serviço:"
ssh root@${HOST} "systemctl status zfs-health-monitor.service --no-pager | head -10"
echo ""

echo "✅ Alterações aplicadas com sucesso!"
echo ""
echo "📝 Backup salvo em: ${BACKUP_FILE}"
echo ""
echo "⚠️  O que foi alterado:"
echo "   - CHECK_INTERVAL: 300s (5 min) → 86400s (24 horas)"
echo "   - ALERT_RATE_LIMIT: 300s (5 min) → 86400s (24 horas)"
echo "   - NOTIFY_ON_HIGH_CAPACITY: true → false (desabilita WARNING de capacity)"
echo ""
echo "📧 Você receberá:"
echo "   - 1 email por dia sobre os pools em CRITICAL (>90%)"
echo "   - Apenas alertas CRITICAL (WARNING desabilitados)"
echo ""
echo "🔙 Para restaurar configuração original:"
echo "   ssh root@${HOST} 'cp ${BACKUP_FILE} ${CONFIG_FILE} && systemctl restart zfs-health-monitor.service'"
