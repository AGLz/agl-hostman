# Análise de Riscos - Cluster Proxmox

> **Data**: 2025-11-08
> **Cluster**: agl-cluster (AGLSRV6 + AGLSRV6C + AGLSRV6D)
> **Criticidade**: ALTA (AGLSRV6 em produção)

---

## 🚨 Riscos Identificados

### 1. Perda de Dados em AGLSRV6 (CRÍTICO)

**Probabilidade**: BAIXA (se seguir procedimentos)
**Impacto**: MUITO ALTO

**Risco**:
- Ao adicionar AGLSRV6 ao cluster, `/etc/pve` é sobrescrito
- Se houver VMIDs duplicados, pode haver conflitos
- Configurações personalizadas em `/etc/pve` podem ser perdidas

**Mitigação**:
- ✅ Backup completo de AGLSRV6 ANTES de adicionar ao cluster
- ✅ Verificar VMIDs duplicados entre nós
- ✅ Documentar todas as configurações personalizadas
- ✅ Testar cluster com AGLSRV6C/AGLSRV6D antes de adicionar AGLSRV6

---

### 2. Downtime em AGLSRV6 (ALTO)

**Probabilidade**: CERTA
**Impacto**: ALTO (usuários afetados)

**Risco**:
- Adicionar AGLSRV6 ao cluster causa downtime
- VMs/CTs podem ficar indisponíveis durante processo
- Processo pode levar 1-2 horas

**Mitigação**:
- ✅ Agendar janela de manutenção (mínimo 2 horas)
- ✅ Notificar usuários com antecedência (24-48h)
- ✅ Executar durante horário de baixo uso
- ✅ Ter plano de rollback pronto

---

### 3. Falha no Quorum (BAIXO)

**Probabilidade**: MUITO BAIXA
**Impacto**: MUITO ALTO (cluster inacessível)

**Risco**:
- Com quorum 3/4: Se 2+ nós falharem, cluster perde quorum
- Com quorum 2/4: Apenas se 3+ componentes falharem (muito improvável)

**Mitigação**:
- ✅ Quorum configurado para 2/4 (mais tolerante)
- ✅ Com 2/4: AGLSRV6 + QDevice = operacional (AGLSRV6C/D podem cair)
- ✅ QDevice em AGLSRV1 (voto externo independente)
- ✅ Monitorar status de quorum continuamente
- ✅ Ter procedimento de recuperação de quorum

**Vantagem do 2/4**:
- ✅ AGLSRV6 permanece operacional mesmo se AGLSRV6C e AGLSRV6D caírem juntos
- ✅ Permite manutenção simultânea em múltiplos nós
- ✅ Maior flexibilidade operacional

---

### 4. Latência de Rede (MÉDIO)

**Probabilidade**: MÉDIA
**Impacto**: MÉDIO (performance degradada)

**Risco**:
- Cluster via WireGuard tem latência ~30-40ms
- Proxmox recomenda <10ms para cluster
- Latência alta pode causar timeouts no Corosync

**Mitigação**:
- ✅ Usar WireGuard (melhor opção disponível)
- ✅ Configurar timeouts do Corosync adequadamente
- ✅ Monitorar latência entre nós
- ⚠️ Considerar não usar live migration entre AGLSRV6 e AGLSRV6C/AGLSRV6D

---

### 5. VMIDs Duplicados (MÉDIO)

**Probabilidade**: BAIXA
**Impacto**: ALTO (conflitos no cluster)

**Risco**:
- Se AGLSRV6 tiver VMID 100 e AGLSRV6C também
- Cluster não permite VMIDs duplicados
- Pode causar falha ao adicionar nó

**Mitigação**:
- ✅ AGLSRV6C e AGLSRV6D estão vazios (sem VMs/CTs)
- ✅ Listar VMIDs de AGLSRV6 antes de adicionar
- ✅ Documentar range de VMIDs por nó
- ✅ Estabelecer política de alocação de VMIDs

---

### 6. Split-Brain (BAIXO)

**Probabilidade**: MUITO BAIXA (com QDevice)
**Impacto**: MUITO ALTO (dados corrompidos)

**Risco**:
- Se rede particionar em 2 grupos
- Cada grupo pode achar que é o cluster ativo
- Dados podem ser corrompidos

