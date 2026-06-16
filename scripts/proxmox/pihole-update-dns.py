#!/usr/bin/env python3
# Atualiza hosts/domain/revServers no pihole.toml (v6, com sufixo ### CHANGED).
import re
import sys
from pathlib import Path

DOMAIN = sys.argv[1] if len(sys.argv) > 1 else "localdomain"
HOSTS_FILE = Path(sys.argv[2] if len(sys.argv) >
                  2 else "/tmp/pihole-hosts-sync.txt")

lines = [ln.strip()
         for ln in HOSTS_FILE.read_text().splitlines() if ln.strip()]
entries = ",\n".join(f'    "{ln}"' for ln in lines)
hosts_block = f"hosts = [\n{entries}\n  ] ### CHANGED, default = []"

toml = Path("/etc/pihole/pihole.toml")
text = toml.read_text()

text, n1 = re.subn(
    r"(?m)^  hosts = \[\n(?:    .*\n)*  \] ### CHANGED, default = \[\]",
    hosts_block,
    text,
    count=1,
)
text, n2 = re.subn(
    r'(?m)^  domain = "lan"$',
    f'  domain = "{DOMAIN}" ### CHANGED',
    text,
    count=1,
)
if n2 == 0:
    text, n2 = re.subn(
        rf'(?m)^  domain = "{re.escape(DOMAIN)}" ### CHANGED.*$',
        f'  domain = "{DOMAIN}" ### CHANGED',
        text,
        count=1,
    )
text, n3 = re.subn(
    r"  revServers = \[\n    .*\n  \] ### CHANGED, default = \[\]",
    "revServers = [] ### CHANGED, default = []",
    text,
    count=1,
)
if n3 == 0:
    text, n3 = re.subn(
        r"revServers = \[\] ### CHANGED, default = \[\]",
        "revServers = [] ### CHANGED, default = []",
        text,
        count=1,
    )

toml.write_text(text)
print(
    f"replacements: hosts={n1} domain={n2} revServers={n3} count={len(lines)}")
