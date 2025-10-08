# 🔴 RELATÓRIO: SISTEMAS PERDIDOS NA OTIMIZAÇÃO DE STORAGE

## 📅 Contexto
- **Data da Otimização**: 26/09/2025 (ontem)
- **Evento**: Otimização de storages com deleção de backups antigos
- **Impacto**: Múltiplos CTs/VMs perderam seus backups

## 📊 Análise dos Sistemas Solicitados

### ✅ RECUPERÁVEIS (Backups Encontrados)
| ID | Tipo | Nome | Backup Disponível | Status |
|----|------|------|-------------------|--------|
| 107 | CT | Jellyfin | 6.3GB (23/09/2025) | 🔄 Restaurando |
| 157 | CT | CT157 | 11GB (19/09/2025) | 🔄 Restaurando |
| 160 | CT | Game | 5.9GB (19/09/2025) | 🔄 Restaurando |

### ❌ PERDIDOS (Sem Backups)
| ID | Tipo | Evidências Encontradas | Situação |
|----|------|------------------------|----------|
| 108 | VM | Apenas log de 2023 | Backup deletado |
| 109 | CT | Apenas arquivo .notes | Backup deletado |
| 110 | CT | Apenas arquivo .notes | Backup deletado |
| 118 | CT | Apenas arquivo .notes | Backup deletado |
| 119 | CT | Apenas arquivo .notes | Backup deletado |
| 127 | ? | Nenhuma evidência | Completamente perdido |
| 129 | VM | Apenas arquivo .notes | Backup deletado |
| 130 | CT | Apenas arquivo .notes | Backup deletado |
| 134 | VM | Apenas log de 2024 | Backup deletado |
| 140 | CT | Apenas arquivo .notes | Backup deletado |
| 143 | CT | Apenas log de 2024 | Backup deletado |
| 158 | CT | Apenas arquivo .notes | Backup deletado |
| 164 | CT | Apenas arquivo .notes | Backup deletado |
| 166 | ? | Nenhuma evidência | Completamente perdido |
| 175 | CT | Apenas log | Backup deletado |
| 177 | ? | Nenhuma evidência | Completamente perdido |

## 🔍 Detalhes da Investigação

### Locais Verificados:
1. ✅ `/spark/base/dump/` - Storage principal
2. ✅ `/overpower/base/dump/` - Storage secundário
3. ✅ `/var/lib/vz/dump/` - Storage local
4. ✅ Snapshots ZFS - Nenhum encontrado para estes IDs
5. ✅ Logs do sistema - Sem registros de deleção detalhados

### Evidências da Deleção:
- **Arquivos .notes**: Indicam que backups existiam mas foram deletados
- **Arquivos .log**: Logs de backups antigos sem os arquivos .tar.zst/.vma.zst
- **Padrão**: Maioria tinha backups de março/2025 que foram removidos

## 📈 Impacto

### Sistemas Críticos Perdidos:
- **VM 108**: Possível servidor (log de 2023)
- **VM 134**: Sistema antigo (log de 2024)
- **CT 143**: Container antigo (agosto/2024)

### Sistemas Recentes Perdidos:
- **CTs 109, 110, 118, 119, 130**: Backups de março/2025 deletados
- **CT 140, 158**: Backups de março/2025 deletados
- **CT 164**: Backup de janeiro/2025 deletado

## 🚨 AÇÕES TOMADAS

### Restaurações em Andamento:
1. **CT 107 (Jellyfin)**: Restaurando do backup de 23/09
2. **CT 157**: Restaurando do backup de 19/09
3. **CT 160 (Game)**: Restaurando do backup de 19/09

### Tentativas Sem Sucesso:
- Busca em todos os storages disponíveis
- Verificação de snapshots ZFS
- Análise de logs do sistema
- Procura por templates ou imagens base

## 💡 RECOMENDAÇÕES

### Imediatas:
1. **Aguardar** conclusão das 3 restaurações em andamento
2. **Verificar** se há outros locais de backup não verificados
3. **Documentar** quais sistemas eram críticos entre os perdidos

### Futuras:
1. **Política de Retenção**: Implementar política clara de retenção de backups
2. **Backup Offsite**: Manter cópias em storage externo
3. **Verificação Prévia**: Sempre verificar importância antes de deletar
4. **Logs de Deleção**: Manter logs detalhados de operações de limpeza

## 📝 NOTAS IMPORTANTES

### Sobre a Otimização de Ontem:
- Aparentemente foi uma limpeza agressiva de backups antigos
- Arquivos .notes e .log permaneceram mas os backups foram removidos
- Não há como recuperar sem os arquivos .tar.zst ou .vma.zst

### Possibilidades de Recuperação:
1. **Verificar** se há backup em fita ou storage externo
2. **Consultar** se alguém tem cópia local destes sistemas
3. **Recriar** do zero os sistemas menos críticos

## ⚠️ CONCLUSÃO

**Situação**:
- 3 de 19 sistemas podem ser recuperados
- 16 sistemas foram permanentemente perdidos
- Causa: Deleção de backups durante otimização de storage

**Status Final**:
- ✅ 3 CTs em processo de restauração
- ❌ 16 sistemas sem possibilidade de recuperação atual

---
**Relatório gerado**: 27/09/2025 13:20
**Severidade**: CRÍTICA - Perda permanente de dados