**Mitigação**:
- ✅ QDevice fornece tie-breaker
- ✅ Configurar fencing (STONITH) se possível
- ✅ Monitorar conectividade de rede
- ✅ Usar WireGuard exclusivamente (evitar múltiplos paths)

---

### 7. Incompatibilidade de Versões (BAIXO)

**Probabilidade**: BAIXA
**Impacto**: MÉDIO (cluster instável)

**Risco**:
- AGLSRV6 pode ter versão diferente do Proxmox
- Versões incompatíveis podem causar problemas

**Mitigação**:
- ✅ Verificar versões do Proxmox em todos os nós
- ✅ Atualizar nós para mesma versão ANTES de criar cluster
- ✅ Proxmox VE 9.0 em AGLSRV6C e AGLSRV6D (confirmado)
- ⚠️ Verificar versão em AGLSRV6

---

### 8. Firewall Bloqueando Portas (BAIXO)

**Probabilidade**: BAIXA
**Impacto**: ALTO (cluster não forma)

**Risco**:
- Firewall bloqueando portas UDP 5405-5412 (Corosync)
- Firewall bloqueando porta TCP 5403 (QDevice)
- Cluster não consegue comunicar

**Mitigação**:
- ✅ Scripts verificam conectividade
- ✅ Proxmox geralmente libera portas automaticamente
- ✅ Documentar regras de firewall necessárias
- ✅ Testar comunicação antes de criar cluster

---

## 📋 Janela de Manutenção

### Planejamento da Janela

**Duração Estimada**: 2-3 horas
**Horário Recomendado**: Madrugada ou fim de semana
**Participantes**: Mínimo 2 pessoas (uma executando, outra monitorando)

### Timeline Detalhado

**Antes da Janela** (dias antes):
- T-48h: Notificar usuários
- T-24h: Backup completo de AGLSRV6
- T-12h: Confirmar backup bem-sucedido
- T-6h: Revisar procedimentos

**Durante a Janela**:
```
T+00:00 - Início da janela
  ├─ Notificar usuários (downtime iniciado)
  ├─ Verificar backup
  ├─ Listar VMs/CTs de AGLSRV6
  └─ DECISÃO: Migrar VMs ou manter?

T+00:15 - Migração de VMs críticas (se necessário)
  ├─ Migrar para AGLSRV6C ou AGLSRV6D
  ├─ Ou desligar VMs temporariamente
  └─ Verificar VMs funcionando

T+00:45 - Executar Script 5
  ├─ Confirmar 3x antes de executar
  ├─ Adicionar AGLSRV6 ao cluster
  ├─ Aguardar estabilização
  └─ Verificar quorum

T+01:15 - Verificações
  ├─ pvecm status (3 nós + QDevice)
  ├─ Listar VMs/CTs
  ├─ Testar acesso Web UI
  └─ Verificar logs

T+01:30 - Migrar VMs de volta (se foi migrado)
  ├─ Retornar VMs para AGLSRV6
  ├─ Testar funcionamento
  └─ Verificar performance

T+02:00 - Testes de HA
  ├─ Criar VM de teste
  ├─ Habilitar HA
  ├─ Testar migração
  └─ Testar failover (opcional)

T+02:30 - Finalização
  ├─ Notificar usuários (manutenção concluída)
  ├─ Atualizar documentação
  ├─ Criar relatório de manutenção
  └─ Fim da janela
```

### Critérios de Sucesso

✅ **Janela bem-sucedida se**:
- Cluster formado com 3 nós + QDevice
- Quorum funcional (3/4 votes)
- Todas as VMs/CTs acessíveis
- HA funcionando
- Sem erros nos logs

❌ **Rollback se**:
- Cluster não forma quorum
- VMs/CTs inacessíveis
- Erros críticos nos logs
- Downtime > 3 horas

---

## 🔄 Plano de Rollback

### Cenário 1: Antes de Adicionar AGLSRV6 ao Cluster

**Se algo der errado nos Scripts 1-4**:

```bash
# Remover AGLSRV6D do cluster
ssh root@10.6.0.22 "pvecm delnode man6d"

# Em AGLSRV6D, limpar configuração
ssh root@10.6.0.23 "systemctl stop pve-cluster corosync"
ssh root@10.6.0.23 "rm -rf /etc/pve/corosync.conf /etc/corosync/*"

# Em AGLSRV6C, destruir cluster se necessário
ssh root@10.6.0.22 "systemctl stop pve-cluster corosync"
ssh root@10.6.0.22 "rm -rf /etc/pve/corosync.conf /etc/corosync/*"
```

