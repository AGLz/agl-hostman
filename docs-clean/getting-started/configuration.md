# Configuration

This guide covers the configuration options for AGL Hostman, from basic settings to advanced configuration.

## Configuration Files

### Primary Configuration File

The main configuration file is located at `config/config.json`:

```json
{
  "version": "1.0.0",
  "environment": "production",
  "storage": {
    "nfs": {
      "enabled": true,
      "server": "aglsrv1.local",
      "base_path": "/mnt/aglsrv1/data",
      "mount_options": ["defaults", "_netdev", "hard", "intr", "tcp", "nfsvers=4.2"],
      "exports": {
        "data": {
          "path": "/mnt/aglsrv1/data",
          "options": "rw,sync,no_root_squash"
        },
        "backups": {
          "path": "/mnt/aglsrv1/backups",
          "options": "ro,sync"
        }
      }
    },
    "iscsi": {
      "enabled": true,
      "target": "iqn.2025-10.com.aglhostman:storage",
      "portal": "aglsrv1.local:3260",
      "auth": {
        "username": null,
        "password": null
      }
    },
    "pbs": {
      "enabled": true,
      "server": "aglsrv1.local",
      "port": 8007,
      "repository": "agl-backups",
      "username": "agl-hostman",
      "ssh_key": "/home/agl-hostman/.ssh/pbs_backup"
    }
  },
  "monitoring": {
    "enabled": true,
    "port": 9090,
    "grafana": {
      "enabled": true,
      "port": 3000,
      "admin_password": "change-me"
    },
    "loki": {
      "enabled": true,
      "port": 3100
    },
    "jaeger": {
      "enabled": true,
      "port": 16686
    }
  },
  "backups": {
    "enabled": true,
    "schedule": "0 2 * * *",
    "retention": {
      "daily": 7,
      "weekly": 4,
      "monthly": 12
    },
    "compression": true,
    "encryption": true,
    "offsite": {
      "enabled": true,
      "remote": "backup-server.local",
      "path": "/backups/aglhostman"
    }
  },
  "security": {
    "ssl": {
      "enabled": true,
      "cert_path": "/etc/agl-hostman/cert.pem",
      "key_path": "/etc/agl-hostman/key.pem"
    },
    "auth": {
      "method": "jwt",
      "token_expiry": 3600,
      "refresh_token_expiry": 86400
    },
    "firewall": {
      "enabled": true,
      "allowed_ports": ["22", "80", "443", "9090", "3000", "8080"]
    }
  },
  "api": {
    "enabled": true,
    "port": 8080,
    "rate_limit": {
      "enabled": true,
      "requests": 100,
      "window": 60
    },
    "cors": {
      "enabled": true,
      "allowed_origins": ["https://app.aglhostman.local"]
    }
  }
}
```

### Environment Variables

Configuration can also be set via environment variables:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=agl_hostman
DB_USER=agl_hostman
DB_PASSWORD=secure_password

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=redis_password

# API
API_PORT=8080
API_SECRET=api_secret_key

