# Flash BIOS AGLSRV3 — ficheiros e scripts

Scripts para preparar pen USB UEFI. **ROMs não incluídas** (proprietárias).

## Descarregar BIOS

| Destino                           | URL                                                                    |
| --------------------------------- | ---------------------------------------------------------------------- |
| iEngineer CX99DE77+ (recomendado) | https://www.patreon.com/BIOSiEngineer/posts/huananzhi-x99-f8-142711215 |
| Oficial Huananzhi                 | https://huananzhi.tw/catalog/motherboard/x99-f8/                       |
| Histórico CX99DE29 (actual)       | https://github.com/paulocmarques/HUANANZHI-X99-F8/releases             |

## Scripts

```bash
# Detectar Super I/O (5532 vs 5567)
bash detect-super-io.sh          # no host
ssh root@100.123.5.81 bash detect-super-io.sh

# Preparar pen (substituir /dev/sdX)
sudo bash prepare-uefi-usb.sh --usb /dev/sdX --bios-dir ~/CX99DE77-NEWBIOS/
```

Tutorial completo: [`docs/AGLSRV3-BIOS-UEFI-FLASH.md`](../../docs/AGLSRV3-BIOS-UEFI-FLASH.md)
