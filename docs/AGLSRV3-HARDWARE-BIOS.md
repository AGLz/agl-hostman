# AGLSRV3 — Hardware, BIOS e estabilidade

> **Host**: `aglsrv3` · Tailscale `100.123.5.81`  
> **Placa**: **HUANANZHI X99-F8 Gaming** (Intel C610/X99)  
> **BIOS actual**: `CX99DE29` (AMI, 2021-11-09)  
> **Sem IPMI/BMC** — monitorização via `lm-sensors` + RAPL + SMART

---

## Sintomas reportados (Jun 2026)

- Travamentos sob carga (vzdump massivo, Ollama VM310 activa)
- Após **power cycle**, BIOS **reseta para defaults** → boot vai para **NVMe** em vez do **SSD Samsung** (Proxmox)
- Disco ZFS `X6KLT31FT` intermitente (porta ASMedia) — substituído Jun 2026

---

## Causa provável (prioridade)

### 1. Bateria CMOS (CR2032) — **mais provável**

Placas chinesas X99 perdem settings quando a bateria está fraca ou mal contactada.

**Verificar no site:**

1. Medir bateria CR2032: deve estar **≥ 2.8 V** (ideal 3.0–3.3 V)
2. Confirmar jumper **CLR-CMOS** (`CLR-CMOS` na placa) **não** está em posição de clear permanente
3. Substituir bateria; **desligar PSU da parede** 30 s antes de trocar

**Após trocar:** entrar BIOS (`Del`), definir boot order → **Samsung SSD 850 EVO** primeiro, guardar (`F10`).

### 2. PSU insuficiente ou degradada

**PSU actual:** Corsair **650 W Gold** (confirmado Jun 2026).

Carga típica AGLSRV3:

- Xeon E5 (14 cores visíveis) — ~120–165 W pico
- **2× RX580** passthrough VM310 (~150–185 W cada sob carga) → **300–370 W**
- **5× HDD** raidz1 + SSD sistema — ~40–60 W
- **Pico estimado:** **500–655 W** (margem zero na Corsair 650 W)

Brownout da PSU → freeze + CMOS corrupto, especialmente com vzdump + Ollama + ZFS em simultâneo.

**Acção imediata (650 W):** parar VM310 durante backups; usar `scripts/backup/aglsrv3-vzdump-sequential.sh`.  
**Médio prazo:** PSU **≥ 850 W** Gold+ se freezes persistirem sob carga GPU+CPU.

Tutorial flash BIOS + PSU: [`AGLSRV3-BIOS-UEFI-FLASH.md`](AGLSRV3-BIOS-UEFI-FLASH.md)

### 3. Placa Huananzhi — qualidade RTC/CMOS

Comunidade reporta resets frequentes mesmo com bateria nova → circuito RTC ou jumper.

Referências: [GitHub HUANANZHI-X99-F8](https://github.com/paulocmarques/HUANANZHI-X99-F8), [Manual X99-F8](https://www.manualslib.com/manual/3460574/Huananzhi-X99-F8-Gaming.html)

---

## Actualização BIOS

| Item       | Valor                                                               |
| ---------- | ------------------------------------------------------------------- |
| Actual     | **CX99DE29** (Nov 2021)                                             |
| Oficial    | [huananzhi.com X99-F8](https://www.huananzhi.com/en/list_6/34.html) |
| Comunidade | CX99DE77+ (modded, Patreon/GitHub)                                  |

**Atenção:**

- Primeira flash a partir de BIOS stock Huananzhi: preferir **programador SPI (CH341A)** ou UEFI Shell conforme guia da imagem
- **Nunca** flash durante instabilidade eléctrica — usar UPS
- Após flash: clear CMOS (retirar bateria + desligar PSU **15 min**), `Load Optimized Defaults`, reconfigurar boot order

**Settings recomendados pós-BIOS:**

- Boot #1: Samsung SSD 850 EVO (`S2RANX0H564404D`)
- VT-d / IOMMU: **Enabled** (GPU passthrough)
- Above 4G Decoding: **Enabled**
- C-States agressivos: testar **Disabled** se freezes persistirem idle→load

---

## Crash pós-backup VM301 (Jun 2026)

Foi lançado `vzdump` **simultâneo** de 10 guests com **VM310 Ollama running** (24 GB RAM):

```
Mem: 31 Gi total, ~28 Gi used → host sem margem
```

VM301 (stopped, NVMe passthrough) iniciou setup TPM/swtpm no log — I/O + RAM pressure.

**Política segura de backup:**

1. **Nunca** vzdump massivo com VM310 running
2. Sequencial: CTs pequenos → VMs paradas → VM310 por último (ou parar VM310 temporariamente)
3. VM301 **sempre stopped** — backup OK se mapping PCI correcto

---

## Monitorização instalada

```bash
# Instalar no host (remoto de agldv03)
bash scripts/monitoring/aglsrv3-hardware-monitor-install.sh --apply --remote

# Snapshot manual
ssh root@100.123.5.81 /usr/local/sbin/aglsrv3-hardware-snapshot.sh

# Log contínuo (cron 5 min)
tail -f /var/log/hostman/aglsrv3-hardware.log
```

| Métrica           | Ferramenta              | Notas                                            |
| ----------------- | ----------------------- | ------------------------------------------------ |
| CPU temp          | `lm-sensors` / coretemp | Package + per-core                               |
| Potência CPU      | **intel-rapl**          | Estimativa socket, não PSU total                 |
| Temp discos       | `smartctl -A`           | Por HDD/SSD                                      |
| Temp GPU          | `amdgpu` hwmon          | Se driver expõe (host, não passthrough)          |
| Voltagem rails    | **N/A**                 | Sem IPMI nesta placa                             |
| Consumo PSU total | **N/A software**        | Considerar PDU inteligente ou wattímetro externo |

**Alternativas avançadas (opcional):**

- [PVE-Hardware-Monitor](https://github.com/AviFR-dev/PVE-Hardware-Monitor) — dashboard web
- Prometheus + `node_exporter` + textfile collector para RAPL
- UPS com SNMP (voltagem entrada) se disponível no site AGLFG

---

## Checklist pós-intervenção física

- [ ] Bateria CMOS CR2032 nova (≥ 3.0 V)
- [ ] Jumper CLR-CMOS na posição normal (não cleared)
- [ ] Boot order: SSD Samsung → resto
- [ ] BIOS actualizada (se estável eléctricamente)
- [ ] Teste: power off PSU 5 min → boot mantém settings?
- [ ] Monitorização cron activa
- [ ] Backups sequenciais — `scripts/backup/aglsrv3-vzdump-sequential.sh`

---

## Referências

- Discos: [`AGLSRV3-DISKS.md`](AGLSRV3-DISKS.md)
- GPU/Ollama: [`AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md)
- Health check: `scripts/monitoring/aglsrv3-health-check.sh`
