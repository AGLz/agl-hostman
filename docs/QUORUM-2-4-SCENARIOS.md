# Cenários de Quorum 2/4 - Cluster Proxmox

> **Configuração**: 3 nós + 1 QDevice = 4 votos totais
> **Quorum**: 2/4 votes (50% + 1 voto)
> **Data**: 2025-11-08

---

## 🎯 Por Que Quorum 2/4?

### Caso de Uso Principal
**AGLSRV6 é o servidor de produção principal**. Com quorum 2/4:
- ✅ AGLSRV6 + QDevice = cluster operacional
- ✅ AGLSRV6C e AGLSRV6D podem estar offline para manutenção simultânea
- ✅ Maior flexibilidade operacional

### Comparação com 3/4

**Quorum 3/4 (padrão)**:
```
4 votos totais, precisa de 3 para quorum (75%)
❌ AGLSRV6 + QDevice = 2/4 (SEM QUORUM)
✅ AGLSRV6 + AGLSRV6C + QDevice = 3/4 (OK)
```

**Quorum 2/4 (nossa configuração)**:
```
4 votos totais, precisa de 2 para quorum (50%)
✅ AGLSRV6 + QDevice = 2/4 (OK!)
✅ AGLSRV6 + AGLSRV6C = 2/4 (OK!)
✅ AGLSRV6C + AGLSRV6D = 2/4 (OK!)
```

---

## 📊 Matriz de Cenários

### ✅ Cenários com Quorum (2+ votos)

| Componentes Ativos | Votos | Status | Observação |
|-------------------|-------|--------|------------|
| AGLSRV6 + AGLSRV6C + AGLSRV6D + QDevice | 4/4 | ✅ TOTAL | Configuração ideal |
| AGLSRV6 + AGLSRV6C + AGLSRV6D | 3/4 | ✅ OK | QDevice offline |
| AGLSRV6 + AGLSRV6C + QDevice | 3/4 | ✅ OK | AGLSRV6D offline |
| AGLSRV6 + AGLSRV6D + QDevice | 3/4 | ✅ OK | AGLSRV6C offline |
| AGLSRV6C + AGLSRV6D + QDevice | 3/4 | ✅ OK | AGLSRV6 em manutenção |
| **AGLSRV6 + QDevice** | **2/4** | **✅ OK** | **AGLSRV6C/D podem estar offline!** |
| AGLSRV6 + AGLSRV6C | 2/4 | ✅ OK | QDevice e AGLSRV6D offline |
| AGLSRV6 + AGLSRV6D | 2/4 | ✅ OK | QDevice e AGLSRV6C offline |
| AGLSRV6C + AGLSRV6D | 2/4 | ✅ OK | AGLSRV6 e QDevice offline |
| AGLSRV6C + QDevice | 2/4 | ✅ OK | AGLSRV6 e AGLSRV6D offline |
| AGLSRV6D + QDevice | 2/4 | ✅ OK | AGLSRV6 e AGLSRV6C offline |

### ❌ Cenários SEM Quorum (1 voto)

| Componentes Ativos | Votos | Status | Ação |
|-------------------|-------|--------|------|
| AGLSRV6 sozinho | 1/4 | ❌ SEM QUORUM | Aguardar outro nó ou QDevice |
| AGLSRV6C sozinho | 1/4 | ❌ SEM QUORUM | Aguardar outro nó ou QDevice |
| AGLSRV6D sozinho | 1/4 | ❌ SEM QUORUM | Aguardar outro nó ou QDevice |
| QDevice sozinho | 1/4 | ❌ SEM QUORUM | Aguardar qualquer nó |

---

## 🔧 Cenários Práticos de Operação

### Cenário 1: Manutenção em AGLSRV6C e AGLSRV6D

**Situação**: Atualizar/reiniciar AGLSRV6C e AGLSRV6D simultaneamente

**Com quorum 2/4**:
```
1. AGLSRV6C offline (3/4 votes - OK)
2. AGLSRV6D offline (2/4 votes - OK!)
3. AGLSRV6 + QDevice continuam operacionais
4. VMs em AGLSRV6 continuam rodando normalmente
```

**Com quorum 3/4** (não temos mais):
```
1. AGLSRV6C offline (3/4 votes - OK)
2. AGLSRV6D offline (2/4 votes - PERDA DE QUORUM!)
3. Cluster entra em modo read-only
4. VMs podem não iniciar
```

### Cenário 2: Problema em AGLSRV6 (Produção)

**Situação**: AGLSRV6 precisa ser reiniciado urgentemente

**Com quorum 2/4**:
```
1. AGLSRV6 offline (3/4 votes - OK)
2. AGLSRV6C + AGLSRV6D + QDevice mantêm cluster
3. VMs podem ser migradas para AGLSRV6C ou AGLSRV6D
4. HA funciona normalmente
```

### Cenário 3: QDevice (AGLSRV1) Offline

