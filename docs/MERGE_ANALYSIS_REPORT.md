# Análise de Merge - host-admin Project
**Data**: 2025-10-21
**Objetivo**: Consolidar conteúdos de 3 localizações em um repositório único no GitHub

## 📊 Resumo das Localizações

### 1. Local WSL: `/root/host-admin`
- **Tamanho**: 8.5M
- **Característica**: Versão de trabalho atual com documentação claudedocs/ mais recente
- **Conteúdo Exclusivo**:
  - claudedocs/ mais completa (52 documentos)
  - scripts/ organizados
  - .hive-mind/ com sessões

### 2. CT179 (agldv3): `/root/host-admin`
- **Tamanho**: 5.3M
- **Característica**: Versão organizada com estrutura de código
- **Conteúdo Exclusivo**:
  - **config/** - Configurações de infraestrutura
    - exports.example, fstab.example
    - monitoring, systemd templates
    - iSCSI, NFS, PBS setup scripts
  - **src/** - Código-fonte TypeScript/JavaScript
    - hive-mind-integration/ (AgentTemplates, HiveMindWorkerPool, PerformanceMonitor)
    - performance/worker-pool/
  - **tests/** - Testes automatizados
    - hive-mind integration tests
    - performance/worker-pool tests
  - **docs/** - Documentação estruturada (25 documentos)
    - Architecture summaries
    - Implementation checklists
    - Storage research
    - Performance testing
    - Network topology
  - **examples/** - Exemplos de uso
    - hive-mind-neural-training.js
    - hive-mind-parallel-agents.js
  - **logs/** - Diretório de logs

### 3. CT179 (agldv3): `/mnt/overpower/apps/dev/agl/hostman`
- **Tamanho**: 811K
- **Característica**: Projeto específico Hive/Migration
- **Conteúdo**:
  - **hive/** (analysis, code, testing)
  - **migration-strategy/** (PHP compatibility, route mapping)
  - **migration-tools/** (ferramentas de migração)
  - **compatibility-shims/**
  - RESEARCH_FINDINGS_FGSRV05_APIS.md
  - HIVE_IMMEDIATE_PHASE_COMPLETE.md

## 🎯 Estratégia de Merge Proposta

### Fase 1: Backup
- ✅ Criar backup completo da pasta local atual
- Preservar estrutura git existente

### Fase 2: Integração de Estruturas
1. **Manter base local** (8.5M) como fundação
2. **Adicionar do CT179 /root/host-admin**:
   - config/ → /root/host-admin/config/
   - src/ → /root/host-admin/src/
   - tests/ → /root/host-admin/tests/
   - docs/ → /root/host-admin/docs/ (merge com claudedocs/)
   - examples/ → /root/host-admin/examples/

3. **Integrar /mnt/overpower/apps/dev/agl/hostman**:
   - Opção A: Criar subdiretório /root/host-admin/projects/hive-migration/
   - Opção B: Mesclar conteúdo nas pastas correspondentes

### Fase 3: Organização Final
```
/root/host-admin/
├── .git/
├── .hive-mind/
├── .claude-flow/
├── config/              # ← do CT179
├── src/                 # ← do CT179
├── tests/               # ← do CT179
├── examples/            # ← do CT179
├── docs/                # ← merge CT179 docs + claudedocs
├── scripts/             # ← local (já existe)
├── projects/            # ← NOVO
│   └── hive-migration/  # ← do overpower
├── logs/                # ← do CT179
└── [arquivos diversos]
```

## ⚠️ Conflitos Potenciais

### Arquivos Duplicados
- Ambos locais têm mesmos .md na raiz
- Datas diferentes (local mais recente em alguns casos)
- **Resolução**: Manter versão mais recente baseado em mtime

### Estrutura .hive-mind/
- Ambos têm, mas com conteúdos diferentes
- **Resolução**: Merge manual preservando sessões de ambos

### Documentação
- claudedocs/ (local) vs docs/ (CT179)
- **Resolução**: Manter docs/ como principal, mover claudedocs/ único para lá

## 📋 Próximos Passos

1. ✅ Backup completo
2. Copiar diretórios exclusivos do CT179 /root/host-admin
3. Integrar conteúdo do /mnt/overpower
4. Resolver conflitos de arquivos duplicados
5. Limpar estrutura final
6. Criar repositório GitHub
7. Push inicial

## 🤔 Decisões Necessárias

**Pergunta 1**: Como integrar o conteúdo de `/mnt/overpower/apps/dev/agl/hostman`?
- [ ] Opção A: Subdiretório `projects/hive-migration/`
- [ ] Opção B: Merge direto nas pastas existentes
- [ ] Opção C: Repositório separado linkado como submodule

**Pergunta 2**: Documentação duplicada?
- [ ] Manter `docs/` como principal
- [ ] Manter `claudedocs/` como principal
- [ ] Manter ambos separados

**Pergunta 3**: Nome do repositório GitHub?
- Sugestão: `host-admin` ou `infrastructure-management` ou `agl-hostman`
