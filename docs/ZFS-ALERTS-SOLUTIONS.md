# Solução para Alertas ZFS no AGLSRV1

> **Data**: 2025-01-15
> **Problema**: Muitos emails sobre espaço em pools ZFS (overpower: 93%, spark: 96%)
> **Restrição**: Não remover arquivos, novo storage em ~60 dias

---

## 📊 Status Atual

```bash
# Verificar status atual
./scripts/check-zfs-status.sh
```

**Pools Críticos:**
- **overpower**: 93% usado (13.6T / 14.5T) - 905G livres
- **spark**: 96% usado (10.5T / 10.9T) - 384G livres
- **rpool**: 60% usado - OK

**Fonte dos Emails:**
- Serviço: `zfs-zed.service` (ZFS Event Daemon)
- Config: `/etc/zfs/zed.d/zed.rc`
- Email: `root@localhost`
- Intervalo: 3600s (1 hora)

---

## 🎯 Soluções Propostas

### ✅ **Opção 1: Reduzir Frequência** (RECOMENDADO)

**O que faz**: Aumenta intervalo de 1h para 24h (1 email por dia)

**Vantagens**:
- ✅ Mantém monitoramento crítico (falhas de disco, corruption, etc)
- ✅ Reduz spam de 24x/dia para 1x/dia
- ✅ Ainda será alertado se piorar
- ✅ Reversível facilmente

**Como aplicar**:
```bash
./scripts/disable-zfs-capacity-alerts.sh
```

**Manualmente**:
```bash
ssh root@100.107.113.33 << 'EOF'
# Backup
cp /etc/zfs/zed.d/zed.rc /etc/zfs/zed.d/zed.rc.backup-$(date +%Y%m%d)

# Aumentar intervalo para 24 horas
sed -i 's/ZED_NOTIFY_INTERVAL_SECS=3600/ZED_NOTIFY_INTERVAL_SECS=86400/' /etc/zfs/zed.d/zed.rc

# Restart
systemctl restart zfs-zed.service

# Verificar
grep ZED_NOTIFY_INTERVAL_SECS /etc/zfs/zed.d/zed.rc
EOF
```

**Reverter**:
```bash
ssh root@100.107.113.33 "cp /etc/zfs/zed.d/zed.rc.backup-* /etc/zfs/zed.d/zed.rc && systemctl restart zfs-zed.service"
```

---

### ⚠️ **Opção 2: Desabilitar Totalmente** (CUIDADO)

**O que faz**: Para completamente o ZED, sem NENHUM alerta

**Riscos**:
- ❌ Não recebe alertas de falha de disco
- ❌ Não recebe alertas de data corruption
- ❌ Não recebe alertas de resilver finish
- ❌ Fica cego a problemas críticos por 60 dias

**Como aplicar**:
```bash
./scripts/stop-zfs-alerts.sh
```

**Manualmente**:
```bash
ssh root@100.107.113.33 "systemctl stop zfs-zed.service && systemctl disable zfs-zed.service"
```

**Reabilitar após 60 dias**:
```bash
ssh root@100.107.113.33 "systemctl enable zfs-zed.service && systemctl start zfs-zed.service"
```

---

### 📧 **Opção 3: Redirecionar Email** (Alternativa)

**O que faz**: Manda emails para outra conta que você pode filtrar/ignorar

**Como aplicar**:
```bash
ssh root@100.107.113.33 << 'EOF'
# Editar config
sed -i 's/ZED_EMAIL_ADDR="root"/ZED_EMAIL_ADDR="seu-email@exemplo.com"/' /etc/zfs/zed.d/zed.rc

# Ou criar filtro local
echo "root: /root/mail/zfs-alerts" >> /etc/aliases
newaliases

# Restart
systemctl restart zfs-zed.service
EOF
```

---

## 📝 Minha Recomendação

**Use a Opção 1** (reduzir frequência):

1. **Reduz drasticamente o spam** (de 24x/dia para 1x/dia)
2. **Mantém segurança** (ainda alerta em emergências)
3. **É segura** (pode reverter facilmente)
4. **É adequada para 60 dias** (período curto)

**Aplicar agora**:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
chmod +x scripts/*.sh
./scripts/disable-zfs-capacity-alerts.sh
```

**Após 60 dias (com novo storage)**:
1. Adicionar novos discos aos pools
2. Capacity vai diminuir naturalmente
3. Restaurar configuração original (opcional)
4. Emails vão parar naturalmente

---

## 🔍 Monitoramento Manual

Enquanto ajusta os alertas, monitore manualmente:

```bash
# Verificar status semanal
ssh root@100.107.113.33 "zpool list -o name,cap,health,size,free"

# Verificar se ainda tem espaço razoável
# Se <100G livres em qualquer pool, URGENTE!
```

---

## 📚 Referências

- Config ZED: `/etc/zfs/zed.d/zed.rc`
- ZEDLETs: `/etc/zfs/zed.d/`
- Service: `zfs-zed.service`
- Logs: `journalctl -u zfs-zed`

---

**Document Version**: 1.0
**Last Updated**: 2025-01-15
