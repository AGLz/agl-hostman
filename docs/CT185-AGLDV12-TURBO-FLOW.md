# CT185 (agldv12) — Clone do agldv03 + Turbo Flow

> **Status**: Em configuração  
> **Criado**: 2026-03-16  
> **Origem**: Clone do CT179 (agldv03)

## Resumo

| Item | Valor |
|------|-------|
| **VMID** | 185 |
| **Hostname** | agldv12 |
| **IP LAN** | 192.168.0.185 |
| **IP LAN2** | 192.168.1.185 |
| **Stack** | Turbo Flow v4.0 (Ruflo v3.5) |

## Procedimento de Criação

### Opção A: Script único (recomendado)

Aguarda o backup terminar e executa tudo em sequência:

```bash
./scripts/proxmox/ct185-full-setup.sh
```

Com auth key do Tailscale (evita prompt interativo):

```bash
./scripts/proxmox/ct185-full-setup.sh --tailscale-authkey=tskey-auth-xxx
```

Pular instalação do Turbo Flow:

```bash
./scripts/proxmox/ct185-full-setup.sh --skip-turbo-flow
```

### Opção B: Passos manuais

### 1. Backup do CT179 (no aglsrv1)

O `pct clone` falha com bind mounts. Usar backup/restore:

```bash
ssh root@100.107.113.33 'vzdump 179 --mode snapshot --compress 0 --storage local'
```

Aguarde conclusão (~15-30 min para 78GB). O backup fica em `/var/lib/vz/dump/`.

### 2. Restore e configuração

```bash
./scripts/proxmox/clone-ct179-to-ct185.sh
```

Ou manualmente:

```bash
# Restore
ssh root@100.107.113.33 'pct restore 185 /var/lib/vz/dump/vzdump-lxc-179-YYYY_MM_DD-HH_MM_SS.tar --storage local-zfs'

# Configurar
ssh root@100.107.113.33 'pct set 185 --hostname agldv12'
ssh root@100.107.113.33 'pct set 185 --net0 "name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.185/24,ip6=dhcp,type=veth"'
ssh root@100.107.113.33 'pct set 185 --net1 "name=eth1,bridge=vmbr1,gw=192.168.1.1,ip=192.168.1.185/24,type=veth"'
ssh root@100.107.113.33 'pct start 185'
```

### 3. Resetar Tailscale (obrigatório — executar **dentro** do CT185)

O clone herda a identidade do agldv03. É preciso resetar para obter novo IP/config. **Executar dentro do CT**:

```bash
ssh root@192.168.0.185

# Dentro do CT (agldv12):
systemctl stop tailscaled
rm -rf /var/lib/tailscale/tailscaled.state
systemctl start tailscaled

tailscale up --accept-dns=false --hostname=aglsrv1-agldv12 --ssh
# (ou com auth key: tailscale up --authkey=tskey-auth-xxx --accept-dns=false --hostname=aglsrv1-agldv12 --ssh)
```

Ou via script (executa via SSH): `./scripts/proxmox/reset-tailscale-ct185.sh` (opcional: passar auth key como arg)

### 4. Instalar Turbo Flow

```bash
./scripts/proxmox/setup-turbo-flow-ct185.sh
```

## Turbo Flow v4.0

[Turbo Flow](https://github.com/marcuspat/turbo-flow) — ambiente agentic com:

- **Ruflo v3.5** — orquestração (60+ agentes, 215+ MCP tools)
- **Beads** — memória cross-session (git-native JSONL)
- **GitNexus** — knowledge graph do codebase
- **Git Worktrees** — isolamento por agente
- **6 plugins** — Agentic QE, Code Intel, Test Intel, Perf, Teammate, Gastown

### Comandos principais

```bash
turbo-status    # Status dos componentes
turbo-help      # Referência de comandos
rf-doctor       # Health check Ruflo
rf-swarm        # Swarm hierárquico (8 agentes)
bd-ready        # Estado do projeto (Beads)
gnx-analyze     # Indexar repo no knowledge graph
```

### Integração com AGL

- **LiteLLM**: agldv12 usa gateway em agldv03 (`http://100.94.221.87:4000`)
- **Tailscale**: **obrigatório resetar** após clone (passo 3) — clone herda identidade do agldv03
- **WireGuard**: opcional, seguir padrão dos outros dev containers

## Troubleshooting

### Plugin code-intelligence falhou (opcional)

O plugin depende de `@claude-flow/ruvector-upstream` que não existe mais. Usar override:

```bash
./scripts/proxmox/fix-turbo-flow-code-intelligence.sh root@192.168.0.185
```

Ou manualmente no CT: editar `~/.claude-flow/plugins/package.json` (ou `/opt/turbo-flow/.claude-flow/plugins/`), adicionar dependency + override, e rodar `npm install`.

## Issues conhecidos

| Item | Status | Nota |
|------|--------|------|
| **Ruflo doctor** | ❌ Invalid Version | Bug em dependência agentic-flow/@claude-flow (version vazia). Usar ruflo no agldv03 ou aguardar fix upstream. |
| **Beads** | ✅ | Pacote correto: `@beads/bd` — `npm i -g @beads/bd && bd init` |
| **Trivy (security-check)** | ⚠️ | Timeout ao baixar imagem Docker. Usar `--skip-docker` ou pré-pull: `docker pull aquasec/trivy:latest`. |

## Alternativa: DevPod

Para criar ambiente Turbo Flow via DevPod (sem clone de CT):

```bash
devpod up . --ide vscode
```

Ver [DEVPOD-TURBO-FLOW.md](DEVPOD-TURBO-FLOW.md) para o fluxo completo.

## Referências

- [DEVPOD-TURBO-FLOW.md](DEVPOD-TURBO-FLOW.md) — workflow DevPod + agl-hostman
- [TROUBLESHOOTING-AGLDV12.md](TROUBLESHOOTING-AGLDV12.md) — soluções detalhadas para Ruflo, Beads, Docker/Trivy
- [Turbo Flow README](https://github.com/marcuspat/turbo-flow)
- [INFRA.md](INFRA.md) — mapa de infraestrutura
- [CLAUDE-FLOW-LITELLM.md](CLAUDE-FLOW-LITELLM.md) — gateway multi-model
