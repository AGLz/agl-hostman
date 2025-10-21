# FGSRV All Hosts - Troubleshooting Summary

**Data**: 2025-10-20
**Hosts Corrigidos**: FGSRV3, FGSRV4, FGSRV5, FGSRV6
**Status**: ✅ **TODOS OS HOSTS CORRIGIDOS COM SUCESSO**

---

## 🎯 Problema Global

Todos os servidores FGSRV (3, 4, 5, 6) estavam com **repositórios APT quebrados** devido ao mirror da Locaweb descontinuado.

---

## 📊 Status Por Host

| Host | Hostname | Ubuntu | IP Tailscale | Status | Kept-Back |
|------|----------|--------|--------------|--------|-----------|
| **FGSRV3** | vps14419 | Focal 20.04 | 100.67.99.115 | ✅ OK | 0 pacotes |
| **FGSRV4** | vps22826 | Jammy 22.04 | 100.111.79.2 | ✅ OK | 9 pacotes (systemd) |
| **FGSRV5** | vps24136 | Jammy 22.04 | 100.71.107.26 | ✅ OK | 1 pacote (distro-info-data) |
| **FGSRV6** | vps41772 | Jammy 22.04 | 100.83.51.9 | ✅ OK | 0 pacotes |

---

## 🔍 Diagnóstico

### Problema Identificado

**Root Cause**: Repositório mirror da Locaweb descontinuado

```bash
# Erro comum em todos os hosts:
Err: http://ubuntu-archive.locaweb.com.br/ubuntu [release] Release
  404  Not Found [IP: 186.202.135.162 80]
```

### Verificações Realizadas

#### 1. Conectividade Tailscale
- ✅ Todos os hosts acessíveis via Tailscale
- ✅ Latência: 14-36ms (normal)
- ✅ DNS Tailscale funcionando (100.100.100.100)

#### 2. Configuração WireGuard
- ✅ FGSRV6: wg0 interface UP (10.6.0.5/24, 29 peers)
- ⚪ FGSRV3/4/5: Não verificado (não necessário)

#### 3. Resolução DNS
- ✅ DNS resolvendo corretamente
- ✅ Problema confirmado: Mirror Locaweb removido (404)

---

## 🔧 Correções Aplicadas

### Processo Executado em Todos os Hosts

#### 1. Backup dos Repositórios
```bash
cp /etc/apt/sources.list /etc/apt/sources.list.backup-20251020-HHMMSS
```

**Backups criados**:
- FGSRV3: `/etc/apt/sources.list.backup-20251020-205520`
- FGSRV4: `/etc/apt/sources.list.backup-20251020-205521`
- FGSRV5: `/etc/apt/sources.list.backup-20251020-205523`
- FGSRV6: `/etc/apt/sources.list.backup-20251020-203533`

#### 2. Substituição dos Repositórios
```bash
# Comando aplicado em todos os hosts
sed -i 's|http://ubuntu-archive.locaweb.com.br/ubuntu|http://br.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list
```

**Antes**:
```
deb http://ubuntu-archive.locaweb.com.br/ubuntu [focal|jammy] main restricted
```

**Depois**:
```
deb http://br.archive.ubuntu.com/ubuntu [focal|jammy] main restricted
```

#### 3. Limpeza de Cache APT
```bash
rm -rf /var/lib/apt/lists/*
apt clean
```

#### 4. Validação
```bash
apt update
```

**Resultados**:
- FGSRV3: ✅ 40.4 MB baixados, 1 pacote upgradable
- FGSRV4: ✅ 55.9 MB baixados, 21 pacotes upgradable → 9 kept-back
- FGSRV5: ✅ 56.1 MB baixados, 2 pacotes upgradable → 1 kept-back
- FGSRV6: ✅ 43.9 MB baixados, 36 pacotes upgradable → 0 kept-back

#### 5. Execução do Script upd.sh
```bash
DEBIAN_FRONTEND=noninteractive bash ~/upd.sh
```

**Script upd.sh**:
```bash
apt update && \
apt upgrade -y --allow-downgrades && \
apt full-upgrade -y && \
apt dist-upgrade -y && \
apt autoremove -y && \
apt clean -y
```

