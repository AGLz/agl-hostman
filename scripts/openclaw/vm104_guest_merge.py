#!/usr/bin/env python3
"""Merge agents.list na VM Windows via qm guest exec — base64 em chunks (limite cmd)."""
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
        print("Uso: vm104_guest_merge.py <vmid> <fragment.json>", file=sys.stderr)
        return 2
    vmid = sys.argv[1]
    frag_path = pathlib.Path(sys.argv[2])
    b64 = base64.b64encode(frag_path.read_bytes()).decode("ascii")

    guest_b64 = "C:\\\\Users\\\\Administrator\\\\AppData\\\\Local\\\\Temp\\\\oc-frag.b64.txt"

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

    # Sem aspas simples (PowerShell $js = '...')
    js_line = (
        'const fs=require("fs");'
        'const p="C:/Users/Administrator/.openclaw/openclaw.json";'
        'const t="C:/Users/Administrator/AppData/Local/Temp/oc-agents-fragment.json";'
        'const raw=fs.readFileSync("C:/Users/Administrator/AppData/Local/Temp/oc-frag.b64.txt","utf8");'
        'const buf=Buffer.from(raw.trim(),"base64");'
        'fs.writeFileSync(t,buf);'
        'const c=JSON.parse(fs.readFileSync(p,"utf8"));'
        'const f=JSON.parse(fs.readFileSync(t,"utf8"));'
        'c.agents=c.agents||{};'
        'c.agents.list=f.agents.list;'
        'fs.writeFileSync(p,JSON.stringify(c,null,2));'
        'console.log("listLen",c.agents.list.length);'
    )

    merge_ps = (
        f"$js = '{js_line}'; "
        f"$jsPath = Join-Path $env:TEMP 'merge.js'; "
        f"Set-Content -Path $jsPath -Value $js -Encoding UTF8; "
        f"$cfg = 'C:\\Users\\Administrator\\.openclaw\\openclaw.json'; "
        f"if (-not (Test-Path $cfg)) {{ Write-Error 'Missing config'; exit 2 }}; "
        f"& 'C:\\Program Files\\nodejs\\node.exe' $jsPath; "
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
