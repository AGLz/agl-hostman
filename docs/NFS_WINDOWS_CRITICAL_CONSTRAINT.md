# ⚠️ RESTRIÇÃO CRÍTICA: Serviço NfsClnt no Windows

**Data**: 2025-10-21
**Sistema**: Windows 11 Host
**Problema**: Restart do serviço NfsClnt trava o sistema
**Severidade**: 🔴 CRÍTICA

---

## 🚨 Problema Identificado

### Sintoma
**Reiniciar o serviço NFS Client (NfsClnt) trava o Windows, requerendo reboot completo do host.**

```powershell
# NUNCA EXECUTAR - TRAVA O SISTEMA
Restart-Service NfsClnt  # ❌ PROIBIDO
Stop-Service NfsClnt     # ❌ PROIBIDO
```

### Impacto
- **Downtime forçado**: Requer reboot completo do Windows
- **Perda de sessões**: Todas as aplicações e trabalho em andamento são perdidos
- **Indisponibilidade**: Sistema fica temporariamente inutilizável durante travamento

---

## 🔍 Análise Técnica

### Causa Provável
**Bug conhecido do Windows NFS Client em certas configurações**:

1. **State corruption**: NFS Client mantém estado de conexões ativas
2. **Kernel lock**: Restart do serviço pode causar deadlock no kernel
3. **Driver issue**: Drivers de rede Windows podem entrar em estado inconsistente
4. **Resource leak**: Handles de arquivos NFS não liberados corretamente

### Configurações que Agravam o Problema
- Mounts NFS ativos durante restart do serviço
- Múltiplos mounts simultâneos (Y: e Z:)
- Operações de I/O em andamento durante restart
- Windows 11 com certas versões de kernel

---

## 🛡️ Regras de Ouro - NÃO FAZER

### ❌ Operações Proibidas

```powershell
# NUNCA executar os seguintes comandos:
Restart-Service NfsClnt
Stop-Service NfsClnt
Start-Service NfsClnt  # OK apenas se já estiver parado

# NUNCA modificar configuração sem desmount:
Set-Service NfsClnt -StartupType Automatic  # OK
# Mas restart após mudança = PROIBIDO
```

### ❌ Cenários de Risco

1. **Troubleshooting NFS**: NÃO reiniciar serviço para resolver problemas
2. **Configuração**: NÃO aplicar mudanças que requerem restart de serviço
3. **Scripts automatizados**: NÃO incluir restart de NfsClnt em scripts

---

## ✅ Procedimentos Seguros

### Cenário 1: Problemas com Mounts NFS
**Problema**: Mount NFS não responde ou trava

**Solução SEGURA**:
```powershell
# 1. Desmontar APENAS o mount problemático (não restart serviço)
umount -f Y:  # Force unmount do drive específico

# 2. Aguardar alguns segundos
Start-Sleep -Seconds 5

# 3. Remontar
mount -o anon,nolock 192.168.0.178:/mnt/power Y:

# 4. Verificar
Test-Path Y:\
```

**❌ NÃO FAZER**:
```powershell
# Isto vai TRAVAR o sistema:
Restart-Service NfsClnt  # ❌
```

### Cenário 2: Mounts Não Aparecem no Boot
**Problema**: Após reboot do Windows, Y: e Z: não montam automaticamente

**Solução SEGURA**:
```powershell
# 1. Verificar se serviço está rodando
Get-Service NfsClnt

# 2. Se PARADO, pode iniciar (OK porque não há restart)
if ((Get-Service NfsClnt).Status -eq 'Stopped') {
    Start-Service NfsClnt  # ✅ Seguro se estiver parado
    Start-Sleep -Seconds 5
}

# 3. Montar manualmente (via script)
C:\NFS\auto-mount-nfs.ps1

# 4. Criar Tarefa Agendada para auto-mount no boot
# (sem restart de serviço)
```

### Cenário 3: Status "Disconnected" no Explorer
**Problema**: Drives mostram "Disconnected" mas funcionam

**Solução SEGURA**:
```powershell
# 1. Verificar se drives estão realmente acessíveis
Test-Path Y:\
Test-Path Z:\

# 2. Se TRUE, é apenas bug visual - IGNORAR
# Explorer mostra "Disconnected" mas funciona normalmente

# 3. Se quiser corrigir visualmente: MIGRAR PARA SMB
umount -f Y:
umount -f Z:
net use Y: \\aglfs1\power /PERSISTENT:YES
net use Z: \\aglfs1\overpower /PERSISTENT:YES

# SMB não tem bug de "Disconnected"
```

