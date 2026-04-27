# GStack Integration Summary for AGLz AI Agency

## Overview

Esta pasta contém a adaptação do **gstack** (por Garry Tan) para o ecossistema AGLz AI Agency, especificamente para os agentes executivos **Jarvis O (OpenClaw)** e **Jarvis H (Hermes)**.

## O que é GStack

GStack é um sistema de automação de browser headless de alta performance com:
- **Binary compilado** (~58MB) via Bun
- **Browser daemon persistente** - Chromium long-lived
- **Sistema de refs** - @e1, @e2 em vez de CSS selectors
- **HTTP API local** - comunicação via localhost
- **Sistema de skills** - definições em Markdown

## Arquivos Criados

### 1. Documentação

| Arquivo | Descrição |
|---------|-----------|
| `GSTACK_ARCHITECTURE_AGLZ.md` | Arquitetura completa da integração |
| `JARVIS_O_JARVIS_H_GSTACK_COMPLETE.md` | Documentação técnica completa |

### 2. Scripts de Instalação

| Arquivo | Descrição |
|---------|-----------|
| `install-gstack-aglz.sh` | Script de instalação para CT-203 e CT-204 |

### 3. Configurações

```
gstack/
├── config/
│   ├── jarvis-o.yaml    # Configuração Jarvis O (CT-203)
│   └── jarvis-h.yaml    # Configuração Jarvis H (CT-204)
└── skills/
    └── browse/
        └── SKILL.md     # Skill de browser automation
```

## Principais Adaptações para AGLz

### 1. A2A Protocol Integration

O gstack original é para uso individual. A versão AGLz adiciona:
- Comunicação A2A entre Jarvis O ↔ Jarvis H
- Controle remoto de browser entre agentes
- Broadcast de comandos para AGLz Crew

```typescript
// Jarvis O pode controlar browser do Jarvis H
/a2a message jarvis-h --type command --content "browse goto https://docs.aglz.ai"
```

### 2. Multi-Agent Support

- Cada agente tem seu próprio daemon Chromium isolado
- Cookies e estado são separados por agente
- Portas aleatórias (10000-60000) para evitar conflitos

### 3. Personas Integradas

- **Jarvis O**: Configurado com persona Satya Nadella + Tim Cook
- **Jarvis H**: Configurado com persona Demis Hassabis + Jeff Dean

### 4. Skills Específicas

- `browse` - Automação de browser
- `qa` - Testes de QA (a implementar)
- `ship` - Deployment (a implementar)
- `investigate` - Investigação de bugs (a implementar)

## Comandos Disponíveis

### Navegação
```bash
$gb goto https://aglz.ai
$gb back
$gb forward
$gb reload
```

### Snapshot (Sistema de Refs)
```bash
$gb snapshot -i      # Elementos interativos com @refs
$gb snapshot -D      # Diff contra snapshot anterior
$gb snapshot -a      # Screenshot anotado
$gb snapshot -C      # Elementos cursor-interactive (@c refs)
```

### Interação
```bash
$gb click @e3
$gb fill @e4 "texto"
$gb select @e5 "option"
$gb upload @e6 /path/to/file
```

### Visual
```bash
$gb screenshot /tmp/page.png
$gb pdf /tmp/page.pdf
$gb responsive /tmp/layout
```

### A2A
```bash
$gb a2a message jarvis-h "browse goto https://aglz.ai"
$gb a2a query jarvis-h status
$gb a2a broadcast "qa check all systems"
```

## Instalação

### Em CT-203 (Jarvis O)
```bash
ssh root@192.168.0.203
cd /opt
git clone https://github.com/aglz-ai/agl-hostman.git
cd agl-hostman/projects/aglz-crew
chmod +x install-gstack-aglz.sh
./install-gstack-aglz.sh jarvis-o 203
```

### Em CT-204 (Jarvis H)
```bash
ssh root@192.168.0.204
cd /opt
git clone https://github.com/aglz-ai/agl-hostman.git
cd agl-hostman/projects/aglz-crew
chmod +x install-gstack-aglz.sh
./install-gstack-aglz.sh jarvis-h 204
```

## Arquitetura de Comunicação

```
┌─────────────────────────────────────────────────────────────────┐
│                        AGLz AI Agency                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐         HTTP/API         ┌─────────────────┐  │
│  │  Jarvis O   │ ◄──────────────────────► │ Browser Daemon  │  │
│  │  CT-203     │   localhost:random       │   CT-203        │  │
│  │             │   Bearer Token           │   • Chromium    │  │
│  │  gstack CLI │                          │   • Playwright  │  │
│  └──────┬──────┘                          └─────────────────┘  │
│         │                                                       │
│         │ A2A Protocol                                          │
│         │ HTTP/8080                                             │
│         ▼                                                       │
│  ┌─────────────┐         HTTP/API         ┌─────────────────┐  │
│  │  Jarvis H   │ ◄──────────────────────► │ Browser Daemon  │  │
│  │  CT-204     │   localhost:random       │   CT-204        │  │
│  │             │   Bearer Token           │   • Chromium    │  │
│  │  gstack CLI │                          │   • Playwright  │  │
│  └─────────────┘                          └─────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Próximos Passos

1. [ ] **Testar instalação** em CTs de desenvolvimento
2. [ ] **Implementar skills adicionais** (qa, ship, investigate)
3. [ ] **Integrar com LiteLLM** em CT-207
4. [ ] **Criar dashboard** de monitoramento
5. [ ] **Documentar casos de uso** específicos da AGLz

## Referências

- **GStack Original**: https://github.com/garrytan/gstack
- **Playwright**: https://playwright.dev/
- **Bun**: https://bun.sh/

---

*Documento criado em: 2026-04-19*
*Versão: 1.0.0-aglz*