---

## ✅ Resultados Finais

### Por Host

#### FGSRV3 (Ubuntu 20.04 Focal)
```
Status: ✅ Totalmente atualizado
Packages: 0 upgraded, 0 to remove, 0 not upgraded
Kept-back: Nenhum
```

#### FGSRV4 (Ubuntu 22.04 Jammy)
```
Status: ✅ Atualizado (9 kept-back)
Packages: 0 upgraded, 0 to remove, 9 not upgraded
Kept-back: systemd, systemd-sysv, systemd-timesyncd, libnss-systemd,
           libpam-systemd, libsystemd0, libudev1, udev, distro-info-data
Motivo: Pacotes systemd requerem cuidado especial (podem requerer reboot)
```

#### FGSRV5 (Ubuntu 22.04 Jammy)
```
Status: ✅ Atualizado (1 kept-back)
Packages: 0 upgraded, 0 to remove, 1 not upgraded
Kept-back: distro-info-data
Solução: apt install -y distro-info-data (se necessário)
```

#### FGSRV6 (Ubuntu 22.04 Jammy)
```
Status: ✅ Totalmente atualizado
Packages: 0 upgraded, 0 to remove, 0 not upgraded
Kept-back: Nenhum
Problema adicional corrigido: dpkg --configure -a (iptables-persistent)
```

---

## 📋 Pacotes Kept-Back

### Por que alguns pacotes ficaram kept-back?

**Kept-back** significa que o APT decidiu NÃO atualizar automaticamente porque:
1. **Dependências complexas**: Pacote requer instalação de novos pacotes
2. **Segurança**: Pacotes críticos do sistema (systemd) requerem atenção manual
3. **Configuração**: Pode requerer intervenção ou reboot

### FGSRV4: Pacotes Systemd (9 kept-back)

```bash
# Pacotes relacionados ao systemd:
- systemd
- systemd-sysv
- systemd-timesyncd
- libnss-systemd
- libpam-systemd
- libsystemd0
- libudev1
- udev
- distro-info-data
```

**Recomendação**:
```bash
# Atualizar systemd manualmente (PODE REQUERER REBOOT):
apt install -y systemd systemd-sysv systemd-timesyncd libnss-systemd \
               libpam-systemd libsystemd0 libudev1 udev distro-info-data

# Verificar se reboot é necessário:
[ -f /var/run/reboot-required ] && echo "REBOOT REQUIRED" || echo "NO REBOOT"
```

### FGSRV5: distro-info-data (1 kept-back)

```bash
# Atualizar manualmente se necessário:
apt install -y distro-info-data
```

---

## 🔒 Tailscale e WireGuard - Verificação

### Tailscale
- ✅ **Todos os hosts conectados via Tailscale**
- ✅ **DNS funcionando** (100.100.100.100)
- ✅ **Resolução de nomes OK**
- ✅ **Não foi a causa do problema**

### WireGuard (FGSRV6)
- ✅ **Interface wg0 UP** (10.6.0.5/24)
- ✅ **29 peers configurados**
- ✅ **Não interferiu no DNS ou APT**
- ✅ **Não foi a causa do problema**

---

## 🎬 Comandos Úteis

### Verificar Status APT
```bash
apt update
apt list --upgradable
apt list --installed | grep -i held
```

### Instalar Pacotes Kept-Back
```bash
# FGSRV4 - Systemd (CUIDADO: pode requerer reboot)
apt install -y systemd systemd-sysv systemd-timesyncd

# FGSRV5 - distro-info-data
apt install -y distro-info-data
```

### Verificar se Reboot é Necessário
```bash
[ -f /var/run/reboot-required ] && cat /var/run/reboot-required || echo "No reboot required"
```

### Reverter Mudanças (se necessário)
```bash
# FGSRV3
cp /etc/apt/sources.list.backup-20251020-205520 /etc/apt/sources.list

# FGSRV4
cp /etc/apt/sources.list.backup-20251020-205521 /etc/apt/sources.list

# FGSRV5
cp /etc/apt/sources.list.backup-20251020-205523 /etc/apt/sources.list

# FGSRV6
cp /etc/apt/sources.list.backup-20251020-203533 /etc/apt/sources.list

apt update
```