# Monitoring
GRAFANA_PASSWORD=grafana_password
PROMETHEUS_RETENTION=15d
```

## Storage Configuration

### NFS Configuration

#### Basic NFS Setup
```json
{
  "storage": {
    "nfs": {
      "enabled": true,
      "server": "aglsrv1.local",
      "base_path": "/mnt/aglsrv1/data",
      "mounts": {
        "data": {
          "path": "/mnt/aglsrv1/data",
          "options": "rw,sync,no_root_squash"
        }
      }
    }
  }
}
```

#### Advanced NFS Configuration
```json
{
  "storage": {
    "nfs": {
      "enabled": true,
      "server": "aglsrv1.local",
      "base_path": "/mnt/aglsrv1/data",
      "mount_options": [
        "defaults",
        "_netdev",
        "hard",
        "intr",
        "tcp",
        "nfsvers=4.2",
        "rsize=1048576",
        "wsize=1048576",
        "async"
      ],
      "auto_mount": true,
      "exports": [
        {
          "path": "/mnt/aglsrv1/data",
          "options": "rw,sync,no_root_squash",
          "mount_point": "/nfs/data"
        },
        {
          "path": "/mnt/aglsrv1/backups",
          "options": "ro,sync",
          "mount_point": "/nfs/backups"
        }
      ]
    }
  }
}
```

### iSCSI Configuration

#### Basic iSCSI Setup
```json
{
  "storage": {
    "iscsi": {
      "enabled": true,
      "target": "iqn.2025-10.com.aglhostman:storage",
      "portal": "aglsrv1.local:3260",
      "initiator": "iqn.2025-10.com.hostman:initiator"
    }
  }
}
```

#### Advanced iSCSI Configuration
```json
{
  "storage": {
    "iscsi": {
      "enabled": true,
      "targets": [
        {
          "name": "storage-main",
          "portal": "aglsrv1.local:3260",
          "luns": [
            {
              "id": "0",
              "size_gb": 500,
              "alias": "main-storage"
            },
            {
              "id": "1",
              "size_gb": 1000,
              "alias": "backup-storage"
            }
          ]
        }
      ],
      "auth": {
        "username": "iscsi_user",
        "password": "iscsi_password",
        "chap_username": null,
        "chap_password": null
      },
      "discovery": {
        "method": "sendtargets",
        "interval": 60
      }
    }
  }
}
```

### PBS Configuration

#### Basic PBS Setup
```json
{
  "storage": {
    "pbs": {
      "enabled": true,
      "server": "aglsrv1.local",
      "port": 8007,
      "repository": "agl-backups",
      "username": "agl-hostman",
      "ssh_key": "/home/agl-hostman/.ssh/pbs_backup"
    }
  }
}
```

#### Advanced PBS Configuration
```json
{
  "storage": {
    "pbs": {
      "enabled": true,
      "servers": [
        {
          "host": "aglsrv1.local",
          "port": 8007,
          "repository": "agl-backups",
          "username": "agl-hostman",
          "ssh_key": "/home/agl-hostman/.ssh/pbs_backup1"
        },
        {
          "host": "aglsrv6.local",
          "port": 8007,
          "repository": "agl-backups-2",
          "username": "agl-hostman",
          "ssh_key": "/home/agl-hostman/.ssh/pbs_backup2"
        }
      ],
      "backup_schedule": [
        "0 2 * * *",
        "0 14 * * *"
      ],
      "retention": {
        "hourly": 24,
        "daily": 7,
        "weekly": 4,
        "monthly": 12
      },
      "compression": {
        "enabled": true,
        "algorithm": "zstd",
        "level": 3
      },
      "encryption": {
        "enabled": true,
        "key": "/etc/agl-hostman/pbs.encryption.key"
      }
    }
  }
}
```

## Monitoring Configuration

### Prometheus Configuration

#### Basic Setup
```json
{
  "monitoring": {
    "prometheus": {
      "enabled": true,
      "port": 9090,
      "retention": "15d"
    }
  }
}
```

#### Advanced Setup
```json
{
  "monitoring": {
    "prometheus": {
      "enabled": true,
      "port": 9090,
      "retention": "15d",
      "storage": {
        "tsdb": {
          "path": "/var/lib/prometheus/data",
          "wal_compression": true,
          "out_of_order_window": 0
        }
      },
      "alerting": {
        "enabled": true,
        "rules_path": "/etc/prometheus/rules",
        "alertmanagers": [
          {
            "static_configs": [
              {
                "targets": ["localhost:9093"]
              }
            ]
          }
        ]
      }
    }
  }
}
```

### Grafana Configuration

#### Basic Setup
```json
{
  "monitoring": {
    "grafana": {
      "enabled": true,
      "port": 3000,
      "admin_password": "change-me"
    }
  }
}
```

#### Advanced Setup
```json
{
  "monitoring": {
    "grafana": {
      "enabled": true,
      "port": 3000,
      "admin_password": "secure-password",
      "dashboards": {
        "path": "/etc/grafana/dashboards",
        "auto_import": true
      },
      "datasources": [
        {
          "name": "Prometheus",
          "type": "prometheus",
          "url": "http://localhost:9090",
          "access": "proxy",
          "is_default": true
        },
        {
          "name": "Loki",
          "type": "loki",
          "url": "http://localhost:3100",
          "access": "proxy"
        }
      ],
      "users": [
        {
          "email": "admin@aglhostman.local",
          "name": "admin",
          "password": "secure-password",
          "role": "Admin"
        }
      ]
    }
  }
}
```

### Loki Configuration

#### Basic Setup
```json
{
  "monitoring": {
    "loki": {
      "enabled": true,
      "port": 3100,
      "retention": "7d"
    }
  }
}
```

#### Advanced Setup
```json
{
  "monitoring": {
    "loki": {
      "enabled": true,
      "port": 3100,
      "retention": "7d",
      "schema_config": {
        "configs": [
          {
            "from_date": "2025-10-01",
            "store": "tsdb",
            "object_store": "s3",
            "schema": "v11",
            "index": {
              "prefix": "index_",
              "period": "24h"
            }
          }
        ]
      },
      "chunk_store_config": {
        "max_look_back_period": 0
      }
    }
  }
}
```

## Backup Configuration

### Basic Backup Setup
```json
{
  "backups": {
    "enabled": true,
    "schedule": "0 2 * * *",
    "retention": {
      "daily": 7,
      "weekly": 4,
      "monthly": 12
    },
    "compression": true,
    "encryption": true
  }
}
```

### Advanced Backup Setup
```json
{
  "backups": {
    "enabled": true,
    "schedule": [
      "0 2 * * *",
      "0 14 * * *"
    ],
    "retention": {
      "hourly": 24,
      "daily": 7,
      "weekly": 4,
      "monthly": 12,
      "yearly": 1
    },
    "compression": {
      "enabled": true,
      "algorithm": "zstd",
      "level": 3
    },
    "encryption": {
      "enabled": true,
      "algorithm": "aes256",
      "key": "/etc/agl-hostman/backup.encryption.key"
    },
    "verification": {
      "enabled": true,
      "schedule": "0 3 * * 1"
    },
    "offsite": {
      "enabled": true,
      "method": "rsync",
      "remote": "backup-server.local",
      "path": "/backups/aglhostman",
      "schedule": "0 4 * * *"
    },
    "notifications": {
      "enabled": true,
      "success": true,
      "failure": true,
      "email": {
        "enabled": false,
        "smtp": {
          "host": "smtp.example.com",
          "port": 587,
          "username": "alerts@example.com",
          "password": "password"
        },
        "recipients": ["admin@aglhostman.local"]
      },
      "webhook": {
        "enabled": true,
        "url": "https://hooks.slack.com/services/..."
      }
    }
  }
}
```

## Security Configuration

### Authentication Configuration

#### JWT Authentication
```json
{
  "security": {
    "auth": {
      "method": "jwt",
      "secret": "your-secret-key",
      "algorithm": "HS256",
      "token_expiry": 3600,
      "refresh_token_expiry": 86400,
      "refresh_token_rotation": true
    }
  }
}
```

#### OAuth2 Authentication
```json
{
  "security": {
    "auth": {
      "method": "oauth2",
      "oauth2": {
        "provider": "github",
        "client_id": "your-client-id",
        "client_secret": "your-client-secret",
        "redirect_uri": "https://app.aglhostman.local/auth/callback",
        "scope": "read:user"
      }
    }
  }
}
```

### SSL/TLS Configuration

#### Self-Signed Certificate
```json
{
  "security": {
    "ssl": {
      "enabled": true,
      "cert_path": "/etc/agl-hostman/cert.pem",
      "key_path": "/etc/agl-hostman/key.pem",
      "generate_self_signed": true,
      "country": "US",
      "state": "California",
      "locality": "San Francisco",
      "organization": "AGL Hostman",
      "common_name": "app.aglhostman.local"
    }
  }
}
```

#### Let's Encrypt Certificate
```json
{
  "security": {
    "ssl": {
      "enabled": true,
      "cert_path": "/etc/agl-hostman/cert.pem",
      "key_path": "/etc/agl-hostman/key.pem",
      "letsencrypt": {
        "enabled": true,
        "email": "admin@aglhostman.local",
        "domains": ["app.aglhostman.local", "api.aglhostman.local"]
      }
    }
  }
}
```

## API Configuration

### Basic API Setup
```json
{
  "api": {
    "enabled": true,
    "port": 8080,
    "cors": {
      "enabled": true,
      "allowed_origins": ["https://app.aglhostman.local"]
    }
  }
}
```

### Advanced API Setup
```json
{
  "api": {
    "enabled": true,
    "port": 8080,
    "rate_limit": {
      "enabled": true,
      "requests": 100,
      "window": 60,
      "burst": 10
    },
    "cors": {
      "enabled": true,
      "allowed_origins": [
        "https://app.aglhostman.local",
        "https://staging.app.aglhostman.local"
      ],
      "allowed_methods": ["GET", "POST", "PUT", "DELETE"],
      "allowed_headers": ["Authorization", "Content-Type"],
      "exposed_headers": ["X-Rate-Limit"],
      "max_age": 3600
    },
    "openapi": {
      "enabled": true,
      "spec_path": "/docs/api-schema.json",
      "redoc": true,
      "swagger_ui": true
    },
    "middleware": [
      "auth",
      "cors",
      "rate-limit",
      "compression"
    ]
  }
}
```

## Configuration Validation

### Validate Configuration

```bash
# Validate configuration file
agl-hostman config validate

