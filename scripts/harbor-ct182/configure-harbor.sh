#!/bin/bash
#
# Harbor Configuration Automation Script
# Post-installation configuration including projects, users, and policies
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
HARBOR_URL="https://192.168.1.182"
HARBOR_ADMIN_USER="admin"
HARBOR_ADMIN_PASSWORD=""
INSTALL_DIR="/opt/harbor"
CTID=182

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Harbor Configuration Automation${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if running on Proxmox host or container
if command -v pct &> /dev/null && pct status $CTID &> /dev/null; then
    RUN_PREFIX="pct exec $CTID --"
    echo -e "${GREEN}Configuring Harbor on CT$CTID${NC}"
else
    RUN_PREFIX=""
    echo -e "${GREEN}Configuring Harbor directly${NC}"
fi

# Function to execute commands
run_cmd() {
    if [ -n "$RUN_PREFIX" ]; then
        $RUN_PREFIX bash -c "$1"
    else
        bash -c "$1"
    fi
}

# Prompt for admin password
if [ -z "$HARBOR_ADMIN_PASSWORD" ]; then
    read -sp "Enter Harbor admin password: " HARBOR_ADMIN_PASSWORD
    echo
fi

# Install jq for JSON processing
echo -e "${GREEN}Installing prerequisites...${NC}"
run_cmd "apt-get update && apt-get install -y jq curl"

# Function to call Harbor API
harbor_api() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -n "$data" ]; then
        run_cmd "curl -k -s -X $method -u '$HARBOR_ADMIN_USER:$HARBOR_ADMIN_PASSWORD' \
            -H 'Content-Type: application/json' \
            -d '$data' \
            '$HARBOR_URL/api/v2.0$endpoint'"
    else
        run_cmd "curl -k -s -X $method -u '$HARBOR_ADMIN_USER:$HARBOR_ADMIN_PASSWORD' \
            -H 'Content-Type: application/json' \
            '$HARBOR_URL/api/v2.0$endpoint'"
    fi
}

echo -e "${GREEN}Step 1: Verifying Harbor is running...${NC}"
sleep 5
if ! run_cmd "curl -k -s $HARBOR_URL/api/v2.0/health" | grep -q "healthy"; then
    echo -e "${RED}ERROR: Harbor is not responding or not healthy${NC}"
    exit 1
fi
echo -e "${GREEN}Harbor is healthy!${NC}"

echo -e "${GREEN}Step 2: Creating projects...${NC}"

# Create library project (if not exists)
echo -e "${YELLOW}Creating 'library' project...${NC}"
harbor_api POST "/projects" '{
  "project_name": "library",
  "metadata": {
    "public": "true",
    "enable_content_trust": "false",
    "prevent_vul": "false",
    "severity": "low",
    "auto_scan": "true"
  },
  "storage_limit": -1
}' || echo -e "${YELLOW}Library project may already exist${NC}"

# Create development project
echo -e "${YELLOW}Creating 'development' project...${NC}"
harbor_api POST "/projects" '{
  "project_name": "development",
  "metadata": {
    "public": "false",
    "enable_content_trust": "false",
    "prevent_vul": "true",
    "severity": "medium",
    "auto_scan": "true"
  },
  "storage_limit": -1
}' || echo -e "${YELLOW}Development project may already exist${NC}"

# Create production project
echo -e "${YELLOW}Creating 'production' project...${NC}"
harbor_api POST "/projects" '{
  "project_name": "production",
  "metadata": {
    "public": "false",
    "enable_content_trust": "true",
    "prevent_vul": "true",
    "severity": "high",
    "auto_scan": "true"
  },
  "storage_limit": -1
}' || echo -e "${YELLOW}Production project may already exist${NC}"

echo -e "${GREEN}Step 3: Configuring vulnerability scanning...${NC}"

# Configure Trivy scanner
echo -e "${YELLOW}Enabling automatic vulnerability scanning...${NC}"
harbor_api PUT "/configurations" '{
  "scan_all_policy": {
    "type": "daily",
    "parameter": {
      "daily_time": 0
    }
  }
}'

echo -e "${GREEN}Step 4: Configuring garbage collection...${NC}"

# Schedule garbage collection
echo -e "${YELLOW}Setting up garbage collection schedule...${NC}"
harbor_api POST "/system/gc/schedule" '{
  "schedule": {
    "type": "Weekly",
    "cron": "0 0 * * 0"
  },
  "delete_untagged": true,
  "workers": 1
}' || echo -e "${YELLOW}GC schedule may already exist${NC}"

