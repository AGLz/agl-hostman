#!/usr/bin/env python3
"""Escrever 1 em cada cgroup.kill sob um caminho (ordem find -depth). Uso em PVE para limpar árvore órfã."""
import subprocess
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "/sys/fs/cgroup/lxc/200"
out = subprocess.check_output(
    ["find", root, "-depth", "-name", "cgroup.kill"],
    text=True,
)
for line in out.splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        open(line, "w").write("1")
    except OSError as e:
        print(line, e, file=sys.stderr)