---

## 📈 Estatísticas

### Tempo de Execução
- **Diagnóstico**: ~15 minutos
- **Correção por host**: ~5 minutos
- **upd.sh por host**: ~2-5 minutos
- **Total**: ~30-40 minutos para 4 hosts

### Dados Baixados
- FGSRV3: 40.4 MB
- FGSRV4: 55.9 MB
- FGSRV5: 56.1 MB
- FGSRV6: 43.9 MB
- **Total**: ~196 MB

### Pacotes Atualizados
- FGSRV3: 1 pacote inicial → 0 kept-back
- FGSRV4: 21 pacotes iniciais → 9 kept-back (systemd)
- FGSRV5: 2 pacotes iniciais → 1 kept-back (distro-info-data)
- FGSRV6: 36 pacotes iniciais → 0 kept-back

---

## 💡 Recomendações

### Imediato
1. ✅ **Manter repositórios oficiais** (br.archive.ubuntu.com)
2. ⚠️ **Avaliar pacotes kept-back no FGSRV4** (systemd pode requerer reboot)
3. ⚪ **Opcional**: Atualizar distro-info-data no FGSRV5

### Curto Prazo
1. **Monitorar**: Implementar verificação automática de saúde dos repositórios
2. **Documentar**: Manter registro de mirrors confiáveis
3. **Alertar**: Notificação quando repositórios falharem

### Longo Prazo
1. **Automação**: Script para verificar disponibilidade antes de apt update
2. **Redundância**: Adicionar repositórios secundários no sources.list
3. **Padronização**: Usar mesmos repositórios em todos os hosts

---

## 🔗 Arquivos Modificados

### Por Host

**FGSRV3 (100.67.99.115)**:
- `/etc/apt/sources.list` - Atualizado (focal)
- `/etc/apt/sources.list.backup-20251020-205520` - Backup

**FGSRV4 (100.111.79.2)**:
- `/etc/apt/sources.list` - Atualizado (jammy)
- `/etc/apt/sources.list.backup-20251020-205521` - Backup

**FGSRV5 (100.71.107.26)**:
- `/etc/apt/sources.list` - Atualizado (jammy)
- `/etc/apt/sources.list.backup-20251020-205523` - Backup

**FGSRV6 (100.83.51.9)**:
- `/etc/apt/sources.list` - Atualizado (jammy)
- `/etc/apt/sources.list.backup-20251020-203533` - Backup
- `/var/lib/dpkg/status` - dpkg corrigido

---

## 🎯 Conclusão

### Problema
❌ **Repositórios APT quebrados** (mirror Locaweb descontinuado) em **todos os 4 hosts**

### Causa Raiz
❌ **Mirror removido/descontinuado** pelo provedor (404 Not Found)

### Solução
✅ **Substituição por repositórios oficiais Ubuntu** (br.archive.ubuntu.com)

### Status Final
✅ **TODOS OS 4 HOSTS CORRIGIDOS E FUNCIONAIS**

| Componente | Status |
|------------|--------|
| **Repositórios APT** | ✅ Corrigidos |
| **apt update** | ✅ Funcionando |
| **upd.sh** | ✅ Executando normalmente |
| **Tailscale** | ✅ OK (não era o problema) |
| **WireGuard** | ✅ OK (não era o problema) |
| **DNS** | ✅ OK (não era o problema) |

---

## 📚 Relatórios Relacionados

- **FGSRV6 Detalhado**: `/root/host-admin/claudedocs/FGSRV6_TROUBLESHOOTING_REPORT.md`
- **Tailscale Performance**: `/root/host-admin/claudedocs/TAILSCALE_STORAGE_PERFORMANCE_SUMMARY.md`
- **Tailscale Storage**: `/root/host-admin/claudedocs/TAILSCALE_DISTRIBUTED_STORAGE.md`

---

*Report gerado em: 2025-10-20/21 00:03 UTC*
*Troubleshooting realizado por: Claude Code*
*Hosts corrigidos: FGSRV3, FGSRV4, FGSRV5, FGSRV6*
*Duração total: ~40 minutos*
*Status: ✅ **MISSÃO CUMPRIDA!***
