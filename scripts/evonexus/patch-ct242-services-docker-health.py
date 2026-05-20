#!/usr/bin/env python3
"""Patch EvoNexus services.routes.py for Docker Hub compose (sem binário `ps`)."""

from __future__ import annotations

from pathlib import Path


def main() -> None:
    path = Path("/opt/evonexus/services.routes.py")
    if not path.is_file():
        raise SystemExit(f"ficheiro inexistente: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()

    bp_idx = next(i for i, line in enumerate(lines) if line.startswith("bp = Blueprint"))
    head = [
        '"""Services endpoint — check running background services."""',
        "",
        "import glob",
        "import os",
        "import shutil",
        "import subprocess",
        "",
        "from flask import Blueprint, jsonify",
        "",
        "from routes._helpers import WORKSPACE",
        "",
    ]
    lines = head + lines[bp_idx:]

    sched_idx = next(i for i, line in enumerate(lines) if line == "def _check_scheduler() -> dict:")
    helpers = [
        "",
        "def _proc_cmdlines_contain(substring: str) -> bool:",
        '    """Imagens Docker minimalistas podem não incluir `ps`; usa /proc/*/cmdline."""',
        '    for path in glob.glob("/proc/[0-9]*/cmdline"):',
        "        try:",
        '            raw = open(path, "rb").read().replace(b"\\x00", b" ").decode(errors="ignore")',
        "            if substring in raw:",
        "                return True",
        "        except OSError:",
        "            continue",
        "    return False",
        "",
        "",
        "def _http_self_health() -> dict | None:",
        "    try:",
        "        import urllib.request",
        "",
        '        port = os.environ.get("EVONEXUS_PORT", "8080")',
        '        url = f"http://127.0.0.1:{port}/api/version"',
        "        with urllib.request.urlopen(url, timeout=2) as r:",
        "            ok = r.status == 200",
        '            return {"running": ok, "detail": "HTTP /api/version OK" if ok else ""}',
        "    except Exception:",
        "        return None",
        "",
        "",
        "def _check_dashboard_app() -> dict:",
        '    if shutil.which("ps"):',
        '        result = _check_process(["ps", "aux"], pipe_grep="app.py")',
        '        if result["running"]:',
        "            return result",
        '    if _proc_cmdlines_contain("app.py"):',
        '        return {"running": True, "detail": "Running (process)"}',
        "    http_result = _http_self_health()",
        '    if http_result and http_result["running"]:',
        "        return http_result",
        '    return {"running": False, "detail": ""}',
        "",
    ]
    lines = lines[:sched_idx] + helpers + lines[sched_idx:]

    start = next(i for i, line in enumerate(lines) if line == "def _check_scheduler() -> dict:")
    end = start + 1
    while end < len(lines) and lines[end].strip() != "":
        end += 1

    new_fn = [
        "def _check_scheduler() -> dict:",
        '    """Check if scheduler thread is running inside the dashboard process."""',
        "    import threading",
        "",
        "    for t in threading.enumerate():",
        '        if t.name == "scheduler" and t.is_alive():',
        '            return {"running": True, "detail": "Running (embedded in dashboard)"}',
        '    if shutil.which("ps"):',
        '        result = _check_process(["ps", "aux"], pipe_grep="scheduler.py")',
        '        if result["running"]:',
        "            return result",
        '    if _proc_cmdlines_contain("scheduler.py"):',
        '        return {"running": True, "detail": "Running (process)"}',
        "    try:",
        '        pid_path = WORKSPACE / "ADWs" / "logs" / "scheduler.pid"',
        "        if pid_path.is_file() and pid_path.read_text(encoding=\"utf-8\", errors=\"ignore\").strip():",
        '            return {"running": True, "detail": "Running (scheduler.pid na workspace partilhada)"}',
        "    except OSError:",
        "        pass",
        '    return {"running": False, "detail": ""}',
    ]
    lines = lines[:start] + new_fn + lines[end:]

    idx_services_route = next(i for i, line in enumerate(lines) if line.startswith('@bp.route("/api/services")'))
    telegram_fn = [
        "",
        "def _check_telegram() -> dict:",
        '    """Telegram: sessão screen (legado) ou stack Docker Compose (hostname do serviço)."""',
        '    if shutil.which("screen"):',
        '        result = _check_process(["screen", "-list"], pipe_grep="telegram")',
        '        if result["running"]:',
        "            return result",
        '    host = os.environ.get("EVONEXUS_TELEGRAM_SERVICE_HOST", "telegram")',
        "    try:",
        "        import socket",
        "",
        "        socket.getaddrinfo(host, None)",
        '        return {"running": True, "detail": f"Compose: hostname `{host}` resolve na rede Docker"}',
        "    except OSError:",
        "        pass",
        '    return {"running": False, "detail": ""}',
        "",
    ]
    lines = lines[:idx_services_route] + telegram_fn + lines[idx_services_route:]

    replaced_dashboard = False
    for i, line in enumerate(lines):
        # Linha no dict `list_services` usa 12 espaços — não confundir com `_check_dashboard_app()`.
        if line == '            **_check_process(["ps", "aux"], pipe_grep="app.py"),':
            lines[i] = "            **_check_dashboard_app(),"
            replaced_dashboard = True
            break
    if not replaced_dashboard:
        raise SystemExit("não encontrei linha dashboard app.py (dict list_services)")

    replaced_logs = False
    for i, line in enumerate(lines):
        if line == '            result = _check_process(["ps", "aux"], pipe_grep="scheduler.py")':
            lines[i] = "            result = _check_scheduler()"
            replaced_logs = True
            break
    if not replaced_logs:
        raise SystemExit("não encontrei fallback ps nos logs do scheduler")

    replaced_telegram_service = False
    for i, line in enumerate(lines):
        if line == '            **_check_process(["screen", "-list"], pipe_grep="telegram"),':
            lines[i] = "            **_check_telegram(),"
            replaced_telegram_service = True
            break
    if not replaced_telegram_service:
        raise SystemExit("não encontrei entrada telegram em list_services")

    replaced_telegram_logs = False
    for i, line in enumerate(lines):
        if line == '            result = _check_process(["screen", "-list"], pipe_grep="telegram")':
            lines[i] = "            result = _check_telegram()"
            replaced_telegram_logs = True
            break
    if not replaced_telegram_logs:
        raise SystemExit("não encontrei fallback screen nos logs do telegram")

    tg_block_start = next(
        i for i, line in enumerate(lines) if line.strip() == 'if service_id == "telegram":'
    )
    tg_block_end = next(
        i for i in range(tg_block_start + 1, len(lines)) if lines[i].startswith("    elif ")
    )
    for i in range(tg_block_start, tg_block_end):
        if 'f"Screen: {result' in lines[i]:
            lines[i] = lines[i].replace("Screen:", "Detection:")
            break

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"OK escrito: {path}")


if __name__ == "__main__":
    main()
