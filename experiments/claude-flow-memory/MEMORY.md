---
title: Auto Memory - AGL Hostman Production
tags: [memory, production, agl]
updated: 2026-07-01
sources: [auto-memory]
---

# Auto Memory - AGL Hostman Production

> Sistema de memória local integrado com Claude Code

## Status do Sistema
- ✅ AutoMemoryBridge: Instalado e configurado
- ✅ LearningBridge: Ativo (sonaMode: balanced)
- ✅ MemoryGraph: Ativo (5000 nodes max)
- ✅ AgentScopes: Ativo (default: project)
- ✅ LLM-Wiki: Integração bidirecional configurada

## Integração com Claude Code
Os hooks em `settings.json` gerenciam automaticamente:
- **SessionStart**: Importar memória local para backend
- **SessionEnd**: Sincronizar insights de volta para MEMORY.md
- **Stop**: Salvar dados pendentes

## Fluxo de Trabalho
1. **Pré-tarefa**: Consultar memória existente
2. **Execução**: Usar `cc` e `hive` aliases
3. **Pós-tarefa**: Registrar insights no sistema

---

*Última atualização: 2026-07-01*
