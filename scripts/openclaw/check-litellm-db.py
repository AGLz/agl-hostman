#!/usr/bin/env python3
"""Check LiteLLM database for model overrides."""
import subprocess
import json

# Query model count
r = subprocess.run(
    ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm", 
     "-t", "-c", "SELECT COUNT(*) FROM litellm_modeltable;"],
    capture_output=True, text=True
)
print(f"Models in DB: {r.stdout.strip()}")

# Query all models
r = subprocess.run(
    ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm",
     "-t", "-c", "SELECT model_name FROM litellm_modeltable ORDER BY model_name;"],
    capture_output=True, text=True
)
db_models = [m.strip() for m in r.stdout.strip().split("\n") if m.strip()]
print(f"\nDB models ({len(db_models)}):")
for m in db_models:
    print(f"  {m}")

# Check for ZAI/GLM models
glm = [m for m in db_models if "glm" in m.lower()]
print(f"\nGLM models in DB: {len(glm)}")
for m in glm:
    print(f"  {m}")

# Check agl-primary details
r = subprocess.run(
    ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm",
     "-t", "-c", "SELECT litellm_params FROM litellm_modeltable WHERE model_name = 'agl-primary';"],
    capture_output=True, text=True
)
if r.stdout.strip():
    try:
        params = json.loads(r.stdout.strip())
        print(f"\nagl-primary DB params: {json.dumps(params, indent=2)}")
    except:
        print(f"\nagl-primary raw: {r.stdout.strip()[:200]}")
