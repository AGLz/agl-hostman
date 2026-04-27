-- ============================================================================
-- Database Index Optimization for Monitoring Queries
-- ============================================================================
-- These indexes improve query performance for monitoring, alerts, and
-- performance trend queries.
--
-- Apply indexes incrementally and measure impact
-- ============================================================================

-- ============================================================================
-- PERFORMANCE_TRENDS Table Indexes
-- Primary time-series data - high write volume
-- ============================================================================

-- Core query index for resource metrics retrieval
-- Covers queries filtered by resource, metric type, and time range
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_trends_resource_metric_time
ON performance_trends (resource_type, resource_id, metric_type, recorded_at DESC);

-- Latest metric lookup index
-- Used for fetching current state of resources
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_trends_latest
ON performance_trends (resource_id, metric_type, recorded_at DESC)
WHERE recorded_at > NOW() - INTERVAL '7 days';

-- Metric type aggregation index
-- Used for aggregate queries (MIN, MAX, AVG) over time ranges
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_trends_metric_time
ON performance_trends (metric_type, recorded_at DESC)
WHERE recorded_at > NOW() - INTERVAL '90 days';

-- ============================================================================
-- ALERTS Table Indexes
-- Moderate write volume, heavy read for dashboard
-- ============================================================================

-- Active alerts index - critical for dashboard queries
-- Covers filtering by status, severity, and creation time
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_status_severity_time
ON alerts (status, severity DESC, created_at DESC)
WHERE status != 'resolved';

-- Resource-specific alert lookup
-- Polymorphic relationship queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_resource
ON alerts (resource_type, resource_id, status)
WHERE status = 'active';

-- Alert type filtering
-- Used for alert type-specific dashboards
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_type_status
ON alerts (alert_type, status, created_at DESC);

-- Muted alerts index
-- Excludes muted alerts from active queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_muted
ON alerts (muted_until)
WHERE muted_until IS NOT NULL;

-- Composite index for unresolved critical alerts
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_unresolved_critical
ON alerts (is_resolved, severity, created_at DESC)
WHERE is_resolved = false;

-- ============================================================================
-- LXC_CONTAINERS Table Indexes
-- ============================================================================

-- Status filtering for dashboard
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_containers_status
ON lxc_containers (status, proxmox_server_id)
WHERE status IN ('running', 'starting');

-- Server relationship index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_containers_server
ON lxc_containers (proxmox_server_id);

-- VMID lookup for API queries
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_containers_vmid
ON lxc_containers (vmid);

-- ============================================================================
-- DOKPLOY_DEPLOYMENTS Table Indexes
-- ============================================================================

-- Application deployment history
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deployments_app_status
ON dokploy_deployments (application_id, status, created_at DESC);

-- Branch filtering for CI/CD
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deployments_branch
ON dokploy_deployments (branch, created_at DESC)
WHERE branch IN ('main', 'develop', 'staging');

-- Triggered_by user lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deployments_user
ON dokploy_deployments (triggered_by, created_at DESC);

-- ============================================================================
-- USERS Table Indexes (for permission checks)
-- ============================================================================

-- Email lookup for authentication
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email
ON users (email)
WHERE is_active = true;

-- Active users index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_active
ON users (is_active, last_login_at DESC);

-- ============================================================================
-- PARTIAL INDEX EXAMPLES (PostgreSQL)
-- ============================================================================

-- Only index recent trends (save space)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_performance_trends_recent
ON performance_trends (resource_id, metric_type, value, recorded_at)
WHERE recorded_at > NOW() - INTERVAL '30 days';

-- Only index critical unresolved alerts
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_alerts_critical_active
ON alerts (resource_id, severity, created_at)
WHERE severity >= 70 AND status = 'active';

-- ============================================================================
-- INDEX USAGE ANALYSIS
-- ============================================================================

-- Check index usage (PostgreSQL)
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;

-- Find unused indexes (PostgreSQL)
-- Consider dropping indexes that haven't been used in 30 days
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Index size analysis (PostgreSQL)
SELECT
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- ============================================================================
-- INDEX MAINTENANCE
-- ============================================================================

-- Reindex concurrently (PostgreSQL)
-- Run during maintenance windows
REINDEX INDEX CONCURRENTLY idx_performance_trends_resource_metric_time;

-- Vacuum analyze to update statistics
-- Run after bulk data loads or deletes
VACUUM ANALYZE performance_trends;
VACUUM ANALYZE alerts;

-- ============================================================================
-- DROP INDEX EXAMPLES (Use with caution!)
-- ============================================================================

-- Drop unused index (PostgreSQL)
-- DROP INDEX CONCURRENTLY IF NOT EXISTS idx_unused_index;

-- Drop multiple indexes (PostgreSQL)
-- DROP INDEX CONCURRENTLY IF EXISTS idx_old_1, idx_old_2, idx_old_3;
