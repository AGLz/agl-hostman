# 🔐 INFORMAÇÕES DE ACESSO - VPS LOCAWEB

**Data:** 2025-10-22
**Objetivo:** Documentar acesso SSH aos hosts VPS Locaweb para implementação de correções

---

## 🌐 HOSTS VPS LOCAWEB

### FGSRV6 (✅ CONFIRMADO)
```
Hostname: fgsrv6
IP Tailscale: 100.83.51.9 (PREFERIDO - MÉTODO PRIMÁRIO)
IP Público: 186.202.57.120 (alternativo)
IP WireGuard: 10.6.0.5 (legado - descontinuado)
VPS ID: vps41772
Serviço: WireGuard Hub (18+ peers)
Acesso SSH: ssh root@100.83.51.9 (via Tailscale - RECOMENDADO)
         OU ssh root@186.202.57.120 (via IP público)
```

### FGSRV3 (❓ A CONFIRMAR)
```
Hostname: fgsrv3
Serviço: MySQL Database Server
IP: [A DESCOBRIR]
Acesso: [A CONFIGURAR]
Necessário para: Correção #1 (Backup reschedule - 70% impacto)
```

### FGSRV4 (❓ A CONFIRMAR)
```
Hostname: fgsrv4
Serviço: nginx + PHP5
Website: https://falg.com.br
IP: [A DESCOBRIR]
Acesso: [A CONFIGURAR]
Necessário para: Correções #2, #3, #5
```

### FGSRV5 (❓ A CONFIRMAR)
```
Hostname: fgsrv5
Serviço: nginx + Laravel
API: https://api.falg.com.br
IP WireGuard: 10.6.0.11 (POSSÍVEL)
Acesso: ssh root@10.6.0.11 (via WireGuard - TESTAR)
Necessário para: Correções #2, #3, #5
```

---

## 🔍 PASSOS PARA DESCOBRIR ACESSO

### Opção 1: Via WireGuard Mesh (RECOMENDADO)

Os hosts podem estar na rede WireGuard 10.6.0.x:

```bash
# Testar conectividade via WireGuard
for ip in 10.6.0.{1..254}; do
    timeout 1 ping -c 1 $ip &>/dev/null && echo "$ip responde"
done

# Verificar peers WireGuard
wg show | grep -A 10 "peer:"

# Tentar SSH nos IPs conhecidos do WireGuard
ssh root@10.6.0.11  # Possível fgsrv5
ssh root@10.6.0.5   # fgsrv6 (confirmado)
```

### Opção 2: Consultar Painel Locaweb

1. Acessar painel de controle Locaweb
2. Listar todos os VPS ativos
3. Obter IPs públicos de fgsrv3, fgsrv4, fgsrv5

### Opção 3: Via DNS/Domínios

```bash
# Resolver domínios para IPs
host falg.com.br
host api.falg.com.br

# Tentar SSH nos IPs resolvidos
ssh root@$(host -t A falg.com.br | awk '{print $4}')
ssh root@$(host -t A api.falg.com.br | awk '{print $4}')
```

### Opção 4: Verificar ~/.ssh/known_hosts

```bash
# Buscar hosts conhecidos anteriormente
grep -E "fgsrv|falg|10\.6\.0" ~/.ssh/known_hosts
```

---

## 🧪 TESTES DE CONECTIVIDADE

### Teste 1: WireGuard Peers
```bash
# Ver lista completa de peers
wg show all

# Tentar ping em todos os peers conhecidos
wg show | grep "endpoint:" | awk '{print $2}' | cut -d: -f1 | while read ip; do
    echo "Testando $ip..."
    timeout 2 ping -c 1 $ip && echo "  ✅ $ip responde"
done
```

### Teste 2: Scan de Rede WireGuard
```bash
# Scan da rede 10.6.0.0/24 (WireGuard mesh)
nmap -sn 10.6.0.0/24 2>/dev/null | grep -B 2 "Host is up"
```

### Teste 3: SSH com Tentativas
```bash
# Tentar SSH em IPs comuns WireGuard
for i in 3 4 5 11 12 13; do
    echo "=== Testando 10.6.0.$i ==="
    timeout 5 ssh -o ConnectTimeout=3 root@10.6.0.$i "hostname" 2>&1
    echo ""
done
```

