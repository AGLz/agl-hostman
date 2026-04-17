import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    Settings as SettingsIcon,
    Clock,
    RefreshCw,
    Shield,
    Brain,
    Server,
    Activity,
    CheckCircle,
    AlertCircle,
    XCircle,
    Zap,
    Key,
    Database,
    Globe,
    Plus,
} from 'lucide-react';

import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';


const INTEGRATIONS = [
    { name: 'LiteLLM Gateway', icon: Zap, status: 'healthy', url: 'http://127.0.0.1:4000', lastCheck: '30s ago' },
    { name: 'OpenClaw Gateway', icon: Brain, status: 'healthy', url: 'http://127.0.0.1:3001', lastCheck: '1m ago' },
    { name: 'n8n Workflow', icon: RefreshCw, status: 'healthy', url: 'http://192.168.0.202:5678', lastCheck: '2m ago' },
    { name: 'Proxmox API', icon: Server, status: 'healthy', url: 'https://192.168.0.245:8006', lastCheck: '5m ago' },
    { name: 'DashScope (Qwen)', icon: Globe, status: 'healthy', url: 'https://dashscope-intl.aliyuncs.com', lastCheck: '10m ago' },
    { name: 'Tailscale', icon: Shield, status: 'healthy', url: 'https://login.tailscale.com', lastCheck: '15m ago' },
    { name: 'Cloudflare Tunnel', icon: Globe, status: 'healthy', url: 'https://dash.cloudflare.com', lastCheck: '20m ago' },
    { name: 'Redis Cache', icon: Database, status: 'healthy', url: '192.168.0.137:6379', lastCheck: '1m ago' },
    { name: 'PostgreSQL', icon: Database, status: 'healthy', url: '192.168.0.149:5432', lastCheck: '1m ago' },
];

const CRON_JOBS = [
    { name: 'websites-monitor', interval: '15m', status: 'failed', lastRun: '5m ago', description: 'Monitor website availability' },
    { name: 'critical-services-monitor', interval: '5m', status: 'failed', lastRun: '2m ago', description: 'Monitor critical services health' },
    { name: 'storage-health-check', interval: '60m', status: 'failed', lastRun: '15m ago', description: 'Check storage health across hosts' },
    { name: 'host-health-check', interval: '30m', status: 'failed', lastRun: '10m ago', description: 'Ping infrastructure hosts' },
    { name: 'ai-stack-health', interval: '60m', status: 'lost', lastRun: '1h ago', description: 'Monitor AI/ML services' },
    { name: 'morning-briefing', interval: '480m', status: 'failed', lastRun: '2h ago', description: 'Daily morning briefing' },
    { name: 'daily-maintenance', interval: '1440m', status: 'failed', lastRun: '1d ago', description: 'Daily maintenance tasks' },
    { name: 'daily-backup', interval: '1440m', status: 'succeeded', lastRun: '1d ago', description: 'Daily backup of configs' },
];

function IntegrationCard({ integration }) {
    const statusConfig = {
        healthy: { color: 'text-green-400', dot: 'bg-green-500', label: 'Healthy' },
        warning: { color: 'text-yellow-400', dot: 'bg-yellow-500', label: 'Warning' },
        error: { color: 'text-red-400', dot: 'bg-red-500', label: 'Error' },
    };
    const status = statusConfig[integration.status];

    return (
        <div className="flex items-center justify-between p-3 rounded-lg bg-white/[0.03] border border-white/5">
            <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center">
                    <integration.icon className="w-4 h-4 text-white/60" />
                </div>
                <div>
                    <p className="text-sm font-medium text-white/80">{integration.name}</p>
                    <p className="text-[10px] text-white/30">{integration.url}</p>
                </div>
            </div>
            <div className="text-right">
                <div className="flex items-center gap-1.5">
                    <span className={cn("w-2 h-2 rounded-full", status.dot)} />
                    <span className={cn("text-xs", status.color)}>{status.label}</span>
                </div>
                <p className="text-[10px] text-white/20 mt-0.5">{integration.lastCheck}</p>
            </div>
        </div>
    );
}

function CronJobRow({ job }) {
    const statusConfig = {
        succeeded: { icon: CheckCircle, color: 'text-green-400', bg: 'bg-green-500/10' },
        failed: { icon: XCircle, color: 'text-red-400', bg: 'bg-red-500/10' },
        lost: { icon: AlertCircle, color: 'text-yellow-400', bg: 'bg-yellow-500/10' },
        running: { icon: RefreshCw, color: 'text-blue-400', bg: 'bg-blue-500/10' },
    };
    const status = statusConfig[job.status] || statusConfig.lost;

    return (
        <div className="flex items-center justify-between p-3 rounded-lg bg-white/[0.03] border border-white/5 hover:bg-white/[0.05] transition-colors">
            <div className="flex items-center gap-3">
                <div className={cn("w-8 h-8 rounded-lg flex items-center justify-center", status.bg)}>
                    <status.icon className={cn("w-4 h-4", status.color)} />
                </div>
                <div>
                    <p className="text-sm font-medium text-white/80">{job.name}</p>
                    <p className="text-[10px] text-white/30">{job.description}</p>
                </div>
            </div>
            <div className="text-right flex items-center gap-4">
                <div className="text-xs text-white/40">
                    <Clock className="w-3 h-3 inline mr-1" />
                    {job.interval}
                </div>
                <div className="text-[10px] text-white/30">{job.lastRun}</div>
                <Badge variant="secondary" className={cn("text-[10px] border-none", status.bg, status.color)}>
                    {job.status}
                </Badge>
            </div>
        </div>
    );
}

