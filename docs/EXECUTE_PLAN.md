# AGLSRV1 Backup Recovery - Execution Plan

## Status: Aguardando servidor subir após stop/start

---

## Plano de Execução Cirúrgico

### FASE 1: Cleanup Imediato (Assim que servidor subir)
**Objetivo**: Liberar ~1 TB sem tocar em recovery-full
**Tempo estimado**: 5 minutos
**Risco**: BAIXO

```bash
# Execute assim que AGLSRV1 estiver online:
ssh AGLSRV1 'bash -s' < phase1_cleanup_surgical.sh
```

**O que faz**:
- ✓ Remove snapshot ZFS de 17/09/2025 (~1 TB)
- ✓ Remove backups antigos da VM 105 (~24 GB)
- ✓ Limpa diretórios temporários
- ✗ **PULA** recovery-full (mantém os 6.14 TB intactos)

**Espaço esperado liberado**: ~1 TB

---

### FASE 2: Otimizações (Logo após Fase 1)
**Objetivo**: Reduzir retenção, ativar compressão, otimizar schedule
**Tempo estimado**: 10 minutos
**Risco**: BAIXO

```bash
# Execute imediatamente após Fase 1:
ssh AGLSRV1 'bash -s' < optimization_plan.sh
```

**O que faz**:
- ✓ Reduz retenção: 7→3 backups (keep-last=3, keep-weekly=2, keep-monthly=3, keep-yearly=1)
- ✓ Executa prune para remover backups excedentes (~2.8 TB liberados)
- ✓ Ativa compressão LZ4 no ZFS (2x capacidade efetiva para novos dados)
- ✓ Documenta otimização de schedule (requer ajuste manual via GUI)

**Espaço esperado liberado**: ~2.8 TB adicional
**Capacidade efetiva**: 7 TB → 14 TB (com compressão)

---

### FASE 3: Verificação (Após Fase 2)
**Objetivo**: Confirmar sistema operacional
**Tempo estimado**: 2 minutos

```bash
# Verificar sucesso das operações:
ssh AGLSRV1 'bash -s' < verify_backup_system.sh
```

**Verifica**:
- Espaço disponível (meta: >500 GB livre)
- Lock files removidos
- Configuração de retenção aplicada
- Sistema pronto para próximo backup

---

## Resultados Esperados

| Métrica | Antes | Após Fase 1 | Após Fase 2 |
|---------|-------|-------------|-------------|
| Spark usado | 10.7 TB (99%) | 9.7 TB (90%) | 6.9 TB (64%) |
| Espaço livre | 768 MB | 1.7 TB | 3.9 TB |
| Capacidade efetiva | 10.9 TB | 10.9 TB | **21.8 TB** (com compressão) |
| Retenção | 7 backups | 7 backups | **3 backups** |
| Status | **TRAVADO** | Operacional | **OTIMIZADO** |

---

## Comandos Quick Check (Durante execução)

### Verificar se servidor subiu:
```bash
ping -c 3 192.168.0.245
ssh AGLSRV1 "pveversion"
```

### Monitorar espaço em tempo real:
```bash
watch -n 5 'ssh AGLSRV1 "df -h /spark/base && zfs list spark"'
```

### Verificar processos travados:
```bash
ssh AGLSRV1 "ps aux | grep vzdump | grep -v grep"
```

### Limpar locks manualmente (se necessário):
```bash
ssh AGLSRV1 "find /var/lock -name 'vzdump*' -delete"
```

---

## Ordem de Execução

1. **Aguardar**: Servidor AGLSRV1 completar stop/start
2. **Verificar**: `ssh AGLSRV1 "uptime"` - confirmar servidor online
3. **Executar Fase 1**: `ssh AGLSRV1 'bash -s' < phase1_cleanup_surgical.sh`
4. **Verificar espaço**: Deve mostrar ~1 TB livre
5. **Executar Fase 2**: `ssh AGLSRV1 'bash -s' < optimization_plan.sh`
6. **Verificar espaço**: Deve mostrar ~3-4 TB livre
7. **Executar Fase 3**: `ssh AGLSRV1 'bash -s' < verify_backup_system.sh`
8. **Confirmar**: Status HEALTHY

---

## Rollback (Se necessário)

### Se Fase 1 causar problemas:
```bash
# Não há rollback necessário - apenas removeu snapshots/arquivos antigos
# Backups ativos não foram tocados
```

### Se Fase 2 causar problemas:
```bash
# Restaurar retenção anterior:
ssh AGLSRV1 "pvesm set spark --prune-backups keep-last=7,keep-weekly=4,keep-monthly=6,keep-yearly=1"

# Desativar compressão (não recomendado):
ssh AGLSRV1 "zfs set compression=off spark"
```

---

## Monitoramento Pós-Execução

### Verificar próximo backup bem-sucedido:
```bash
ssh AGLSRV1 "pvesh get /cluster/tasks --limit 5 | grep vzdump"
```

### Monitorar taxa de compressão:
```bash
ssh AGLSRV1 "zfs get compressratio spark"
```

---

## Status Atual
- [ ] Servidor AGLSRV1 em stop/start
- [ ] Aguardando servidor subir
- [x] Scripts de cleanup criados
- [x] Scripts de otimização criados
- [x] Scripts de verificação criados
- [ ] Fase 1 executada
- [ ] Fase 2 executada
- [ ] Fase 3 executada
- [ ] Sistema validado

**Próximo passo**: Executar Fase 1 assim que servidor estiver online