---

## 📝 AÇÕES NECESSÁRIAS

### URGENTE (ANTES DE IMPLEMENTAR CORREÇÕES):

1. **Descobrir IPs dos hosts fgsrv3, fgsrv4, fgsrv5**
   - [ ] Tentar conectividade via WireGuard (10.6.0.x)
   - [ ] Consultar painel Locaweb
   - [ ] Resolver via DNS dos domínios
   - [ ] Verificar documentação existente

2. **Configurar ~/.ssh/config** (após descobrir IPs)
   ```bash
   cat >> ~/.ssh/config <<'EOF'

   # VPS Locaweb - Timeout Fix Project
   Host fgsrv3
       HostName [IP_A_DESCOBRIR]
       User root
       IdentityFile ~/.ssh/id_rsa

   Host fgsrv4
       HostName [IP_A_DESCOBRIR]
       User root
       IdentityFile ~/.ssh/id_rsa

   Host fgsrv5
       HostName 10.6.0.11
       User root
       IdentityFile ~/.ssh/id_rsa

   Host fgsrv6
       HostName 186.202.57.120
       User root
       IdentityFile ~/.ssh/id_rsa
   EOF
   ```

3. **Testar Conectividade**
   ```bash
   for host in fgsrv3 fgsrv4 fgsrv5 fgsrv6; do
       echo "=== $host ==="
       ssh $host "hostname && uptime" || echo "  ❌ Falhou"
   done
   ```

4. **Verificar Permissões sudo**
   ```bash
   for host in fgsrv3 fgsrv4 fgsrv5; do
       ssh $host "sudo -n true" && echo "✅ $host: sudo OK" || echo "❌ $host: sudo necessita senha"
   done
   ```

---

## 🔑 INFORMAÇÕES DE AUTENTICAÇÃO

### Chaves SSH
```bash
# Verificar chaves disponíveis
ls -la ~/.ssh/id_*

# Se necessário, gerar nova chave
ssh-keygen -t ed25519 -C "vps-timeout-fix@agl"

# Copiar chave para hosts (após descobrir IPs)
ssh-copy-id root@[IP_HOST]
```

### Credenciais
- Usuário: `root` (padrão VPS Locaweb)
- Senha: [CONSULTAR PAINEL LOCAWEB OU VAULT]
- Porta SSH: 22 (padrão)

---

## 📊 STATUS ATUAL

| Host | IP Público | IP WireGuard | Status Acesso | Necessário Para |
|------|-----------|--------------|---------------|-----------------|
| fgsrv6 | 186.202.57.120 | 10.6.0.5 | ✅ CONFIRMADO | Não necessário para fix |
| fgsrv5 | ? | 10.6.0.11 (possível) | ⚠️ A TESTAR | Correções #2, #3, #5 |
| fgsrv4 | ? | ? | ❌ DESCONHECIDO | Correções #2, #3, #5 |
| fgsrv3 | ? | ? | ❌ DESCONHECIDO | Correção #1 (CRÍTICA - 70%) |

---

## 🚨 PRIORIDADE IMEDIATA

**ANTES DE EXECUTAR QUALQUER CORREÇÃO**, precisamos:

1. ✅ Descobrir IP/acesso do **fgsrv3** (MySQL) - CRÍTICO
2. ✅ Descobrir IP/acesso do **fgsrv4** (nginx/PHP5)
3. ✅ Descobrir IP/acesso do **fgsrv5** (Laravel)
4. ✅ Configurar ~/.ssh/config
5. ✅ Testar conectividade SSH
6. ✅ Verificar permissões sudo

**SEM ESSES ACESSOS, NÃO PODEMOS IMPLEMENTAR AS CORREÇÕES!**

---

## 💡 PRÓXIMO PASSO RECOMENDADO

```bash
# Execute este comando para tentar descobrir os hosts via WireGuard:
bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/discover-vps-hosts.sh
```

Se o script não existir, criar um para automatizar a descoberta.

---

**Criado por:** Hive Mind Troubleshooting
**Status:** 🔴 BLOQUEADOR - Acesso aos hosts necessário antes de prosseguir
**Próxima ação:** Descobrir IPs e configurar acesso SSH
