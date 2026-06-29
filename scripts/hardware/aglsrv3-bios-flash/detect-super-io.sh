#!/usr/bin/env bash
# Identifica Super I/O na HUANANZHI X99-F8 (escolha do ROM iEngineer correcto).
# Correr no host AGLSRV3 com Proxmox parado ou a partir de Linux live USB.
set -euo pipefail

echo "=== HUANANZHI X99-F8 — detecção hardware ==="
echo "BIOS: $(dmidecode -s bios-version 2>/dev/null || echo '?')"
echo "Board: $(dmidecode -s baseboard-product-name 2>/dev/null || echo '?')"
echo

if command -v lspci >/dev/null; then
  echo "--- lspci ISA/LPC ---"
  lspci | grep -iE 'isa|lpc|bridge' || true
fi

echo
echo "--- Super I/O (dmesg) ---"
dmesg 2>/dev/null | grep -iE 'nct5532|nct5567|nuvoton|super.?i/o' | tail -10 || true

echo
echo "--- lm-sensors (módulos voltagem) ---"
if command -v sensors >/dev/null; then
  sensors 2>/dev/null | head -20 || true
else
  echo "lm-sensors não instalado"
fi

echo
echo "ROM iEngineer (CX99DE77+):"
echo "  NCT5532D  → *-5532*.ROM / pasta 5532"
echo "  NCT5567D-B → *-5567*.ROM / pasta 5567"
echo
echo "Se incerto: foto da placa perto do chip Nuvoton ou usar ROM 5532 (mais comum em X99-F8 2021)."
