import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    Activity,
    Users,
    Clock,
    Zap,
    TrendingUp,
    AlertCircle,
    CheckCircle,
    XCircle,
    Loader2,
    RefreshCw,
    Terminal,
    Server,
    Shield,
    Brain
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { fetchMissionControlSnapshot, formatAgentLastActive, formatCheckedAt, POLL_INTERVAL_MS } from '@/lib/hermes';


const container = {
    hidden: { opacity: 0 },
    show: { opacity: 1, transition: { staggerChildren: 0.08 } }
};

const item = {
    hidden: { opacity: 0, y: 12 },
    show: { opacity: 1, y: 0 }
};

function MetricCard({ title, value, icon: Icon, trend, color, subtitle }) {
    return (
        <motion.div variants={item}>
            <Card className="bg-white/[0.03] border-white/5 hover:bg-white/[0.05] transition-all duration-300 hover:-translate-y-0.5">
                <CardContent className="p-5">
                    <div className="flex items-center justify-between mb-3">
                        <div className={cn("p-2 rounded-lg", color)}>
                            <Icon className="w-4 h-4 text-white" />
                        </div>
                        {trend && (
                            <Badge variant="secondary" className={cn(
                                "text-[10px] border-none",
                                trend.startsWith('+') ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                            )}>
                                {trend}
                            </Badge>
                        )}
                    </div>
                    <p className="text-2xl font-bold text-white">{value}</p>
                    <p className="text-xs text-white/50 mt-1">{title}</p>
                    {subtitle && <p className="text-[10px] text-white/30 mt-0.5">{subtitle}</p>}
                </CardContent>
            </Card>
        </motion.div>
    );
}

function AgentStatusDot({ status }) {
    const colors = {
        active: 'bg-green-500 shadow-green-500/50',
        pending: 'bg-yellow-500 shadow-yellow-500/50',
        error: 'bg-red-500 shadow-red-500/50',
        idle: 'bg-gray-500 shadow-gray-500/50',
    };
    return (
        <span className={cn("w-2 h-2 rounded-full shadow-sm", colors[status] || colors.idle)} />
    );
}

function ActivityFeed({ activities }) {
    if (!activities || activities.length === 0) {
        return (
            <div className="flex flex-col items-center justify-center py-12 text-white/30">
                <Activity className="w-8 h-8 mb-2" />
                <p className="text-sm">No recent activity</p>
            </div>
        );
    }

    return (
        <div className="space-y-3 max-h-[400px] overflow-y-auto pr-2 scrollbar-thin">
            {activities.map((activity, i) => (
                <motion.div
                    key={i}
                    initial={{ opacity: 0, x: -10 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: i * 0.03 }}
                    className="flex items-start gap-3 p-3 rounded-lg bg-white/[0.02] hover:bg-white/[0.04] transition-colors"
                >
                    <AgentStatusDot status={activity.status} />
                    <div className="flex-1 min-w-0">
                        <p className="text-sm text-white/80 truncate">{activity.action}</p>
                        <div className="flex items-center gap-2 mt-1">
                            <span className="text-[10px] text-white/40">{activity.agent}</span>
                            <span className="text-[10px] text-white/20">•</span>
                            <span className="text-[10px] text-white/30">{activity.time}</span>
                        </div>
                    </div>
                </motion.div>
            ))}
        </div>
    );
}