**Situação**: AGLSRV1 está sendo atualizado

**Com quorum 2/4**:
```
1. QDevice offline (3/4 votes - OK)
2. AGLSRV6 + AGLSRV6C + AGLSRV6D mantêm cluster
3. Ainda tem quorum com os 3 nós
4. Operação normal
```

### Cenário 4: Rede Particionada

**Situação**: WireGuard cai entre AGLSRV6 e AGLSRV6C/D

**Partição A**: AGLSRV6 + QDevice = 2/4 ✅
**Partição B**: AGLSRV6C + AGLSRV6D = 2/4 ✅

⚠️ **ATENÇÃO**: AMBAS as partições têm quorum!
- Risco de split-brain se não houver fencing
- QDevice ajuda: Vai ficar apenas com uma partição
- AGLSRV6C/D perdem acesso ao QDevice = 2/4 mas provavelmente não verão o AGLSRV1

**Mitigação**:
- QDevice está em AGLSRV1 (rede diferente de AGLSRV6C/D)
- Se WireGuard cair, AGLSRV6C/D perdem QDevice também
- Configurar fencing seria ideal (mas não obrigatório)

---

## 🎛️ Comandos de Verificação

### Verificar Status do Quorum
```bash
# Status completo
pvecm status

# Apenas quorum
pvecm status | grep -E '(Expected|Quorum|Quorate)'

# Exemplo de saída:
# Expected votes:   4
# Quorum:           2  ← Configurado para 2/4
# Quorate:          Yes
```

### Verificar Configuração
```bash
# Ver configuração do Corosync
cat /etc/pve/corosync.conf | grep -A5 quorum

# Ajustar expected votes (se necessário)
pvecm expected 2
```

### Simular Falha de Nó
```bash
# Parar corosync em um nó para testar
systemctl stop corosync pve-cluster

# Verificar que cluster ainda tem quorum em outros nós
pvecm status | grep Quorate  # Deve mostrar "Yes"

# Reativar
systemctl start pve-cluster corosync
```

---

## 📈 Vantagens e Desvantagens

### ✅ Vantagens do Quorum 2/4

1. **Flexibilidade Operacional**
   - Manutenção em múltiplos nós simultaneamente
   - AGLSRV6 continua operacional sozinho com QDevice

2. **Alta Disponibilidade**
   - Cluster aguenta perda de 2 componentes
   - Menos interrupções operacionais

3. **Produção Resiliente**
   - AGLSRV6 (produção) nunca perde quorum se QDevice estiver online
   - Ideal para ambiente onde AGLSRV6 é crítico

### ⚠️ Desvantagens e Cuidados

1. **Risco de Split-Brain** (baixo mas existe)
   - Se rede particionar, ambos os lados podem ter quorum
   - Mitigado por QDevice em rede separada
   - Fencing seria ideal (mas não essencial)

2. **Requer Monitoramento**
   - Importante monitorar conectividade de rede
   - Alertas se QDevice ficar offline

3. **Não Recomendado pela Proxmox** sem fencing
   - Documentação recomenda maioria absoluta (3/4)
   - Mas em prática funciona bem com QDevice

---

## 🔐 Proteções Implementadas

### 1. QDevice em Rede Separada
- AGLSRV1 (QDevice) está em LAN (192.168.0.245)
- AGLSRV6C e AGLSRV6D em rede remota
- Se WireGuard cair, AGLSRV6C/D perdem acesso ao QDevice
- AGLSRV6 + QDevice mantêm quorum

### 2. Monitoramento
```bash
# Script de monitoramento (executar periodicamente)
#!/bin/bash
STATUS=$(pvecm status | grep "Quorate" | awk '{print $2}')
if [ "$STATUS" != "Yes" ]; then
    echo "⚠️ ALERTA: Cluster SEM quorum!"
    # Enviar notificação
fi
```

### 3. Procedimento de Emergência
Se cluster perder quorum:
```bash
# Verificar qual nó tem mais componentes ativos
pvecm status

# Forçar quorum temporariamente (emergência)
pvecm expected 1

# IMPORTANTE: Restaurar para 2 após resolver o problema!
pvecm expected 2
```

---

## 📋 Checklist de Validação

Após implementação, validar:

- [ ] `pvecm status | grep "Quorum"` mostra `2`
- [ ] `pvecm status | grep "Quorate"` mostra `Yes`
- [ ] Testar: Parar AGLSRV6D, cluster mantém quorum
- [ ] Testar: Parar AGLSRV6C também, cluster mantém quorum (AGLSRV6 + QDevice)
- [ ] Testar: Reiniciar todos os nós, quorum restaurado
- [ ] Monitoramento de quorum configurado
- [ ] Alertas configurados para perda de QDevice

---

**Documento criado**: 2025-11-08
**Configuração**: Quorum 2/4 para máxima flexibilidade operacional
**Status**: Configuração recomendada para este ambiente
