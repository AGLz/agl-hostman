# PegaProx - Gerenciamento Multi-Cluster Proxmox VE

> **Fonte**: [pegaprox.com](https://pegaprox.com) | **Licença**: AGPL-3.0 | **Status**: Beta, 100% gratuito

## Visão geral

PegaProx é uma plataforma open-source para gerenciar múltiplos clusters Proxmox VE em uma única interface. Principais recursos:

| Recurso | Descrição |
|---------|-----------|
| **Multi-cluster** | Gerencie vários clusters Proxmox em um painel |
| **Migração cross-cluster** | Migração live de VMs entre clusters |
| **Load balancing** | Distribuição inteligente de carga |
| **HA 2-node** | Suporte a alta disponibilidade em 2 nós |
| **LDAP/OIDC** | SSO com Active Directory, Entra ID |
| **Ceph** | Gerenciamento de clusters Ceph |
| **CVE Scanner** | Varredura de vulnerabilidades |

## Instalação no aglsrv1

### Opção 1: Deploy remoto (recomendado)

A partir do CT179 (agldv03) ou qualquer máquina com SSH ao aglsrv1:

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/scripts/pegaprox
./deploy-remote.sh 192.168.0.245   # via LAN
# ou
./deploy-remote.sh 100.107.113.33  # via Tailscale
```

O script cria o CT210, instala o PegaProx e configura o serviço.

### Opção 2: Execução direta no host

SSH no aglsrv1 e execute:

```bash
# Copiar script para o host
scp scripts/pegaprox/create-ct-and-install.sh root@192.168.0.245:/tmp/
ssh root@192.168.0.245 'chmod +x /tmp/create-ct-and-install.sh && /tmp/create-ct-and-install.sh'
```

### Opção 3: Instalação direta no host (sem CT)

Para instalar o PegaProx diretamente no host Proxmox (menos isolamento):

```bash
ssh root@192.168.0.245
curl -sSL https://raw.githubusercontent.com/PegaProx/project-pegaprox/refs/heads/main/deploy.sh | sudo bash
# Escolha porta 5000 ou 443 no prompt interativo
```

## Configuração pós-instalação

### Adicionar cluster Proxmox

1. Acesse `https://192.168.0.210:5000` (ou IP do host se instalado direto)
2. Crie usuário admin na primeira execução
3. **Settings → Clusters → Add Cluster**
4. Preencha:
   - **Name**: aglsrv1
   - **Host**: 192.168.0.245 (ou 10.6.0.10 via WireGuard)
   - **Port**: 8006
   - **User**: `root@pam` ou token API
   - **Verify SSL**: desmarque se usar certificado auto-assinado

### Token API Proxmox (recomendado)

Crie um token no Proxmox para acesso mais seguro:

1. Proxmox Web UI → Datacenter → Permissions → API Tokens
2. Add → Token ID: `pegaprox`, User: `root@pam`
3. Copie o secret e use em PegaProx

## Especificações do CT210

| Parâmetro | Valor |
|-----------|-------|
| VMID | 210 |
| Hostname | pegaprox |
| IP | 192.168.0.210 |
| RAM | 2GB |
| Disco | 32GB |
| Storage | local-zfs |
| Porta Web | 5000 |

## Comandos úteis

```bash
# Status do serviço
pct exec 210 -- systemctl status pegaprox

# Logs
pct exec 210 -- journalctl -u pegaprox -f

# Reiniciar
pct exec 210 -- systemctl restart pegaprox

# Atualizar (via UI)
# Settings → Updates → Check for Updates
```

## Acesso

| Rede | URL |
|------|-----|
| LAN | https://192.168.0.210:5000 |
| Tailscale | https://\<tailscale-ip\>:5000 (após `tailscale up`) |

### Tailscale no CT210

Tailscale instalado. Para conectar:

```bash
ssh root@192.168.0.245
pct exec 210 -- tailscale up --accept-dns=false --hostname=aglsrv1-pegaprox
```

Abra a URL exibida no navegador para autorizar o nó. Ou use auth key:

```bash
pct exec 210 -- tailscale up --authkey=tskey-auth-xxx --accept-dns=false --hostname=aglsrv1-pegaprox
```

## Referências

- [PegaProx Website](https://pegaprox.com)
- [GitHub](https://github.com/PegaProx/project-pegaprox)
- [Documentação](https://pegaprox.com/docs)
