# Guia de Migração IDE para VirtIO - VM100 → VM200

## ⚠️ SITUAÇÃO ATUAL
- VM200 criada como ambiente de teste para migração VirtIO
- Discos IDE da VM100 adicionados na VM200 (IDE1 e IDE2)
- VM200 bootando pelo IDE1 com disco VirtIO SCSI0 disponível (500GB)
- ISO dos drivers VirtIO montado em IDE3

## 📋 PASSOS PARA INSTALAR DRIVERS VIRTIO

### 1. Acessar o Windows
- Via Console Proxmox ou RDP
- Aguarde o Windows detectar novo hardware SCSI

### 2. Instalar Driver VirtIO SCSI
1. Abra o **Gerenciador de Dispositivos**
2. Procure por **"Controlador SCSI"** com ⚠️ amarelo
3. Clique com botão direito → **Atualizar driver**
4. **Procurar software de driver no computador**
5. Navegar para **D:\vioscsi\2k19\amd64** (ou w10\amd64)
6. Instalar o driver Red Hat VirtIO SCSI

### 3. Verificar Instalação
- O disco SCSI de 1GB deve aparecer no Gerenciador de Discos
- Não precisa formatar, é só para teste

### 4. Instalar OUTROS Drivers Importantes
Ainda no Gerenciador de Dispositivos, instale:
- **VirtIO Serial Driver**: D:\vioserial\
- **Balloon Driver**: D:\balloon\
- **QEMU Guest Agent**: D:\guest-agent\

## 🔄 PROCESSO DE MIGRAÇÃO GRADUAL

### Fase 1: Preparação (ATUAL)
✅ MergeIDE executado
✅ Registry modificado
✅ Disco SCSI teste adicionado
⏳ Drivers sendo instalados

### Fase 2: Migração Híbrida
Após instalar drivers:
```bash
# Manter IDE0 como boot principal
# Adicionar cópias SCSI dos discos
qm set 100 --scsi1 rpool:vm-100-disk-0,cache=writeback,size=952832M
qm set 100 --scsi2 rpool:vm-100-disk-1,cache=writeback,size=952832M
```

### Fase 3: Teste com Boot SCSI
```bash
# Mudar ordem de boot para SCSI
qm set 100 --boot 'order=scsi1;ide0'
```

### Fase 4: Migração Completa
Se Windows bootar com SCSI:
```bash
# Remover discos IDE
qm set 100 --delete ide0
qm set 100 --delete ide1
# Renumerar SCSI
qm disk move 100 scsi1 --storage rpool --target-disk scsi0
```

## 🚨 PLANO DE CONTINGÊNCIA

Se falhar em qualquer fase:
1. Reverter para IDE imediatamente
2. Boot com IDE funcional
3. Revisar logs do Windows: Event Viewer → System
4. Verificar BCD: `bcdedit /enum`

## 📊 STATUS DOS DRIVERS

| Driver | Status | Caminho |
|--------|--------|---------|
| VirtIO SCSI | ⏳ Instalando | vioscsi\2k19\amd64 |
| VirtIO Serial | ⏳ Pendente | vioserial\2k19\amd64 |
| Balloon | ⏳ Pendente | balloon\2k19\amd64 |
| Guest Agent | ⏳ Pendente | guest-agent\qemu-ga-x86_64.msi |

## 💡 DICAS IMPORTANTES

1. **NÃO** remova os discos IDE até confirmar boot com SCSI
2. **SEMPRE** mantenha backup recente antes de mudanças
3. **TESTE** performance com benchmark após migração
4. **DOCUMENTE** todos os passos executados

## 🎯 OBJETIVO FINAL

- VM100 rodando 100% com VirtIO SCSI
- Backups funcionando sem travar a VM
- Performance de I/O > 100 MB/s (vs 13 MB/s atual)
- SQL Server com latência reduzida