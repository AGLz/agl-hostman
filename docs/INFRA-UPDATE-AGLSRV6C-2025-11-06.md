# Atualização de Infraestrutura - Novo Servidor AGLSRV6C
**Data**: 2025-11-06
**Técnico**: Claude Code

---

## 📋 Resumo

Documentação da transição AGLSRV6B → AGLSRV6C devido a falha de hardware.

---

## 🔴 Servidor DESATIVADO: AGLSRV6B (man6b)

### Status
- **Hardware**: ❌ **QUEIMOU** (IPERC)
- **Status Operacional**: **OFFLINE** (permanente)
- **IP Original**: 192.168.0.232
- **Containers Afetados**: Todos os CTs/VMs do host man6b

### PBS Afetado
```
man6b-pbs (CT desconhecido em man6b)
├─ IP: 192.168.0.232
├─ Status: OFFLINE
├─ Datastore: backups
└─ Jobs de backup: DESABILITADOS (correto)
```

### Jobs de Backup Relacionados
**Todos os jobs com destino `man6b-pbs` estão DESABILITADOS:**
- `backup-14eaa1e1-8aef` - Daily All-CTs to PBS (schedule 2:30)
- `backup-4487932b-284a` - Daily-VM-Clone to PBS (schedule 06:00)
- `backup-d129d288-6fc2` - Every 2h CTs to PBS (schedule 9,21)
- `backup-27a38af3-fa94` - Daily-CT-Clone to USB (schedule 07:00)
- `backup-21778230-bf30` - Daily-CT-Clone to PBS (schedule 09:30)
- `backup-vm100-pbs` - VM100 SQL Server PBS Backup (schedule 03:30)

**Ação Necessária**: Migrar jobs para novo servidor AGLSRV6C quando disponível.

---

## 🟢 NOVO SERVIDOR: AGLSRV6C (man6c)

### Informações Básicas
| Propriedade | Valor |
|------------|-------|
| **Hostname** | aglsrv6c / man6c |
| **IP LAN** | 192.168.0.233 |
| **Status** | ⚠️ **INSTALADO - Aguardando configuração de rede** |
| **Data Instalação** | Antes de 2025-11-06 |
| **Ajuste Rede Previsto** | **Próximo Sábado** (físico) |

### Status Atual (2025-11-06 00:50)
```bash
# Teste de conectividade de AGLSRV6 (man6)
ping 192.168.0.233
❌ Destination Host Unreachable

# Causa: Configuração física de rede pendente
```

### Próximos Passos

#### Sábado (Ajuste Físico de Rede)
1. **Configuração Física de Rede**
   - Conectar cabos de rede
   - Configurar switch/router se necessário
   - Validar conectividade LAN (ping de AGLSRV6)

2. **Configuração de Rede no Servidor**
   ```bash
   # A ser executado no man6c
   # Verificar interfaces
   ip addr show

   # Configurar IP estático (se não configurado)
   # /etc/network/interfaces ou /etc/netplan/

   # Testar conectividade
   ping 192.168.0.1  # Gateway
   ping 192.168.0.202  # AGLSRV6 (man6)
   ping 8.8.8.8  # Internet
   ```

3. **WireGuard Mesh Integration**
   ```bash
   # Gerar chaves WireGuard no man6c
   wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

   # Alocar IP na mesh: Próximo disponível (verificar docs/INFRA.md)
   # Sugestão: 10.6.0.14 ou 10.6.0.15

   # Configurar /etc/wireguard/wg0.conf
   # Adicionar peer no hub AGLSRV1 (CT145)
   ```

4. **Tailscale Integration**
   ```bash
   # Instalar Tailscale
   curl -fsSL https://tailscale.com/install.sh | sh

   # Autenticar
   tailscale up --advertise-tags=tag:servers,tag:proxmox

   # Verificar IP atribuído
   tailscale ip -4
   ```

#### Após Conectividade Estabelecida

5. **PBS Deployment** (se necessário)
   ```bash
   # Opção 1: Restaurar CT do backup
   # Localizar backup do man6b-pbs (se existir)

   # Opção 2: Deploy novo PBS via Community Script
   # https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-backup-server

   # Configurar datastore
   # Configurar usuários e permissões
   # Atualizar fingerprint em /etc/pve/storage.cfg
   ```

