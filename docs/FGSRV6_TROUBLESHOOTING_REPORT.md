# FGSRV6 Troubleshooting Report

**Data**: 2025-10-20
**Host**: FGSRV6 (vps41772)
**IP Tailscale**: 100.83.51.9
**Status**: ✅ Problema resolvido

---

## 🎯 Problema Reportado

Script `~/upd.sh` falhando ao executar `apt update` com erros relacionados a repositórios quebrados.

---

## 🔍 Diagnóstico Realizado

### 1. Conectividade
- ✅ **Tailscale**: Funcionando (100.83.51.9)
- ✅ **WireGuard (wg0)**: Configurado e UP (10.6.0.5/24)
- ✅ **DNS**: Funcionando via Tailscale DNS (100.100.100.100)
- ✅ **Ping**: Latência 14-36ms (normal)

### 2. Configurações DNS
```bash
# /etc/resolv.conf
nameserver 100.100.100.100  # Tailscale DNS
search degu-chromatic.ts.net aglz.io
```

**Teste de resolução DNS**:
```bash
$ nslookup ubuntu-archive.locaweb.com.br
Server: 100.100.100.100
Address: 100.100.100.100#53
Name: ubuntu-archive.locaweb.com.br
Address: 186.202.135.162
```

✅ **DNS está funcionando corretamente**

### 3. Problema Identificado

**Root Cause**: Repositório mirror da **Locaweb descontinuado/removido**

```
Err:5 http://ubuntu-archive.locaweb.com.br/ubuntu jammy Release
  404  Not Found [IP: 186.202.135.162 80]
```

- DNS resolveu corretamente: `ubuntu-archive.locaweb.com.br` → `186.202.135.162`
- Servidor respondeu, mas retorna **404 Not Found**
- Mirror da Locaweb não existe mais ou foi removido

### 4. Problema Secundário

```
E: dpkg was interrupted, you must manually run 'dpkg --configure -a' to correct the problem.
```

Instalação anterior de `iptables-persistent` foi interrompida.

---

## 🔧 Solução Aplicada

### Passo 1: Backup do sources.list
```bash
cp /etc/apt/sources.list /etc/apt/sources.list.backup-20251020-203533
```

### Passo 2: Substituir repositórios
```bash
sed -i 's|http://ubuntu-archive.locaweb.com.br/ubuntu|http://br.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list
```

**Antes**:
```
deb http://ubuntu-archive.locaweb.com.br/ubuntu jammy main restricted
```

**Depois**:
```
deb http://br.archive.ubuntu.com/ubuntu jammy main restricted
```

### Passo 3: Corrigir dpkg interrompido
```bash
dpkg --configure -a
```

### Passo 4: Validar correção
```bash
apt update
```

**Resultado**:
```
Fetched 43.9 MB in 9s (5,011 kB/s)
Reading package lists... Done
Building dependency tree... Done
36 packages can be upgraded.
```

✅ **apt update funcionando perfeitamente!**

---

## 📊 Configurações de Rede

### Interfaces de Rede
```bash
# eth0 - Interface principal
186.202.57.120/24 via 186.202.57.1

# wg0 - WireGuard VPN
10.6.0.5/24 (29 peers configurados)

# tailscale0 - Tailscale VPN (implícito)
100.83.51.9
```

### Tabela de Rotas
```
default via 186.202.57.1 dev eth0 onlink
10.6.0.0/24 dev wg0 proto kernel scope link src 10.6.0.5
186.202.57.0/24 dev eth0 proto kernel scope link src 186.202.57.120
```

### WireGuard Peers (wg0.conf)
- 29 peers configurados
- Endpoints diversos (AGLSRV1, AGLSRV5, AGLSRV6 containers)
- PersistentKeepalive = 25 segundos

---

## ✅ Status Final

### Problemas Resolvidos
- ✅ Repositórios APT corrigidos (Locaweb → br.archive.ubuntu.com)
- ✅ apt update funcionando
- ✅ dpkg corrigido (iptables-persistent configurado)
- ✅ DNS funcionando via Tailscale
- ✅ Tailscale conectado e operacional
- ✅ WireGuard (wg0) UP e configurado

### Script upd.sh
```bash
#!/bin/bash
apt update && \
apt upgrade -y --allow-downgrades && \
apt full-upgrade -y && \
apt dist-upgrade -y && \
apt autoremove -y && \
apt clean -y
```

**Status**: ✅ Executando normalmente (36 pacotes para atualizar)

---

## 🔍 Análise Técnica

### Por que o DNS não foi o problema?

1. **Resolução DNS funcionou**:
   - `nslookup` resolveu o domínio corretamente
   - Servidor Tailscale DNS (100.100.100.100) respondeu
   - IP retornado: 186.202.135.162

2. **Conexão HTTP funcionou**:
   - apt conseguiu conectar ao servidor
   - Servidor respondeu com HTTP 404

3. **Problema real**:
   - Mirror da Locaweb **removeu os arquivos** Release
   - Servidor existe, mas conteúdo não está mais disponível

### Por que Tailscale/WireGuard não interferiram?

- **Tailscale DNS**: Apenas resolve nomes para IPs Tailscale
- **Fallback**: Para domínios externos, usa DNS upstream
- **WireGuard**: Não tem configuração de DNS própria
- **Rotas**: Tráfego para internet vai por eth0 (default route)

---

## 📝 Recomendações

### Imediato
1. ✅ Manter repositórios oficiais (br.archive.ubuntu.com)
2. ✅ Backup do sources.list mantido em `/etc/apt/sources.list.backup-20251020-203533`
3. ⏳ Aguardar conclusão do `apt upgrade` (36 pacotes)

### Futuro
1. **Monitoramento**: Implementar verificação de saúde dos repositórios
2. **Automação**: Script para verificar disponibilidade antes de `apt update`
3. **Redundância**: Adicionar repositórios secundários no sources.list
4. **Documentação**: Manter registro de mirrors confiáveis

---

## 🔗 Arquivos Modificados

- `/etc/apt/sources.list` - Repositórios atualizados
- `/etc/apt/sources.list.backup-20251020-203533` - Backup criado
- `/var/lib/dpkg/status` - dpkg corrigido

---

## 📚 Comandos Úteis

### Verificar status APT
```bash
apt update
apt list --upgradable
```

### Verificar DNS
```bash
cat /etc/resolv.conf
nslookup archive.ubuntu.com
```

### Verificar Tailscale
```bash
tailscale status
tailscale netcheck
```

### Verificar WireGuard
```bash
ip addr show wg0
wg show
```

### Reverter mudanças (se necessário)
```bash
cp /etc/apt/sources.list.backup-20251020-203533 /etc/apt/sources.list
apt update
```

---

## 🎯 Conclusão

**Problema**: Repositórios APT quebrados (mirror Locaweb descontinuado)
**Causa Raiz**: Mirror removido/descontinuado pelo provedor
**Solução**: Substituição por repositórios oficiais Ubuntu
**Status**: ✅ **RESOLVIDO**

**Tailscale e WireGuard**: ✅ Funcionando corretamente, não foram a causa do problema

---

*Report gerado em: 2025-10-20 23:38 UTC*
*Troubleshooting realizado por: Claude Code*
*Duração: ~15 minutos*
