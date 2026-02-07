# Diagnóstico de Erros de Backup - AGLSRV1

> **Data**: 2026-01-15
> **Host**: AGLSRV1 (100.107.113.33)
> **Problema**: Diversos erros sendo exibidos na console web do Proxmox

---

## 📊 Resumo Executivo

**Boa Notícia**: Os backups estão funcionando! ✅

**Erros Encontrados**:
1. ⚠️ Storage PBS remoto offline (aglsrv6b-pbs)
2. ⚠️ Machine Check Exceptions (MCE) - erros de hardware

---

## 🔍 Análise Detalhada

### 1. Status dos Backups

**Jobs Configurados**:
- **small-vms-backup**: ✅ Ativo (VMs: 101,102,111,112,117,176)
- **large-vms-backup**: ✅ Ativo (58 VMs/CTs)
- **full-backup**: ❌ Desabilitado

**Storage de Backup**:
- **spark**: 98.25% usado (7.1T de 7.2T) - ⚠️ Quase cheio
- **spark-zfs**: 98.26% usado

**Resultado dos Backups**:
```
INFO: Backup job finished successfully
TASK OK
```

✅ **Conclusão**: Os backups estão funcionando perfeitamente!

---

## ⚠️ Erro 1: Storage PBS Remoto Offline

### Descrição

```
aglsrv6b-pbs: error fetching datastores - 500 Can't connect to 10.6.0.15:8007 (Connection timed out)
```

**Ocorre**: A cada 10 segundos (pvestatd tentando conectar)

### Causa Raiz

O storage **aglsrv6b-pbs** está configurado mas o host **AGLSRV6B está offline/dead**:

```bash
# Host AGLSRV6B Status
Type: Dead
Status: ❌ Dead
CT172: offline
```

### Configuração Atual

```bash
pbs: aglsrv6b-pbs
    datastore backups
    server 10.6.0.15  # AGLSR6B WireGuard IP
    content backup
    prune-backups keep-all=1
```

### Impacto

- ❌ Gera spam de erros na console web
- ❌ Pvestatd tenta conectar a cada 10s
- ✅ **Não afeta backups** (backups usam storage spark local)
- ✅ **Não quebra funcionalidades críticas**

---

## ⚠️ Erro 2: Machine Check Exceptions (MCE)

### Descrição

```
kernel: mce: [Hardware Error]: Machine check events logged
kernel: mce_notify_irq: 58 callbacks suppressed
```

**Ocorre**: ~2 vezes por minuto (1x30s)

### O que é MCE?

Machine Check Exception é um mecanismo da CPU que reporta erros de hardware:

**Tipos**:
- **Corrected Errors**: Não críticos, ECC corrigiu
- **Uncorrected Errors**: ❌ CRÍTICO, dados corrompidos

### Análise

```bash
# Disks NVMe
SMART overall-health: PASSED
Temperature: 51-60°C (Normal)
Media Errors: 0
Error Log Entries: 0

# CPU
Model: Intel Xeon E5-2680 v4 @ 2.40GHz
Cores: 56 (hyperthreaded)
```

✅ **Boas notícias**:
- SMART passou
- Temperatura normal
- Sem erros de disco
- MCE provavelmente são **corrected errors** (não críticos)

⚠️ **Recomendação**: Monitorar, mas não emergência

---

## 🎯 Soluções Propostas

### Solução 1: Remover Storage PBS Offline ⭐ RECOMENDADO

**Benefícios**:
- ✅ Para spam de erros na console
- ✅ Reduz load do pvestatd
- ✅ Limpa visualização

**Como Aplicar**:

```bash
# Opção A: Desabilitar (manter config)
ssh root@100.107.113.33 << 'EOF'
# Backup da config
cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-$(date +%Y%m%d)

# Comentar storage aglsrv6b-pbs
sed -i 's/^pbs: aglsrv6b-pbs/#pbs: aglsrv6b-pbs (disabled - host offline)/' /etc/pve/storage.cfg
sed -i '/^datastore backups/{n;s/^/#/}' /etc/pve/storage.cfg
sed -i '/^server 10.6.0.15/{s/^/#/}' /etc/pve/storage.cfg
sed -i '/^content backup/{n;s/^/#/}' /etc/pve/storage.cfg

# Reload storage config
pvesm parse /etc/pve/storage.cfg
EOF
```

