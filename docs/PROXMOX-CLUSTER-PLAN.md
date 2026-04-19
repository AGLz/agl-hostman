# Plano de Implementação - Cluster Proxmox (AGLSRV6 + AGLSRV6C + AGLSRV6D)

> **Status**: 📋 Planejamento completo - Aguardando janela de manutenção
> **Data de criação**: 2025-11-08
> **Versão**: 1.0.0

---

## 🎯 Objetivo

Criar um cluster Proxmox de 3 nós com QDevice externo para alta disponibilidade:
- **AGLSRV6** (10.6.0.12) - Nó principal (EM PRODUÇÃO)
- **AGLSRV6C** (10.6.0.22) - Nó secundário (Novo)
- **AGLSRV6D** (10.6.0.23) - Nó terciário (Novo)
- **QDevice**: AGLSRV1 (10.6.0.10) - Voto externo para quorum

---

## 🚨 AVISOS CRÍTICOS

### ⚠️ AGLSRV6 EM PRODUÇÃO
**NUNCA execute comandos de cluster no AGLSRV6 fora da janela de manutenção!**

- ✅ AGLSRV6 tem 11 containers e 6 VMs em produção
- ✅ Usuários ativos no momento
- ✅ Executar cluster commands pode causar downtime
- ✅ **TODO O TRABALHO DEVE SER FEITO DURANTE JANELA DE MANUTENÇÃO**

### ⚠️ Impactos da Criação do Cluster

1. **Configuração /etc/pve será SOBRESCRITA**:
   - Ao adicionar um nó ao cluster, **TODA** configuração em `/etc/pve` é substituída
   - VMs/CTs existentes **NÃO podem estar presentes** no nó que está entrando
   - VMIDs duplicados causarão conflitos

2. **Mudança de arquitetura**:
   - De standalone para cluster
   - Requer sincronização de configuração via Corosync
   - Estado de quorum passa a ser crítico

3. **Network Requirements**:
   - Portas UDP 5405-5412 (Corosync)
   - Porta TCP 22 (SSH)
   - Latência baixa (<10ms recomendado, temos ~30-40ms via WireGuard)

---

## 📊 Análise de Servidores

### AGLSRV6 (Nó Principal - EM PRODUÇÃO)
| Propriedade | Valor |
|------------|-------|
| **Hostname** | AGLSRV6 (man6) |
| **OS** | Proxmox VE |
| **WireGuard IP** | 10.6.0.12 |
| **Tailscale IP** | 100.98.108.66 |
| **Resources** | 11 CTs, 6 VMs |
| **Storage** | 954GB (bb), 3.9TB (usb4tb), 1.2TB (PBS) |
| **Status** | 🔴 EM PRODUÇÃO - NÃO MEXER AGORA |

**Containers em Produção**:
- CT111 (aluzdivina) - NFS server (10.6.0.20)
- CT113 (PBS), CT172 (PBS) - Backup servers
- CT108 (agldv06) - Development
- CT101 (cloudflared), CT102 (meshcentral)

### AGLSRV6C (Nó Secundário)
| Propriedade | Valor |
|------------|-------|
| **Hostname** | man6c (aglsrv6c) |
| **OS** | Proxmox VE 9.0 / Debian 13 |
| **Kernel** | 6.14.11-4-pve |
| **LAN IP** | 192.168.0.233 |
| **WireGuard IP** | 10.6.0.22 |
| **Tailscale IP** | 100.124.53.91 |
| **Resources** | Novo - sem VMs/CTs |
| **Status** | ✅ Pronto para cluster |

### AGLSRV6D (Nó Terciário)
| Propriedade | Valor |
|------------|-------|
| **Hostname** | man6d (aglsrv6d) |
| **OS** | Proxmox VE 9.0.11 / Debian 13 |
| **Kernel** | 6.14.11-4-pve |
| **LAN IP** | 192.168.0.234 |
| **WireGuard IP** | 10.6.0.23 |
| **Tailscale IP** | 100.76.201.83 |
| **Hardware** | i5-4590, 8GB RAM, 465GB SSD |
| **Resources** | Novo - sem VMs/CTs |
| **Status** | ✅ Pronto para cluster |

