#!/usr/bin/env bash
# Instala arsenal de guerra nos profiles Hermes (CT188) + plugin Ponytail.
#
# Uso (root no CT188):
#   bash install-hermes-arsenal-skills-ct188.sh
#   INSTALL_PONYTAIL_PLUGIN=0 bash install-hermes-arsenal-skills-ct188.sh
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
AGL_HOSTMAN="${AGL_HOSTMAN:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_USER="${HERMES_USER:-hermes}"
INSTALL_PONYTAIL_PLUGIN="${INSTALL_PONYTAIL_PLUGIN:-1}"

log() { printf '[hermes-arsenal] %s\n' "$*"; }

profile_dir() {
  case "$1" in
    jarvis) echo "${HERMES_ROOT}/data" ;;
    *) echo "${HERMES_ROOT}/profiles/$1" ;;
  esac
}

link_skill() {
  local agent="$1"
  local skill_name="$2"
  local src="$3"
  local pdir
  pdir="$(profile_dir "$agent")"
  local dst="${pdir}/skills/${skill_name}"

  if [[ ! -e "$src" ]]; then
    log "WARN skill em falta: $src"
    return 0
  fi
  /usr/bin/install -d -m 0700 "${pdir}/skills"
  ln -sfn "$src" "$dst"
  if chown -h "${HERMES_UID}:${HERMES_UID}" "$dst" 2>/dev/null; then
    :
  else
    log "WARN chown symlink falhou (correr como root no CT188?): $dst"
  fi
  log "OK ${agent} ← ${skill_name}"
}

install_ponytail_plugin() {
  [[ "$INSTALL_PONYTAIL_PLUGIN" == "1" ]] || { log "INSTALL_PONYTAIL_PLUGIN=0 — saltar"; return 0; }
  if ! command -v hermes >/dev/null 2>&1; then
    log "WARN hermes CLI ausente — Ponytail plugin manual:"
    log "  hermes plugins install DietrichGebert/ponytail --enable"
    return 0
  fi
  if id "$HERMES_USER" &>/dev/null; then
  log "instalar Ponytail plugin (user $HERMES_USER)"
  su - "$HERMES_USER" -c 'hermes plugins install DietrichGebert/ponytail --enable' 2>/dev/null \
    || log "WARN ponytail plugin falhou — instalar manualmente no CT188"
  else
    hermes plugins install DietrichGebert/ponytail --enable 2>/dev/null \
      || log "WARN ponytail plugin falhou"
  fi
}

VTD_SRC="${AGL_HOSTMAN}/.agents/skills/video-transcript-downloader"
IMPROVE_SRC="${AGL_HOSTMAN}/.cursor/skills/improve"
VIDEO_ANALYSIS_SRC="${AGL_HOSTMAN}/.cursor/skills/agl-video-analysis"
ARCH_DIAG_SRC="${AGL_HOSTMAN}/.cursor/skills/agl-architecture-diagram"
DRAWIO_SRC="${AGL_HOSTMAN}/.cursor/skills/drawio-skill"

AGENTS=(jarvis elon satya werner curator orion)

for agent in "${AGENTS[@]}"; do
  link_skill "$agent" "video-transcript-downloader" "$VTD_SRC"
  link_skill "$agent" "improve" "$IMPROVE_SRC"
  link_skill "$agent" "agl-video-analysis" "$VIDEO_ANALYSIS_SRC"
  link_skill "$agent" "agl-architecture-diagram" "$ARCH_DIAG_SRC"
  link_skill "$agent" "drawio-skill" "$DRAWIO_SRC"
  chown -R "${HERMES_UID}:${HERMES_UID}" "$(profile_dir "$agent")/skills" 2>/dev/null || true
done

install_ponytail_plugin

log "=== Arsenal skills ligadas em ${#AGENTS[@]} profiles ==="
log "Reiniciar contentores Hermes se necessário: docker compose restart"
