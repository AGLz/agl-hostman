<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Users table indexes
        Schema::table('users', function (Blueprint $table) {
            // Email is already indexed by Laravel
            // Add composite indexes for common queries
            $table->index(['is_active', 'created_at'], 'users_active_created_index');
            $table->index(['last_login_at'], 'users_last_login_index');
            $table->index('workos_id', 'users_workos_id_index');
        });

        // LXC Containers indexes
        Schema::table('lxc_containers', function (Blueprint $table) {
            $table->index(['proxmox_server_id', 'status'], 'containers_server_status_index');
            $table->index(['status', 'created_at'], 'containers_status_created_index');
            $table->index('vmid', 'containers_vmid_index');
            $table->index('hostname', 'containers_hostname_index');
            $table->index(['is_template', 'auto_start'], 'containers_template_autostart_index');
        });

        // Proxmox Servers indexes
        Schema::table('proxmox_servers', function (Blueprint $table) {
            $table->index(['status', 'created_at'], 'proxmox_status_created_index');
            $table->index(['location_id', 'status'], 'proxmox_location_status_index');
        });

        // Dokploy Applications indexes
        Schema::table('dokploy_applications', function (Blueprint $table) {
            $table->index(['user_id', 'created_at'], 'dokploy_apps_user_created_index');
            $table->index(['type', 'status'], 'dokploy_apps_type_status_index');
            $table->index(['project_id', 'created_at'], 'dokploy_apps_project_created_index');
        });

        // Dokploy Deployments indexes
        Schema::table('dokploy_deployments', function (Blueprint $table) {
            $table->index(['application_id', 'status'], 'deployments_app_status_index');
            $table->index(['application_id', 'created_at'], 'deployments_app_created_index');
            $table->index(['status', 'created_at'], 'deployments_status_created_index');
            $table->index(['triggered_by', 'created_at'], 'deployments_user_created_index');
            $table->index(['branch', 'created_at'], 'deployments_branch_created_index');
        });

        // Container Health Logs indexes
        Schema::table('container_health_logs', function (Blueprint $table) {
            $table->index(['lxc_container_id', 'created_at'], 'health_logs_container_created_index');
            $table->index(['lxc_container_id', 'is_healthy', 'created_at'], 'health_logs_container_health_created_index');
            $table->index(['created_at'], 'health_logs_created_index');
        });

        // Performance Trends indexes
        Schema::table('performance_trends', function (Blueprint $table) {
            $table->index(['resource_type', 'resource_id', 'recorded_at'], 'perf_trends_resource_recorded_index');
            $table->index(['recorded_at'], 'perf_trends_recorded_index');
            $table->index(['metric_type', 'recorded_at'], 'perf_trends_metric_recorded_index');
        });

        // Audit Logs indexes
        Schema::table('audit_logs', function (Blueprint $table) {
            $table->index(['user_id', 'created_at'], 'audit_logs_user_created_index');
            $table->index(['action', 'created_at'], 'audit_logs_action_created_index');
            $table->index(['resource_type', 'resource_id'], 'audit_logs_resource_index');
            $table->index(['ip_address', 'created_at'], 'audit_logs_ip_created_index');
        });

        // Alerts indexes
        Schema::table('alerts', function (Blueprint $table) {
            $table->index(['severity', 'is_resolved', 'created_at'], 'alerts_severity_resolved_created_index');
            $table->index(['resource_type', 'resource_id', 'created_at'], 'alerts_resource_created_index');
            $table->index(['is_resolved', 'created_at'], 'alerts_resolved_created_index');
        });

        // API Keys indexes
        Schema::table('api_keys', function (Blueprint $table) {
            $table->index(['user_id', 'last_used_at'], 'api_keys_user_lastused_index');
            $table->index(['is_active', 'expires_at'], 'api_keys_active_expires_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Users table
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('users_active_created_index');
            $table->dropIndex('users_last_login_index');
            $table->dropIndex('users_workos_id_index');
        });

        // LXC Containers
        Schema::table('lxc_containers', function (Blueprint $table) {
            $table->dropIndex('containers_server_status_index');
            $table->dropIndex('containers_status_created_index');
            $table->dropIndex('containers_vmid_index');
            $table->dropIndex('containers_hostname_index');
            $table->dropIndex('containers_template_autostart_index');
        });

        // Proxmox Servers
        Schema::table('proxmox_servers', function (Blueprint $table) {
            $table->dropIndex('proxmox_status_created_index');
            $table->dropIndex('proxmox_location_status_index');
        });

        // Dokploy Applications
        Schema::table('dokploy_applications', function (Blueprint $table) {
            $table->dropIndex('dokploy_apps_user_created_index');
            $table->dropIndex('dokploy_apps_type_status_index');
            $table->dropIndex('dokploy_apps_project_created_index');
        });

        // Dokploy Deployments
        Schema::table('dokploy_deployments', function (Blueprint $table) {
            $table->dropIndex('deployments_app_status_index');
            $table->dropIndex('deployments_app_created_index');
            $table->dropIndex('deployments_status_created_index');
            $table->dropIndex('deployments_user_created_index');
            $table->dropIndex('deployments_branch_created_index');
        });

        // Container Health Logs
        Schema::table('container_health_logs', function (Blueprint $table) {
            $table->dropIndex('health_logs_container_created_index');
            $table->dropIndex('health_logs_container_health_created_index');
            $table->dropIndex('health_logs_created_index');
        });

        // Performance Trends
        Schema::table('performance_trends', function (Blueprint $table) {
            $table->dropIndex('perf_trends_resource_recorded_index');
            $table->dropIndex('perf_trends_recorded_index');
            $table->dropIndex('perf_trends_metric_recorded_index');
        });

        // Audit Logs
        Schema::table('audit_logs', function (Blueprint $table) {
            $table->dropIndex('audit_logs_user_created_index');
            $table->dropIndex('audit_logs_action_created_index');
            $table->dropIndex('audit_logs_resource_index');
            $table->dropIndex('audit_logs_ip_created_index');
        });

        // Alerts
        Schema::table('alerts', function (Blueprint $table) {
            $table->dropIndex('alerts_severity_resolved_created_index');
            $table->dropIndex('alerts_resource_created_index');
            $table->dropIndex('alerts_resolved_created_index');
        });

        // API Keys
        Schema::table('api_keys', function (Blueprint $table) {
            $table->dropIndex('api_keys_user_lastused_index');
            $table->dropIndex('api_keys_active_expires_index');
        });
    }
};