### QDevice Host (AGLSRV1)
| Propriedade | Valor |
|------------|-------|
| **Hostname** | algsrv1 |
| **OS** | Proxmox VE |
| **WireGuard IP** | 10.6.0.10 |
| **LAN IP** | 192.168.0.245 |
| **Tailscale IP** | 100.107.113.33 |
| **Role** | External vote provider (QDevice) |
| **Status** | ✅ Disponível |

---

## 🛣️ Estratégia de Implementação

### Abordagem Conservadora (RECOMENDADA)

**Ordem de criação do cluster:**

1. **AGLSRV6C** cria o cluster (novo, sem dados)
2. **AGLSRV6D** entra no cluster
3. **QDevice** é configurado em AGLSRV1
4. **Testar failover** e quorum
5. **Durante janela de manutenção**: AGLSRV6 entra no cluster

### Por que AGLSRV6C deve criar o cluster?

✅ **Vantagens**:
- AGLSRV6C está vazio (sem VMs/CTs)
- Zero risco de perda de dados
- Permite testar o cluster antes de mexer em AGLSRV6
- AGLSRV6 continua operacional durante testes

❌ **Desvantagens de AGLSRV6 criar o cluster**:
- Requer migração de TODAS as VMs/CTs antes
- Alto risco de downtime
- Processo mais complexo e demorado

---

## 📋 Pré-requisitos

### 1. Verificações de Rede

- [ ] WireGuard mesh funcionando (10.6.0.0/24)
- [ ] Conectividade entre todos os nós (ping test)
- [ ] Portas Corosync abertas (UDP 5405-5412)
- [ ] Porta SSH aberta (TCP 22)
- [ ] Latência aceitável (<100ms, ideal <10ms)

### 2. Verificações de Sistema

- [ ] **Todos os nós com mesmo timezone** (America/Sao_Paulo)
- [ ] **Relógios sincronizados** (NTP/timesyncd)
- [ ] **Mesma versão do Proxmox** (ou compatível)
- [ ] **Hostnames únicos e resolvíveis**
- [ ] **Root password access** entre nós

### 3. Verificações de Storage

- [ ] **AGLSRV6C**: Sem VMs/CTs (✅ confirmado)
- [ ] **AGLSRV6D**: Sem VMs/CTs (✅ confirmado)
- [ ] **AGLSRV6**: Backups de todas VMs/CTs (antes de entrar no cluster)

### 4. Verificações de Software

- [ ] `corosync-qdevice` instalado em AGLSRV1 (QDevice host)
- [ ] `pve-ha-manager` instalado em todos os nós
- [ ] Firewall rules configuradas (ou desabilitado para cluster traffic)

---

## 🔧 Fases de Implementação

### Fase 1: Preparação (PRÉ-JANELA DE MANUTENÇÃO)

**Objetivo**: Preparar AGLSRV6C, AGLSRV6D e AGLSRV1 (QDevice)

**Tempo estimado**: 30-45 minutos

**Ações**:
1. ✅ Verificar pré-requisitos em todos os nós
2. ✅ Instalar `corosync-qdevice` em AGLSRV1
3. ✅ Configurar firewall rules (se necessário)
4. ✅ Sincronizar relógios (NTP)
5. ✅ Documentar estado atual de AGLSRV6

**Scripts**: `01-prerequisites.sh`

### Fase 2: Criação do Cluster Base (PRÉ-JANELA)

**Objetivo**: Criar cluster com AGLSRV6C e AGLSRV6D

**Tempo estimado**: 15-20 minutos

**Ações**:
1. ✅ AGLSRV6C: `pvecm create agl-cluster --link0 10.6.0.22`
2. ✅ AGLSRV6D: `pvecm add 10.6.0.22 --link0 10.6.0.23`
3. ✅ Verificar status do cluster: `pvecm status`
4. ✅ Verificar quorum: `pvecm nodes`

**Scripts**: `02-create-cluster.sh`

### Fase 3: Configuração do QDevice (PRÉ-JANELA)

**Objetivo**: Adicionar voto externo para quorum

**Tempo estimado**: 10-15 minutos

