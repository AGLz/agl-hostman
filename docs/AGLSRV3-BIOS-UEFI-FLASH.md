# AGLSRV3 — Flash BIOS X99-F8 via UEFI Shell (passo a passo)

> **Placa:** HUANANZHI X99-F8 Gaming  
> **BIOS actual (confirmado):** `CX99DE29` (iEngineer, Nov 2021)  
> **Boot Proxmox:** Samsung SSD 850 EVO (`S2RANX0H564404D`)  
> **PSU actual:** Corsair Gold **650 W** — ver [secção PSU](#psu-corsair-650w-gold)

Scripts no repo: `scripts/hardware/aglsrv3-bios-flash/`

---

## 1. Qual BIOS usar?

| Origem                                                                                      | Versão             | Quando usar                                                        |
| ------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------ |
| **Já instalada**                                                                            | **CX99DE29**       | Base iEngineer — permite update UEFI Shell para versões mais novas |
| [Huananzhi oficial](https://huananzhi.tw/catalog/motherboard/x99-f8/)                       | F8-BIOS (Set 2021) | Stock de fábrica / referência                                      |
| [iEngineer Patreon](https://www.patreon.com/BIOSiEngineer/posts/huananzhi-x99-f8-142711215) | **CX99DE77+**      | Recomendado se quiser TPM 2.0, ReBAR, microcode recente            |
| [GitHub paulocmarques](https://github.com/paulocmarques/HUANANZHI-X99-F8/releases)          | CX99DE25–DE29      | Histórico / DE29 = versão actual                                   |

**Importante:** Com **CX99DE29** já instalada, **não** precisa de programador CH341A para ir a **CX99DE77** — use o pacote UEFI (`flash.nsh`) do iEngineer.

Se a BIOS mostrar versão **stock Huananzhi** (não CX99DE\*): primeira flash **obrigatoriamente** via CH341A ou UEFI Shell do pacote iEngineer (ver aviso no README do GitHub).

---

## 2. Ferramentas necessárias

### Hardware

| Item                              | Notas                                          |
| --------------------------------- | ---------------------------------------------- |
| Pen USB **≥ 1 GB**                | FAT32, GPT com partição EFI                    |
| UPS                               | Obrigatório durante flash                      |
| Bateria **CR2032** nova           | Trocar **antes** ou **logo após** flash        |
| (Opcional) Programador **CH341A** | Só se BIOS stock brickada ou first flash stock |

### Software (repo agl-hostman)

```bash
# No agldv03 ou laptop de preparação (Debian/Ubuntu)
sudo apt install parted dosfstools curl unzip

# Detectar Super I/O no host (escolher ROM 5532 vs 5567)
scp scripts/hardware/aglsrv3-bios-flash/detect-super-io.sh root@100.123.5.81:/root/
ssh root@100.123.5.81 bash /root/detect-super-io.sh
```

| Super I/O            | ROM iEngineer          |
| -------------------- | ---------------------- |
| **NCT5532D** (comum) | `CX99DE77-F8-5532.ROM` |
| **NCT5567D-B**       | `CX99DE77-F8-5567.ROM` |

### Ficheiros a descarregar (manual — licença proprietária)

1. **Pacote iEngineer CX99DE77** (ZIP com `NEWBIOS/`, `flash.nsh`, `AfuEfix64.efi`, `.ROM`)  
   → [Patreon BIOSiEngineer](https://www.patreon.com/BIOSiEngineer/posts/huananzhi-x99-f8-142711215)

2. **Alternativa oficial** (se preferir stock):  
   → [huananzhi.tw X99-F8 BIOS](https://huananzhi.tw/catalog/motherboard/x99-f8/) → linha **HUANANZHI X99 F8-BIOS**

3. **UEFI Shell** (se o script não descarregar):  
   → [Tianocore Shell.efi](https://github.com/tianocore/edk2/releases) — o script `prepare-uefi-usb.sh` descarrega automaticamente.

**Não commitar** ficheiros `.ROM` / `.zip` no Git.

---

## 3. Preparar pen USB

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman

# Verificar pen (substituir sdX — APAGA O DISCO!)
lsblk

# Com ZIP iEngineer descompactado em ~/CX99DE77-NEWBIOS/
sudo bash scripts/hardware/aglsrv3-bios-flash/prepare-uefi-usb.sh \
  --usb /dev/sdX \
  --bios-dir ~/CX99DE77-NEWBIOS/

# Ou directamente do ZIP:
sudo bash scripts/hardware/aglsrv3-bios-flash/prepare-uefi-usb.sh \
  --usb /dev/sdX \
  --bios-zip ~/Downloads/CX99DE77-F8-5532.zip
```

Estrutura final na pen:

```
EFI/BOOT/BOOTX64.EFI    ← UEFI Shell
NEWBIOS/
  AfuEfix64.efi
  CX99DE77-F8-5532.ROM
  flash.nsh
LEIA-ME.txt
```

---

## 4. Passo a passo no AGLSRV3 (flash)

### Antes

- [ ] Anotar settings actuais (foto BIOS): boot order, VT-d, Above 4G, RAM XMP
- [ ] Parar **todas** as VMs/CTs ou migrar carga (flash = downtime)
- [ ] Confirmar UPS ligado
- [ ] **Não** correr backups vzdump em paralelo

### Flash

1. **Desligar** AGLSRV3 (PSU off na parede, 30 s).
2. Inserir pen USB na porta **USB 2.0** traseira (mais fiável para boot).
3. Ligar — premir **`Del`** para BIOS Setup.
4. Verificar versão actual: `CX99DE29` (canto ou Main).
5. **Boot** → escolher:
   - `UEFI: Built-in EFI Shell` (já existe na CX99DE29), **ou**
   - `UEFI: USB` / `Boot from File` → `\EFI\BOOT\BOOTX64.EFI`
6. No **UEFI Shell**:

   ```text
   map -r
   fs0:
   ls
   fs1:
   ls
   ```

   Encontrar a pen (directório `NEWBIOS`):

   ```text
   fs1:
   cd NEWBIOS
   ls
   flash.nsh
   ```

7. Aguardar **100%** — **não** reiniciar nem cortar energia.
8. Quando pedir reboot, desligar PSU.

### Após flash — Clear CMOS (obrigatório em placas Huananzhi)

1. Desligar PSU da parede.
2. Retirar bateria **CR2032** 15 minutos.
3. Verificar jumper **CLR-CMOS** na posição **normal** (não cleared).
4. Recolocar bateria, ligar PSU.

### Configuração BIOS pós-flash

| Setting                          | Valor                              |
| -------------------------------- | ---------------------------------- |
| Load Optimized Defaults          | Sim, primeiro                      |
| Boot Option #1                   | **Samsung SSD 850 EVO 500GB**      |
| Boot Option #2+                  | NVMe / outros conforme necessidade |
| VT-d / Intel VT for Directed I/O | **Enabled**                        |
| Above 4G Decoding                | **Enabled**                        |
| IOMMU                            | **Enabled**                        |
| Fast Boot                        | **Disabled** (até estabilizar)     |
| C-States                         | Testar **Disabled** se freezes     |
| Save & Exit                      | **F10**                            |

### Teste de persistência CMOS

1. Boot Proxmox OK.
2. **Power off PSU** 5 minutos (não só reboot).
3. Ligar — BIOS **deve** manter SSD como boot #1.
4. Se resetar → **bateria CR2032** ou jumper CLR-CMOS (não BIOS).

---

## 5. Se algo correr mal

| Sintoma                | Acção                                                                                                                                                     |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Black screen pós-flash | Clear CMOS 15 min; tentar boot com 1 stick RAM                                                                                                            |
| Brick total            | Flash **backup ROM** com **CH341A** ([guia](https://www.miyconst.com/Blog/View/2086/ch341a-minimal-usage-guide-how-to-read-and-write-a-motherboard-bios)) |
| Boot vai para NVMe     | Entrar BIOS → boot order → SSD Samsung                                                                                                                    |
| Proxmox não arranca    | Boot USB Proxmox rescue / chroot; `pveversion`                                                                                                            |

Guardar **backup do chip** com CH341A **antes** de qualquer flash (ler SPI → ficheiro `.bin`).

---

## 6. PSU — Corsair 650 W Gold

Estimativa de pico AGLSRV3:

| Componente                          | Pico aprox.   |
| ----------------------------------- | ------------- |
| Xeon E5 (14c)                       | 120–165 W     |
| 2× RX580 2048SP (passthrough VM310) | 300–370 W     |
| Placa + RAM + fans                  | 40–60 W       |
| 5× HDD ZFS + SSD                    | 40–60 W       |
| **Total pico**                      | **500–655 W** |

Com **650 W Gold** (~520 W sustentados 80 Plus Gold @ 100%):

- Margem **muito apertada** com ambas GPUs + CPU a 100% + vzdump + ZFS resilver.
- Brownout da PSU explica **freeze + CMOS corrupto** sob backup massivo + Ollama.

**Recomendações (sem trocar PSU imediatamente):**

1. **Parar VM310** durante backups (`aglsrv3-vzdump-sequential.sh` faz isto por defeito).
2. Nunca vzdump de 10 guests em paralelo.
3. Limitar carga GPU no Ollama se possível (`OLLAMA_NUM_PARALLEL`, modelos menores).
4. **Médio prazo:** PSU **850 W Gold+** (Corsair RM850x, Seasonic Focus, etc.).

---

## 7. Backup sequencial seguro

```bash
# Dry-run (plano + pré-checks)
bash scripts/backup/aglsrv3-vzdump-sequential.sh --remote --dry-run

# Executar (para VM310, pausa entre jobs, skip PBS 318)
bash scripts/backup/aglsrv3-vzdump-sequential.sh --remote --apply

# Excluir VM301 (problemática TPM/NVMe) por agora
bash scripts/backup/aglsrv3-vzdump-sequential.sh --remote --apply --skip 301
```

Ordem: CTs 304→306→317→338 → VMs 303→302→305→308 → **310** (para Ollama) → **301** (última).

Pré-checks: RAM livre ≥ 4 GB, ZFS ONLINE, sem outro vzdump, storage PBS OK.

---

## 8. Referências

- [`AGLSRV3-HARDWARE-BIOS.md`](AGLSRV3-HARDWARE-BIOS.md) — monitorização, CMOS
- [Manual X99-F8](https://www.manualslib.com/manual/3460574/Huananzhi-X99-F8-Gaming.html) — jumper CLR-CMOS, tecla Del
- [GitHub HUANANZHI-X99-F8](https://github.com/paulocmarques/HUANANZHI-X99-F8)
- `scripts/monitoring/aglsrv3-hardware-snapshot.sh` — temps/RAPL pós-intervenção
