#!/usr/bin/env bash
# Wrapper /usr/local/bin/obsidian para CLI em LXC root + Xvfb (agldv03, CT193).
set -euo pipefail

TARGET="/usr/local/bin/obsidian"
OBSIDIAN_CONFIG="${OBSIDIAN_CONFIG_DIR:-/root/.config/obsidian}"
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/overpower/apps/dev/agl/llm-wiki}"
VAULT_NAME="${OBSIDIAN_VAULT_NAME:-llm-wiki}"

mkdir -p "${OBSIDIAN_CONFIG}"
vault_ts="$(date +%s)000"
obsidian_json="${OBSIDIAN_CONFIG}/obsidian.json"
if [[ ! -f "${obsidian_json}" ]]; then
  cat >"${obsidian_json}" <<EOF
{"vaults":{"${VAULT_NAME}":{"path":"${VAULT_PATH}","ts":${vault_ts},"open":true}},"cli":true}
EOF
  echo "OK: ${obsidian_json} (cli=true, vault=${VAULT_NAME})"
elif ! grep -q '"cli":true' "${obsidian_json}" 2>/dev/null; then
  python3 - <<PY
import json, pathlib
p = pathlib.Path("${obsidian_json}")
data = json.loads(p.read_text()) if p.exists() else {}
data["cli"] = True
vaults = data.setdefault("vaults", {})
v = vaults.setdefault("${VAULT_NAME}", {})
v.setdefault("path", "${VAULT_PATH}")
v.setdefault("ts", ${vault_ts})
v["open"] = True
p.write_text(json.dumps(data, separators=(",", ":")))
PY
  echo "OK: ${obsidian_json} (cli=true injectado)"
fi

cat >"${TARGET}" <<'EOF'
#!/usr/bin/env bash
# Reason: IPC CLI usa o Xvfb do obsidian-hub; head -1 em /tmp falha com Xauthority stale.
resolve_x11() {
  local line display xauth
  line="$(ps -eo args | grep -E '[X]vfb :[0-9]+' | head -1 || true)"
  if [[ -z "${line}" ]]; then
    return 1
  fi
  display=":${line#*Xvfb :}"
  display="${display%% *}"
  xauth="$(grep -oE '/tmp/xvfb-run\.[^ ]+/Xauthority' <<<"${line}" || true)"
  if [[ -z "${xauth}" ]]; then
    xauth="$(find /tmp -maxdepth 2 -path '*/xvfb-run.*/Xauthority' -printf '%T@ %p\n' 2>/dev/null \
      | sort -rn | head -1 | cut -d' ' -f2- || true)"
  fi
  if [[ -n "${display}" && -n "${xauth}" && -f "${xauth}" ]]; then
    export DISPLAY="${display}"
    export XAUTHORITY="${xauth}"
    return 0
  fi
  return 1
}

if resolve_x11; then
  :
elif [[ -n "${OBSIDIAN_DISPLAY:-}" && -n "${OBSIDIAN_XAUTHORITY:-}" && -f "${OBSIDIAN_XAUTHORITY}" ]]; then
  export DISPLAY="${OBSIDIAN_DISPLAY}"
  export XAUTHORITY="${OBSIDIAN_XAUTHORITY}"
fi

exec /opt/obsidian/obsidian --no-sandbox --disable-gpu "$@"
EOF

chmod +x "${TARGET}"
echo "OK: ${TARGET} (Xvfb hub + --no-sandbox)"
