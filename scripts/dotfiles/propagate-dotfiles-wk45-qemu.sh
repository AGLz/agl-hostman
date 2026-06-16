#!/usr/bin/env bash
# Propaga dotfiles + live sync para aglwk45 (VM104) via AGLSRV1 + qm guest exec.
#
# Pré-requisito: git pull no NFS overpower (todos os hosts vêem o mesmo repo).
#
# Uso:
#   bash scripts/dotfiles/propagate-dotfiles-wk45-qemu.sh
#   DRY_RUN=1 bash scripts/dotfiles/propagate-dotfiles-wk45-qemu.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGLSRV="${AGLSRV1_HOST:-root@100.107.113.33}"
VMID="${AGLWK45_VMID:-104}"
WK45_REPO="${WK45_REPO_WIN:-C:/Users/Administrator/apps/dev/agl/agl-hostman}"
HOME_SYNC="${WK45_HOME_SYNC:-Z:/apps/dev/agl/agl-home-sync}"
HOME_USER="${AGL_HOME_USER:-linux-root}"
GUEST_DOTFILES="C:/Windows/Temp/agl-dotfiles"
BUNDLED_REPO="${GUEST_DOTFILES}/agl-hostman"

PS1_GUEST="$REPO_ROOT/scripts/dotfiles/wk45-propagate-dotfiles-guest.ps1"
INSTALL_PS1="$REPO_ROOT/scripts/dotfiles/install-agl-home-sync.ps1"
VERIFY_SH="$REPO_ROOT/scripts/dotfiles/verify-agl-home-sync.sh"
MIRROR_PS1="$REPO_ROOT/scripts/skills/wk45-mirror-agl-hostman-repo.ps1"
HELPER="$REPO_ROOT/scripts/openclaw/vm104_guest_exec_ps1.py"

for f in "$PS1_GUEST" "$INSTALL_PS1" "$VERIFY_SH" "$HELPER"; do
  [[ -f "$f" ]] || { echo "Erro: em falta $f" >&2; exit 1; }
done

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "=== DRY_RUN propagate-dotfiles-wk45-qemu ==="
  echo "AGLSRV=$AGLSRV VMID=$VMID"
  echo "Guest: wk45-propagate-dotfiles-guest.ps1"
  echo "RepoRoot=$WK45_REPO HomeSync=$HOME_SYNC HomeUser=$HOME_USER"
  exit 0
fi

echo "=== AGLSRV1 $AGLSRV — dotfiles VM $VMID (guest agent) ==="
ssh -o BatchMode=yes -o ConnectTimeout=25 "$AGLSRV" "qm agent ${VMID} ping" >/dev/null

# Garantir repo actualizado no NFS (wk45 lê Z:\apps\dev\agl\agl-hostman)
git -c safe.directory="$REPO_ROOT" -C "$REPO_ROOT" pull --ff-only 2>/dev/null || true

scp -q "$PS1_GUEST" "$INSTALL_PS1" "$VERIFY_SH" "$HELPER" "${AGLSRV}:/tmp/"
if [[ -f "$MIRROR_PS1" ]]; then
  scp -q "$MIRROR_PS1" "${AGLSRV}:/tmp/"
fi

# Mirror Z:\ → C:\ (repo local no guest) quando possível
if [[ -f "$MIRROR_PS1" && "${SKIP_MIRROR:-0}" != "1" ]]; then
  echo "=== Mirror repo agl-hostman no guest ==="
  ssh -o BatchMode=yes "$AGLSRV" \
    "python3 /tmp/vm104_guest_exec_ps1.py ${VMID} /tmp/wk45-mirror-agl-hostman-repo.ps1" \
    2>&1 | tail -15 || echo "WARN: mirror falhou — continuar com UNC/temp"
fi

# Empacotar config/dotfiles para upload ao guest (SYSTEM não precisa de repo completo)
DOTFILES_TAR="/tmp/agl-dotfiles-config.tar"
tar -C "$REPO_ROOT" -cf "$DOTFILES_TAR" config/dotfiles
scp -q "$DOTFILES_TAR" "${AGLSRV}:/tmp/agl-dotfiles-config.tar"