# Validate configuration with environment
agl-hostman config validate --env

# Check configuration syntax
agl-hostman config check-syntax

# Test configuration
agl-hostman config test
```

### Common Configuration Issues

#### 1. Invalid Configuration Format
```bash
# Check JSON syntax
cat config/config.json | python -m json.tool

# Use validator tool
agl-hostman config validate
```

#### 2. Missing Required Fields
```bash
# Check required fields
agl-hostman config check-required

# Show missing fields
agl-hostman config validate --verbose
```

#### 3. Configuration File Permissions
```bash
# Fix permissions
chmod 600 config/config.json
chown agl-hostman:agl-hostman config/config.json
```

## Configuration Management

### Environment-Specific Configurations

Create separate configuration files for different environments:

```bash
# Production
config/config.production.json

# Staging
config/config.staging.json

# Development
config/config.development.json
```

### Configuration Versioning

Track configuration changes:

```bash
# Add configuration to git
git add config/

# Commit changes
git commit -m "Update configuration"

# Tag release
git tag -a "v1.0.0" -m "Version 1.0.0"
```

### Configuration Backup

```bash
# Backup configuration
cp config/config.json config/backup/config-$(date +%Y%m%d).json

# Backup with encryption
cp config/config.json config/backup/config-encrypted.json.gpg
gpg -c config/backup/config-encrypted.json.gpg
```

## Next Steps

1. [Initial Setup](initial-setup.md) - Complete post-installation configuration
2. [Storage Management](../storage/nfs.md) - Configure storage protocols
3. [Monitoring Setup](../monitoring/stack.md) - Set up monitoring
4. [Backup Configuration](../backup/strategy.md) - Configure backup systems

---

*Need help? Check the [troubleshooting guide](../troubleshooting/common.md) or create an issue on [GitHub](https://github.com/aglhostman/agl-hostman/issues).*