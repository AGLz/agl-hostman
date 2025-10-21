# Guia: Montar NFS do aglfs1 no Windows 11 + WSL2

**Data**: 2025-10-21
**Objetivo**: Montar NFS do aglfs1 (CT178) no Windows 11 e acessar via WSL2 para benchmarks
**Servidor**: aglfs1 (192.168.0.178)

---

## 📋 Visão Geral

Este guia mostra como:
1. Instalar NFS Client no Windows 11
2. Montar shares NFS do aglfs1 no Windows
3. Acessar os mounts NFS via WSL2
4. Realizar benchmarks de performance
5. Configurar auto-mount no boot do Windows

**Vantagem desta abordagem**:
- Windows usa seu stack NFS nativo (não WSL2)
- WSL2 acessa via `/mnt/c/NFS/*` (compartilhamento Windows)
- Melhor performance que NFS direto no WSL2
- Permite benchmarks em múltiplos cenários

---

## 🚀 Passo 1: Instalar NFS Client no Windows 11

### Opção A: Via PowerShell (Recomendado)

1. **Abra PowerShell como Administrador**:
   - Pressione `Win + X`
   - Selecione "Windows PowerShell (Admin)"

2. **Execute o script de setup**:
   ```powershell
   cd C:\temp
   .\setup-nfs-windows.ps1
   ```

3. **Se NFS Client não estiver instalado**, o script vai:
   - Instalar `ClientForNFS-Infrastructure`
   - Instalar `ServicesForNFS-ClientOnly`
   - **Solicitar reinicialização do Windows**

4. **Após reiniciar**, execute o script novamente para montar os shares

### Opção B: Via Interface Gráfica

1. Pressione `Win + R` → digite `optionalfeatures`
2. Marque: **"Services for NFS"** → **"Client for NFS"**
3. Clique OK e aguarde instalação
4. **Reinicie o Windows**

### Opção C: Via Linha de Comando

```powershell
# Como Administrador
dism /online /enable-feature /featurename:ServicesForNFS-ClientOnly /all
dism /online /enable-feature /featurename:ClientForNFS-Infrastructure /all

# Reinicie o Windows
shutdown /r /t 0
```

---

## 📂 Passo 2: Montar NFS Shares

### Método Automático (Script)

```powershell
# Como Administrador
cd C:\temp
.\setup-nfs-windows.ps1
```

O script vai:
1. ✅ Verificar instalação do NFS Client
2. ✅ Testar conectividade com aglfs1 (192.168.0.178)
3. ✅ Listar exports NFS disponíveis
4. ✅ Criar diretórios `C:\NFS\overpower` e `C:\NFS\spark`
5. ✅ Montar os shares NFS

### Método Manual

```powershell
# Como Administrador

# Criar diretórios
New-Item -ItemType Directory -Path "C:\NFS\overpower" -Force
New-Item -ItemType Directory -Path "C:\NFS\spark" -Force

# Montar overpower
mount -o anon nolock 192.168.0.178:/mnt/overpower C:\NFS\overpower

# Montar spark
mount -o anon nolock 192.168.0.178:/mnt/power C:\NFS\spark

# Verificar mounts
mount
```

**Opções de Mount**:
- `anon` - Acesso anônimo (usuário nobody)
- `nolock` - Desabilita file locking (melhor performance, menos seguro)

**Opções avançadas** (se necessário):
```powershell
# Com autenticação UID/GID
mount -o anon rsize=32768 wsize=32768 192.168.0.178:/mnt/overpower C:\NFS\overpower

# Com timeout customizado
mount -o anon timeout=10 retry=2 192.168.0.178:/mnt/overpower C:\NFS\overpower
```

---

## 🔗 Passo 3: Acessar via WSL2

### No WSL2, os mounts estarão disponíveis em:

```bash
# Overpower
/mnt/c/NFS/overpower

# Spark
/mnt/c/NFS/spark
```

### Verificar mounts no WSL2

```bash
# Listar arquivos
ls -lh /mnt/c/NFS/overpower | head -10
ls -lh /mnt/c/NFS/spark | head -10

# Ver tamanho dos mounts
df -h | grep NFS
```

### Criar symlinks para facilitar acesso

```bash
# No WSL2
ln -s /mnt/c/NFS/overpower ~/nfs-overpower
ln -s /mnt/c/NFS/spark ~/nfs-spark

# Agora pode acessar via:
ls ~/nfs-overpower
ls ~/nfs-spark
```

---

## 📊 Passo 4: Realizar Benchmarks

### Opção A: Benchmark Automatizado (PowerShell)

```powershell
# No Windows, como Administrador
cd C:\temp
.\benchmark-nfs-windows.ps1
```

**O script testa**:
- ✅ Velocidade de escrita (500MB)
- ✅ Velocidade de leitura (arquivo grande existente)
- ✅ Gera relatório em `C:\NFS\benchmark-results.txt`

