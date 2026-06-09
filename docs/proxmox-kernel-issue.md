# AGLSRV1 — Incidente kernel 6.2.16 e ZFS rpool

## Resumo

| Campo | Valor |
|-------|--------|
| Data | 2026-06-04 |
| Acção incorrecta | `proxmox-boot-tool kernel pin 6.2.16-5-pve` + reboot |
| Sintoma | Host não arranca; ZFS `rpool` — *unsupported feature* `vdev_zaps_v2` |
| Causa raiz | Kernel 6.2 traz ZFS/OpenZFS demasiado antigo para o pool criado/atualizado em kernels 6.11+ |
| Recuperação | Boot manual em `6.14.8-2-pve` ou `6.11.0-2-pve`; repinar kernel |

## Contexto

Tentativa de contornar erro QEMU `pci_irq_handler` no passthrough GTX 1650 → VM110.  
Downgrade para 6.2.16 **não** resolve passthrough e **quebra** o import do `rpool`.

## Recuperação (consola / IPMI / menu GRUB)

1. No GRUB: **Advanced options for Proxmox VE** → `6.14.8-2-pve` (ou `6.11.0-2-pve`)
2. Após login como root:

```bash
proxmox-boot-tool kernel pin 6.14.8-2-pve
proxmox-boot-tool refresh
cat /etc/kernel/proxmox-boot-pin   # deve mostrar 6.14.8-2-pve
zpool status rpool
reboot   # opcional — confirmar arranque automático OK
```

3. Opcional — remover kernel perigoso do menu (não obrigatório se pin estiver correcto):

```bash
# apt remove proxmox-kernel-6.2  # só se instalado como metapackage separado
```

## Estado correcto pós-recuperação

- Kernel activo: `6.14.8-2-pve` (ou `6.11.0-2-pve`)
- Pin: **nunca** `6.2.16-5-pve`
- GPU host: `vfio-pci` em `05:00.0` + `05:00.1`
- VM110: Ollama CPU (`vga: virtio`, sem `hostpci`) até passthrough estável

## GPU passthrough — resolução (2026-06-05)

| Problema | Solução |
|----------|---------|
| `pci_irq_handler` no 2.º `qm start` | Hook `post-stop` com reenumeração PCI + `bind_vfio` |
| `Key was rejected by service` (nvidia) | `efidisk0` com `pre-enrolled-keys=0` |
| GPU stuck D3cold / not ready after reset | Reboot host; **não** usar `disable_idle_d3=1` |
| Passthrough falha após `pci remove` | Reboot host obrigatório se `05:00` não reaparece |

Alternativas válidas (sem downgrade de kernel):

1. Manter kernel ≥ 6.11 (actual: `6.8.12-1-pve`)
2. Hook `/var/lib/vz/snippets/vm110-gpu-hook.sh`
3. Config: `0000:05:00.0,pcie=1,rombar=0` + `vga: virtio`
4. `pcie_aspm=off` em `/etc/kernel/cmdline`

## Lição

**Pools ZFS em Proxmox 9 / kernel 6.11+ não são bootáveis em kernels 6.2.**  
Qualquer pin de kernel deve ser **≥** versão em que o pool foi criado ou last upgraded.