echo -e "${GREEN}Step 5: Creating robot accounts...${NC}"

# Create robot account for CI/CD
echo -e "${YELLOW}Creating CI/CD robot account...${NC}"
harbor_api POST "/projects/library/robots" '{
  "name": "cicd-robot",
  "description": "Robot account for CI/CD pipelines",
  "duration": -1,
  "level": "project",
  "disable": false,
  "permissions": [
    {
      "kind": "project",
      "namespace": "library",
      "access": [
        {"resource": "repository", "action": "push"},
        {"resource": "repository", "action": "pull"},
        {"resource": "artifact", "action": "delete"}
      ]
    }
  ]
}' > /tmp/robot-secret.json 2>/dev/null || echo -e "${YELLOW}Robot account may already exist${NC}"

if [ -f /tmp/robot-secret.json ]; then
    echo -e "${GREEN}Robot account created! Save these credentials:${NC}"
    run_cmd "cat /tmp/robot-secret.json | jq -r '.name, .secret'"
fi

echo -e "${GREEN}Step 6: Configuring replication...${NC}"

# Create replication endpoint (example for Docker Hub)
echo -e "${YELLOW}Replication can be configured via UI or API as needed${NC}"

echo -e "${GREEN}Step 7: Configuring retention policies...${NC}"

# Set retention policy for development project
echo -e "${YELLOW}Setting retention policy for development project...${NC}"
harbor_api POST "/retentions" '{
  "algorithm": "or",
  "rules": [
    {
      "disabled": false,
      "action": "retain",
      "params": {
        "latestPushedK": 10
      },
      "tag_selectors": [
        {
          "kind": "doublestar",
          "decoration": "matches",
          "pattern": "**"
        }
      ],
      "scope_selectors": {
        "repository": [
          {
            "kind": "doublestar",
            "decoration": "repoMatches",
            "pattern": "**"
          }
        ]
      }
    }
  ],
  "trigger": {
    "kind": "Schedule",
    "settings": {
      "cron": "0 0 * * *"
    }
  },
  "scope": {
    "level": "project",
    "ref": 2
  }
}' || echo -e "${YELLOW}Retention policy may already exist${NC}"

echo -e "${GREEN}Step 8: Creating sample users (optional)...${NC}"

# Create developer user
echo -e "${YELLOW}Creating developer user...${NC}"
harbor_api POST "/users" '{
  "username": "developer",
  "email": "developer@localhost",
  "realname": "Developer User",
  "password": "Developer123!",
  "comment": "Development team user"
}' || echo -e "${YELLOW}Developer user may already exist${NC}"

echo -e "${GREEN}Step 9: Configuring system settings...${NC}"

# Configure system-wide settings
harbor_api PUT "/configurations" '{
  "token_expiration": 30,
  "project_creation_restriction": "adminonly",
  "audit_log_forward_endpoint": "",
  "skip_audit_log_database": false
}'

echo -e "${GREEN}Step 10: Creating configuration backup...${NC}"
run_cmd "cd $INSTALL_DIR && docker-compose exec -T postgresql pg_dump -U postgres registry > /tmp/harbor-db-backup-$(date +%Y%m%d).sql" || echo -e "${YELLOW}Backup failed, may need manual execution${NC}"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Harbor Configuration Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Created Projects:${NC}"
echo -e "  - ${GREEN}library${NC} (public, auto-scan)"
echo -e "  - ${GREEN}development${NC} (private, auto-scan)"
echo -e "  - ${GREEN}production${NC} (private, content trust, strict scanning)"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Scheduled Tasks:${NC}"
echo -e "  - Vulnerability Scan: ${GREEN}Daily at midnight${NC}"
echo -e "  - Garbage Collection: ${GREEN}Weekly on Sunday${NC}"
echo -e "  - Retention Policy: ${GREEN}Daily at midnight${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Access Harbor:${NC}"
echo -e "URL: ${GREEN}$HARBOR_URL${NC}"
echo -e "User: ${GREEN}admin${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Login to Harbor UI"
echo -e "2. Review and adjust project settings"
echo -e "3. Add project members"
echo -e "4. Configure replication if needed"
echo -e "5. Test pushing/pulling images"
echo -e "${BLUE}========================================${NC}"
