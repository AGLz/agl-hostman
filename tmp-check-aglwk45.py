#!/usr/bin/env python3
"""Check if OpenClaw is running on aglwk45 via AGLSRV1 QEMU guest agent."""
import subprocess
import sys

def run_guest_exec(cmd):
    """Execute command on VM104 via QEMU guest agent on AGLSRV1."""
    full_cmd = [
        "ssh", "-o", "ConnectTimeout=10",
        "root@100.107.113.33",
        "qm", "guest", "exec", "104",
        "--", "bash", "-c", cmd
    ]
    result = subprocess.run(full_cmd, capture_output=True, text=True, timeout=30)
    return result.stdout.strip(), result.stderr.strip(), result.returncode

# 1. Check OpenClaw containers
print("=== OpenClaw containers ===")
out, err, rc = run_guest_exec("docker ps -a --filter name=openclaw --format '{{.Names}} {{.Status}}'")
print(out or "(none)")
if err:
    print(f"stderr: {err}")

# 2. Check for any process using Telegram bot token
print("\n=== Processes with 'openclaw' or 'telegram' ===")
out, err, rc = run_guest_exec("ps aux | grep -i openclaw | grep -v grep")
print(out or "(none)")

# 3. Check Docker containers running on aglwk45
print("\n=== All running containers ===")
out, err, rc = run_guest_exec("docker ps --format '{{.Names}} {{.Status}}'")
print(out or "(none)")