6. **Atualizar Storage Configuration**
   ```bash
   # Em AGLSRV6 (man6)
   # Editar /etc/pve/storage.cfg

   # Atualizar referências man6b → man6c
   # Atualizar IP 192.168.0.232 → 192.168.0.233
   # Atualizar fingerprint do novo PBS
   # Testar conectividade: pvesm status
   ```

7. **Migrar Jobs de Backup**
   ```bash
   # Editar /etc/pve/jobs.cfg
   # Atualizar jobs desabilitados:
   # - Trocar storage man6b-pbs → man6c-pbs (novo nome sugerido)
   # - Verificar vmid ainda existem
   # - Re-habilitar jobs (enabled 1)
   # - Ajustar schedules se necessário
   ```

8. **Teste de Validação**
   ```bash
   # Backup manual de teste
   vzdump <vmid> --storage man6c-pbs --mode snapshot

   # Verificar no PBS
   proxmox-backup-manager datastore list
   proxmox-backup-manager snapshot list backups

   # Testar restore
   pct restore <new_vmid> <backup_path>
   ```

---

## 📊 Inventário de Containers/VMs Afetados

### man6b (Offline - Hardware Queimado)
**Todos os CTs/VMs deste host estão INACESSÍVEIS até migração**

Jobs conhecidos que referenciavam man6b:
- CT 172 (Daily-CT-Clone)
- Possivelmente outros CTs não documentados

**Ação Requerida**:
1. Inventariar backups existentes de man6b
2. Planejar migração para man6c
3. Validar quais VMs/CTs são críticos

---

## 🔧 Configuração Atual de Backup (AGLSRV6/man6)

### Jobs ATIVOS (Funcionando Normalmente)
Após correção do erro 401 do man6-pbs:

#### 1. backup-pbs-tier2-infra-12h
```ini
comment: PBS-Tier2-Infra-12h
schedule: 2,14  # Às 02h e 14h
enabled: 1 ✅
storage: man6-pbs ✅
vmid: 101,102,109,114
prune-backups: keep-last=7,keep-monthly=1,keep-weekly=1,keep-yearly=1
```

#### 2. backup-vm200-production
```ini
comment: VM200 Production - PBS with Fleecing
schedule: 02:00  # Diário às 02h
enabled: 1 ✅
storage: man6-pbs ✅
vmid: 200
prune-backups: keep-daily=7,keep-monthly=3,keep-weekly=4,keep-yearly=1
```

### Storage PBS Operacional
```
man6-pbs (CT 113 - 192.168.0.231)
├─ Status: ACTIVE ✅
├─ Capacidade: 1.26 TB
├─ Usado: 408 GB (32.30%)
├─ Disponível: 855 GB (67.70%)
├─ Credenciais: root@pam / lx4936@klfap (atualizado 2025-11-06)
└─ Próximo backup: 02:00 (daqui a ~1h30min)
```

---

## 📋 Checklist de Migração man6b → man6c

### Fase 1: Preparação (Antes do Sábado)
- [ ] Inventariar todos os CTs/VMs do man6b (via backups ou logs)
- [ ] Listar backups existentes do man6b-pbs
- [ ] Identificar VMs/CTs críticos para priorização
- [ ] Documentar configurações de rede específicas
- [ ] Revisar storage requirements (discos, capacidade)

### Fase 2: Sábado (Configuração Física)
- [ ] Conectar cabos de rede no man6c
- [ ] Configurar IP estático 192.168.0.233
- [ ] Testar conectividade LAN (ping gateway, ping man6)
- [ ] Testar acesso SSH de man6 para man6c
- [ ] Configurar DNS/hostname

### Fase 3: Integração de Rede
- [ ] Instalar e configurar WireGuard (gerar chaves, alocar IP mesh)
- [ ] Adicionar peer no hub AGLSRV1
- [ ] Testar conectividade WireGuard mesh
- [ ] Instalar e configurar Tailscale
- [ ] Adicionar tags apropriadas (tag:servers, tag:proxmox)
- [ ] Atualizar docs/INFRA.md com novos IPs