# Copiar scripts + config/dotfiles para guest
ssh -o BatchMode=yes "$AGLSRV" bash -s "$VMID" "$BUNDLED_REPO" <<'REMOTE'
set -euo pipefail
VMID="$1"
BUNDLED_REPO="$2"
python3 - "$VMID" "$BUNDLED_REPO" <<'PY'
import pathlib
import sys
import time

sys.path.insert(0, "/tmp")
from vm104_guest_exec_ps1 import upload_b64_file, qm_powershell

vmid, bundled_repo = sys.argv[1], sys.argv[2]
guest_dir = "C:/Windows/Temp/agl-dotfiles"
qm_powershell(vmid, f"New-Item -ItemType Directory -Force -Path '{guest_dir}' | Out-Null")
qm_powershell(vmid, f"New-Item -ItemType Directory -Force -Path '{bundled_repo}' | Out-Null")

for name in ("install-agl-home-sync.ps1", "wk45-propagate-dotfiles-guest.ps1", "verify-agl-home-sync.sh"):
    local = pathlib.Path("/tmp") / name
    out = f"{guest_dir}/{name}"
    upload_b64_file(vmid, local.read_bytes(), f"{out}.b64", out)
    print(f"OK uploaded {name}")
    time.sleep(2)

tar_path = pathlib.Path("/tmp/agl-dotfiles-config.tar")
guest_tar = f"{guest_dir}/agl-dotfiles-config.tar"
upload_b64_file(vmid, tar_path.read_bytes(), f"{guest_tar}.b64", guest_tar)
print("OK uploaded config tarball")
time.sleep(2)

extract_cmd = (
    f"tar -xf '{guest_tar}' -C '{bundled_repo}' 2>&1; "
    f"if (Test-Path '{bundled_repo}/config/dotfiles/manifest.yaml') {{ Write-Output OK_TAR_EXTRACT }} "
    f"else {{ Write-Output FAIL_TAR_EXTRACT; exit 1 }}"
)
r = qm_powershell(vmid, extract_cmd)
print(r.stdout or "")
if r.returncode != 0:
    sys.exit(r.returncode)
PY
REMOTE

ssh -o BatchMode=yes "$AGLSRV" \
  "python3 /tmp/vm104_guest_exec_ps1.py ${VMID} /tmp/wk45-propagate-dotfiles-guest.ps1 \
    -RepoRoot '${WK45_REPO}' -HomeSyncRoot '${HOME_SYNC}' -HomeUser '${HOME_USER}' \
    -BundledRepo '${BUNDLED_REPO}'"

echo ""
echo "=== A aguardar dotfiles no guest (poll até 20 min) ==="
deadline=$((SECONDS + 1200))
while (( SECONDS < deadline )); do
  out=$(ssh -o BatchMode=yes "$AGLSRV" \
    "qm guest exec ${VMID} -- powershell -NoProfile -Command \"if (Test-Path C:/Users/Administrator/wk45-dotfiles-result.txt) { Get-Content C:/Users/Administrator/wk45-dotfiles-result.txt -Tail 6 } else { Write-Output WAITING }\"" \
    2>&1) || true
  if echo "$out" | grep -q "concluído\|concluido"; then
    echo "Guest reportou conclusão."
    break
  fi
  if echo "$out" | grep -q "FAIL install exit=\|FAIL verify exit="; then
    echo "Guest dotfiles falhou."
    break
  fi
  sleep 20
done

echo ""
echo "=== Resultado guest (tail) ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"Get-Content C:/Users/Administrator/wk45-dotfiles-result.txt -Tail 30\"" \
  2>&1 | tail -40

echo ""
echo "=== Verificação rápida symlinks ==="
ssh -o BatchMode=yes "$AGLSRV" \
  "qm guest exec ${VMID} -- powershell -NoProfile -Command \"\$c=Get-Item 'C:\\Users\\Administrator\\.cursor\\chats' -ErrorAction SilentlyContinue; if (\$c -and \$c.LinkType) { Write-Output ('CHATS_SYMLINK ' + (\$c.Target -join ',')) } else { Write-Output CHATS_MISSING }\"" \
  2>&1 | tail -5

echo ""
echo "=== Concluído: dotfiles propagado para aglwk45 (VM${VMID}) ==="
