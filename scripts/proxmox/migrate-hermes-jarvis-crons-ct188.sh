#!/usr/bin/env bash
# Migra crons "executor" do Jarvis para os agentes especialistas (modelo Manager).
# Jarvis fica só com trabalho gerencial (briefing, stand-up) + inbox CEO (emails).
#
# Mapeamento:
#   Werner ← infra (daily-maintenance, daily-backup, health-check)
#   Elon   ← research/roadmap (AI Opportunity Research, AI Implementation Planning Sprint)
#   Satya  ← pipeline makemoney (sync-crons, deep-dive, wiki-feed, generate-dossiers, pipeline-report, git-sync)
#
# Uso (root no CT188):
#   bash migrate-hermes-jarvis-crons-ct188.sh            # aplica
#   DRY_RUN=1 bash migrate-hermes-jarvis-crons-ct188.sh  # só mostra

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
DRY_RUN="${DRY_RUN:-0}"
TS="$(date +%Y%m%d-%H%M%S)"

JARVIS_JOBS="${HERMES_ROOT}/data/cron/jobs.json"
test -f "${JARVIS_JOBS}" || { echo "ERRO: falta ${JARVIS_JOBS}" >&2; exit 1; }

python3 - "${HERMES_ROOT}" "${JARVIS_JOBS}" "${DRY_RUN}" "${TS}" <<'PY'
import json, sys, shutil
from pathlib import Path

root, jarvis_path, dry, ts = sys.argv[1], Path(sys.argv[2]), sys.argv[3] == "1", sys.argv[4]

# name (em jarvis) -> agente destino (profile dir; 'data' = jarvis)
MAP = {
    "hermes-ct188-daily-maintenance": "werner",
    "hermes-ct188-daily-backup": "werner",
    "hermes-ct188-health-check": "werner",
    "AI Opportunity Research — scan expandido": "elon",
    "AI Implementation Planning Sprint": "elon",
    "makemoney-sync-crons": "satya",
    "makemoney-deep-dive": "satya",
    "makemoney-wiki-feed": "satya",
    "makemoney-generate-dossiers": "satya",
    "makemoney-pipeline-report": "satya",
    "makemoney-git-sync": "satya",
}

# Correção de referências de script partidas (descoberto na auditoria 2026-06-29).
SCRIPT_FIX = {
    "hermes-makemoney-sync-crons-fixed.sh": "hermes-makemoney-sync-crons.sh",
    "scripts/hermes-makemoney-deep-dive.sh": "hermes-makemoney-deep-dive.sh",
    "makemoney-pipeline-report-wrapper.sh": "hermes-makemoney-pipeline-report.sh",
}

SRC_SCRIPTS = Path(root) / "data" / "scripts"

def jobs_path(agent):
    if agent == "data":
        return root + "/data/cron/jobs.json"
    return f"{root}/profiles/{agent}/cron/jobs.json"

def load(p):
    p = Path(p)
    if not p.is_file():
        return {"jobs": []}
    d = json.loads(p.read_text())
    return d if isinstance(d, dict) else {"jobs": d}

def save(p, d):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

jdata = load(jarvis_path)
jjobs = jdata.setdefault("jobs", [])

moving = [j for j in jjobs if j.get("name") in MAP]
keeping = [j for j in jjobs if j.get("name") not in MAP]

print(f"Jarvis: {len(jjobs)} jobs → mover {len(moving)}, manter {len(keeping)}")
for j in moving:
    sc = j.get("script")
    fix = SCRIPT_FIX.get(sc)
    note = f"  (fix: {sc} → {fix})" if fix else ""
    print(f"  → {MAP[j['name']]:8} {j.get('name')}{note}")
print("Mantém em Jarvis:")
for j in keeping:
    print(f"  · {j.get('name')}")

if dry:
    print("\n[DRY_RUN] nada gravado.")
    sys.exit(0)

# normaliza script field + recolhe ficheiros a copiar por destino
def norm_script(j):
    sc = j.get("script")
    if not sc:
        return None
    sc = SCRIPT_FIX.get(sc, sc)
    if sc.startswith("scripts/"):
        sc = sc[len("scripts/"):]
    j["script"] = sc
    return sc

# backups
shutil.copy2(jarvis_path, str(jarvis_path) + f".bak-{ts}")

by_dest = {}
for j in moving:
    by_dest.setdefault(MAP[j["name"]], []).append(j)

for agent, items in by_dest.items():
    dest_p = jobs_path(agent)
    ddata = load(dest_p)
    djobs = ddata.setdefault("jobs", [])
    dnames = {x.get("name"): i for i, x in enumerate(djobs)}
    if Path(dest_p).is_file():
        shutil.copy2(dest_p, dest_p + f".bak-{ts}")
    dest_scripts = Path(root) / "profiles" / agent / "scripts"
    dest_scripts.mkdir(parents=True, exist_ok=True)
    for j in items:
        sc = norm_script(j)
        if sc:
            src_f = SRC_SCRIPTS / sc
            if src_f.is_file():
                shutil.copy2(src_f, dest_scripts / sc)
                print(f"   copy script {sc} → {agent}/scripts")
            else:
                print(f"   AVISO: script ausente em data/scripts: {sc}")
        if j["name"] in dnames:
            djobs[dnames[j["name"]]] = j
        else:
            djobs.append(j)
    save(dest_p, ddata)
    print(f"OK {agent}: +{len(items)} jobs → {dest_p}")

jdata["jobs"] = keeping
save(jarvis_path, jdata)
print(f"OK jarvis: {len(keeping)} jobs restantes → {jarvis_path}")
PY

if [[ "${DRY_RUN}" != "1" ]]; then
  # permissões por perfil destino (jobs + scripts copiados)
  for a in werner elon satya; do
    f="${HERMES_ROOT}/profiles/${a}/cron/jobs.json"
    [[ -f "${f}" ]] && chown "${HERMES_UID}:${HERMES_UID}" "${f}" && chmod 644 "${f}"
    sd="${HERMES_ROOT}/profiles/${a}/scripts"
    if [[ -d "${sd}" ]]; then
      chown -R "${HERMES_UID}:${HERMES_UID}" "${sd}"
      find "${sd}" -name '*.sh' -exec chmod 0755 {} \; 2>/dev/null || true
    fi
  done
  chown "${HERMES_UID}:${HERMES_UID}" "${JARVIS_JOBS}" && chmod 644 "${JARVIS_JOBS}"
  echo "OK migração aplicada (backups .bak-${TS}). Restart agentes afetados para recarregar crons."
fi
