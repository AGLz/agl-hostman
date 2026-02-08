-- ============================================================================
-- Performance Trend Analysis Queries
-- ============================================================================
-- These queries analyze performance trends for capacity planning and
-- predictive maintenance.
--
-- PostgreSQL and MySQL compatible (with minor adjustments)
-- ============================================================================

-- ============================================================================
-- 1. CPU Growth Rate Analysis
-- Calculate weekly CPU usage growth to predict when thresholds will be reached
-- ============================================================================
WITH weekly_cpu AS (
    SELECT
        resource_id,
        DATE_TRUNC('week', recorded_at) as week,
        AVG(value) as avg_cpu,
        MIN(value) as min_cpu,
        MAX(value) as max_cpu
    FROM performance_trends
    WHERE resource_type = 'server'
      AND metric_type = 'cpu'
      AND recorded_at >= NOW() - INTERVAL '8 weeks'
    GROUP BY resource_id, DATE_TRUNC('week', recorded_at)
),
cpu_growth AS (
    SELECT
        resource_id,
        (MAX(avg_cpu) - MIN(avg_cpu)) / MIN(avg_cpu) * 100 as growth_rate_pct,
        MAX(avg_cpu) as current_avg
    FROM weekly_cpu
    GROUP BY resource_id
)
SELECT
    resource_id,
    current_avg,
    growth_rate_pct,
    CASE
        WHEN current_avg > 85 THEN 'CRITICAL - Immediate action needed'
        WHEN current_avg > 70 THEN 'WARNING - Monitor closely'
        WHEN growth_rate_pct > 20 THEN 'WARNING - Rapid growth detected'
        ELSE 'OK'
    END as status,
    -- Predict weeks until 85% threshold
    CASE
        WHEN growth_rate_pct > 0 THEN
            CEIL((85 - current_avg) / (current_avg * growth_rate_pct / 100))
        ELSE NULL
    END as weeks_until_critical
FROM cpu_growth
WHERE current_avg > 50  -- Only showing resources with significant usage
ORDER BY current_avg DESC;

-- ============================================================================
-- 2. Disk Capacity Forecasting
-- Predict when storage will be full based on historical growth
-- ============================================================================
WITH disk_history AS (
    SELECT
        resource_id,
        recorded_at,
        value as disk_usage_pct,
        LAG(value) OVER (PARTITION BY resource_id ORDER BY recorded_at) as prev_usage
    FROM performance_trends
    WHERE resource_type = 'storage'
      AND metric_type = 'disk'
      AND recorded_at >= NOW() - INTERVAL '30 days'
),
growth_rate AS (
    SELECT
        resource_id,
        AVG(disk_usage_pct - prev_usage) as daily_growth_pct
    FROM disk_history
    WHERE prev_usage IS NOT NULL
    GROUP BY resource_id
)
SELECT
    dh.resource_id,
    MAX(dh.disk_usage_pct) as current_usage,
    gr.daily_growth_pct,
    CASE
        WHEN gr.daily_growth_pct > 0 THEN
            DATE_ADD(MAX(dh.recorded_at),
                INTERVAL CEIL((90 - MAX(dh.disk_usage_pct)) / gr.daily_growth_pct) DAY)
        ELSE NULL
    END as estimated_full_date
FROM disk_history dh
LEFT JOIN growth_rate gr ON dh.resource_id = gr.resource_id
GROUP BY dh.resource_id, gr.daily_growth_pct
HAVING MAX(dh.disk_usage_pct) > 70  -- Only show above 70%
ORDER BY current_usage DESC;

-- ============================================================================
-- 3. Memory Pressure Detection
-- Identify containers with sustained high memory usage
-- ============================================================================
SELECT
    resource_id,
    AVG(value) as avg_memory_pct,
    MAX(value) as peak_memory_pct,
    COUNT(*) as data_points,
    SUM(CASE WHEN value > 80 THEN 1 ELSE 0 END) as critical_count,
    SUM(CASE WHEN value > 75 THEN 1 ELSE 0 END) as warning_count
FROM performance_trends
WHERE resource_type = 'container'
  AND metric_type = 'memory'
  AND recorded_at >= NOW() - INTERVAL '24 hours'
GROUP BY resource_id
HAVING AVG(value) > 60  -- Only showing concerning usage
ORDER BY avg_memory_pct DESC;

