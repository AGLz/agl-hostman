#!/usr/bin/env python3
"""Envia um .ps1 para a VM Windows (guest) via qm guest exec + base64 e executa-o.
Uso no Proxmox: python3 vm104_guest_exec_ps1.py <vmid> /caminho/local/script.ps1 [-- args ao ps1]
Ex.: python3 vm104_guest_exec_ps1.py 104 /tmp/wk45-diagnostics-gateway.ps1 -Repair
"""
from __future__ import annotations

import base64
import pathlib
import subprocess
import sys

CHUNK = 1200
GUEST_PS1 = "C:/Users/Administrator/AppData/Local/Temp/wk45-exec-remote.ps1"
GUEST_B64 = "C:/Users/Administrator/AppData/Local/Temp/wk45-exec-remote.ps1.b64"


def run(args: list) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True)


def ps_escape_single(s: str) -> str:
    return s.replace("'", "''")


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
    qm_powershell(vmid, f"if (Test-Path '{guest_b64_path}') {{ Remove-Item '{guest_b64_path}' -Force }}")
    for i in range(0, len(b64), CHUNK):
        part = ps_escape_single(b64[i : i + CHUNK])
        r = qm_powershell(vmid, f"[IO.File]::AppendAllText('{guest_b64_path}', '{part}')")
        if r.returncode != 0:
            sys.stderr.write(r.stderr or "")
            sys.exit(r.returncode)
    decode = (
        f"$raw = Get-Content -Raw '{guest_b64_path}'; "
        f"$bytes = [Convert]::FromBase64String($raw.Trim()); "
        f"[IO.File]::WriteAllBytes('{guest_out_path}', $bytes)"
    )
    r = qm_powershell(vmid, decode)
    if r.returncode != 0:
        sys.stderr.write(r.stderr or "")
        sys.exit(r.returncode)


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Uso: vm104_guest_exec_ps1.py <vmid> <script.ps1> [-- args...]",
            file=sys.stderr,
        )
        return 2
    vmid = sys.argv[1]
    local = pathlib.Path(sys.argv[2])
    if not local.is_file():
        print(f"Erro: ficheiro inexistente: {local}", file=sys.stderr)
        return 2
    ps1_args = sys.argv[3:]
    args_ps = " ".join(ps1_args) if ps1_args else ""

    upload_b64_file(vmid, local.read_bytes(), GUEST_B64, GUEST_PS1)

    # -File com caminho sem espaços → evita nested quotes difíceis no -Command
    invoke = f"& '{GUEST_PS1}'"
    if args_ps:
        invoke += f" {args_ps}"
    r = qm_powershell(vmid, invoke)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr or "")
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
