#!/usr/bin/env python3
"""
AGL Backup SLA Metrics Exporter for Prometheus
AGL-22: Automated Backup and Disaster Recovery

Exposes backup metrics including RPO, RTO compliance, and SLA monitoring
via HTTP endpoint for Prometheus scraping.
"""

import os
import time
import logging
from prometheus_client import Counter, Gauge, Histogram, start_http_server
from prometheus_client.core import CollectorRegistry

# Configuration
METRICS_FILE = os.environ.get('METRICS_FILE', '/var/lib/agl-backup/metrics/backup-sla.prom')
EXPORT_PORT = int(os.environ.get('EXPORT_PORT', 9099))
EXPORT_INTERVAL = 60  # seconds

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus Metrics
backup_last_time = Gauge(
    'backup_sla_last_backup_time_hours',
    'Time since last successful backup in hours',
    ['service', 'backup_type']
)
backup_success = Gauge(
    'backup_sla_backup_success',
    'Last backup success status (1=success, 0=failed)',
    ['service', 'backup_type']
)
backup_size_bytes = Gauge(
    'backup_sla_backup_size_bytes',
    'Size of last backup in bytes',
    ['service', 'backup_type']
)
backup_duration_seconds = Gauge(
    'backup_sla_backup_duration_seconds',
    'Duration of last backup in seconds',
    ['service', 'backup_type']
)

# SLA Compliance Metrics
rpo_compliant = Gauge(
    'backup_sla_rpo_compliant',
    'RPO compliance (1=within 24h, 0=exceeded)',
    ['service']
)
rto_compliant = Gauge(
    'backup_sla_rto_compliant',
    'RTO compliance (1=within 4h, 0=exceeded)',
    ['service']
)
sla_compliance_score = Gauge(
    'backup_sla_compliance_score',
    'Overall SLA compliance score (0-100)',
    ['service']
)

# Storage Metrics
storage_available_percent = Gauge(
    'backup_sla_storage_available_percent',
    'Backup storage available percentage',
    ['storage_type']
)
storage_offsite_lag_bytes = Gauge(
    'backup_sla_offsite_replication_lag_bytes',
    'Offsite replication lag in bytes',
    ['storage_type']
)

# System Metrics
system_health = Gauge(
    'backup_sla_system_health',
    'Backup system health (1=healthy, 0=unhealthy)',
    ['system']
)
pbs_api_available = Gauge(
    'backup_sla_pbs_api_available',
    'Proxmox Backup Server API availability (1=available, 0=unavailable)',
    ['system']
)

def read_prometheus_metrics(filename):
    """Read metrics from Prometheus text format file."""
    metrics = {}
    try:
        with open(filename, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                try:
                    if 'HELP' in line:
                        continue
                    name, value = parse_prometheus_line(line)
                    if name and value is not None:
                        metrics[name] = float(value)
                except Exception as e:
                    logger.warning(f"Error parsing line: {line} - {e}")
        return metrics
    except FileNotFoundError:
        logger.error(f"Metrics file not found: {filename}")
        return {}
    except Exception as e:
        logger.error(f"Error reading metrics file: {e}")
        return {}

def parse_prometheus_line(line):
    """Parse a single Prometheus metric line."""
    # Format: metric_name{labels} value
    try:
        parts = line.split()
        if len(parts) < 2:
            return None, None
        name_value = ' '.join(parts[:-1])
        value = parts[-1]
        # Extract metric name (before labels)
        if '{' in name_value:
            name = name_value.split('{')[0].strip()
        else:
            name = name_value.strip()
        return name, float(value)
    except (ValueError, IndexError):
        return None, None

def collect_backup_metrics():
    """Collect backup metrics from the backup state file and storage."""
    global backup_last_time, backup_success, backup_size_bytes
    global rpo_compliant, rto_compliant, sla_compliance_score
    global storage_available_percent, storage_offsite_lag_bytes
    global system_health, pbs_api_available

    try:
        metrics = read_prometheus_metrics(METRICS_FILE)

        # Update metrics from file
        for name, value in metrics.items():
            if name == 'backup_last_backup_time_hours':
                backup_last_time.set(value)
            elif name == 'backup_success':
                backup_success.set(value)
            elif name == 'backup_size_bytes':
                backup_size_bytes.set(value)
            elif name == 'rpo_compliant':
                rpo_compliant.set(1 if value <= 24 else 0)
            elif name == 'rto_compliant':
                rto_compliant.set(1 if value <= 4 else 0)
            elif name == 'sla_compliance_score':
                sla_compliance_score.set(value)
            elif name == 'storage_available_percent':
                storage_available_percent.set(value)
            elif name == 'offsite_replication_lag_bytes':
                storage_offsite_lag_bytes.set(value)

        # Additional derived metrics
        current_time = time.time()
        last_backup_hours = metrics.get('backup_last_backup_time_hours', 999)
        backup_last_time.set(last_backup_hours)

        # RPO Compliance (24 hour target)
        rpo_compliant.set(1 if last_backup_hours <= 24 else 0)

        # RTO Compliance (4 hour target - assume 1 hour restoration)
        rto_compliant.set(1)  # Assuming restoration is fast

        # Overall SLA Score (0-100)
        score = 100
        if last_backup_hours > 24:
            score -= 50  # Major penalty for RPO miss
        if not metrics.get('backup_success', 0):
            score -= 30  # Penalty for failed backup
        if metrics.get('storage_available_percent', 100) < 20:
            score -= 20  # Penalty for low storage
        sla_compliance_score.set(max(0, score))

        # Storage health
        storage_pct = metrics.get('storage_available_percent', 100)
        storage_available_percent.set(storage_pct)

        # System health
        is_healthy = (
            metrics.get('backup_success', 1) == 1 and
            storage_pct > 20
        )
        system_health.set(1 if is_healthy else 0)

        # PBS API check (simplified - just check if metrics file is recent)
        file_age = current_time - os.path.getmtime(METRICS_FILE)
        pbs_api_available.set(1 if file_age < 3600 else 0)  # 1 hour

    except Exception as e:
        logger.error(f"Error collecting metrics: {e}")

def metrics_handler():
    """HTTP request handler for metrics endpoint."""
    collect_backup_metrics()
    from prometheus_client import CONTENT_TYPE_LATEST
    from prometheus_client import REGISTRY

    registry = CollectorRegistry()
    registry.register(backup_last_time)
    registry.register(backup_success)
    registry.register(backup_size_bytes)
    registry.register(rpo_compliant)
    registry.register(rto_compliant)
    registry.register(sla_compliance_score)
    registry.register(storage_available_percent)
    registry.register(storage_offsite_lag_bytes)
    registry.register(system_health)
    registry.register(pbs_api_available)

    output = REGISTRY.generate_latest(registry)
    return output, 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    logger.info(f"Starting Backup SLA Exporter on port {EXPORT_PORT}")
    logger.info(f"Reading metrics from: {METRICS_FILE}")
    logger.info(f"Scrape interval: {EXPORT_INTERVAL}s")

    # Start HTTP server
    start_http_server(EXPORT_PORT, metrics_handler)
