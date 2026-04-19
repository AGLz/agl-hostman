#!/bin/bash
#
# ZFS Monitoring Setup - Install and configure monitoring dashboard
# Sets up Grafana dashboard for ZFS metrics visualization
#

set -euo pipefail

LOG_FILE="/var/log/zfs-protection/setup-monitoring.log"
CONFIG_DIR="/etc/zfs-protection"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ This script must be run as root"
        exit 1
    fi
}

# Install monitoring dependencies
install_dependencies() {
    log "📦 Installing monitoring dependencies..."

    # Update package list
    apt-get update

    # Install required packages
    local packages=(
        "prometheus"
        "grafana"
        "node-exporter"
        "curl"
        "jq"
        "bc"
    )

    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package "; then
            log "✅ $package already installed"
        else
            log "📦 Installing $package..."
            if apt-get install -y "$package"; then
                log "✅ $package installed successfully"
            else
                log "❌ Failed to install $package"
                return 1
            fi
        fi
    done
}

# Configure Prometheus for ZFS metrics
configure_prometheus() {
    log "📊 Configuring Prometheus for ZFS metrics..."

    local prometheus_config="/etc/prometheus/prometheus.yml"
    local prometheus_backup="/etc/prometheus/prometheus.yml.backup.$(date +%Y%m%d_%H%M%S)"

    # Backup existing configuration
    if [[ -f "$prometheus_config" ]]; then
        cp "$prometheus_config" "$prometheus_backup"
        log "📋 Backed up Prometheus config to: $prometheus_backup"
    fi

    # Create ZFS metrics configuration
    cat > "$prometheus_config" <<EOF
# Prometheus configuration for ZFS monitoring
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/zfs-rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'zfs-metrics'
    static_configs:
      - targets: ['localhost:9101']
    scrape_interval: 30s
    metrics_path: '/metrics'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

EOF

    # Create ZFS alerting rules
    cat > "/etc/prometheus/zfs-rules.yml" <<EOF
groups:
  - name: zfs_alerts
    rules:
      - alert: ZFSPoolDegraded
        expr: zfs_pool_health != 1
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "ZFS pool {{ \$labels.pool }} is degraded"
          description: "Pool {{ \$labels.pool }} health status: {{ \$value }}"

      - alert: ZFSHighCapacity
        expr: zfs_pool_capacity_percent > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "ZFS pool {{ \$labels.pool }} capacity high"
          description: "Pool {{ \$labels.pool }} is {{ \$value }}% full"

      - alert: ZFSCapacityCritical
        expr: zfs_pool_capacity_percent > 90
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ZFS pool {{ \$labels.pool }} capacity critical"
          description: "Pool {{ \$labels.pool }} is {{ \$value }}% full"

      - alert: ZFSARCHitRatioLow
        expr: zfs_arc_hit_ratio < 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "ZFS ARC hit ratio is low"
          description: "ARC hit ratio is {{ \$value }}%"

      - alert: ZFSScrubErrors
        expr: increase(zfs_pool_scrub_errors[1h]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "ZFS scrub found errors on pool {{ \$labels.pool }}"
          description: "Scrub found {{ \$value }} errors on pool {{ \$labels.pool }}"

EOF

    # Restart Prometheus
    if systemctl restart prometheus; then
        log "✅ Prometheus configured and restarted"
    else
        log "❌ Failed to restart Prometheus"
        return 1
    fi

    # Enable Prometheus service
    systemctl enable prometheus
}

# Create ZFS metrics exporter
create_zfs_exporter() {
    log "📈 Creating ZFS metrics exporter..."

    local exporter_script="/opt/zfs-protection/scripts/zfs-metrics-exporter.sh"

    cat > "$exporter_script" <<'EOF'
#!/bin/bash
#
# ZFS Metrics Exporter for Prometheus
#

set -euo pipefail

# Function to escape metric names
escape_metric() {
    echo "$1" | sed 's/[^a-zA-Z0-9_]/_/g'
}

# Export pool metrics
export_pool_metrics() {
    echo "# HELP zfs_pool_health Pool health status (1=ONLINE, 0=other)"
    echo "# TYPE zfs_pool_health gauge"

    echo "# HELP zfs_pool_capacity_bytes Pool capacity in bytes"
    echo "# TYPE zfs_pool_capacity_bytes gauge"

    echo "# HELP zfs_pool_capacity_percent Pool capacity percentage"
    echo "# TYPE zfs_pool_capacity_percent gauge"

    echo "# HELP zfs_pool_free_bytes Pool free space in bytes"
    echo "# TYPE zfs_pool_free_bytes gauge"

    for pool in $(zpool list -H -o name 2>/dev/null || echo ""); do
        if [[ -z "$pool" ]]; then
            continue
        fi

        local health size alloc free cap
        health=$(zpool get -H -o value health "$pool" 2>/dev/null || echo "UNKNOWN")
        size=$(zpool get -H -o value size "$pool" 2>/dev/null || echo "0")
        alloc=$(zpool get -H -o value allocated "$pool" 2>/dev/null || echo "0")
        free=$(zpool get -H -o value free "$pool" 2>/dev/null || echo "0")
        cap=$(zpool get -H -o value capacity "$pool" 2>/dev/null | tr -d '%' || echo "0")

        # Convert sizes to bytes
        size_bytes=$(echo "$size" | sed 's/[KMGT]//' | awk '{
            if (match($0, /K/)) print $1 * 1024
            else if (match($0, /M/)) print $1 * 1024 * 1024
            else if (match($0, /G/)) print $1 * 1024 * 1024 * 1024
            else if (match($0, /T/)) print $1 * 1024 * 1024 * 1024 * 1024
            else print $1
        }')

        free_bytes=$(echo "$free" | sed 's/[KMGT]//' | awk '{
            if (match($0, /K/)) print $1 * 1024
            else if (match($0, /M/)) print $1 * 1024 * 1024
            else if (match($0, /G/)) print $1 * 1024 * 1024 * 1024
            else if (match($0, /T/)) print $1 * 1024 * 1024 * 1024 * 1024
            else print $1
        }')

        # Health status (1 for ONLINE, 0 for others)
        local health_value=0
        [[ "$health" == "ONLINE" ]] && health_value=1

        local escaped_pool
        escaped_pool=$(escape_metric "$pool")

        echo "zfs_pool_health{pool=\"$pool\"} $health_value"
        echo "zfs_pool_capacity_bytes{pool=\"$pool\"} $size_bytes"
        echo "zfs_pool_capacity_percent{pool=\"$pool\"} $cap"
        echo "zfs_pool_free_bytes{pool=\"$pool\"} $free_bytes"
    done
}

# Export ARC metrics
export_arc_metrics() {
    if [[ ! -f /proc/spl/kstat/zfs/arcstats ]]; then
        return
    fi

    echo "# HELP zfs_arc_size Current ARC size in bytes"
    echo "# TYPE zfs_arc_size gauge"

    echo "# HELP zfs_arc_max Maximum ARC size in bytes"
    echo "# TYPE zfs_arc_max gauge"

    echo "# HELP zfs_arc_hits ARC cache hits"
    echo "# TYPE zfs_arc_hits counter"

    echo "# HELP zfs_arc_misses ARC cache misses"
    echo "# TYPE zfs_arc_misses counter"

    echo "# HELP zfs_arc_hit_ratio ARC hit ratio percentage"
    echo "# TYPE zfs_arc_hit_ratio gauge"

    local arc_size arc_max arc_hits arc_misses arc_hit_ratio

    arc_size=$(awk '/^size/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arc_max=$(awk '/^c_max/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arc_hits=$(awk '/^hits/ {print $3}' /proc/spl/kstat/zfs/arcstats)
    arc_misses=$(awk '/^misses/ {print $3}' /proc/spl/kstat/zfs/arcstats)

    if [[ "$arc_hits" -gt 0 ]] && [[ "$arc_misses" -gt 0 ]]; then
        arc_hit_ratio=$(echo "scale=2; $arc_hits * 100 / ($arc_hits + $arc_misses)" | bc)
    else
        arc_hit_ratio=0
    fi

    echo "zfs_arc_size $arc_size"
    echo "zfs_arc_max $arc_max"
    echo "zfs_arc_hits $arc_hits"
    echo "zfs_arc_misses $arc_misses"
    echo "zfs_arc_hit_ratio $arc_hit_ratio"
}

# Export dataset metrics
export_dataset_metrics() {
    echo "# HELP zfs_dataset_used_bytes Dataset used space in bytes"
    echo "# TYPE zfs_dataset_used_bytes gauge"

    echo "# HELP zfs_dataset_available_bytes Dataset available space in bytes"
    echo "# TYPE zfs_dataset_available_bytes gauge"

    for dataset in $(zfs list -H -o name -t filesystem | head -10); do
        local used avail
        used=$(zfs get -H -o value used "$dataset" 2>/dev/null || echo "0")
        avail=$(zfs get -H -o value available "$dataset" 2>/dev/null || echo "0")

        # Convert to bytes
        used_bytes=$(echo "$used" | sed 's/[KMGT]//' | awk '{
            if (match($0, /K/)) print $1 * 1024
            else if (match($0, /M/)) print $1 * 1024 * 1024
            else if (match($0, /G/)) print $1 * 1024 * 1024 * 1024
            else if (match($0, /T/)) print $1 * 1024 * 1024 * 1024 * 1024
            else print $1
        }')

        avail_bytes=$(echo "$avail" | sed 's/[KMGT]//' | awk '{
            if (match($0, /K/)) print $1 * 1024
            else if (match($0, /M/)) print $1 * 1024 * 1024
            else if (match($0, /G/)) print $1 * 1024 * 1024 * 1024
            else if (match($0, /T/)) print $1 * 1024 * 1024 * 1024 * 1024
            else print $1
        }')

        local escaped_dataset
        escaped_dataset=$(escape_metric "$dataset")

        echo "zfs_dataset_used_bytes{dataset=\"$dataset\"} $used_bytes"
        echo "zfs_dataset_available_bytes{dataset=\"$dataset\"} $avail_bytes"
    done
}

# Main export function
main() {
    export_pool_metrics
    echo ""
    export_arc_metrics
    echo ""
    export_dataset_metrics
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
EOF

    chmod +x "$exporter_script"

    # Create systemd service for metrics exporter
    cat > "/etc/systemd/system/zfs-metrics-exporter.service" <<EOF
[Unit]
Description=ZFS Metrics Exporter for Prometheus
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/bin/bash -c 'while true; do /opt/zfs-protection/scripts/zfs-metrics-exporter.sh > /var/lib/prometheus/node-exporter/zfs-metrics.prom.tmp && mv /var/lib/prometheus/node-exporter/zfs-metrics.prom.tmp /var/lib/prometheus/node-exporter/zfs-metrics.prom; sleep 30; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create metrics directory
    mkdir -p /var/lib/prometheus/node-exporter

    # Start and enable the service
    systemctl daemon-reload
    systemctl enable zfs-metrics-exporter.service
    systemctl start zfs-metrics-exporter.service

    log "✅ ZFS metrics exporter created and started"
}

# Configure Grafana
configure_grafana() {
    log "📊 Configuring Grafana for ZFS monitoring..."

    # Start and enable Grafana
    systemctl enable grafana-server
    systemctl start grafana-server

    # Wait for Grafana to start
    sleep 10

    # Check if Grafana is running
    if ! curl -s http://localhost:3000/api/health >/dev/null; then
        log "❌ Grafana is not responding"
        return 1
    fi

    log "✅ Grafana is running on http://localhost:3000"
    log "📝 Default login: admin/admin (change on first login)"

    # Create datasource configuration
    local datasource_config="/tmp/prometheus-datasource.json"
    cat > "$datasource_config" <<EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://localhost:9090",
  "access": "proxy",
  "isDefault": true
}
EOF

    # Add Prometheus datasource (will fail if already exists, that's ok)
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "@$datasource_config" \
        http://admin:admin@localhost:3000/api/datasources \
        >/dev/null 2>&1 || true

    rm -f "$datasource_config"

    # Create ZFS dashboard
    create_grafana_dashboard

    log "✅ Grafana configured with ZFS dashboard"
}

# Create Grafana dashboard for ZFS
create_grafana_dashboard() {
    local dashboard_file="/tmp/zfs-dashboard.json"

    cat > "$dashboard_file" <<'EOF'
{
  "dashboard": {
    "id": null,
    "title": "ZFS Monitoring Dashboard",
    "description": "Comprehensive ZFS monitoring with pool health, capacity, and performance metrics",
    "tags": ["zfs", "storage", "proxmox"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "panels": [
      {
        "id": 1,
        "title": "Pool Health Status",
        "type": "stat",
        "targets": [
          {
            "expr": "zfs_pool_health",
            "legendFormat": "{{pool}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            },
            "mappings": [
              {"options": {"0": {"text": "OFFLINE"}}, "type": "value"},
              {"options": {"1": {"text": "ONLINE"}}, "type": "value"}
            ]
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Pool Capacity",
        "type": "gauge",
        "targets": [
          {
            "expr": "zfs_pool_capacity_percent",
            "legendFormat": "{{pool}}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 70},
                {"color": "orange", "value": 80},
                {"color": "red", "value": 90}
              ]
            },
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "ARC Hit Ratio",
        "type": "gauge",
        "targets": [
          {
            "expr": "zfs_arc_hit_ratio"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 80},
                {"color": "green", "value": 90}
              ]
            },
            "unit": "percent",
            "min": 0,
            "max": 100
          }
        },
        "gridPos": {"h": 8, "w": 8, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "ARC Size",
        "type": "timeseries",
        "targets": [
          {
            "expr": "zfs_arc_size",
            "legendFormat": "Current Size"
          },
          {
            "expr": "zfs_arc_max",
            "legendFormat": "Max Size"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 16, "x": 8, "y": 8}
      },
      {
        "id": 5,
        "title": "Pool Free Space",
        "type": "timeseries",
        "targets": [
          {
            "expr": "zfs_pool_free_bytes",
            "legendFormat": "{{pool}} Free"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
      }
    ]
  },
  "folderId": 0,
  "overwrite": true
}
EOF

    # Import dashboard
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "@$dashboard_file" \
        http://admin:admin@localhost:3000/api/dashboards/db \
        >/dev/null 2>&1 || true

    rm -f "$dashboard_file"
}

# Setup log aggregation
setup_log_aggregation() {
    log "📋 Setting up log aggregation..."

    # Create centralized logging script
    local log_aggregator="/opt/zfs-protection/scripts/log-aggregator.sh"

    cat > "$log_aggregator" <<'EOF'
#!/bin/bash
#
# ZFS Log Aggregator - Collect and analyze ZFS protection logs
#

set -euo pipefail

LOG_DIR="/var/log/zfs-protection"
REPORT_DIR="/var/log/zfs-protection/reports"
RETENTION_DAYS=30

# Create report directory
mkdir -p "$REPORT_DIR"

# Generate daily summary report
generate_daily_report() {
    local date="${1:-$(date +%Y-%m-%d)}"
    local report_file="$REPORT_DIR/daily-summary-$date.txt"

    {
        echo "📊 ZFS Protection Daily Summary - $date"
        echo "=========================================="
        echo ""

        echo "🔍 Health Check Summary:"
        grep -c "Health check cycle completed" "$LOG_DIR/health-monitor.log" 2>/dev/null || echo "0"
        echo ""

        echo "💾 Backup Summary:"
        grep -c "completed successfully" "$LOG_DIR/backup.log" 2>/dev/null || echo "0 successful"
        grep -c "failed" "$LOG_DIR/backup.log" 2>/dev/null || echo "0 failed"
        echo ""

        echo "🔍 Scrub Summary:"
        grep -c "Scrub completed" "$LOG_DIR/scrub.log" 2>/dev/null || echo "0 completed"
        echo ""

        echo "🚨 Alert Summary:"
        grep -c "CRITICAL" "$LOG_DIR/alerts.log" 2>/dev/null || echo "0 critical"
        grep -c "WARNING" "$LOG_DIR/alerts.log" 2>/dev/null || echo "0 warnings"
        echo ""

        echo "📈 Pool Status:"
        zpool status | grep -E "pool:|state:"
        echo ""

        echo "💿 Capacity Usage:"
        zfs list -o name,used,avail,refer,mountpoint | head -10

    } > "$report_file"

    echo "📄 Daily report generated: $report_file"
}

# Clean old logs
cleanup_logs() {
    find "$LOG_DIR" -name "*.log" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "*.txt" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
}

# Main function
case "${1:-daily}" in
    "daily")
        generate_daily_report
        cleanup_logs
        ;;
    "cleanup")
        cleanup_logs
        ;;
    *)
        echo "Usage: $0 [daily|cleanup]"
        exit 1
        ;;
esac
EOF

    chmod +x "$log_aggregator"

    # Create systemd timer for daily reports
    cat > "/etc/systemd/system/zfs-log-aggregator.service" <<EOF
[Unit]
Description=ZFS Log Aggregator
After=network.target

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/opt/zfs-protection/scripts/log-aggregator.sh daily
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    cat > "/etc/systemd/system/zfs-log-aggregator.timer" <<EOF
[Unit]
Description=ZFS Log Aggregator Timer
Requires=zfs-log-aggregator.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable zfs-log-aggregator.timer
    systemctl start zfs-log-aggregator.timer

    log "✅ Log aggregation configured"
}

# Generate monitoring summary
generate_monitoring_summary() {
    local summary_file="/var/log/zfs-protection/monitoring-setup-summary.txt"

    {
        echo "📊 ZFS Monitoring Setup Summary - $(date)"
        echo "=============================================="
        echo ""

        echo "🔧 Installed Components:"
        echo "- Prometheus: http://localhost:9090"
        echo "- Grafana: http://localhost:3000 (admin/admin)"
        echo "- Node Exporter: http://localhost:9100/metrics"
        echo "- ZFS Metrics Exporter: running as systemd service"
        echo ""

        echo "📊 Monitoring Services Status:"
        systemctl is-active prometheus || echo "prometheus: inactive"
        systemctl is-active grafana-server || echo "grafana-server: inactive"
        systemctl is-active node-exporter || echo "node-exporter: inactive"
        systemctl is-active zfs-metrics-exporter || echo "zfs-metrics-exporter: inactive"
        echo ""

        echo "📋 Configuration Files:"
        echo "- Prometheus: /etc/prometheus/prometheus.yml"
        echo "- Grafana: http://localhost:3000/dashboard/import"
        echo "- ZFS Exporter: /opt/zfs-protection/scripts/zfs-metrics-exporter.sh"
        echo ""

        echo "🚀 Next Steps:"
        echo "1. Access Grafana at http://localhost:3000"
        echo "2. Login with admin/admin and change password"
        echo "3. Import ZFS dashboard (automatically created)"
        echo "4. Configure additional alerts if needed"
        echo "5. Set up external access if required"
        echo ""

        echo "📚 Useful Commands:"
        echo "- Check metrics: curl http://localhost:9100/metrics | grep zfs"
        echo "- Restart services: systemctl restart prometheus grafana-server"
        echo "- View logs: journalctl -u zfs-metrics-exporter"

    } > "$summary_file"

    log "📄 Monitoring setup summary: $summary_file"
    cat "$summary_file"
}

# Main setup function
main() {
    log "🚀 Starting ZFS monitoring setup..."

    check_root

    # Install components
    install_dependencies
    configure_prometheus
    create_zfs_exporter
    configure_grafana
    setup_log_aggregation

    # Generate summary
    generate_monitoring_summary

    log "✅ ZFS monitoring setup completed successfully!"
    log "🌐 Access Grafana at: http://$(hostname -I | awk '{print $1}'):3000"
    log "📊 Default credentials: admin/admin"
}

# Run setup
main "$@"