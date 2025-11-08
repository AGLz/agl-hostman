# Scripts de Implementação - Cluster Proxmox

> **Data**: 2025-11-08
> **Status**: Prontos para execução
> **Cluster**: agl-cluster (AGLSRV6 + AGLSRV6C + AGLSRV6D + QDevice)

---

## 📋 Ordem de Execução

Execute os scripts **NA ORDEM NUMÉRICA**:

### Pré-Janela de Manutenção (Pode executar agora)

1. **`01-prerequisites.sh`** - Verificação de pré-requisitos
   - ✅ Pode executar AGORA
   - Verifica rede, pacotes, sincronização
   - Instala dependências necessárias
   - **Tempo estimado**: 5-10 minutos

2. **`02-create-cluster.sh`** - Criação do cluster base
   - ✅ Pode executar AGORA
   - Cria cluster em AGLSRV6C
   - Adiciona AGLSRV6D ao cluster
   - **Tempo estimado**: 15-20 minutos
   - ⚠️ NÃO mexe em AGLSRV6

3. **`03-setup-qdevice.sh`** - Configuração do QDevice
   - ✅ Pode executar AGORA
   - Instala corosync-qnetd em AGLSRV1
   - Configura voto externo
   - **Tempo estimado**: 10-15 minutos
   - ⚠️ NÃO mexe em AGLSRV6

4. **`04-test-cluster.sh`** - Testes de cluster e failover
   - ✅ Pode executar AGORA
   - Testa HA e failover
   - Cria VM de teste
   - **Tempo estimado**: 20-30 minutos
   - ⚠️ NÃO mexe em AGLSRV6

### Durante Janela de Manutenção (⚠️ REQUER DOWNTIME)

5. **`05-add-aglsrv6.sh`** - Adicionar AGLSRV6 ao cluster
   - 🔴 **SOMENTE DURANTE JANELA DE MANUTENÇÃO**
   - Adiciona AGLSRV6 ao cluster
   - **CAUSA DOWNTIME**
   - **Tempo estimado**: 1-2 horas
   - Requer 3 confirmações antes de executar

---

## 🚀 Quick Start

### 1. Tornar scripts executáveis
```bash
cd /tmp/cluster-scripts
chmod +x *.sh
```

### 2. Executar scripts 1-4 (PRÉ-JANELA)
```bash
# Script 1: Pré-requisitos
./01-prerequisites.sh

# Script 2: Criar cluster base (AGLSRV6C + AGLSRV6D)
./02-create-cluster.sh

# Script 3: Configurar QDevice
./03-setup-qdevice.sh

# Script 4: Testes
./04-test-cluster.sh
```

### 3. Agendar janela de manutenção
- Notificar usuários com antecedência
- Tempo estimado: 2-3 horas
- Backup completo de AGLSRV6

### 4. Durante janela: Script 5
```bash
# Script 5: Adicionar AGLSRV6 (SOMENTE NA JANELA)
./05-add-aglsrv6.sh
```

---

## ⚠️ Avisos Críticos

### AGLSRV6 em Produção
- ✅ Scripts 1-4 NÃO mexem em AGLSRV6
- ✅ AGLSRV6 permanece standalone e operacional
- 🔴 Script 5 adiciona AGLSRV6 ao cluster (CAUSA DOWNTIME)

### Requisitos Antes do Script 5
- [ ] Backup completo de AGLSRV6
- [ ] Usuários notificados (mínimo 2 horas)
- [ ] Janela de manutenção agendada
- [ ] Scripts 1-4 executados com sucesso
- [ ] Testes de failover validados

---

## 🌐 Topologia do Cluster

### Configuração Final
```
┌─────────────────────────────────────────┐
│         Cluster: agl-cluster            │
├─────────────────────────────────────────┤
│  Nó 1: AGLSRV6  (10.6.0.12) - Produção │
│  Nó 2: AGLSRV6C (10.6.0.22) - Novo     │
│  Nó 3: AGLSRV6D (10.6.0.23) - Novo     │
├─────────────────────────────────────────┤
│  QDevice: AGLSRV1 (10.6.0.10)          │
└─────────────────────────────────────────┘

Quorum: 2/4 votes (configuração flexível)
Network: WireGuard Mesh (10.6.0.0/24)

Cenários de operação:
  ✅ AGLSRV6 + QDevice = 2/4 (OK)
  ✅ AGLSRV6C + AGLSRV6D = 2/4 (OK)
  ✅ Qualquer 1 nó + QDevice = 2/4 (OK)
```

---

## 📊 Checklist Completo

### Antes de Começar
- [ ] Todos os scripts baixados em `/tmp/cluster-scripts/`
- [ ] Scripts tornados executáveis (`chmod +x *.sh`)
- [ ] Documentação lida (`PROXMOX-CLUSTER-PLAN.md`)
- [ ] Backup completo de AGLSRV6 realizado

### Fase 1-4 (Pré-Janela)
- [ ] ✅ Script 1 executado (pré-requisitos)
- [ ] ✅ Script 2 executado (cluster base)
- [ ] ✅ Script 3 executado (QDevice)
- [ ] ✅ Script 4 executado (testes)
- [ ] ✅ Todos os testes passaram
- [ ] ✅ Cluster AGLSRV6C + AGLSRV6D operacional

### Fase 5 (Janela de Manutenção)
- [ ] Janela de manutenção agendada
- [ ] Usuários notificados
- [ ] Backup final de AGLSRV6 confirmado
- [ ] 🔴 Script 5 executado (adicionar AGLSRV6)
- [ ] Cluster completo operacional (3 nós + QDevice)
- [ ] VMs/CTs testados após migração
- [ ] Documentação atualizada

---

## 🔧 Troubleshooting

### Se algo der errado no Script 2
```bash
# Em AGLSRV6C:
pvecm delnode man6d  # Remove AGLSRV6D

# Em AGLSRV6D:
systemctl stop pve-cluster corosync
rm -rf /etc/pve/corosync.conf /etc/corosync/*
```

### Se algo der errado no Script 5
⚠️ **MUITO MAIS COMPLEXO**
- AGLSRV6 pode precisar ser reinstalado
- **Melhor estratégia**: Testar tudo nos scripts 1-4 primeiro!

### Comandos Úteis
```bash
# Verificar status do cluster
pvecm status

# Listar nós
pvecm nodes

# Verificar quorum
pvecm status | grep Quorate

# Logs do Corosync
journalctl -u corosync -f

# Status do QDevice
pvecm status | grep -A5 Qdevice
```

---

## 📞 Suporte

**Documentação completa**: `/tmp/PROXMOX-CLUSTER-PLAN.md`

**Proxmox Docs**:
- Cluster Manager: https://pve.proxmox.com/pve-docs/chapter-pvecm.html
- QDevice: https://pve.proxmox.com/pve-docs/chapter-pvecm.html#_corosync_external_vote_support

---

**Criado**: 2025-11-08
**Versão**: 1.0.0
**Próximos passos**: Executar scripts 1-4, depois agendar janela para script 5
