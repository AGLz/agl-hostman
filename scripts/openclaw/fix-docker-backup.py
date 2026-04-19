#!/usr/bin/env python3
"""
Fix daily-backup.sh and docker-compose.yml for Docker container.
- Adds backup volume mount to docker-compose.yml
- Fixes /root/ -> /home/node/ paths in daily-backup.sh
- Adds SSH key mount for git push
"""
import re

# 1. Fix docker-compose.yml - add backup volume
DC_PATH = "/mnt/overpower/apps/dev/agl/openclaw-repo/docker-compose.yml"
with open(DC_PATH) as f:
    dc = f.read()

# Add backup volume mount (before the last volume line)
if "/root/.openclaw/backup" not in dc:
    # Add after the last /root/.openclaw mount
    dc = dc.replace(
        "      - /root/.openclaw/.env:/root/.openclaw/.env:ro\n",
        "      - /root/.openclaw/.env:/root/.openclaw/.env:ro\n"
        "      - /root/.openclaw/backup:/root/.openclaw/backup\n"
        "      - /root/.ssh:/root/.ssh:ro\n"
    )
    with open(DC_PATH, "w") as f:
        f.write(dc)
    print("docker-compose.yml: added backup + SSH volumes")
else:
    print("docker-compose.yml: backup volume already present")

# 2. Fix daily-backup.sh paths
SCRIPT_DIR = "/mnt/overpower/apps/dev/agl/openclaw-repo/config"
BACKUP_SCRIPT = f"{SCRIPT_DIR}/workspace/scripts/daily-backup.sh"
try:
    with open(BACKUP_SCRIPT) as f:
        script = f.read()
    
    original = script
    
    # The backup paths should stay as /root/ since we mount the host dirs there
    # But the config source paths need to use /home/node/
    # The script copies FROM /root/.openclaw/ TO /root/.openclaw/backup/
    # With our mount: /root/.openclaw/backup -> host /root/.openclaw/backup
    # And config is at /home/node/.openclaw/
    
    # Fix source paths (where data is read FROM) to use HOME or /home/node
    # But keep backup/repo paths at /root/.openclaw/backup
    
    # Actually, simpler: replace only the SOURCE paths, not the BACKUP_DIR/REPO_DIR paths
    script = script.replace(
        'LOG_FILE="/root/.openclaw/logs/daily-backup.log"',
        'LOG_FILE="/root/.openclaw/logs/daily-backup.log"  # mounted from host'
    )
    
    # Replace source cp paths
    script = re.sub(
        r'cp /root/\.openclaw/(workspace/)',
        r'cp /home/node/.openclaw/\1',
        script
    )
    script = re.sub(
        r'cp /root/\.openclaw/cron/',
        r'cp /home/node/.openclaw/cron/',
        script
    )
    
    # Fix openclaw.json source path
    script = script.replace(
        'cp /root/.openclaw/openclaw.json',
        'cp /home/node/.openclaw/openclaw.json'
    )
    
    if script != original:
        with open(BACKUP_SCRIPT, "w") as f:
            f.write(script)
        print(f"daily-backup.sh: fixed source paths (/root/ -> /home/node/)")
    else:
        print("daily-backup.sh: no changes needed")
        
except FileNotFoundError:
    print(f"daily-backup.sh: NOT FOUND at {BACKUP_SCRIPT}")
    print("Will need manual fix after confirming script location")

print("\nDone. Restart container with: docker compose down && docker compose up -d")