**Ações**:
1. ✅ AGLSRV1: Instalar `corosync-qnetd`
2. ✅ AGLSRV6C: `pvecm qdevice setup 10.6.0.10`
3. ✅ Verificar QDevice: `pvecm status`
4. ✅ Testar failover: Desligar AGLSRV6D temporariamente

**Scripts**: `03-setup-qdevice.sh`

### Fase 4: Testes de Failover (PRÉ-JANELA)

**Objetivo**: Validar que o cluster está funcionando

**Tempo estimado**: 20-30 minutos

**Ações**:
1. ✅ Criar VM de teste em AGLSRV6C
2. ✅ Habilitar HA para a VM
3. ✅ Desligar AGLSRV6C e verificar migração automática
4. ✅ Testar perda de quorum (desligar 2 nós)
5. ✅ Verificar logs do cluster

**Scripts**: `04-test-cluster.sh`

### Fase 5: Integração do AGLSRV6 (JANELA DE MANUTENÇÃO)

**Objetivo**: Adicionar AGLSRV6 ao cluster

**Tempo estimado**: 1-2 horas

**⚠️ REQUER JANELA DE MANUTENÇÃO ⚠️**

**Ações**:
1. 🔴 **Notificar usuários** (downtime de 1-2 horas)
2. 🔴 **Migrar VMs/CTs críticos** para AGLSRV6C/AGLSRV6D (ou desligar)
3. 🔴 **Backup completo** de AGLSRV6
4. 🔴 AGLSRV6: `pvecm add 10.6.0.22 --link0 10.6.0.12`
5. 🔴 Verificar cluster status
6. 🔴 Migrar VMs/CTs de volta (se necessário)
7. 🔴 Testar HA e failover

**Scripts**: `05-add-aglsrv6.sh` (⚠️ SOMENTE NA JANELA DE MANUTENÇÃO)

---

## 🌐 Configuração de Rede Recomendada

### Usar WireGuard como Cluster Network (RECOMENDADO)

**Por que WireGuard?**
- ✅ Criptografado
- ✅ Já configurado e estável
- ✅ Todos os nós já conectados
- ✅ Latência aceitável (~30-40ms)

**Configuração**:
```bash
# No pvecm create e pvecm add, usar:
--link0 <WIREGUARD_IP>

# Exemplo:
# AGLSRV6C: pvecm create agl-cluster --link0 10.6.0.22
# AGLSRV6D: pvecm add 10.6.0.22 --link0 10.6.0.23
# AGLSRV6: pvecm add 10.6.0.22 --link0 10.6.0.12
```

### Redundância de Links (OPCIONAL)

Adicionar LAN como link secundário (apenas para AGLSRV6C e AGLSRV6D que estão na mesma rede local):

```bash
# Exemplo com 2 links:
pvecm add 10.6.0.22 --link0 10.6.0.23 --link1 192.168.0.234
```

**Nota**: AGLSRV6 está em local diferente, então não tem acesso à LAN 192.168.0.x

---

## 📦 Pacotes Necessários

### Em todos os nós do cluster:
```bash
apt-get update
apt-get install -y pve-ha-manager corosync pve-cluster
```

### No QDevice host (AGLSRV1):
```bash
apt-get update
apt-get install -y corosync-qnetd corosync-qdevice
```

---

## 🔒 Firewall Rules

### Proxmox Cluster (todos os nós)

**Corosync**:
```bash
# UDP ports 5405-5412
iptables -A INPUT -p udp --dport 5405:5412 -j ACCEPT
```

