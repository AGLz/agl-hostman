#!/usr/bin/env bash
# Governança de crons Hermes CT188 — anti-flood, briefing consolidado, email crons off.
# Jarvis = Cron Steward (registo em hermes-cron-registry.yaml).
#
# Uso (root no CT188):
#   bash fix-hermes-cron-governance-ct188.sh
#   bash fix-hermes-cron-governance-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman --dry-run

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
DRY="${2:-}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
TELEGRAM_CHAT="${TELEGRAM_CHAT:-1272190248}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"
MON="${AGL_HOSTMAN}/scripts/monitoring"

run() {
  if [[ "${DRY}" == "--dry-run" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

echo "=== Hermes cron governance (Jarvis = Cron Steward) ==="

echo "=== 1/8 Instalar scripts monitoring ==="
for s in \
  hermes-notify-lib.sh \
  hermes-ct188-daily-briefing-fleet.sh \
  hermes-ct188-daily-briefing-humanized.sh \
  hermes-ct188-health-check.sh \
  hermes-ct188-daily-maintenance.sh \
  hermes-ct188-daily-backup.sh \
  hermes-argus-quota-digest.sh; do
  src="${MON}/${s}"
  test -f "${src}" || { echo "ERRO: falta ${src}" >&2; exit 1; }
  for dest_root in "${HERMES_ROOT}/data/scripts" "${HERMES_ROOT}/profiles/werner/scripts" "${HERMES_ROOT}/profiles/argus/scripts"; do
    if [[ -d "$(dirname "${dest_root}")" ]] || [[ "${dest_root}" == *"/data/scripts" ]]; then
      run install -d -m 755 -o "${HERMES_UID}" -g "${HERMES_UID}" "${dest_root}" 2>/dev/null || run mkdir -p "${dest_root}"
      run sed 's/\r$//' "${src}" > "${dest_root}/${s}.tmp"
      run mv "${dest_root}/${s}.tmp" "${dest_root}/${s}"
      run chmod 0755 "${dest_root}/${s}"
      run chown "${HERMES_UID}:${HERMES_UID}" "${dest_root}/${s}" 2>/dev/null || true
    fi
  done
  echo "OK ${s}"
done

echo "=== 2/8 Migrar executores Jarvis → Werner/Elon/Satya (se ainda presentes) ==="
if [[ "${DRY}" != "--dry-run" ]] && [[ -f "${JARVIS_JOBS:-${HERMES_ROOT}/data/cron/jobs.json}" ]]; then
  bash "${SCRIPTS}/migrate-hermes-jarvis-crons-ct188.sh" 2>/dev/null || echo "AVISO: migrate skip"
fi

echo "=== 3/8 Setup crons por agente (Argus, Curator, Orion, Standup) ==="
for setup in \
  setup-hermes-argus-monitor-crons-ct188.sh \
  setup-hermes-curator-crons-ct188.sh \
  setup-hermes-orion-media-crons-ct188.sh \
  setup-hermes-jarvis-standup-cron-ct188.sh; do
  run bash "${SCRIPTS}/${setup}" 2>/dev/null || echo "AVISO: ${setup}"
done

echo "=== 4/8 Patch jobs.json — email anti-flood + health schedule ==="
python3 - "${HERMES_ROOT}" "${TELEGRAM_CHAT}" <<'PY'
import json, sys
from pathlib import Path

root, chat = Path(sys.argv[1]), sys.argv[2]

EMAIL_OFF = {
    "email-digest-manha",
    "email-digest-noite",
    "email-critico-monitor",
    "email-summary-domingo",
}
LEGACY_OFF = {
    "Verificar status do Gateway Jarvis (localhost:8642",
    "Argus LiteLLM Quota Monitor AGL Agency",
}
REASON = "Desactivado 2026-07-09: sem inbox/tools ou duplicado — ver fix-hermes-cron-governance"
LEGACY_REASON = "Desactivado 2026-07-09: legado flood (*/1, */5) — substituído por monitores profile + briefing"

def patch_file(path: Path):
    if not path.is_file():
        return
    data = json.loads(path.read_text())
    jobs = data if isinstance(data, list) else data.setdefault("jobs", [])
    changed = False
    for j in jobs:
        name = j.get("name", "")
        if name in EMAIL_OFF:
            if j.get("enabled", True):
                j["enabled"] = False
                j["paused_reason"] = REASON
                changed = True
                print(f"  DISABLE {path.name}: {name}")
        if name in LEGACY_OFF or name.startswith("Verificar status do Gateway"):
            if j.get("enabled", True):
                j["enabled"] = False
                j["paused_reason"] = LEGACY_REASON
                changed = True
                print(f"  DISABLE legacy {path.name}: {name}")
        if name == "hermes-ct188-health-check":
            expr = "0 8,20 * * *"
            j.setdefault("schedule", {})["expr"] = expr
            j["schedule_display"] = expr
            changed = True
            print(f"  SCHEDULE {name} → {expr}")
        if name == "hermes-daily-briefing":
            j["script"] = "hermes-ct188-daily-briefing-humanized.sh"
            j["no_agent"] = True
            changed = True
    if isinstance(data, list):
        out = jobs
    else:
        data["jobs"] = jobs
        out = data
    if changed:
        path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

patch_file(root / "data" / "cron" / "jobs.json")
for p in (root / "profiles").glob("*/cron/jobs.json"):
    jobs = json.loads(p.read_text()).get("jobs", [])
    new_jobs = [j for j in jobs if j.get("name") != "argus-limits-watch"]
    if len(new_jobs) != len(jobs):
        data = json.loads(p.read_text())
        if isinstance(data, dict):
            data["jobs"] = new_jobs
        else:
            data = new_jobs
        p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"  REMOVED argus-limits-watch from {p}")
    patch_file(p)
PY

echo "=== 5/8 Permissões cron ==="
run bash "${SCRIPTS}/fix-hermes-cron-perms-ct188.sh" 2>/dev/null || true

echo "=== 6/8 Reiniciar gateways (scheduler) ==="
if [[ "${DRY}" != "--dry-run" ]] && command -v docker >/dev/null 2>&1; then
  for c in agl-hermes-jarvis agl-hermes-werner agl-hermes-satya agl-hermes-elon \
           agl-hermes-argus agl-hermes-curator agl-hermes-orion; do
    if docker ps --format '{{.Names}}' | grep -qx "${c}"; then
      docker restart "${c}" >/dev/null && echo "OK restart ${c}"
      sleep 3
    fi
  done
fi

echo "=== 7/8 Inventário fleet ==="
python3 - "${HERMES_ROOT}" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
total = 0
for p in sorted(root.glob("**/cron/jobs.json")):
    d = json.loads(p.read_text())
    jobs = d if isinstance(d, list) else d.get("jobs", [])
    en = sum(1 for j in jobs if j.get("enabled", True))
    tg = sum(1 for j in jobs if j.get("enabled", True) and j.get("deliver"))
    print(f"  {p.relative_to(root)}: {en}/{len(jobs)} activos, {tg} com deliver")
    total += en
print(f"Total activos: {total}")
PY

echo "=== 8/8 Smoke briefing (dry stdout) ==="
if [[ "${DRY}" != "--dry-run" ]] && [[ -x "${HERMES_ROOT}/data/scripts/hermes-ct188-daily-briefing-fleet.sh" ]]; then
  HERMES_HOME="${HERMES_ROOT}/data" bash "${HERMES_ROOT}/data/scripts/hermes-ct188-daily-briefing-fleet.sh" | head -20
fi

echo ""
echo "Concluído. Jarvis = Cron Steward. Registo: scripts/proxmox/hermes-cron-registry.yaml"
echo "Email crons desactivados até integração inbox. Monitores: [SILENT] em OK."