export default function MissionControlSettings() {
    const [integrations, setIntegrations] = useState(INTEGRATIONS);
    const [cronJobs, setCronJobs] = useState(CRON_JOBS);

    const healthyCount = integrations.filter(i => i.status === 'healthy').length;
    const cronStatusCounts = {
        succeeded: cronJobs.filter(j => j.status === 'succeeded').length,
        failed: cronJobs.filter(j => j.status === 'failed').length,
        lost: cronJobs.filter(j => j.status === 'lost').length,
    };

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div>
                    <h1 className="text-2xl font-bold text-white">Settings</h1>
                    <p className="text-sm text-white/40 mt-1">Cron jobs, integrations, and agent configuration</p>
                </div>

                {/* Integration Status */}
                <Card className="bg-white/[0.02] border-white/5">
                    <CardHeader className="pb-3">
                        <div className="flex items-center justify-between">
                            <div>
                                <CardTitle className="text-sm text-white/80 flex items-center gap-2">
                                    <Activity className="w-4 h-4 text-blue-400" />
                                    Integration Status
                                </CardTitle>
                                <CardDescription className="text-white/40">
                                    {healthyCount}/{integrations.length} services healthy
                                </CardDescription>
                            </div>
                            <Button variant="outline" size="sm" className="bg-white/5 border-white/10 text-white/60">
                                <RefreshCw className="w-3.5 h-3.5 mr-1.5" />
                                Refresh All
                            </Button>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-2">
                            {integrations.map(integration => (
                                <IntegrationCard key={integration.name} integration={integration} />
                            ))}
                        </div>
                    </CardContent>
                </Card>

                {/* Cron Job Manager */}
                <Card className="bg-white/[0.02] border-white/5">
                    <CardHeader className="pb-3">
                        <div className="flex items-center justify-between">
                            <div>
                                <CardTitle className="text-sm text-white/80 flex items-center gap-2">
                                    <Clock className="w-4 h-4 text-green-400" />
                                    Cron Job Manager
                                </CardTitle>
                                <CardDescription className="text-white/40">
                                    {cronStatusCounts.succeeded} succeeded, {cronStatusCounts.failed} failed, {cronStatusCounts.lost} lost
                                </CardDescription>
                            </div>
                            <Button variant="outline" size="sm" className="bg-white/5 border-white/10 text-white/60">
                                <Plus className="w-3.5 h-3.5 mr-1.5" />
                                New Job
                            </Button>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-2">
                            {cronJobs.map(job => (
                                <CronJobRow key={job.name} job={job} />
                            ))}
                        </div>
                    </CardContent>
                </Card>

                {/* Agent Configuration */}
                <Card className="bg-white/[0.02] border-white/5">
                    <CardHeader className="pb-3">
                        <CardTitle className="text-sm text-white/80 flex items-center gap-2">
                            <Brain className="w-4 h-4 text-purple-400" />
                            Agent Configuration
                        </CardTitle>
                        <CardDescription className="text-white/40">
                            OpenClaw agent settings and model routing
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-4">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div className="p-4 rounded-lg bg-white/[0.03] border border-white/5">
                                    <p className="text-xs text-white/40 mb-1">Default Model</p>
                                    <p className="text-sm font-medium text-white/80">qwen3.5-flash</p>
                                    <p className="text-[10px] text-white/30 mt-1">DashScope Singapore - 1M context</p>
                                </div>
                                <div className="p-4 rounded-lg bg-white/[0.03] border border-white/5">
                                    <p className="text-xs text-white/40 mb-1">Coding Model</p>
                                    <p className="text-sm font-medium text-white/80">qwen-coder</p>
                                    <p className="text-[10px] text-white/30 mt-1">DashScope - 1M context</p>
                                </div>
                                <div className="p-4 rounded-lg bg-white/[0.03] border border-white/5">
                                    <p className="text-xs text-white/40 mb-1">Reasoning Model</p>
                                    <p className="text-sm font-medium text-white/80">qwq-plus</p>
                                    <p className="text-[10px] text-white/30 mt-1">DashScope - 131K context</p>
                                </div>
                                <div className="p-4 rounded-lg bg-white/[0.03] border border-white/5">
                                    <p className="text-xs text-white/40 mb-1">Fallback Model</p>
                                    <p className="text-sm font-medium text-white/80">or-glm-air-free</p>
                                    <p className="text-[10px] text-white/30 mt-1">OpenRouter free tier</p>
                                </div>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>
        
    );
}