**SSH**:
```bash
# TCP port 22
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

**QDevice**:
```bash
# TCP port 5403 (no QDevice host e nos cluster nodes)
iptables -A INPUT -p tcp --dport 5403 -j ACCEPT
```

**Nota**: Se usando Proxmox firewall GUI, adicionar rules via interface web.

---

## ✅ Checklist de Execução

### Antes de Começar
- [ ] Todos os scripts criados e revisados
- [ ] Backup completo de AGLSRV6
- [ ] Documentação completa lida
- [ ] Janela de manutenção agendada (mínimo 2 horas)
- [ ] Usuários notificados sobre downtime

### Fase 1: Preparação (PRÉ-JANELA)
- [ ] Executar `01-prerequisites.sh` em todos os nós
- [ ] Verificar conectividade de rede
- [ ] Instalar pacotes necessários
- [ ] Sincronizar relógios

### Fase 2: Cluster Base (PRÉ-JANELA)
- [ ] Executar `02-create-cluster.sh` em AGLSRV6C
- [ ] Adicionar AGLSRV6D ao cluster
- [ ] Verificar status do cluster
- [ ] Verificar quorum (2/2 votes)

### Fase 3: QDevice (PRÉ-JANELA)
- [ ] Executar `03-setup-qdevice.sh` em AGLSRV1 e AGLSRV6C
- [ ] Verificar QDevice ativo
- [ ] Verificar quorum (2/3 votes com QDevice)

### Fase 4: Testes (PRÉ-JANELA)
- [ ] Executar `04-test-cluster.sh`
- [ ] Criar VM de teste
- [ ] Testar HA e failover
- [ ] Documentar resultados

### Fase 5: AGLSRV6 (JANELA DE MANUTENÇÃO)
- [ ] **INICIAR JANELA DE MANUTENÇÃO**
- [ ] Notificar usuários
- [ ] Migrar ou desligar VMs/CTs de AGLSRV6
- [ ] Backup final de AGLSRV6
- [ ] Executar `05-add-aglsrv6.sh`
- [ ] Verificar cluster status (3/3 nodes)
- [ ] Testar HA e failover completo
- [ ] Migrar VMs/CTs de volta
- [ ] **FINALIZAR JANELA DE MANUTENÇÃO**

---

## 🚨 Rollback Plan

### Se algo der errado:

**ANTES de adicionar AGLSRV6 ao cluster:**
```bash
# Em AGLSRV6C:
pvecm delnode man6d  # Remove AGLSRV6D

# Em AGLSRV6D:
systemctl stop pve-cluster
systemctl stop corosync
rm -rf /etc/pve/corosync.conf
rm -rf /etc/corosync/*
pvecm updatecerts -f  # Force recreation
```

**DEPOIS de adicionar AGLSRV6 ao cluster:**
⚠️ **MUITO MAIS COMPLEXO** - Requer reinstalação do Proxmox em AGLSRV6

**Melhor estratégia**: Testar tudo nas Fases 1-4 antes da Fase 5!

---

## 📊 Monitoramento Pós-Implementação

### Comandos de Monitoramento

```bash
# Status geral do cluster
pvecm status

# Listar nós
pvecm nodes

# Status do QDevice
pvecm status | grep -A5 "Qdevice"

# Logs do Corosync
journalctl -u corosync -f

# Logs do cluster
journalctl -u pve-cluster -f

# Status de HA
ha-manager status
```

---

## 📁 Scripts Criados

1. **`01-prerequisites.sh`** - Verificação de pré-requisitos
2. **`02-create-cluster.sh`** - Criação do cluster base
3. **`03-setup-qdevice.sh`** - Configuração do QDevice
4. **`04-test-cluster.sh`** - Testes de failover
5. **`05-add-aglsrv6.sh`** - ⚠️ Adicionar AGLSRV6 (JANELA MANUTENÇÃO)

---

## 📞 Suporte e Referências

**Documentação Oficial**:
- Proxmox Cluster Manager: https://pve.proxmox.com/pve-docs/chapter-pvecm.html
- QDevice Setup: https://pve.proxmox.com/pve-docs/chapter-pvecm.html#_corosync_external_vote_support
- High Availability: https://pve.proxmox.com/pve-docs/chapter-ha-manager.html

**Troubleshooting**:
- Cluster não forma quorum: Verificar portas UDP 5405-5412
- QDevice não conecta: Verificar porta TCP 5403
- Nó não entra no cluster: Verificar `/etc/pve` vazio

---

**Plano criado**: 2025-11-08
**Versão**: 1.0.0
**Status**: 📋 Aguardando janela de manutenção para Fase 5
**Próximos passos**: Executar Fases 1-4 (pré-janela), agendar Fase 5
