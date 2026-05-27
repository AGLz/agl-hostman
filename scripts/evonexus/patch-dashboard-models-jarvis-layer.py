#!/usr/bin/env python3
"""Garante \"jarvis\" em AGENT_LAYERS (engineering) no models.py do dashboard EvoNexus.

Motivo: /api/agents usa has_agent_access(); com agent_access por camada, agentes sem
entrada em AGENT_LAYERS ficam locked. O ficheiro models.py vem da imagem Docker —
reaplicar após `docker compose pull` / recreate do contentor.

Uso no CT242 (exemplo):
  docker cp patch-dashboard-models-jarvis-layer.py evonexus-dashboard:/tmp/
  docker exec evonexus-dashboard python3 /tmp/patch-dashboard-models-jarvis-layer.py
  docker compose -f docker-compose.hub.yml restart dashboard
"""
from __future__ import annotations

from pathlib import Path

MODELS = Path("/workspace/dashboard/backend/models.py")
NEEDLE = '    "oracle": "business",\n'
INSERT = NEEDLE + '    "jarvis": "engineering",\n'
MARKER = '"jarvis": "engineering"'


def main() -> None:
    if not MODELS.is_file():
        raise SystemExit(f"Ficheiro inexistente: {MODELS}")
    text = MODELS.read_text()
    if MARKER in text:
        print("jarvis: ja presente em AGENT_LAYERS — nada a fazer")
        return
    if NEEDLE not in text:
        raise SystemExit('Marcador "oracle": "business" nao encontrado — revisar upstream')
    MODELS.write_text(text.replace(NEEDLE, INSERT, 1))
    print("jarvis: AGENT_LAYERS actualizado — reinicie o servico dashboard")


if __name__ == "__main__":
    main()
