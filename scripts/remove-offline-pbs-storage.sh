#!/bin/bash
# Script para remover storage PBS offline e parar erros na console web
# Uso: ./scripts/remove-offline-pbs-storage.sh

set -e

HOST="100.107.113.33"  # AGLSRV1 Tailscale IP

echo "🔧 Removendo storage aglsrv6b-pbs offline..."
echo ""

# Verificar se storage existe antes de remover
echo "📊 Verificando storage atual..."
ssh root@${HOST} "pvesm status | grep pbs"
echo ""

# Confirmar com usuário
read -p "❓ Remover o storage aglsrv6b-pbs? Isso vai parar os erros na console. (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelado."
    exit 1
fi

echo ""
echo "💾 Criando backup da configuração..."
ssh root@${HOST} "cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-\$(date +%Y%m%d-%H%M%S)"

echo ""
echo "🗑️  Removendo seção aglsrv6b-pbs..."
ssh root@${HOST} "sed -i '/^pbs: aglsrv6b-pbs/,/^$/d' /etc/pve/storage.cfg"

echo ""
echo "🔄 Recarregando configuração de storage..."
ssh root@${HOST} "pvesm parse /etc/pve/storage.cfg"

echo ""
echo "✅ Storage removido com sucesso!"
echo ""
echo "📊 Verificando status atual..."
ssh root@${HOST} "pvesm status | grep pbs || echo '  (nenhum storage PBS restante)'"

echo ""
echo "📝 Backup salvo em: /etc/pve/storage.cfg.backup-*"
echo ""
echo "🎉 Os erros 'aglsrv6b-pbs: error fetching datastores' devem parar de aparecer na console web!"
echo ""
echo "⚠️  Para restaurar (se necessário):"
echo "   ssh root@${HOST} 'cp /etc/pve/storage.cfg.backup-* /etc/pve/storage.cfg'"