### Opção B: Benchmark Manual no WSL2

#### Teste de Leitura
```bash
# Overpower
echo "=== LEITURA NFS-Windows Overpower ==="
dd if=/mnt/c/NFS/overpower/test-1gb.bin of=/dev/null bs=1M 2>&1 | grep -E "copied|bytes"

# Spark
echo "=== LEITURA NFS-Windows Spark ==="
dd if=/mnt/c/NFS/spark/test-1gb.bin of=/dev/null bs=1M 2>&1 | grep -E "copied|bytes"
```

#### Teste de Escrita
```bash
# Overpower
echo "=== ESCRITA NFS-Windows Overpower ==="
dd if=/dev/zero of=/mnt/c/NFS/overpower/bench-test.tmp bs=1M count=500 conv=fdatasync 2>&1 | grep -E "copied|bytes"
rm -f /mnt/c/NFS/overpower/bench-test.tmp

# Spark
echo "=== ESCRITA NFS-Windows Spark ==="
dd if=/dev/zero of=/mnt/c/NFS/spark/bench-test.tmp bs=1M count=500 conv=fdatasync 2>&1 | grep -E "copied|bytes"
rm -f /mnt/c/NFS/spark/bench-test.tmp
```

### Opção C: Comparação Completa

```bash
#!/bin/bash
# Script de benchmark comparativo: NFS-Windows vs SSHFS-WSL

echo "========================================="
echo "BENCHMARK COMPARATIVO"
echo "========================================="
echo ""

# NFS via Windows
echo "=== NFS via Windows (overpower) ==="
echo "Leitura:"
dd if=/mnt/c/NFS/overpower/test-1gb.bin of=/dev/null bs=1M 2>&1 | grep copied
echo "Escrita:"
dd if=/dev/zero of=/mnt/c/NFS/overpower/test.tmp bs=1M count=500 conv=fdatasync 2>&1 | grep copied
rm -f /mnt/c/NFS/overpower/test.tmp

echo ""
echo "=== SSHFS direto WSL (overpower) ==="
echo "Leitura:"
dd if=/mnt/overpower-sshfs/test-1gb.bin of=/dev/null bs=1M 2>&1 | grep copied
echo "Escrita:"
dd if=/dev/zero of=/mnt/overpower-sshfs/test.tmp bs=1M count=500 conv=fdatasync 2>&1 | grep copied
rm -f /mnt/overpower-sshfs/test.tmp

echo ""
echo "========================================="
echo "BENCHMARK CONCLUÍDO"
echo "========================================="
```

---

## ⚙️ Passo 5: Auto-Mount no Boot (Opcional)

### Criar Tarefa Agendada para Auto-Mount

```powershell
# Como Administrador
cd C:\temp
.\create-nfs-mount-task.ps1
```

**O que o script faz**:
1. Cria script de auto-mount: `C:\NFS\auto-mount-nfs.ps1`
2. Configura Tarefa Agendada no Windows
3. Executa no boot do sistema (como SYSTEM)
4. Aguarda rede estar disponível (10s delay)
5. Monta automaticamente os shares NFS

### Testar Auto-Mount Manualmente

```powershell
# Executar tarefa agendada manualmente
Start-ScheduledTask -TaskName "NFS Auto-Mount aglfs1"

# Verificar log
Get-Content C:\NFS\mount-log.txt -Tail 20
```

### Gerenciar Tarefa Agendada

```powershell
# Ver tarefa
Get-ScheduledTask -TaskName "NFS Auto-Mount aglfs1"

# Desabilitar auto-mount
Disable-ScheduledTask -TaskName "NFS Auto-Mount aglfs1"

# Habilitar novamente
Enable-ScheduledTask -TaskName "NFS Auto-Mount aglfs1"

# Remover tarefa
Unregister-ScheduledTask -TaskName "NFS Auto-Mount aglfs1" -Confirm:$false
```

---

## 🛠️ Comandos Úteis

### Verificar Mounts Ativos

```powershell
# Listar todos os mounts NFS
mount

# Filtrar apenas aglfs1
mount | Select-String "192.168.0.178"
```

### Desmontar Shares

```powershell
# Desmontar overpower
umount C:\NFS\overpower

# Desmontar spark
umount C:\NFS\spark

# Forçar desmontagem (se travado)
umount -f C:\NFS\overpower
umount -f C:\NFS\spark
```

### Remontar Shares

```powershell
# Desmontar
umount -f C:\NFS\overpower
umount -f C:\NFS\spark

# Aguardar
Start-Sleep -Seconds 2

# Montar novamente
mount -o anon nolock 192.168.0.178:/mnt/overpower C:\NFS\overpower
mount -o anon nolock 192.168.0.178:/mnt/power C:\NFS\spark
```

### Listar Exports Disponíveis

