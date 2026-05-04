# CT178 (aglfs1) - Tailscale Setup

> **Data**: 2025-12-22
> **Container**: CT178 (aglfs1)
> **Host**: AGLSRV1 (192.168.0.245)
> **Status**: ✅ Configurado

## Informações de Conexão

| Tipo | Endereço | Notas |
|------|----------|-------|
| **LAN IP** | 192.168.0.178 | Rede local |
| **Tailscale IP** | 100.69.187.105 | ✅ Ativo |
| **Hostname** | aglfs1 | Container name |

## Acesso via Tailscale

### SSH
```bash
ssh root@100.69.187.105
```

### NFS
```bash
# Montar NFS via Tailscale
mount -t nfs4 100.69.187.105:/mnt/shares /mnt/aglfs1-ts
```

### SMB/CIFS
```bash
# Windows
\\100.69.187.105\shares

# Linux/Mac
smb://100.69.187.105/shares
```

## Configuração

O Tailscale foi instalado e configurado usando o script:
```bash
/scripts/setup-tailscale-ct178.sh
```

### Status do Serviço
```bash
# Verificar status
pct exec 178 -- tailscale status

# Ver IP do Tailscale
pct exec 178 -- tailscale ip -4
```

### Serviço Automático
O serviço `tailscaled` está configurado para iniciar automaticamente:
```bash
pct exec 178 -- systemctl status tailscaled
```

## Integração com Outros Serviços

### Prioridade de Conexão (do CT179)
| Destino | 1ª Prioridade | 2ª Prioridade | 3ª Prioridade |
|---------|---------------|----------------|---------------|
| CT178 | LAN (192.168.0.178) | Tailscale (100.69.187.105) | - |

### Acesso Remoto
- ✅ Acessível via Tailscale de qualquer localização
- ✅ Útil para acesso de WSL2 (AGLHQ11) que só tem Tailscale
- ✅ Backup quando WireGuard não está disponível

## Notas

- O Tailscale deve ser configurado com `--accept-routes=false` para preservar a rota LAN local do CT
- O serviço está habilitado para iniciar automaticamente no boot
- IP Tailscale: **100.69.187.105** (atribuído automaticamente)

## Script de Setup

O script `setup-tailscale-ct178.sh` realiza:
1. ✅ Instalação do Tailscale no container
2. ✅ Autenticação (requer URL de login)
3. ✅ Configuração do serviço automático
4. ✅ Verificação do status e IP

## Referências

- **Script**: `/scripts/setup-tailscale-ct178.sh`
- **Documentação Tailscale**: `docs/CONNECTIONS.md`
- **Infraestrutura**: `docs/INFRASTRUCTURE-STATUS.md`

