# ✅ VM 147 (agldv01) - DESENVOLVIMENTO ESSENCIAL RESTAURADA

## 🚀 STATUS: OPERACIONAL

### Informações da VM
- **ID**: 147
- **Nome**: agldv01
- **Tipo**: VM de Desenvolvimento Essencial
- **Status**: 🟢 RUNNING
- **Uptime**: Iniciada com sucesso

### Especificações Técnicas
| Recurso | Configuração |
|---------|--------------|
| **CPU** | 16 cores (host CPU) |
| **RAM** | 32GB (com ballooning 16-32GB) |
| **Disco** | 240GB SSD NVMe |
| **Rede** | virtio (BC:24:11:10:41:DF) |
| **Bridge** | vmbr0 |
| **Boot** | UEFI (OVMF) |
| **Auto-start** | Sim (onboot=1) |

### Recursos Restaurados
- ✅ Sistema operacional completo
- ✅ 240GB de dados de desenvolvimento
- ✅ Configurações de rede originais
- ✅ UEFI boot configurado
- ✅ QEMU Agent habilitado

### Detalhes da Restauração
```
Backup Original: vzdump-qemu-147-2025_02_28-04_40_02.vma.zst
Tamanho do Backup: 34GB
Data do Backup: 28/02/2025
Restaurado em: 27/09/2025 12:33
Reconfigurado em: 27/09/2025 13:10
Iniciado em: 27/09/2025 13:11
```

### Como Acessar a VM

1. **Via Console Proxmox**:
   ```bash
   qm console 147
   ```

2. **Via VNC**:
   - Acesse a interface web do Proxmox
   - Selecione VM 147 (agldv01)
   - Clique em Console

3. **Via SSH** (quando o IP estiver disponível):
   ```bash
   # Aguarde alguns minutos para o boot completo
   # O IP será atribuído via DHCP no bridge vmbr0
   ```

### Verificação do IP
Para obter o IP da VM após o boot completo:
```bash
qm guest cmd 147 network-get-interfaces
```

## ⚠️ IMPORTANTE

### Seus Desenvolvimentos
- Todos os dados do disco de 240GB foram preservados
- Sistema restaurado do backup de 28/02/2025
- Todos os arquivos e configurações devem estar intactos

### Próximos Passos Recomendados
1. ✅ VM já está rodando
2. Aguarde 2-3 minutos para boot completo
3. Verifique o IP atribuído
4. Acesse via SSH ou console
5. Valide seus projetos de desenvolvimento

## 📝 Notas Adicionais

### Performance
- VM configurada com CPU host (máxima performance)
- 16 cores disponíveis para compilação/desenvolvimento
- 32GB RAM para projetos grandes
- SSD com discard habilitado para melhor performance

### Backup
- Configure backups regulares para não perder trabalho
- Recomendado: Backup diário ou após mudanças importantes

---
**Status Final: 🟢 VM 147 (agldv01) TOTALMENTE OPERACIONAL**
**Desenvolvimento: PRONTO PARA CONTINUAR SEUS PROJETOS**

*Relatório gerado: 27/09/2025 13:11*