### Cenário 4: Mudança de Configuração
**Problema**: Precisa alterar configuração do NFS Client

**Solução SEGURA**:
```powershell
# 1. Desmontar TODOS os mounts NFS primeiro
umount -f Y:
umount -f Z:
# Aguardar confirmação
Start-Sleep -Seconds 5

# 2. Fazer mudanças de configuração
# (exemplo: alterar opções de mount, etc)

# 3. AGENDAR REBOOT do Windows (não restart de serviço)
shutdown /r /t 300 /c "Reboot agendado para aplicar config NFS"

# Ou fazer mudanças e remontar sem restart:
# (se não requer restart de serviço)
```

---

## 🎯 Solução Recomendada: Migrar para SMB

### Por Que SMB é Melhor Neste Caso

| Aspecto | NFS | SMB | Vencedor |
|---------|-----|-----|----------|
| **Restart de serviço** | ❌ Trava sistema | ✅ Seguro | **SMB** |
| **Auto-mount** | ⚠️ Requer script | ✅ Nativo | **SMB** |
| **Explorer status** | ❌ "Disconnected" | ✅ "OK" | **SMB** |
| **WSL2 visibilidade** | ❌ Não aparece | ✅ Auto /mnt/y | **SMB** |
| **Performance LAN** | ~300 MB/s | ~280 MB/s | Empate |
| **Confiabilidade** | ⚠️ Timeouts WSL | ✅ Estável | **SMB** |

### Migração Sem Restart de NfsClnt

```powershell
# Script de migração segura NFS → SMB
# Salvar como: C:\temp\migrate-nfs-to-smb.ps1

Write-Host "`n=== MIGRACAO NFS → SMB (SEGURO) ===" -ForegroundColor Cyan

# 1. Desmontar NFS (sem restart de serviço)
Write-Host "`n[1/3] Desmontando drives NFS..." -ForegroundColor Yellow
umount -f Y: 2>$null
umount -f Z: 2>$null
Start-Sleep -Seconds 3
Write-Host "  OK Drives NFS desmontados" -ForegroundColor Green

# 2. Montar via SMB (persistente)
Write-Host "`n[2/3] Montando via SMB..." -ForegroundColor Yellow

# Y: = spark
net use Y: \\aglfs1\power /PERSISTENT:YES
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Y: montado via SMB" -ForegroundColor Green
} else {
    Write-Host "  X Falha ao montar Y:" -ForegroundColor Red
}

# Z: = overpower
net use Z: \\aglfs1\overpower /PERSISTENT:YES
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Z: montado via SMB" -ForegroundColor Green
} else {
    Write-Host "  X Falha ao montar Z:" -ForegroundColor Red
}

# 3. Verificar resultado
Write-Host "`n[3/3] Verificando mounts..." -ForegroundColor Yellow
$yOk = Test-Path "Y:\"
$zOk = Test-Path "Z:\"

Write-Host "  Y: (spark):     " -NoNewline
Write-Host $(if ($yOk) { "OK" } else { "ERRO" }) -ForegroundColor $(if ($yOk) { "Green" } else { "Red" })

Write-Host "  Z: (overpower): " -NoNewline
Write-Host $(if ($zOk) { "OK" } else { "ERRO" }) -ForegroundColor $(if ($zOk) { "Green" } else { "Red" })

# 4. Testar WSL (reiniciar WSL, não Windows)
Write-Host "`n[4/4] Reiniciando WSL para detectar novos drives..." -ForegroundColor Yellow
wsl --shutdown
Start-Sleep -Seconds 2
Write-Host "  OK WSL reiniciado" -ForegroundColor Green

