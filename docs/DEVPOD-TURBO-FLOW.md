# DevPod + Turbo Flow — agl-hostman

> Workflow: criar ambiente Turbo Flow via DevPod, usar com código agl-hostman, verificar funções.

---

## Visão geral

1. **DevPod** cria o container com Turbo Flow v4.0 (Ruflo, Beads, GitNexus, etc.)
2. O **código agl-hostman** já está no workspace (é este repositório)
3. **Verificação** confirma que todas as funções do Turbo Flow estão ativas

---

## Pré-requisitos

### Instalar DevPod

**Linux:**
```bash
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
sudo install devpod /usr/local/bin
```

**macOS:**
```bash
brew install loft-sh/devpod/devpod
```

**Windows:**
```bash
choco install devpod
```

---

## Passo 1: Criar ambiente inicial

```bash
# Na pasta do projeto agl-hostman
cd /mnt/overpower/apps/dev/agl/agl-hostman

# Subir DevPod (usa .devcontainer/devcontainer.json)
devpod up . --ide vscode
```

O `postCreateCommand` do devcontainer:
1. Instala tmux, htop
2. Clona turbo-flow (ou turbo-flow-claude)
3. Copia `devpods/` para o workspace
4. Executa `devpods/setup.sh` (10 passos: Node, Ruflo, plugins, Beads, GitNexus, etc.)

**Tempo estimado**: 5–15 min (depende da rede).

---

## Passo 2: Código agl-hostman

O workspace do DevPod é o próprio repositório agl-hostman. O código já está presente — não é necessário clonar ou copiar.

Se estiver criando a partir do **turbo-flow** puro e quiser o agl-hostman:

```bash
# Dentro do container
cd /workspaces
git clone <url-do-agl-hostman> agl-hostman
cd agl-hostman
```

Ou use `devpod up` diretamente no clone local do agl-hostman (recomendado).

---

## Passo 3: Verificar funções Turbo Flow

Dentro do container, após o setup:

```bash
# Recarregar shell
source ~/.bashrc  # ou source ~/.zshrc

# 1. Status geral
turbo-status

# 2. Ruflo
rf-doctor
rf-plugins

# 3. Beads (memória cross-session)
bd init
bd ready

# 4. GitNexus (knowledge graph)
gnx-analyze
gnx-serve  # opcional: UI local

# 5. Worktrees (isolamento por agente)
wt-list

# 6. Swarm
rf-swarm
```

### Checklist de verificação

| Função | Comando | Esperado |
|--------|---------|----------|
| Claude Code | `claude -V` | Versão exibida |
| Ruflo | `rf-doctor` | Health OK |
| Beads | `bd ready` | Estado do projeto |
| GitNexus | `gnx-analyze` | Repo indexado |
| Plugins | `rf-plugins` | 6 plugins listados |
| Statusline | (no prompt) | 3 linhas de status |

---

## Integração AGL

O devcontainer define `LITELLM_GATEWAY_URL=http://100.94.221.87:4000` (agldv03).

Para usar LiteLLM local ou outro host, ajuste em `~/.claude/turbo-flow.env`:

```bash
echo 'LITELLM_GATEWAY_URL=http://100.94.221.87:4000' >> ~/.claude/turbo-flow.env
```

---

## Comandos úteis DevPod

```bash
devpod up .              # Criar/abrir workspace
devpod ssh               # SSH no container
devpod stop              # Parar workspace
devpod delete            # Remover workspace
devpod list              # Listar workspaces
```

---

## Estrutura após setup

```
/workspaces/agl-hostman/   # ou containerWorkspaceFolder
├── devpods/               # Copiado do turbo-flow
│   ├── setup.sh
│   ├── post-setup.sh
│   └── ...
├── src/
├── tests/
├── docs/
└── ... (código agl-hostman)
```

---

## Referências

- [Turbo Flow README](https://github.com/marcuspat/turbo-flow)
- [DevPod Docs](https://devpod.sh/docs)
- [CT185-AGLDV12-TURBO-FLOW.md](CT185-AGLDV12-TURBO-FLOW.md) — setup em CT185