**Resultado**: AGLSRV6C e AGLSRV6D voltam a standalone
**Impacto**: ZERO (nós estavam vazios)

---

### Cenário 2: Depois de Adicionar AGLSRV6 ao Cluster

**⚠️ MUITO MAIS COMPLEXO**

**Opção A - Remover AGLSRV6 do Cluster**:
```bash
# Em AGLSRV6C, remover AGLSRV6
pvecm delnode man6

# Em AGLSRV6, limpar e reinstalar
# ⚠️ Isso pode causar perda de dados!
systemctl stop pve-cluster corosync pveproxy pvedaemon
pmxcfs -l  # Local mode
rm -rf /etc/pve/corosync.conf /etc/corosync/*
rm -rf /var/lib/corosync/*
```

**Opção B - Restaurar do Backup**:
```bash
# Reinstalar Proxmox em AGLSRV6
# Restaurar backup completo
# VMs/CTs serão restaurados do backup
```

**Resultado**: AGLSRV6 volta a standalone
**Impacto**: ALTO (possível perda de dados, downtime prolongado)

---

## 📊 Matriz de Riscos

| Risco | Probabilidade | Impacto | Prioridade | Mitigação |
|-------|--------------|---------|------------|-----------|
| Perda de dados AGLSRV6 | Baixa | Muito Alto | **CRÍTICA** | Backup completo |
| Downtime AGLSRV6 | Certa | Alto | **CRÍTICA** | Janela de manutenção |
| Falha de quorum | Baixa | Muito Alto | **ALTA** | QDevice configurado |
| Latência de rede | Média | Médio | **MÉDIA** | Monitorar performance |
| VMIDs duplicados | Baixa | Alto | **MÉDIA** | AGLSRV6C/D vazios |
| Split-brain | Muito Baixa | Muito Alto | **BAIXA** | QDevice + fencing |
| Incompatibilidade versão | Baixa | Médio | **BAIXA** | Verificar versões |
| Firewall bloqueando | Baixa | Alto | **BAIXA** | Verificação prévia |

---

## ✅ Checklist de Segurança

### Antes da Janela de Manutenção
- [ ] Backup completo de AGLSRV6 realizado e verificado
- [ ] Backup de configurações (`/etc/pve`, `/etc/network/interfaces`)
- [ ] Lista de VMIDs de AGLSRV6 documentada
- [ ] Versões do Proxmox verificadas em todos os nós
- [ ] Scripts 1-4 executados com sucesso
- [ ] Testes de failover validados
- [ ] Usuários notificados (48h de antecedência)
- [ ] Time de suporte disponível
- [ ] Plano de rollback revisado

### Durante a Janela de Manutenção
- [ ] Notificação de início de manutenção enviada
- [ ] VMs/CTs críticos migrados ou desligados
- [ ] Backup final confirmado
- [ ] 3 confirmações antes de executar Script 5
- [ ] Logs sendo monitorados em tempo real
- [ ] Time de suporte em standby

### Após Adicionar AGLSRV6
- [ ] Cluster formado com 3 nós + QDevice
- [ ] Quorum funcional (3/4 votes)
- [ ] Todas as VMs/CTs acessíveis
- [ ] Web UI acessível em todos os nós
- [ ] Logs sem erros críticos
- [ ] HA testado e funcionando
- [ ] Documentação atualizada
- [ ] Usuários notificados (manutenção concluída)
- [ ] Relatório de manutenção criado

---

## 📞 Contatos de Emergência

**Durante a janela de manutenção, ter disponível:**

- Documentação oficial do Proxmox
- Acesso SSH a todos os nós
- Acesso físico (se possível) ou IPMI/iLO
- Backup offline verificado
- Time de suporte em standby

---

## 📝 Lições Aprendidas (Preencher após implementação)

### O que funcionou bem?
- _A preencher após implementação_

### O que poderia ser melhorado?
- _A preencher após implementação_

### Problemas encontrados e soluções?
- _A preencher após implementação_

### Recomendações para futuro?
- _A preencher após implementação_

---

**Documento criado**: 2025-11-08
**Versão**: 1.0.0
**Próxima revisão**: Após implementação do cluster
**Status**: Aguardando janela de manutenção para Fase 5