```powershell
# Ver todos os exports do servidor
showmount -e 192.168.0.178
```

---

## 🔍 Troubleshooting

### Problema: "mount: network error - no route to host"

**Solução**:
```powershell
# Verificar conectividade
ping 192.168.0.178

# Verificar serviço NFS Client
Get-Service -Name NfsClnt

# Reiniciar serviço NFS Client
Restart-Service NfsClnt

# Tentar novamente
mount -o anon 192.168.0.178:/mnt/overpower C:\NFS\overpower
```

### Problema: "access denied" ou "permission denied"

**Solução**:
```powershell
# Usar opção 'anon' (acesso anônimo)
mount -o anon 192.168.0.178:/mnt/overpower C:\NFS\overpower

# Se ainda falhar, verificar exports no servidor
showmount -e 192.168.0.178
```

### Problema: Mount trava ou timeout

**Solução**:
```powershell
# Desmontar forçado
umount -f C:\NFS\overpower

# Verificar firewall Windows
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*NFS*"}

# Montar com timeout maior
mount -o anon timeout=30 retry=5 192.168.0.178:/mnt/overpower C:\NFS\overpower
```

### Problema: Performance muito baixa

**Solução**:
```powershell
# Remontar com buffer maior
umount -f C:\NFS\overpower
mount -o anon rsize=65536 wsize=65536 192.168.0.178:/mnt/overpower C:\NFS\overpower

# Ou usar nolock para melhor performance (menos seguro)
mount -o anon nolock rsize=65536 wsize=65536 192.168.0.178:/mnt/overpower C:\NFS\overpower
```

### Problema: WSL não vê os mounts

**Solução**:
```bash
# No WSL2, verificar se C: está montado
ls /mnt/c

# Verificar permissões
ls -la /mnt/c/NFS

# Se não aparecer, reiniciar WSL
# No PowerShell (Windows):
wsl --shutdown
wsl
```

---

## 📈 Cenários de Benchmark

### Cenário 1: NFS via Windows → WSL

```bash
# Acesso: Windows monta NFS → WSL acessa via /mnt/c/
dd if=/mnt/c/NFS/overpower/test-1gb.bin of=/dev/null bs=1M
```

### Cenário 2: SSHFS direto no WSL

```bash
# Acesso: WSL monta SSHFS diretamente
dd if=/mnt/overpower-sshfs/test-1gb.bin of=/dev/null bs=1M
```

### Cenário 3: NFS direto no WSL (problemático)

```bash
# Acesso: WSL tenta montar NFS diretamente (tende a falhar)
mount -t nfs 192.168.0.178:/mnt/overpower /mnt/test-nfs
```

### Cenário 4: Windows direto (via PowerShell)

```powershell
# Acesso: Windows puro, sem WSL
Measure-Command {
    $content = [System.IO.File]::ReadAllBytes("C:\NFS\overpower\test-1gb.bin")
}
```

---

## 📋 Checklist de Setup

- [ ] NFS Client instalado no Windows 11
- [ ] Windows reiniciado após instalação
- [ ] Conectividade com aglfs1 (192.168.0.178) verificada
- [ ] Diretórios `C:\NFS\overpower` e `C:\NFS\spark` criados
- [ ] NFS shares montados com sucesso
- [ ] Mounts visíveis no Explorador de Arquivos
- [ ] WSL2 acessa `/mnt/c/NFS/*` corretamente
- [ ] Benchmarks executados
- [ ] (Opcional) Auto-mount configurado
- [ ] (Opcional) Resultados documentados

---

## 📂 Arquivos Criados

```
C:\temp\
├── setup-nfs-windows.ps1           # Setup principal
├── create-nfs-mount-task.ps1       # Configurar auto-mount
└── benchmark-nfs-windows.ps1       # Benchmarks

C:\NFS\
├── overpower\                      # Mount NFS overpower
├── spark\                          # Mount NFS spark
├── auto-mount-nfs.ps1              # Script de auto-mount
├── mount-log.txt                   # Log de mounts
└── benchmark-results.txt           # Resultados de benchmarks
```

---

## 🎯 Próximos Passos

1. **Executar setup inicial**:
   ```powershell
   cd C:\temp
   .\setup-nfs-windows.ps1
   ```

2. **Realizar benchmarks**:
   ```powershell
   .\benchmark-nfs-windows.ps1
   ```

3. **Acessar via WSL2**:
   ```bash
   ls /mnt/c/NFS/overpower
   ls /mnt/c/NFS/spark
   ```

4. **Comparar resultados** com SSHFS direto no WSL

5. **(Opcional) Configurar auto-mount**:
   ```powershell
   .\create-nfs-mount-task.ps1
   ```

---

**Última Atualização**: 2025-10-21
**Status**: ✅ Scripts criados, aguardando execução no Windows
**Localização**: `/mnt/c/temp/*.ps1`
