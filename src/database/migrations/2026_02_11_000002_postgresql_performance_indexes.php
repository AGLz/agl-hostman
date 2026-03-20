<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * PostgreSQL Performance Indexes
 *
 * Creates optimized indexes for AGL-23 performance target < 50ms p95.
 * Includes covering indexes, composite indexes, and partial indexes.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        // ============================================================================
        // ALERTS TABLE - Critical for monitoring
        // ============================================================================
        $this->createAlertsIndexes();

        // ============================================================================
        // DEPLOYMENTS TABLE - High query volume
        // ============================================================================
        $this->createDeploymentsIndexes();

        // ============================================================================
        // CONTAINER HEALTH LOGS - Time-series data
        // ============================================================================
        $this->createHealthLogsIndexes();

        // ============================================================================
        // USERS TABLE - Authentication queries
        // ============================================================================
        $this->createUsersIndexes();

        // ============================================================================
        // TASKS & STORIES TABLES - Linear integration
        // ============================================================================
        $this->createLinearIndexes();

        // ============================================================================
        // AUDIT LOGS TABLE - Compliance and security
        // ============================================================================
        $this->createAuditLogsIndexes();

        // ============================================================================
        // N8N WORKFLOWS TABLE - Automation tracking
        // ============================================================================
        $this->createN8NIndexes();

        // ============================================================================
        // PERFORMANCE TRENDS TABLE - Metrics storage
        // ============================================================================
        $this->createPerformanceTrendIndexes();

        // ============================================================================
        // COVERING INDEXES for common queries
        // ============================================================================
        $this->createCoveringIndexes();
    }

    /**
     * Create indexes for alerts table
     */
    protected function createAlertsIndexes(): void
    {
        Schema::table('alerts', function (Blueprint $table) {
            // Index for unresolved alerts dashboard (most common query)
            $table->index(['is_resolved', 'created_at'], 'alerts_unresolved_created_index');
            $table->index(['is_resolved', 'severity'], 'alerts_unresolved_severity_index');

            // Index for filtering by severity and date range
            $table->index(['severity', 'created_at'], 'alerts_severity_created_index');

            // Index for resource-specific alerts
            $table->index(['resource_type', 'resource_id', 'created_at'], 'alerts_resource_time_index');

            // Partial index for active critical alerts
            DB::statement("
                CREATE INDEX CONCURRENTLY alerts_active_critical
                ON alerts(severity, created_at DESC)
                WHERE is_resolved = false AND severity = 'critical'
            ");
        });
    }

    /**
     * Create indexes for deployments table
     */
    protected function createDeploymentsIndexes(): void
    {
        Schema::table('dokploy_deployments', function (Blueprint $table) {
            // Application deployment history (ordered by date)
            $table->index(['application_id', 'created_at'], 'deployments_app_created_index');

            // Status filtering with recent first
            $table->index(['status', 'created_at'], 'deployments_status_created_index');

            // Branch-specific deployment tracking
            $table->index(['application_id', 'branch', 'created_at'], 'deployments_app_branch_created_index');

            // Success/failure rate analysis
            $table->index(['application_id', 'status', 'completed_at'], 'deployments_app_status_completed_index');

            // Duration-based performance tracking
            $table->index('duration_seconds', 'deployments_duration_index');

            // Partial index for recent deployments (last 30 days)
            DB::statement("
                CREATE INDEX CONCURRENTLY deployments_recent
                ON dokploy_deployments(application_id, status, created_at DESC)
                WHERE created_at > NOW() - INTERVAL '30 days'
            ");
        });
    }

    /**
     * Create indexes for container health logs (time-series optimization)
     */
    protected function createHealthLogsIndexes(): void
    {
        Schema::table('container_health_logs', function (Blueprint $table) {
            // BRIN index for time-series data (PostgreSQL 9.4+)
            // Much more efficient for time-series than B-tree
            DB::statement('
                CREATE INDEX CONCURRENTLY container_health_logs_created_at_brin
                ON container_health_logs USING BRIN(created_at)
                WITH (pages_per_range = 128)
            ');

            // Composite index for latest health per container
            $table->index(['node_code', 'vmid', 'created_at DESC'], 'health_logs_node_vmid_time_index');

            // Index for unhealthy containers monitoring
            DB::statement("
                CREATE INDEX CONCURRENTLY health_logs_unhealthy
                ON container_health_logs(node_code, vmid, created_at DESC)
                WHERE health_status IN ('warning', 'critical')
            ");

            // Index for metric queries
            $table->index(['health_status', 'created_at'], 'health_logs_status_time_index');
        });
    }

    /**
     * Create indexes for users table
     */
    protected function createUsersIndexes(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Active user queries (authentication)
            $table->index(['is_active', 'email'], 'users_active_email_index');

            // Recent login tracking
            $table->index('last_login_at', 'users_last_login_index');

            // Role-based filtering
            $table->index(['is_active', 'created_at'], 'users_active_created_index');

            // Partial index for active users only
            DB::statement('
                CREATE INDEX CONCURRENTLY users_active_only
                ON users(id, email, last_login_at)
                WHERE is_active = true
            ');
        });
    }

    /**
     * Create indexes for Linear integration tables
     */
    protected function createLinearIndexes(): void
    {
        // Tasks table
        Schema::table('tasks', function (Blueprint $table) {
            $table->index(['status', 'priority', 'created_at'], 'tasks_status_priority_created_index');
            $table->index(['story_id', 'status'], 'tasks_story_status_index');
            $table->index(['assignee_id', 'status', 'updated_at'], 'tasks_assignee_status_updated_index');
            $table->index(['sprint_id', 'status'], 'tasks_sprint_status_index');

            // Partial index for open tasks
            DB::statement("
                CREATE INDEX CONCURRENTLY tasks_open
                ON tasks(sprint_id, status, priority DESC, created_at DESC)
                WHERE status NOT IN ('done', 'cancelled')
            ");
        });

        // Stories table
        Schema::table('stories', function (Blueprint $table) {
            $table->index(['project_id', 'status'], 'stories_project_status_index');
            $table->index(['project_id', 'created_at DESC'], 'stories_project_created_index');
            $table->index(['status', 'created_at DESC'], 'stories_status_created_index');
        });

        // Sprints table
        Schema::table('sprints', function (Blueprint $table) {
            $table->index(['project_id', 'status', 'start_date'], 'sprints_project_status_start_index');
            $table->index(['status', 'end_date'], 'sprints_status_end_index');

            // Partial index for active sprints
            DB::statement("
                CREATE INDEX CONCURRENTLY sprints_active
                ON sprints(project_id, status, start_date, end_date)
                WHERE status = 'active'
            ");
        });
    }

    /**
     * Create indexes for audit logs table
     */
    protected function createAuditLogsIndexes(): void
    {
        Schema::table('audit_logs', function (Blueprint $table) {
            // BRIN index for time-series audit data
            DB::statement('
                CREATE INDEX CONCURRENTLY audit_logs_created_at_brin
                ON audit_logs USING BRIN(created_at)
                WITH (pages_per_range = 128)
            ');

            // User activity tracking
            $table->index(['user_id', 'created_at'], 'audit_logs_user_created_index');

            // Action type filtering
            $table->index(['action', 'created_at'], 'audit_logs_action_created_index');

            // Resource-based audit queries
            $table->index(['resource_type', 'resource_id', 'created_at'], 'audit_logs_resource_time_index');

            // IP-based security queries
            $table->index(['ip_address', 'created_at'], 'audit_logs_ip_created_index');
        });
    }

    /**
     * Create indexes for N8N workflows
     */
    protected function createN8NIndexes(): void
    {
        Schema::table('n8n_workflows', function (Blueprint $table) {
            $table->index(['category', 'active', 'updated_at'], 'n8n_category_active_updated_index');
            $table->index(['active', 'last_executed_at'], 'n8n_active_executed_index');

            // Partial index for active workflows
            DB::statement('
                CREATE INDEX CONCURRENTLY n8n_active_workflows
                ON n8n_workflows(category, last_executed_at DESC, name)
                WHERE active = true
            ');
        });

        Schema::table('n8n_workflow_executions', function (Blueprint $table) {
            // BRIN for execution history
            DB::statement('
                CREATE INDEX CONCURRENTLY n8n_executions_created_at_brin
                ON n8n_workflow_executions USING BRIN(created_at)
                WITH (pages_per_range = 128)
            ');

            // Workflow execution status tracking
            $table->index(['workflow_id', 'status', 'created_at'], 'n8n_exec_workflow_status_created_index');
            $table->index(['status', 'created_at'], 'n8n_exec_status_created_index');

            // Failed executions monitoring
            DB::statement("
                CREATE INDEX CONCURRENTLY n8n_executions_failed
                ON n8n_workflow_executions(workflow_id, created_at DESC, error_message)
                WHERE status = 'failed'
            ");
        });
    }

    /**
     * Create indexes for performance trends table
     */
    protected function createPerformanceTrendIndexes(): void
    {
        Schema::table('performance_trends', function (Blueprint $table) {
            // BRIN index for time-series metrics
            DB::statement('
                CREATE INDEX CONCURRENTLY performance_trends_recorded_brin
                ON performance_trends USING BRIN(recorded_at)
                WITH (pages_per_range = 128)
            ');

            // Resource-specific metric queries (most common pattern)
            $table->index(['resource_type', 'resource_id', 'metric_type', 'recorded_at DESC'], 'perf_trends_resource_metric_time_index');

            // Time-range queries for specific metrics
            $table->index(['metric_type', 'recorded_at'], 'perf_trends_metric_time_index');

            // Partial index for recent metrics (last 7 days)
            DB::statement("
                CREATE INDEX CONCURRENTLY performance_trends_recent
                ON performance_trends(resource_type, resource_id, metric_type, recorded_at DESC)
                WHERE recorded_at > NOW() - INTERVAL '7 days'
            ");
        });
    }

    /**
     * Create covering indexes for common query patterns
     */
    protected function createCoveringIndexes(): void
    {
        // Containers dashboard query (covering index)
        DB::statement('
            CREATE INDEX CONCURRENTLY lxc_containers_dashboard_covering
            ON lxc_containers(proxmox_server_id, status, name, vmid, cores, memory_mb, disk_gb)
        ');

        // Deployment statistics query (covering index)
        DB::statement("
            CREATE INDEX CONCURRENTLY deployments_stats_covering
            ON dokploy_deployments(application_id, status, created_at DESC, duration_seconds)
            WHERE status IN ('success', 'failed')
        ");

        // User permissions check (covering index)
        DB::statement('
            CREATE INDEX CONCURRENTLY user_roles_permissions_covering
            ON model_has_roles(user_id, role_id)
            INCLUDE (model_type)
        ');

        // Recent activity UNION query optimization
        DB::statement("
            CREATE INDEX CONCURRENTLY containers_recent_activity
            ON lxc_containers(created_at DESC, status, name)
            WHERE created_at > NOW() - INTERVAL '7 days'
        ");
    }

    public function down(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        // Drop alerts indexes
        Schema::table('alerts', function (Blueprint $table) {
            $table->dropIndex('alerts_unresolved_created_index');
            $table->dropIndex('alerts_severity_created_index');
            $table->dropIndex('alerts_severity_created_index');
            $table->dropIndex('alerts_resource_time_index');
        });
        DB::statement('DROP INDEX IF EXISTS alerts_active_critical');

        // Drop deployments indexes
        Schema::table('dokploy_deployments', function (Blueprint $table) {
            $table->dropIndex('deployments_app_created_index');
            $table->dropIndex('deployments_status_created_index');
            $table->dropIndex('deployments_app_branch_created_index');
            $table->dropIndex('deployments_app_status_completed_index');
            $table->dropIndex('deployments_duration_index');
        });
        DB::statement('DROP INDEX IF EXISTS deployments_recent');

        // Drop health logs indexes
        Schema::table('container_health_logs', function (Blueprint $table) {
            $table->dropIndex('health_logs_status_time_index');
        });
        DB::statement('DROP INDEX IF EXISTS container_health_logs_created_at_brin');
        DB::statement('DROP INDEX IF EXISTS health_logs_node_vmid_time_index');
        DB::statement('DROP INDEX IF EXISTS health_logs_unhealthy');

        // Drop users indexes
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_active_email_index');
            $table->dropIndex('users_last_login_index');
            $table->dropIndex('users_active_created_index');
        });
        DB::statement('DROP INDEX IF EXISTS users_active_only');

        // Drop Linear indexes
        Schema::table('tasks', function (Blueprint $table) {
            $table->dropIndex('tasks_status_priority_created_index');
            $table->dropIndex('tasks_story_status_index');
            $table->dropIndex('tasks_assignee_status_updated_index');
            $table->dropIndex('tasks_sprint_status_index');
        });
        DB::statement('DROP INDEX IF EXISTS tasks_open');
        Schema::table('stories', function (Blueprint $table) {
            $table->dropIndex('stories_project_status_index');
            $table->dropIndex('stories_project_created_index');
            $table->dropIndex('stories_status_created_index');
        });
        Schema::table('sprints', function (Blueprint $table) {
            $table->dropIndex('sprints_project_status_start_index');
            $table->dropIndex('sprints_status_end_index');
        });
        DB::statement('DROP INDEX IF EXISTS sprints_active');

        // Drop audit logs indexes
        Schema::table('audit_logs', function (Blueprint $table) {
            $table->dropIndex('audit_logs_user_created_index');
            $table->dropIndex('audit_logs_action_created_index');
            $table->dropIndex('audit_logs_resource_time_index');
            $table->dropIndex('audit_logs_ip_created_index');
        });
        DB::statement('DROP INDEX IF EXISTS audit_logs_created_at_brin');

        // Drop N8N indexes
        Schema::table('n8n_workflows', function (Blueprint $table) {
            $table->dropIndex('n8n_category_active_updated_index');
            $table->dropIndex('n8n_active_executed_index');
        });
        DB::statement('DROP INDEX IF EXISTS n8n_active_workflows');
        Schema::table('n8n_workflow_executions', function (Blueprint $table) {
            $table->dropIndex('n8n_exec_workflow_status_created_index');
            $table->dropIndex('n8n_exec_status_created_index');
        });
        DB::statement('DROP INDEX IF EXISTS n8n_executions_created_at_brin');
        DB::statement('DROP INDEX IF EXISTS n8n_executions_failed');

        // Drop performance trends indexes
        Schema::table('performance_trends', function (Blueprint $table) {
            $table->dropIndex('perf_trends_resource_metric_time_index');
            $table->dropIndex('perf_trends_metric_time_index');
        });
        DB::statement('DROP INDEX IF EXISTS performance_trends_recorded_brin');
        DB::statement('DROP INDEX IF EXISTS performance_trends_recent');

        // Drop covering indexes
        DB::statement('DROP INDEX IF EXISTS lxc_containers_dashboard_covering');
        DB::statement('DROP INDEX IF EXISTS deployments_stats_covering');
        DB::statement('DROP INDEX IF EXISTS user_roles_permissions_covering');
        DB::statement('DROP INDEX IF EXISTS containers_recent_activity');
    }
};
