#!/usr/bin/env python3
"""Copy knowledge scripts to architect workspace."""
import shutil
import os

BASE = "/mnt/overpower/apps/dev/agl/openclaw-repo/config"
WORKSPACE = os.path.join(BASE, "workspace-openclaw-architect")
KNOWLEDGE = os.path.join(WORKSPACE, "knowledge")
SCRIPTS_SRC = os.path.join(BASE, "scripts")

SCRIPTS = [
    ("restore-openclaw-docker.py", "restore.py"),
    ("restructure-agency.py", "restructure_agency.py"),
    ("fix-litellm-zai.py", "fix_litellm_zai.py"),
    ("fix-model-names.py", "fix_model_names.py"),
    ("restructure-cron-and-selfimprove.py", "restructure_cron.py"),
    ("test-jarvis-functional.py", "test_jarvis.py"),
    ("test-litellm-comprehensive.py", "test_litellm.py"),
    ("validate-workspaces.py", "validate_workspaces.py"),
]

os.makedirs(KNOWLEDGE, exist_ok=True)

copied = 0
for src, dst in SCRIPTS:
    src_path = os.path.join(SCRIPTS_SRC, src)
    dst_path = os.path.join(KNOWLEDGE, dst)
    if os.path.exists(src_path):
        shutil.copy2(src_path, dst_path)
        copied += 1
        print(f"Copied: {src} -> knowledge/{dst}")
    else:
        print(f"NOT FOUND: {src}")

print(f"\nTotal copied: {copied}/{len(SCRIPTS)}")