### Fase 4: PBS Deployment
- [ ] Decidir: Restaurar PBS do backup OU deploy novo
- [ ] Deploy PBS (CT sugerido: 113 ou similar)
- [ ] Configurar datastore "backups"
- [ ] Configurar usuário root@pam com senha
- [ ] Obter fingerprint do novo PBS
- [ ] Testar autenticação via API

### Fase 5: Integração com Proxmox
- [ ] Adicionar storage em /etc/pve/storage.cfg (man6c-pbs)
- [ ] Testar: `pvesm status` (deve mostrar active)
- [ ] Backup manual de teste
- [ ] Validar backup no datastore do PBS
- [ ] Teste de restore

### Fase 6: Migração de Jobs
- [ ] Listar todos os jobs com destino man6b-pbs
- [ ] Atualizar storage man6b-pbs → man6c-pbs
- [ ] Revisar schedules para evitar conflitos
- [ ] Re-habilitar jobs (enabled 1)
- [ ] Monitorar primeira execução

### Fase 7: Migração de VMs/CTs
- [ ] Priorizar VMs/CTs críticos
- [ ] Restaurar de backup para man6c
- [ ] Validar configurações de rede
- [ ] Testar aplicações
- [ ] Atualizar documentação

### Fase 8: Finalização
- [ ] Desabilitar permanentemente jobs do man6b-pbs
- [ ] Remover storage man6b-pbs de /etc/pve/storage.cfg
- [ ] Atualizar toda documentação (INFRA.md, README.md)
- [ ] Notificar equipe da migração completa
- [ ] Arquivar documentação do man6b

---

## 📞 Informações de Referência

### AGLSRV6 (man6) - Host Atual Operacional
```
LAN: 192.168.0.202
WireGuard: 10.6.0.12
Tailscale: 100.98.108.66
PBS: CT 113 (192.168.0.231) - man6-pbs ✅
```

### AGLSRV6C (man6c) - Novo Servidor
```
LAN: 192.168.0.233 (aguardando configuração física)
WireGuard: TBD (próximo IP disponível)
Tailscale: TBD (após instalação)
PBS: TBD (a ser criado)
```

### AGLSRV6B (man6b) - Desativado
```
❌ Hardware queimado (IPERC)
❌ Todos os serviços offline
❌ PBS: 192.168.0.232 (inacessível)
```

---

## 🔐 Credenciais

### man6-pbs (Atual - Funcionando)
```
URL: https://192.168.0.231:8007
User: root@pam
Password: lx4936@klfap
Datastore: backups
```

### man6c-pbs (Futuro - A ser configurado)
```
URL: https://192.168.0.233:8007 (estimado)
User: TBD (sugestão: root@pam)
Password: TBD (gerar nova senha forte)
Datastore: TBD (sugestão: backups)
```

---

## 📊 Timeline Prevista

| Data | Fase | Atividade |
|------|------|-----------|
| **2025-11-06** | Diagnóstico | ✅ Problema PBS resolvido (401 → OK) |
| **Próx. Sábado** | Físico | 🔧 Configuração de rede man6c |
| **Sábado + 1 dia** | Integração | 🌐 WireGuard + Tailscale setup |
| **Sábado + 2 dias** | PBS | 💾 Deployment e configuração PBS |
| **Sábado + 3 dias** | Testes | 🧪 Validação de backups |
| **Sábado + 1 semana** | Migração | 📦 Restore de VMs/CTs críticos |
| **Sábado + 2 semanas** | Finalização | ✅ Documentação e encerramento |

---

## 📝 Notas Adicionais

### Lições Aprendidas
1. **Redundância Crítica**: Manter PBS em múltiplos hosts
2. **Documentação de Senhas**: Senha do PBS estava desatualizada
3. **Monitoramento Proativo**: Erro 401 passou despercebido por horas
4. **Inventário de Hardware**: Saber idade/status de servidores físicos

### Melhorias Recomendadas
1. **Alertas Automáticos**: Notificação de falhas de autenticação PBS
2. **Backup Cross-Site**: Considerar backup para outro site físico
3. **Documentação Centralizada**: Manter INFRA.md sempre atualizado
4. **Testes de Restore**: Agendar testes mensais de restore

---

**Última Atualização**: 2025-11-06 00:52
**Responsável**: Claude Code
**Status**: 🟡 Em Progresso (Aguardando configuração física sábado)