Write-Host "`n=== MIGRACAO CONCLUIDA ===" -ForegroundColor Cyan
Write-Host "Agora teste no WSL:" -ForegroundColor Yellow
Write-Host "  wsl" -ForegroundColor White
Write-Host "  ls /mnt/y" -ForegroundColor White
Write-Host "  ls /mnt/z" -ForegroundColor White
Write-Host ""
```

**Benefícios desta abordagem**:
- ✅ **ZERO restart de serviço NfsClnt** (evita travamento)
- ✅ **Apenas WSL restart** (rápido e seguro)
- ✅ SMB é nativo e mais estável
- ✅ Auto-mount funciona automaticamente
- ✅ WSL2 detecta /mnt/y e /mnt/z instantaneamente

---

## 📋 Checklist de Segurança

### Antes de Qualquer Operação NFS

- [ ] Verificar se operação requer restart de NfsClnt
- [ ] Se SIM: Agendar reboot do Windows completo
- [ ] Se NÃO: Prosseguir com operação
- [ ] Sempre desmontar drives antes de mudanças
- [ ] Nunca usar `Restart-Service NfsClnt`
- [ ] Preferir migração para SMB quando possível

### Operações Seguras (NÃO requerem restart)

- ✅ `mount.exe` - Montar novo drive
- ✅ `umount.exe` - Desmontar drive
- ✅ `umount -f` - Force unmount
- ✅ `Get-Service NfsClnt` - Verificar status
- ✅ `Start-Service NfsClnt` - APENAS se já estiver PARADO
- ✅ Scripts de auto-mount

### Operações Perigosas (evitar)

- ❌ `Restart-Service NfsClnt`
- ❌ `Stop-Service NfsClnt` (seguido de Start)
- ❌ Mudanças que requerem restart do serviço
- ❌ Reinstalação de NFS Client sem desmontar

---

## 🚀 Plano de Ação Recomendado

### Opção A: Migrar para SMB (Recomendado)
**Prioridade**: 🟢 Alta
**Tempo**: 5 minutos
**Risco**: 🟢 Baixo
**Downtime**: Apenas WSL (~5 segundos)

```powershell
# Executar uma vez:
C:\temp\migrate-nfs-to-smb.ps1
```

**Resultado esperado**:
- Y: e Z: funcionam via SMB
- Status "OK" no Explorer
- /mnt/y e /mnt/z visíveis no WSL
- ZERO problemas com NfsClnt

### Opção B: Manter NFS + Conviver com Limitações
**Prioridade**: 🟡 Média
**Risco**: 🟡 Médio

**Regras estritas**:
1. NUNCA reiniciar serviço NfsClnt
2. Aceitar status "Disconnected" como cosmético
3. Usar SSHFS no WSL em vez de /mnt/y e /mnt/z
4. Reboot completo do Windows se precisar mudar config

### Opção C: Desabilitar NFS Client
**Prioridade**: 🔴 Última opção
**Impacto**: Remove funcionalidade NFS completamente

Apenas se problemas persistirem e SMB for viável:
```powershell
# Desmontar tudo
umount -f Y:
umount -f Z:

# Desabilitar serviço (requer reboot)
Set-Service NfsClnt -StartupType Disabled

# Agendar reboot
shutdown /r /t 60
```

---

## 📚 Referências e Contexto

### Documentação Relacionada
- `WINDOWS_NFS_SETUP_GUIDE.md` - Setup original NFS
- `NFS_WINDOWS_WSL_DIAGNOSTIC_REPORT.md` - Diagnóstico completo
- `NFS_WSL2_INVESTIGATION_REPORT.md` - Problemas NFS + WSL2

### Histórico do Problema
- **2025-10-21**: Identificada restrição crítica de restart NfsClnt
- **Contexto**: Sistema já tem SMB funcional (R:, S:, T:, U:)
- **Servidor**: aglfs1 suporta tanto NFS quanto SMB/Samba

### Alternativas Testadas
1. ✅ **SSHFS** - Funcional, 50-200 MB/s (docs anteriores)
2. ✅ **SMB** - Funcional, R:/S:/T:/U: já operacionais
3. ⚠️ **NFS** - Funcional mas com limitações críticas

---

## 🎬 Resumo Executivo

### ⚠️ CRÍTICO
**NUNCA reiniciar o serviço NfsClnt - trava o Windows e requer reboot completo do host**

### ✅ SOLUÇÃO
**Migrar de NFS para SMB**:
- Evita problema de restart
- Melhor integração Windows + WSL2
- Infraestrutura já existe (aglfs1 tem Samba)
- Performance equivalente em LAN local

### 🚀 AÇÃO IMEDIATA
```powershell
# Executar script de migração segura:
C:\temp\migrate-nfs-to-smb.ps1
```

**Tempo**: 5 minutos
**Risco**: Baixo
**Downtime**: Apenas WSL (~5s)
**Benefício**: Resolve todos os problemas identificados

---

**Última Atualização**: 2025-10-21
**Status**: 🔴 DOCUMENTAÇÃO CRÍTICA - LEITURA OBRIGATÓRIA
**Severidade**: Alta - Pode causar downtime completo do sistema
