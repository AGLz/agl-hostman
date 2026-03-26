#!/usr/bin/env python3
"""
Empacota C:\\Users\\Administrator\\.openclaw (aglwk45) em .tgz via qm guest exec.
Correr no host Proxmox (AGLSRV1). O guest exec usa a conta SYSTEM — caminhos explicitos Administrator.

Uso no PVE: python3 /tmp/vm104_guest_pack_openclaw.py 104 [/tmp/saida.tgz]
Saida: imprime o caminho absoluto do .tgz no host PVE.
"""
from __future__ import annotations

import base64
import binascii
import json
import os
import pathlib
import re
import subprocess
import sys
import time

# Leitura binaria por chamada (limitar numero de qm guest exec)
CHUNK = 196608  # 192 KiB

# tar de .openclaw pode exceder o default do PVE (~30s); sobrescrever com OPENCLAW_GUEST_EXEC_TIMEOUT
GUEST_EXEC_TIMEOUT = int(os.environ.get("OPENCLAW_GUEST_EXEC_TIMEOUT", "900"))

# Barras / sao validas no PowerShell e evitam escapes.
GUEST_HOME = "C:/Users/Administrator"
GUEST_OC = f"{GUEST_HOME}/.openclaw"
GUEST_TGZ = f"{GUEST_HOME}/AppData/Local/Temp/openclaw-wk45-for-agldv03.tgz"


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True)


def qm_powershell(vmid: str, command: str) -> subprocess.CompletedProcess:
    return run(
        [
            "qm",
            "guest",
            "exec",
            vmid,
            "--timeout",
            str(GUEST_EXEC_TIMEOUT),
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


def _decode_out_data(od: str | None) -> str:
    """PVE devolve out-data em texto ou Base64 (ex.: chunks de ficheiro)."""
    if not od:
        return ""
    raw = od.strip() if isinstance(od, str) else str(od)
    # Numeros (ex.: tamanho do .tgz) coincidem com Base64 valido — decodificar daria lixo.
    compact = "".join(raw.split())
    if compact.isdigit():
        return compact
    try:
        return base64.b64decode(raw, validate=True).decode("utf-8", errors="replace")
    except (binascii.Error, ValueError, UnicodeDecodeError):
        return raw


def parse_exec_output(r: subprocess.CompletedProcess) -> tuple[int, str]:
    out = (r.stdout or "").strip()
    err = (r.stderr or "").strip()
    if err:
        sys.stderr.write(err + "\n")
    try:
        j = json.loads(out)
        if isinstance(j, dict) and "out-data" in j:
            text = _decode_out_data(j.get("out-data"))
            ec = int(j.get("exitcode", r.returncode))
            if ec != 0 and j.get("err-data"):
                sys.stderr.write(_decode_out_data(j.get("err-data")) + "\n")
            return ec, text
        if isinstance(j, dict) and j.get("exitcode") is not None:
            ec = int(j["exitcode"])
            if j.get("err-data"):
                sys.stderr.write(_decode_out_data(j.get("err-data")) + "\n")
            return ec, ""
    except json.JSONDecodeError:
        pass
    return r.returncode, out


def main() -> int:
    if len(sys.argv) < 2:
        print(
            "Uso: vm104_guest_pack_openclaw.py <vmid> [/caminho/no/pve/saida.tgz]",
            file=sys.stderr,
        )
        return 2
    vmid = sys.argv[1]
    out_host = pathlib.Path(
        sys.argv[2]
        if len(sys.argv) > 2
        else f"/tmp/openclaw-wk45-for-agldv03-{int(time.time())}.tgz"
    )

    create_ps = (
        f"$tgz = '{GUEST_TGZ}'; "
        f"$base = '{GUEST_HOME}'; "
        f"$oc = '{GUEST_OC}'; "
        f"if (-not (Test-Path $oc)) {{ Write-Error 'missing .openclaw'; exit 2 }}; "
        f"if (Test-Path $tgz) {{ Remove-Item $tgz -Force }}; "
        f"Push-Location $base; "
        f"& tar.exe -czf $tgz --exclude='.openclaw/logs' --exclude='.openclaw/browser' .openclaw; "
        f"$c = $LASTEXITCODE; Pop-Location; if ($c -ne 0) {{ exit $c }}; "
        f"Write-Output ((Get-Item $tgz).Length)"
    )
    r = qm_powershell(vmid, create_ps)
    if os.environ.get("OPENCLAW_PACK_DEBUG"):
        print("DEBUG qm stdout:", (r.stdout or "")[:4000], file=sys.stderr)
    ec, text = parse_exec_output(r)
    if ec != 0:
        print(f"Erro ao criar tgz no guest: exit={ec} stdout={text!r}", file=sys.stderr)
        return 1

    lines = [ln.strip() for ln in text.strip().splitlines() if ln.strip()]
    size = None
    for line in reversed(lines):
        if re.fullmatch(r"\d+", line):
            size = int(line)
            break
    if size is None:
        print(
            f"Erro: nao foi encontrado tamanho (numerico) na saida: {text!r}",
            file=sys.stderr,
        )
        return 1

    if size <= 0:
        print(f"Erro: ficheiro vazio ou tamanho={size}", file=sys.stderr)
        return 1

    out_host.parent.mkdir(parents=True, exist_ok=True)
    offset = 0
    with out_host.open("wb") as raw_file:
        while offset < size:
            read_ps = (
                f"$p = '{GUEST_TGZ}'; "
                f"$fs = [IO.File]::OpenRead($p); "
                f"$null = $fs.Seek({offset}, [IO.SeekOrigin]::Begin); "
                f"$buf = New-Object byte[] {CHUNK}; "
                f"$n = $fs.Read($buf, 0, $buf.Length); "
                f"$fs.Close(); "
                f"if ($n -le 0) {{ Write-Output '' }} else {{ [Convert]::ToBase64String($buf, 0, $n) }}"
            )
            r = qm_powershell(vmid, read_ps)
            ec, b64text = parse_exec_output(r)
            if ec != 0:
                print(
                    f"Erro leitura offset={offset}: exit={ec} out={b64text!r}",
                    file=sys.stderr,
                )
                return 1
            b64text = b64text.strip()
            if not b64text:
                break
            try:
                chunk = base64.b64decode(b64text, validate=True)
            except (binascii.Error, ValueError) as e:
                print(f"Erro Base64 offset={offset}: {e}", file=sys.stderr)
                return 1
            if not chunk:
                break
            raw_file.write(chunk)
            offset += len(chunk)

    final = out_host.stat().st_size
    if final != size:
        print(
            f"Aviso: bytes esperados {size}, escritos {final} (rever guest agent / tar).",
            file=sys.stderr,
        )

    cleanup_ps = f"Remove-Item '{GUEST_TGZ}' -Force -ErrorAction SilentlyContinue"
    qm_powershell(vmid, cleanup_ps)

    print(str(out_host.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
