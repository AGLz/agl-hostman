# Log de Alteração de Alertas ZFS - AGLSRV1

**Data**: 2026-01-23
**Servidor**: aglsrv1 (100.107.113.33)
**Motivo**: Reduzir spam de emails de alerta ZFS durante período de 60 dias antes de expansão de storage

---

## ✅ Alteração Aplicada

### O que foi alterado:
- **Arquivo**: `/etc/zfs/zed.d/zed.rc`
- **Parâmetro**: `ZED_NOTIFY_INTERVAL_SECS`
- **Valor anterior**: `3600` (1 hora = 24 emails/dia)
- **Valor novo**: `86400` (24 horas = 1 email/dia)

### Backup criado:
- **Local**: `/etc/zfs/zed.d/zed.rc.backup-20260123`
- **Serviço restartado**: `zfs-zed.service`

---

## 📊 Status Atual dos Pools

```
NAME        CAP    HEALTH   SIZE   FREE
overpower   93%    ONLINE  14.5T   893G
rpool       61%    ONLINE  2.72T  1.04T
spark       96%    ONLINE  10.9T   385G
```

---

## 🔙 Como Reverter (Após 60 dias)

### Quando restaurar:
Depois de adicionar o novo storage e expandir os pools ZFS

### Comando de restauração:
```bash
ssh root@100.107.113.33 'cp /etc/zfs/zed.d/zed.rc.backup-20260123 /etc/zfs/zed.d/zed.rc && systemctl restart zfs-zed.service'
```

### Verificação após restauração:
```bash
ssh root@100.107.113.33 'grep ZED_NOTIFY_INTERVAL_SECS /etc/zfs/zed.d/zed.rc'
# Deve mostrar: ZED_NOTIFY_INTERVAL_SECS=3600
```

---

## 📝 Benefícios da Alteração

✅ **Redução de spam**: De 24 emails/dia para 1 email/dia
✅ **Monitoramento mantido**: Ainda recebe alertas críticos (falhas de disco, corruptions, etc)
✅ **Segurança**: Backup criado para restauração fácil
✅ **Adequado para 60 dias**: Período curto antes da expansão

---

## ⚠️ Importante

- **Monitoramento manual**: Verificar status dos pools semanalmente
- **Alerta crítico**: Se qualquer pool tiver menos de 100G livres, ação imediata necessária
- **Após 60 dias**: Restaurar configuração original ou ajustar conforme necessidade

---

**Aplicado por**: Claude Code
**Script utilizado**: `scripts/disable-zfs-capacity-alerts.sh`
**Documentação de referência**: `docs/ZFS-ALERTS-SOLUTIONS.md`