function AgentStatusBar({ agents }) {
    const statusGroups = {
        active: agents?.filter(a => a.status === 'active') || [],
        idle: agents?.filter(a => ['idle', 'standby'].includes(a.status)) || [],
        error: agents?.filter(a => a.status === 'error') || [],
    };

    return (
        <div className="space-y-3">
            {statusGroups.active.length > 0 && (
                <div>
                    <p className="text-[10px] text-green-400/60 uppercase tracking-wider mb-2 font-medium">
                        Active ({statusGroups.active.length})
                    </p>
                    <div className="space-y-1.5">
                        {statusGroups.active.slice(0, 5).map(agent => (
                            <div key={agent.id} className="flex items-center gap-2 text-xs">
                                <span className="w-1.5 h-1.5 rounded-full bg-green-500" />
                                <span className="text-white/70 truncate">{agent.name}</span>
                                <span className="text-white/30 ml-auto text-[10px]">{agent.currentTask || 'Idle'}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {statusGroups.idle.length > 0 && (
                <div>
                    <p className="text-[10px] text-yellow-400/60 uppercase tracking-wider mb-2 font-medium">
                        Idle ({statusGroups.idle.length})
                    </p>
                    <div className="space-y-1.5">
                        {statusGroups.idle.slice(0, 3).map(agent => (
                            <div key={agent.id} className="flex items-center gap-2 text-xs">
                                <span className="w-1.5 h-1.5 rounded-full bg-yellow-500" />
                                <span className="text-white/50 truncate">{agent.name}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {statusGroups.error.length > 0 && (
                <div>
                    <p className="text-[10px] text-red-400/60 uppercase tracking-wider mb-2 font-medium">
                        Errors ({statusGroups.error.length})
                    </p>
                    <div className="space-y-1.5">
                        {statusGroups.error.slice(0, 3).map(agent => (
                            <div key={agent.id} className="flex items-center gap-2 text-xs">
                                <span className="w-1.5 h-1.5 rounded-full bg-red-500" />
                                <span className="text-red-400/80 truncate">{agent.name}</span>
                                <span className="text-red-400/50 ml-auto text-[10px]">{agent.error || 'Failed'}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
}

export default function MissionControlDashboard() {
    const [metrics, setMetrics] = useState({
        activeTasks: 0,
        totalTasks: 0,
        activeAgents: 0,
        totalAgents: 0,
        errors: 0,
    });
    const [activities, setActivities] = useState([]);
    const [agents, setAgents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [lastUpdate, setLastUpdate] = useState(null);
    const [gatewayStatus, setGatewayStatus] = useState('unknown');

    useEffect(() => {
        fetchMissionControlData();
        const timer = setInterval(fetchMissionControlData, POLL_INTERVAL_MS);
        return () => clearInterval(timer);
    }, []);

    const fetchMissionControlData = async () => {
        setRefreshing(true);
        try {
            const { agents: agentsData, tasks, hermes } = await fetchMissionControlSnapshot();
            const activeAgents = agentsData.filter(a => a.status === 'active').length;
            const errors = (tasks.failed || 0) + agentsData.filter(a => a.status === 'error').length;

            setAgents(agentsData);
            setGatewayStatus(hermes.status);
            setMetrics({
                activeTasks: tasks.active || 0,
                totalTasks: tasks.total || 0,
                activeAgents,
                totalAgents: agentsData.length,
                errors,
            });
            setActivities([
                {
                    agent: 'hermes',
                    action: `Gateway ${hermes.gateway} at ${hermes.base_url}`,
                    status: hermes.status === 'online' ? 'active' : 'error',
                    time: formatCheckedAt(hermes.checked_at),
                },
                ...agentsData.slice(0, 8).map(agent => ({
                    agent: agent.id,
                    action: agent.currentTask || `${agent.role} ${agent.status}`,
                    status: agent.status,
                    time: formatAgentLastActive(agent.lastActive) || formatCheckedAt(hermes.checked_at),
                })),
            ]);
            setLastUpdate(hermes.checked_at || new Date().toISOString());
        } catch (err) {
            console.error('Failed to fetch mission control data:', err);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-bold text-white">Mission Control</h1>
                        <p className="text-sm text-white/40 mt-1">
                            Central command center for AGL Infrastructure · updated {formatCheckedAt(lastUpdate)}
                        </p>
                    </div>
                    <Button
                        variant="outline"
                        size="sm"
                        className="bg-white/5 border-white/10 text-white/60 hover:text-white hover:bg-white/10"
                        onClick={fetchMissionControlData}
                    >
                        <RefreshCw className={cn("w-3.5 h-3.5 mr-1.5", refreshing && "animate-spin")} />
                        Refresh
                    </Button>
                </div>

                {/* Metrics Cards */}
                <motion.div
                    variants={container}
                    initial="hidden"
                    animate="show"
                    className="grid grid-cols-2 lg:grid-cols-4 gap-4"
                >
                    <MetricCard
                        title="Active Tasks"
                        value={loading ? '...' : metrics.activeTasks}
                        icon={Activity}
                        trend={metrics.activeTasks > 0 ? `+${metrics.activeTasks}` : '0'}
                        color="bg-blue-500/10"
                        subtitle={`of ${metrics.totalTasks} total`}
                    />
                    <MetricCard
                        title="Active Agents"
                        value={loading ? '...' : metrics.activeAgents}
                        icon={Brain}
                        trend={metrics.activeAgents > 0 ? `${metrics.activeAgents}/${metrics.totalAgents}` : '0/0'}
                        color="bg-green-500/10"
                        subtitle="AI team status"
                    />
                    <MetricCard
                        title="Errors"
                        value={loading ? '...' : metrics.errors}
                        icon={AlertCircle}
                        trend={metrics.errors > 0 ? `! ${metrics.errors} failed` : '✓ Clear'}
                        color={metrics.errors > 0 ? "bg-red-500/10" : "bg-green-500/10"}
                        subtitle="Task failures"
                    />
                    <MetricCard
                        title="System Status"
                        value={loading ? '...' : gatewayStatus}
                        icon={Server}
                        trend={gatewayStatus === 'online' ? 'live' : 'check'}
                        color={gatewayStatus === 'online' ? "bg-green-500/10" : "bg-red-500/10"}
                        subtitle="CT188 Hermes Quartet"
                    />
                </motion.div>

                {/* Main Content Grid */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Activity Feed */}
                    <Card className="lg:col-span-2 bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-3">
                            <CardTitle className="text-sm font-medium text-white/80 flex items-center gap-2">
                                <Zap className="w-4 h-4 text-yellow-400" />
                                Live Activity Feed
                            </CardTitle>
                            <CardDescription className="text-white/30">
                                Real-time agent actions and system events
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <ActivityFeed activities={activities} />
                        </CardContent>
                    </Card>

                    {/* Agent Status */}
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-3">
                            <CardTitle className="text-sm font-medium text-white/80 flex items-center gap-2">
                                <Users className="w-4 h-4 text-blue-400" />
                                AI Team Status
                            </CardTitle>
                            <CardDescription className="text-white/30">
                                {agents.length} agents configured
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <AgentStatusBar agents={agents} />
                        </CardContent>
                    </Card>
                </div>

                {/* Quick Actions */}
                <Card className="bg-white/[0.02] border-white/5">
                    <CardHeader className="pb-3">
                        <CardTitle className="text-sm font-medium text-white/80 flex items-center gap-2">
                            <Terminal className="w-4 h-4 text-green-400" />
                            Quick Actions
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                            {[
                                { label: 'Restart Agents', icon: RefreshCw, color: 'text-blue-400' },
                                { label: 'View Logs', icon: Activity, color: 'text-green-400' },
                                { label: 'Run Diagnostics', icon: Shield, color: 'text-yellow-400' },
                                { label: 'Team Overview', icon: Users, color: 'text-purple-400' },
                            ].map((action, i) => (
                                <button
                                    key={i}
                                    className="flex items-center gap-2 p-3 rounded-lg bg-white/[0.03] hover:bg-white/[0.06] transition-colors text-left"
                                >
                                    <action.icon className={cn("w-4 h-4", action.color)} />
                                    <span className="text-xs text-white/60">{action.label}</span>
                                </button>
                            ))}
                        </div>
                    </CardContent>
                </Card>
            </div>
        
    );
}
