# Storage Rename - ct138-nfs → fileserver5-nfs

**Date**: 2026-03-01
**Host**: AGLSRV5 (100.119.223.113 Tailscale / 10.6.0.17 WireGuard)
**Scope**: Renomear storage NFS para refletir nome do serviço (fileserver5)

## Summary

Renomear o storage `ct138-nfs` para `fileserver5-nfs` no AGLSRV5, alinhando a nomenclatura ao hostname do container (CT138 = fileserver5).

## Contexto

- **CT138**: Container fileserver5 no AGLSRV5
- **WireGuard IP**: 10.6.0.21
- **Tailscale**: 100.66.136.84 (aglsrv5-fileserver5)
- **NFS Export**: Provavelmente `/storage/nfs-export` ou similar

## Changes

### Storage Rename

| Old Name | New Name | Source | Protocol |
|----------|----------|--------|----------|
| **ct138-nfs** | **fileserver5-nfs** | 10.6.0.21 ou 192.168.15.138 (CT138) | NFSv4.2 |

### Mount Point Rename

| Old Path | New Path |
|----------|----------|
| `/mnt/pve/ct138-nfs` | `/mnt/pve/fileserver5-nfs` |

## Migration Steps (executar no AGLSRV5)

### 1. Backup das configurações

```bash
# Conectar ao AGLSRV5
ssh root@100.119.223.113   # Tailscale
# ou
ssh root@10.6.0.17         # WireGuard

# Backup
cp /etc/fstab /etc/fstab.backup-rename-$(date +%Y%m%d-%H%M%S)
cp /etc/pve/storage.cfg /etc/pve/storage.cfg.backup-rename-$(date +%Y%m%d-%H%M%S)
```

### 2. Desmontar o NFS

```bash
umount /mnt/pve/ct138-nfs
```

### 3. Renomear diretório do mount point

```bash
mv /mnt/pve/ct138-nfs /mnt/pve/fileserver5-nfs
```

### 4. Atualizar /etc/fstab

```bash
sed -i 's|ct138-nfs|fileserver5-nfs|g' /etc/fstab
```

### 5. Atualizar /etc/pve/storage.cfg

Editar manualmente ou via sed:

```bash
sed -i 's|ct138-nfs|fileserver5-nfs|g' /etc/pve/storage.cfg
```

**Antes** (exemplo):
```
dir: ct138-nfs
	path /mnt/pve/ct138-nfs
	content rootdir,backup,vztmpl,iso,snippets
	shared 0
```

**Depois**:
```
dir: fileserver5-nfs
	path /mnt/pve/fileserver5-nfs
	content rootdir,backup,vztmpl,iso,snippets
	shared 0
```

### 6. Remontar

```bash
mount /mnt/pve/fileserver5-nfs
```

### 7. Verificar

```bash
pvesm status -storage fileserver5-nfs
df -h | grep fileserver5
ls /mnt/pve/fileserver5-nfs
```

## Rollback

```bash
umount /mnt/pve/fileserver5-nfs
mv /mnt/pve/fileserver5-nfs /mnt/pve/ct138-nfs
cp /etc/fstab.backup-rename-* /etc/fstab
cp /etc/pve/storage.cfg.backup-rename-* /etc/pve/storage.cfg
mount /mnt/pve/ct138-nfs
```

## Rationale

- **Clareza**: `fileserver5-nfs` identifica o serviço (fileserver5) em vez do ID do container (ct138)
- **Consistência**: Alinha com convenção usada em fgsrv5-wg, ct111-shares, etc.
- **Manutenção**: Nome mais intuitivo para troubleshooting

## Script de Migração

Script automatizado disponível em `scripts/storage-rename-ct138-to-fileserver5.sh`:

```bash
# Executar via SSH no AGLSRV5
ssh root@100.119.223.113 'bash -s' < scripts/storage-rename-ct138-to-fileserver5.sh
```

## Related

- [PROXMOX-CLUSTER-AGLSRV5-FGSRV7](../PROXMOX-CLUSTER-AGLSRV5-FGSRV7.md) - Inventário AGLSRV5
- [STORAGE-RENAME-NFS-TO-WG](STORAGE-RENAME-NFS-TO-WG.md) - Rename similar no AGLSRV1
