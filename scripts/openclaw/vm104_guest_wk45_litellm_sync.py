#!/usr/bin/env python3
"""Sincroniza openclaw.json na VM Windows (wk45) com LiteLLM agldv03 via qm guest exec."""
from __future__ import annotations

import base64
import os
import pathlib
import subprocess
import sys

CHUNK = 1200

# Barras à frente: evitam escapes \U no Python e são válidas no PowerShell
GUEST_CJS = "C:/Users/Administrator/AppData/Local/Temp/wk45-sync-openclaw-litellm.cjs"
GUEST_ENV = "C:/Users/Administrator/.openclaw/litellm-gateway.env"
GUEST_SECRET = "C:/Users/Administrator/.openclaw/litellm-master.secret.env"
GUEST_B64_CJS = "C:/Users/Administrator/AppData/Local/Temp/wk45-cjs.b64.txt"
GUEST_B64_ENV = "C:/Users/Administrator/AppData/Local/Temp/wk45-env.b64.txt"
GUEST_B64_SECRET = "C:/Users/Administrator/AppData/Local/Temp/wk45-secret.b64.txt"
NODE_EXE = "C:/Program Files/nodejs/node.exe"


def run(args: list) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True)


def ps_escape_single(s: str) -> str:
    return s.replace("'", "''")


def fetch_master_key() -> str:
    env_key = os.environ.get("LITELLM_MASTER_KEY", "").strip()
    if env_key:
        return env_key
    ssh_host = os.environ.get("LITELLM_SSH_HOST", "root@100.94.221.87")
    r = run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "ConnectTimeout=20",
            ssh_host,
            "grep ^LITELLM_MASTER_KEY= /opt/litellm/.env 2>/dev/null | cut -d= -f2-",
        ]
    )
    if r.returncode != 0 or not (r.stdout or "").strip():
        print(
            "Erro: defina LITELLM_MASTER_KEY ou configure SSH ao agldv03.",
            file=sys.stderr,
        )
        sys.stderr.write(r.stderr or "")
        sys.exit(1)
    return r.stdout.strip()


def qm_powershell(vmid: str, command: str) -> subprocess.CompletedProcess:
    return run(
        [
            "qm",
            "guest",
            "exec",
            vmid,
            "--",
            "cmd",
            "/c",
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            command,
        ]
    )


def upload_b64_file(vmid: str, data: bytes, guest_b64_path: str, guest_out_path: str) -> None:
    b64 = base64.b64encode(data).decode("ascii")
    ps_del = f"if (Test-Path '{guest_b64_path}') {{ Remove-Item '{guest_b64_path}' -Force }}"
    qm_powershell(vmid, ps_del)
    for i in range(0, len(b64), CHUNK):
        part = ps_escape_single(b64[i : i + CHUNK])
        ps = f"[IO.File]::AppendAllText('{guest_b64_path}', '{part}')"
        r = qm_powershell(vmid, ps)
        if r.returncode != 0:
            sys.stderr.write(r.stderr)
            sys.exit(r.returncode)
    decode = (
        f"$raw = Get-Content -Raw '{guest_b64_path}'; "
        f"$bytes = [Convert]::FromBase64String($raw.Trim()); "
        f"[IO.File]::WriteAllBytes('{guest_out_path}', $bytes)"
    )
    r = qm_powershell(vmid, decode)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        sys.exit(r.returncode)


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Uso: vm104_guest_wk45_litellm_sync.py <vmid> [wk45-sync-openclaw-litellm.cjs]",
            file=sys.stderr,
        )
        return 2
    vmid = sys.argv[1]
    cjs_host = pathlib.Path(
        sys.argv[2] if len(sys.argv) > 2 else "/tmp/wk45-sync-openclaw-litellm.cjs"
    )
    if not cjs_host.is_file():
        print(f"Erro: ficheiro inexistente: {cjs_host}", file=sys.stderr)
        return 2

    key = fetch_master_key()
    proxy = os.environ.get("LITELLM_PROXY_BASE_URL", "http://100.94.221.87:4000")
    key_b64 = base64.b64encode(key.encode("utf-8")).decode("ascii")

    upload_b64_file(vmid, cjs_host.read_bytes(), GUEST_B64_CJS, GUEST_CJS)

    env_text = (
        f'LITELLM_GATEWAY_URL="{proxy}"\n'
        f'ANTHROPIC_BASE_URL="{proxy}"\n'
        f'LITELLM_MASTER_KEY="{key}"\n'
        f'LITELLM_API_KEY="{key}"\n'
        f'OPENAI_API_KEY="{key}"\n'
    )
    upload_b64_file(vmid, env_text.encode("utf-8"), GUEST_B64_ENV, GUEST_ENV)

    # Alinha com Linux (~/.openclaw/litellm-master.secret.env): clientes OpenClaw / ferramentas que leem só API_KEY
    secret_text = (
        f'LITELLM_MASTER_KEY="{key}"\n'
        f'LITELLM_API_KEY="{key}"\n'
        f'OPENAI_API_KEY="{key}"\n'
    )
    upload_b64_file(vmid, secret_text.encode("utf-8"), GUEST_B64_SECRET, GUEST_SECRET)

    # Só o exit code do Node importa; openclaw restart é best-effort (PATH / serviço)
    run_js = (
        f"$kb = '{key_b64}'; "
        f"$k = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($kb)); "
        f"$env:LITELLM_MASTER_KEY = $k; "
        f"$env:LITELLM_API_KEY = $k; "
        f"$env:OPENAI_API_KEY = $k; "
        f"$env:LITELLM_PROXY_BASE_URL = '{proxy}'; "
        f"$cfg = 'C:\\Users\\Administrator\\.openclaw\\openclaw.json'; "
        f"if (-not (Test-Path $cfg)) {{ Write-Error 'Missing openclaw.json'; exit 2 }}; "
        f"& '{NODE_EXE}' '{GUEST_CJS}' $cfg; "
        f"$code = $LASTEXITCODE; "
        f"$oc = Get-Command openclaw -ErrorAction SilentlyContinue; "
        f"if ($oc) {{ try {{ & openclaw gateway restart 2>$null }} catch {{}} }}; "
        f"exit $code"
    )
    r = qm_powershell(vmid, run_js)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
