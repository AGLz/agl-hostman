# Harbor Troubleshooting Notes - 2025-12-12

## Problem Summary

Harbor registry (CT183) has been stopped for 6 weeks and is experiencing PostgreSQL authentication issues after restart attempt.

## Current Status

- **Harbor Version**: v2.11.1
- **All containers**: Starting but harbor-core and harbor-jobservice are in restart loop
- **Root cause**: Password authentication failed for PostgreSQL user "postgres"
- **Error**: `FATAL: password authentication failed for user "postgres" (SQLSTATE 28P01)`

## Steps Attempted

1. ✅ Ran `./prepare` to regenerate all configurations
2. ✅ Reset PostgreSQL postgres user password to match config: `HarborDB2025!`
3. ❌ harbor-core still fails with authentication error despite password change

## Working Components

- harbor-log: Up and healthy
- harbor-portal: Up and healthy
- harbor-db: Up and healthy (accepts local connections)
- redis: Up and healthy
- registry: Up and healthy
- registryctl: Up and healthy

## Failing Components

- **harbor-core**: Restarting (exit code 1) - cannot connect to PostgreSQL
- **harbor-jobservice**: Restarting (exit code 2) - waiting for harbor-core

## Next Steps to Resolve

### Option 1: Complete Reset (Recommended for non-production)
```bash
cd /root/harbor/harbor
docker compose down -v  # Remove all volumes
./install.sh           # Clean installation
```

**⚠️ WARNING**: This will **DELETE ALL HARBOR DATA** including:
- All pushed images
- User accounts
- Projects
- Configuration

### Option 2: Deep Troubleshooting
```bash
# Check exact password in configuration
cat /root/harbor/harbor/common/config/core/env | grep DATABASE

# Check PostgreSQL pg_hba.conf settings
docker exec harbor-db cat /var/lib/postgresql/data/pg15/pg_hba.conf

# Try manual connection with exact config
docker exec -e PGPASSWORD='HarborDB2025!' harbor-db psql -h postgresql -U postgres -d registry
```

### Option 3: Import Existing Images (if data needs preservation)

1. Backup current registry data:
   ```bash
   docker run -v harbor_registry:/from -v $(pwd)/backup:/to alpine cp -av /from /to
   ```

2. Complete clean install

3. Re-push images from backup or other sources

## Configuration Files Backed Up

- `/docs/updates/backups-2025-12-12/harbor-docker-compose.yml`
- `/docs/updates/backups-2025-12-12/harbor-config.yml`

## Harbor Access Details

- **URL**: https://harbor.aglz.io
- **Registry**: harbor.aglz.io:5000
- **Default credentials**: admin / HarborAdmin12345 (check harbor.yml for actual password)
- **Install location**: `/root/harbor/harbor/`
- **Data volume**: Docker volume `harbor_registry`

## Temporary Workaround

Until Harbor is fixed, use alternative registry:
- **Docker Hub**: docker.io
- **GitHub Container Registry**: ghcr.io
- **Local registry**: Can spin up simple registry on port 5001

## Priority

🟡 **MEDIUM** - Harbor is important for CI/CD but not blocking other infrastructure updates.

Other critical services (Archon, Ollama, n8n) should be addressed first, then return to Harbor issue.

## Last Updated

2025-12-12 17:02 UTC