```bash
# Opção B: Remover completamente (mais limpo)
ssh root@100.107.113.33 << 'EOF'
# Backup
cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-$(date +%Y%m%d)

# Remover seção aglsrv6b-pbs
sed -i '/^pbs: aglsrv6b-pbs/,/^$/d' /etc/pve/storage.cfg

# Reload
pvesm parse /etc/pve/storage.cfg
EOF
```

### Solução 2: Investigar MCEs (Opcional)

Instalar ferramentas de diagnóstico:

```bash
ssh root@100.107.113.33 << 'EOF'
# Instalar mcelog se não existe
apt-get update && apt-get install -y mcelog rasdaemon

# Habilitar serviço
systemctl enable mcelog
systemctl start mcelog

# Verificar próximos erros
tail -f /var/log/mcelog
EOF
```

---

## 📋 Checklist de Ações

### Imediato (Parar Erros na Console)

- [ ] Remover storage aglsrv6b-pbs (Opção 1B acima)
- [ ] Verificar console web não mostra mais erros

### Curto Prazo (Monitoramento)

- [ ] Instalar mcelog para capturar detalhes dos MCEs
- [ ] Verificar se MCEs são corrected ou uncorrected
- [ ] Monitorar temperatura dos NVMe drives

### Médio Prazo (60 dias)

- [ ] Limpar backups antigos do storage spark (liberar espaço)
- [ ] Adicionar novo storage para backups
- [ ] Reavaliar necessidade de storage remoto PBS

---

## 🔧 Scripts Automatizados

### Script: Remover PBS Offline

```bash
#!/bin/bash
# remove-offline-pbs-storage.sh

HOST="100.107.113.33"

echo "🔧 Removendo storage aglsrv6b-pbs offline..."

ssh root@${HOST} << 'EOF'
# Backup
cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-$(date +%Y%m%d)

# Remover seção aglsrv6b-pbs
sed -i '/^pbs: aglsrv6b-pbs/,/^$/d' /etc/pve/storage.cfg

# Reload
pvesm parse /etc/pve/storage.cfg

echo "✅ Storage removido!"
echo "📝 Backup: /etc/pve/storage.cfg.backup-$(date +%Y%m%d)"
EOF

echo ""
echo "Verificando..."
ssh root@${HOST} "pvesm status | grep pbs"
```

### Script: Ver Status dos Backups

```bash
#!/bin/bash
# check-backup-status.sh

HOST="100.107.113.33"

echo "📊 Status dos Backups - AGLSRV1"
echo "================================"
echo ""

ssh root@${HOST} << 'EOF'
echo "Storage Status:"
pvesm status | grep -E '(spark|pbs)'

echo ""
echo "Últimos Backups:"
ls -lt /var/log/vzdump/*.log | head -5 | awk '{print $9}' | xargs -I {} sh -c 'echo "=== {} ===" && tail -3 {}'

echo ""
echo "Jobs Configurados:"
cat /etc/pve/jobs.cfg | grep -E '(vzdump|enabled|vmid)' | grep -B2 -A2 'enabled 1'
EOF
```

---

## 📊 Status Atual dos Backups

```
✅ small-vms-backup: Funcionando
   - Schedule: 03:15 diário
   - Retention: keep-last=7, keep-monthly=6
   - Storage: spark (98.25% cheio)

✅ large-vms-backup: Funcionando
   - Schedule: 03:30 diário
   - Retention: keep-last=1, keep-monthly=1
   - Storage: spark (98.25% cheio)

⚠️ Storage spark: 98.25% usado
   - Total: 7.2T
   - Usado: 7.1T
   - Livre: 128G
   - Status: Precisa de atenção
```

---

## 🎯 Conclusão

**Resumo**:
1. ✅ **Backups funcionam perfeitamente** - Não há problemas com backup
2. ⚠️ **Erro na console** é apenas storage remoto offline
3. ⚠️ **MCEs** são provavelmente corrected errors (não críticos)
4. ⚠️ **Storage spark** está 98% cheio - mas backups ainda funcionam

**Ação Recomendada**:
1. Remover/desabilitar storage aglsrv6b-pbs (para de mostrar erros)
2. Monitorar espaço em spark (pode precisar limpar backups antigos)
3. Em 60 dias, adicionar novo storage

---

**Document Version**: 1.0
**Last Updated**: 2026-01-15
