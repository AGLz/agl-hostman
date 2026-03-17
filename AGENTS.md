# agl-hostman

> Multi-agent orchestration framework for agentic coding

## Project Overview

A Claude Flow powered project

**Tech Stack**: TypeScript, Node.js
**Architecture**: Domain-Driven Design with bounded contexts
**Last Updated**: 2026-03-12

## Quick Start

### Installation
```bash
npm install
```

### Build
```bash
npm run build
```

### Test
```bash
npm test
```

### Development
```bash
npm run dev
```

## Agent Coordination

### Swarm Configuration

This project uses hierarchical swarm coordination for complex tasks:

| Setting | Value | Purpose |
|---------|-------|---------|
| Topology | `hierarchical` | Queen-led coordination (anti-drift) |
| Max Agents | 8 | Optimal team size |
| Strategy | `specialized` | Clear role boundaries |
| Consensus | `raft` | Leader-based consistency |

### When to Use Swarms

**Invoke swarm for:**
- Multi-file changes (3+ files)
- New feature implementation
- Cross-module refactoring
- API changes with tests
- Security-related changes
- Performance optimization

**Skip swarm for:**
- Single file edits
- Simple bug fixes (1-2 lines)
- Documentation updates
- Configuration changes

### Available Skills

Use `$skill-name` syntax to invoke:

| Skill | Use Case |
|-------|----------|
| `$swarm-orchestration` | Multi-agent task coordination |
| `$memory-management` | Pattern storage and retrieval |
| `$sparc-methodology` | Structured development workflow |
| `$security-audit` | Security scanning and CVE detection |

### Agent Types

| Type | Role | Use Case |
|------|------|----------|
| `researcher` | Requirements analysis | Understanding scope |
| `architect` | System design | Planning structure |
| `coder` | Implementation | Writing code |
| `tester` | Test creation | Quality assurance |
| `reviewer` | Code review | Security and quality |

## Code Standards

### File Organization
- **NEVER** save to root folder
- `/src` - Source code files
- `/tests` - Test files
- `/docs` - Documentation
- `/config` - Configuration files

### Quality Rules
- Files under 500 lines
- No hardcoded secrets
- Input validation at boundaries
- Typed interfaces for public APIs
- TDD London School (mock-first) preferred

### Commit Messages
```
<type>(<scope>): <description>

[optional body]

Co-Authored-By: claude-flow <ruv@ruv.net>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

## Security

### Critical Rules
- NEVER commit secrets, credentials, or .env files
- NEVER hardcode API keys
- Always validate user input
- Use parameterized queries for SQL
- Sanitize output to prevent XSS

### Path Security
- Validate all file paths
- Prevent directory traversal (../)
- Use absolute paths internally

## Memory System

### Storing Patterns
```bash
npx @claude-flow/cli memory store \
  --key "pattern-name" \
  --value "pattern description" \
  --namespace patterns
```

### Searching Memory
```bash
npx @claude-flow/cli memory search \
  --query "search terms" \
  --namespace patterns
```

## Infrastructure Operations (AGL)

Para tarefas de infra (Proxmox, CTs, DNS, túneis), consulte `docs/INFRA.md` e `CLAUDE.md` (seção Project). Padrões recorrentes:

| Operação | Comando / Observação |
|----------|----------------------|
| Restart CT | Executar **do host ou de outra máquina**, nunca do próprio CT (ex: CT179) |
| CT locked (snapshot) | `pct unlock <vmid>` antes de `pct start` |
| CT102 (pihole) parado | `pct unlock 102 && pct start 102` |
| Cloudflared (CT117) sem redirecionar | `pct exec 117 -- systemctl restart cloudflared` |
| DNS no aglsrv1 | Pi-hole (192.168.0.102) + Cloudflare (1.1.1.1) + Google (8.8.8.8); `tailscale set --accept-dns=false` |
| **OpenClaw em aglwk45** | VM104 (Windows) — verificar via host: `ssh root@192.168.0.245 'qm agent 104 ping'` e `qm guest exec 104 -- openclaw --version` |

### OpenClaw (multi-host)

| Host | IP | Verificação |
|------|-----|-------------|
| agldv03 | 100.94.221.87 | `source ~/.openclaw/zshrc-openclaw.env && openclaw status` |
| fgsrv06 | 100.83.51.9 | `ssh root@100.83.51.9 'openclaw status'` |
| aglwk45 (VM104) | 100.117.146.21 | Via AGLSRV1: `ssh root@192.168.0.245 'qm guest exec 104 -- openclaw --version'` |

Scripts: `scripts/verify-openclaw-aglwk45.sh`, `scripts/verify-openclaw-aglwk45.ps1`, `scripts/deploy-openclaw-config.sh`

## Links

- Documentation: https://github.com/ruvnet/claude-flow
- Issues: https://github.com/ruvnet/claude-flow/issues