-- ============================================================================
-- 4. Performance Baseline Comparison
-- Compare current metrics against historical baseline
-- ============================================================================
WITH baseline AS (
    SELECT
        resource_id,
        metric_type,
        AVG(value) as baseline_avg,
        STDDEV(value) as baseline_stddev,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value) as p95
    FROM performance_trends
    WHERE recorded_at >= NOW() - INTERVAL '30 days'
      AND recorded_at < NOW() - INTERVAL '7 days'  -- Historical baseline
    GROUP BY resource_id, metric_type
),
current AS (
    SELECT
        resource_id,
        metric_type,
        AVG(value) as current_avg,
        MAX(value) as current_max
    FROM performance_trends
    WHERE recorded_at >= NOW() - INTERVAL '24 hours'
    GROUP BY resource_id, metric_type
)
SELECT
    c.resource_id,
    c.metric_type,
    b.baseline_avg,
    c.current_avg,
    ((c.current_avg - b.baseline_avg) / b.baseline_avg * 100) as change_pct,
    b.p95,
    CASE
        WHEN c.current_avg > b.p95 THEN 'ABOVE P95 - Investigate'
        WHEN ABS((c.current_avg - b.baseline_avg) / b.baseline_avg) > 0.3 THEN '30%+ deviation'
        ELSE 'Normal'
    END as status
FROM current c
JOIN baseline b ON c.resource_id = b.resource_id AND c.metric_type = b.metric_type
ORDER BY change_pct DESC;

-- ============================================================================
-- 5. Peak Usage Detection
-- Find time patterns in resource usage
-- ============================================================================
SELECT
    resource_id,
    EXTRACT(HOUR FROM recorded_at) as hour_of_day,
    EXTRACT(DOW FROM recorded_at) as day_of_week,
    AVG(value) as avg_value,
    MAX(value) as max_value
FROM performance_trends
WHERE resource_type = 'server'
  AND metric_type = 'cpu'
  AND recorded_at >= NOW() - INTERVAL '4 weeks'
GROUP BY resource_id, EXTRACT(HOUR FROM recorded_at), EXTRACT(DOW FROM recorded_at)
ORDER BY resource_id, avg_value DESC
LIMIT 50;

-- ============================================================================
-- 6. Resource Health Score
-- Calculate composite health score for each resource
-- ============================================================================
SELECT
    resource_id,
    resource_type,
    -- CPU health (lower is better)
    AVG(CASE WHEN metric_type = 'cpu' THEN value END) as cpu_avg,
    -- Memory health
    AVG(CASE WHEN metric_type = 'memory' THEN value END) as memory_avg,
    -- Disk health
    AVG(CASE WHEN metric_type = 'disk' THEN value END) as disk_avg,
    -- Composite score (0-100, 100 = perfect)
    100 - (
        AVG(CASE WHEN metric_type = 'cpu' THEN value END) * 0.4 +
        AVG(CASE WHEN metric_type = 'memory' THEN value END) * 0.4 +
        AVG(CASE WHEN metric_type = 'disk' THEN value END) * 0.2
    ) as health_score
FROM performance_trends
WHERE recorded_at >= NOW() - INTERVAL '1 hour'
GROUP BY resource_id, resource_type
HAVING AVG(CASE WHEN metric_type = 'cpu' THEN value END) IS NOT NULL
ORDER BY health_score ASC;

-- ============================================================================
-- 7. Anomaly Detection
-- Find metrics that deviate significantly from expected values
-- ============================================================================
WITH metrics_with_avg AS (
    SELECT
        resource_id,
        metric_type,
        value,
        AVG(value) OVER (
            PARTITION BY resource_id, metric_type
            ORDER BY recorded_at
            ROWS BETWEEN 100 PRECEDING AND 1 PRECEDING
        ) as rolling_avg,
        STDDEV(value) OVER (
            PARTITION BY resource_id, metric_type
            ORDER BY recorded_at
            ROWS BETWEEN 100 PRECEDING AND 1 PRECEDING
        ) as rolling_stddev
    FROM performance_trends
    WHERE recorded_at >= NOW() - INTERVAL '7 days'
)
SELECT
    resource_id,
    metric_type,
    value,
    rolling_avg,
    rolling_stddev,
    -- Z-score: how many standard deviations from mean
    (value - rolling_avg) / NULLIF(rolling_stddev, 0) as z_score
FROM metrics_with_avg
WHERE rolling_stddev IS NOT NULL
  AND ABS((value - rolling_avg) / rolling_stddev) > 3  -- 3-sigma anomaly
ORDER BY ABS(z_score) DESC;
