#!/usr/bin/env python3
"""Envia openclaw.json completo para a VM Windows (aglwk45) via qm guest exec no AGLSRV1.

Uso no Proxmox (AGLSRV1): após copiar o JSON e este script para /tmp/
  python3 /tmp/vm104_guest_push_openclaw_json.py <vmid> /tmp/openclaw.json

Requisitos: guest agent ativo na VM; Node.js e openclaw no PATH do guest (opcional restart).
"""
from __future__ import annotations

import base64
import pathlib
import subprocess
import sys

CHUNK = 1200


def run(args: list) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True)


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "Uso: vm104_guest_push_openclaw_json.py <vmid> <openclaw.json>",
            file=sys.stderr,
        )
        return 2
    vmid = sys.argv[1]
    src = pathlib.Path(sys.argv[2])
    if not src.is_file():
        print(f"Erro: ficheiro inexistente: {src}", file=sys.stderr)
        return 2

    b64 = base64.b64encode(src.read_bytes()).decode("ascii")
    guest_b64 = "C:\\\\Users\\\\Administrator\\\\AppData\\\\Local\\\\Temp\\\\oc-openclaw-full.b64.txt"

    run(
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
            f"if (Test-Path '{guest_b64}') {{ Remove-Item '{guest_b64}' -Force }}",
        ]
    )

    for i in range(0, len(b64), CHUNK):
        part = b64[i : i + CHUNK]
        part_esc = part.replace("'", "''")
        ps = f"[IO.File]::AppendAllText('{guest_b64}', '{part_esc}')"
        r = run(
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
                ps,
            ]
        )
        if r.returncode != 0:
            sys.stderr.write(r.stderr)
            return r.returncode

    js_line = (
        'const fs=require("fs");const path=require("path");'
        'const dir="C:/Users/Administrator/.openclaw";'
        'const p=path.join(dir,"openclaw.json");'
        'const raw=fs.readFileSync("C:/Users/Administrator/AppData/Local/Temp/oc-openclaw-full.b64.txt","utf8");'
        'const buf=Buffer.from(raw.trim(),"base64");'
        'fs.mkdirSync(dir,{recursive:true});'
        'if(fs.existsSync(p)){fs.copyFileSync(p,p+".bak.propagate-"+Date.now());}'
        'fs.writeFileSync(p,buf);'
        'console.log("bytesWritten",buf.length);'
    )

    merge_ps = (
        f"$js = '{js_line}'; "
        f"$jsPath = Join-Path $env:TEMP 'push-openclaw-full.js'; "
        f"Set-Content -Path $jsPath -Value $js -Encoding UTF8; "
        f"& 'C:\\Program Files\\nodejs\\node.exe' $jsPath; "
        f"if ($LASTEXITCODE -ne 0) {{ exit $LASTEXITCODE }}; "
        f"$oc = Get-Command openclaw -ErrorAction SilentlyContinue; "
        f"if ($oc) {{ & openclaw gateway restart }}"
    )

    r = run(
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
            merge_ps,
        ]
    )
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
