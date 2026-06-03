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
import {
    fetchHermesScheduledTasks,
    fetchHermesStatus,
    fetchHermesUiLinks,
    formatCheckedAt,
} from '@/lib/hermes';

const STATIC_INTEGRATIONS = [
    { name: 'LiteLLM Gateway', icon: Zap, status: 'healthy', url: 'http://100.125.249.8:4000', lastCheck: '—' },
    { name: 'n8n Workflow', icon: RefreshCw, status: 'healthy', url: 'http://192.168.0.202:5678', lastCheck: '—' },
    { name: 'Proxmox API', icon: Server, status: 'healthy', url: 'https://192.168.0.245:8006', lastCheck: '—' },
    { name: 'Tailscale', icon: Shield, status: 'healthy', url: 'https://login.tailscale.com', lastCheck: '—' },
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
    const [integrations, setIntegrations] = useState(STATIC_INTEGRATIONS);
    const [cronJobs, setCronJobs] = useState([]);
    const [loading, setLoading] = useState(true);
    const [checkedAt, setCheckedAt] = useState(null);

    const loadData = async () => {
        setLoading(true);
        try {
            const [status, links, scheduled] = await Promise.all([
                fetchHermesStatus(),
                fetchHermesUiLinks(),
                fetchHermesScheduledTasks(),
            ]);

            const hermesHealthy = status.status === 'online';
            const minionsHealthy = !status.minions_health?.error;

            const hermesIntegrations = [
                {
                    name: 'Hermes API (CT188)',
                    icon: Brain,
                    status: hermesHealthy ? 'healthy' : 'error',
                    url: status.base_url || links.api_url,
                    lastCheck: formatCheckedAt(status.checked_at),
                },
                {
                    name: 'Minions Kanban',
                    icon: Activity,
                    status: minionsHealthy ? 'healthy' : 'warning',
                    url: links.minions_url,
                    lastCheck: formatCheckedAt(status.checked_at),
                },
                {
                    name: 'Claw3D Studio',
                    icon: Globe,
                    status: links.studio_url ? 'healthy' : 'warning',
                    url: links.studio_url || '—',
                    lastCheck: formatCheckedAt(status.checked_at),
                },
                {
                    name: 'Hermes Dashboard',
                    icon: Server,
                    status: links.dashboard_url ? 'healthy' : 'warning',
                    url: links.dashboard_url || '—',
                    lastCheck: formatCheckedAt(status.checked_at),
                },
            ];

            setIntegrations([...hermesIntegrations, ...STATIC_INTEGRATIONS]);
            setCheckedAt(status.checked_at);

            const tasks = scheduled.tasks || scheduled.scheduledTasks || [];
            setCronJobs(
                tasks.map((task) => ({
                    name: task.name || task.id || 'scheduled-task',
                    interval: task.schedule || task.interval || task.cron || '—',
                    status: task.enabled === false ? 'lost' : (task.lastStatus || task.status || 'running'),
                    lastRun: task.lastRun || task.last_run || '—',
                    description: task.description || task.prompt?.slice(0, 80) || 'Hermes scheduled task',
                }))
            );
        } catch (error) {
            console.error('Failed to load Hermes settings', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        loadData();
    }, []);

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
                    <p className="text-sm text-white/40 mt-1">Integrações Hermes CT188, cron Minions e configuração de agentes</p>
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
                                    {healthyCount}/{integrations.length} serviços healthy
                                    {checkedAt ? ` · ${formatCheckedAt(checkedAt)}` : ''}
                                </CardDescription>
                            </div>
                            <Button
                                variant="outline"
                                size="sm"
                                className="bg-white/5 border-white/10 text-white/60"
                                onClick={loadData}
                                disabled={loading}
                            >
                                <RefreshCw className={cn('w-3.5 h-3.5 mr-1.5', loading && 'animate-spin')} />
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
                                    Cron Minions (Hermes)
                                </CardTitle>
                                <CardDescription className="text-white/40">
                                    {cronJobs.length === 0
                                        ? 'Nenhuma tarefa agendada ou Minions indisponível'
                                        : `${cronStatusCounts.succeeded} ok, ${cronStatusCounts.failed} falhou, ${cronStatusCounts.lost} inactivas`}
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
                            {cronJobs.length === 0 ? (
                                <p className="text-sm text-white/30 py-4 text-center">Sem cron jobs do Minions</p>
                            ) : (
                                cronJobs.map((job) => <CronJobRow key={job.name} job={job} />)
                            )}
                        </div>
                    </CardContent>
                </Card>

                {/* Agent Configuration */}
                <Card className="bg-white/[0.02] border-white/5">
                    <CardHeader className="pb-3">
                        <CardTitle className="text-sm text-white/80 flex items-center gap-2">
                            <Brain className="w-4 h-4 text-purple-400" />
                            Agent Configuration (Hermes Quartet)
                        </CardTitle>
                        <CardDescription className="text-white/40">
                            CT188 Jarvis · Elon · Satya · Werner via API :8642
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="space-y-4">
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div className="p-4 rounded-lg bg-white/[0.03] border border-white/5">
                                    <p className="text-xs text-white/40 mb-1">Default Model</p>
                                    <p className="text-sm font-medium text-white/80">hermes-agent</p>
                                    <p className="text-[10px] text-white/30 mt-1">CT188 API — quartet personas</p>
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
                                    <p className="text-sm font-medium text-white/80">r1 / qwen3.5-flash</p>
                                    <p className="text-[10px] text-white/30 mt-1">Validated CT186 fallbacks</p>
                                </div>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>
        
    );
}
