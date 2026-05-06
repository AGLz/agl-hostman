import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    Brain,
    Search,
    Filter,
    Shield,
    Terminal,
    Users,
    Rocket,
    Activity,
    ChevronDown,
    Clock,
    AlertCircle,
    CheckCircle,
    Server,
    Code,
    Lock
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { chatWithOpenClawAgent, fetchOpenClawAgents, formatCheckedAt, POLL_INTERVAL_MS } from '@/lib/openclaw';


const agentGroups = [
    {
        name: 'Core',
        icon: Brain,
        color: 'from-blue-500 to-purple-600',
        agents: ['main', 'devops', 'security']
    },
    {
        name: 'Operations',
        icon: Server,
        color: 'from-green-500 to-emerald-600',
        agents: ['infra-manager', 'sre-team', 'release-manager']
    },
    {
        name: 'Scrum Agents',
        icon: Code,
        color: 'from-orange-500 to-red-600',
        agents: ['scr-agl-hostman', 'scr-ald-sys7', 'scr-aldsys8', 'scr-api8', 'scr-api9', 'scr-crowbar', 'scr-fg-antigo']
    },
    {
        name: 'Specialists',
        icon: Shield,
        color: 'from-cyan-500 to-blue-600',
        agents: ['altman', 'gates', 'hassabis', 'karpathy', 'musk']
    },
];

const agentRoles = {
    main: { role: 'Main Coordinator', description: 'Primary agent orchestrating all requests' },
    devops: { role: 'DevOps Engineer', description: 'Docker, CI/CD, deployment automation' },
    security: { role: 'Security Analyst', description: 'Vulnerability scanning, compliance checks' },
    'infra-manager': { role: 'Infrastructure Manager', description: 'Proxmox, hosts, network monitoring' },
    'sre-team': { role: 'Site Reliability', description: 'SLA monitoring, incident response' },
    'release-manager': { role: 'Release Manager', description: 'Version control, deployment coordination' },
    'scr-agl-hostman': { role: 'Scrum Master - Hostman', description: 'Project tracking for agl-hostman' },
    'scr-ald-sys7': { role: 'Scrum - System 7', description: 'Tracking system 7 tasks' },
    'scr-aldsys8': { role: 'Scrum - System 8', description: 'Tracking system 8 tasks' },
    'scr-api8': { role: 'Scrum - API 8', description: 'API development tracking' },
    'scr-api9': { role: 'Scrum - API 9', description: 'API v9 development tracking' },
    'scr-crowbar': { role: 'Scrum - Crowbar', description: 'Crowbar project tracking' },
    'scr-fg-antigo': { role: 'Scrum - FG Legacy', description: 'Legacy FG system tracking' },
};

const initialAgents = agentGroups.flatMap(group =>
    group.agents.map(id => {
        const roleInfo = agentRoles[id] || { role: 'Specialist', description: 'AI specialist agent' };
        return {
            id,
            name: id,
            role: roleInfo.role,
            description: roleInfo.description,
            status: 'idle',
            currentTask: '',
            lastActive: 'pending',
            error: null,
            group: group.name,
            groupColor: group.color,
            groupIcon: group.icon,
        };
    })
);

function AgentCard({ agent, onClick }) {
    const statusColors = {
        active: 'border-green-500/30 bg-green-500/[0.03]',
        idle: 'border-yellow-500/20 bg-yellow-500/[0.02]',
        standby: 'border-yellow-500/20 bg-yellow-500/[0.02]',
        error: 'border-red-500/30 bg-red-500/[0.03]',
    };

    const statusDotColors = {
        active: 'bg-green-500 shadow-green-500/50',
        idle: 'bg-yellow-500 shadow-yellow-500/50',
        standby: 'bg-yellow-500 shadow-yellow-500/50',
        error: 'bg-red-500 shadow-red-500/50',
    };

    return (
        <motion.div
            whileHover={{ y: -2 }}
            className={`p-4 rounded-lg border ${statusColors[agent.status]} hover:bg-white/[0.05] transition-all cursor-pointer`}
            onClick={() => onClick(agent)}
        >
            <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                    <div className={cn("w-8 h-8 rounded-lg bg-gradient-to-br flex items-center justify-center", agent.groupColor)}>
                        <agent.groupIcon className="w-4 h-4 text-white" />
                    </div>
                    <div>
                        <p className="text-sm font-medium text-white/80">{agent.name}</p>
                        <p className="text-[10px] text-white/40">{agent.role}</p>
                    </div>
                </div>
                <span className={cn("w-2 h-2 rounded-full shadow-sm", statusDotColors[agent.status])} />
            </div>

            {agent.currentTask && (
                <p className="text-xs text-white/50 mb-2 truncate">{agent.currentTask}</p>
            )}

            <div className="flex items-center justify-between text-[10px] text-white/30">
                <span className="flex items-center gap-1">
                    <Clock className="w-3 h-3" />
                    {agent.lastActive}
                </span>
                {agent.status === 'error' && (
                    <Badge variant="secondary" className="bg-red-500/10 text-red-400 border-none text-[9px]">
                        Error
                    </Badge>
                )}
            </div>
        </motion.div>
    );
}

function AgentDetailModal({ agent, onClose }) {
    const [messages, setMessages] = useState([]);
    const [draft, setDraft] = useState('Responda apenas: pong');
    const [sending, setSending] = useState(false);

    if (!agent) return null;

    const sendMessage = async () => {
        const text = draft.trim();
        if (!text || sending) return;

        const nextMessages = [...messages, { role: 'user', content: text }];
        setMessages(nextMessages);
        setDraft('');
        setSending(true);

        try {
            const response = await chatWithOpenClawAgent(agent.id, text, messages);
            setMessages([
                ...nextMessages,
                {
                    role: 'assistant',
                    content: response.success ? response.message : response.error,
                    meta: response.latency_ms ? `${response.latency_ms}ms` : null,
                },
            ]);
        } catch (error) {
            setMessages([...nextMessages, { role: 'assistant', content: error.message }]);
        } finally {
            setSending(false);
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-md mx-4 bg-[#1a1a24] border border-white/10 rounded-xl p-6"
                onClick={e => e.stopPropagation()}
            >
                <div className="flex items-center gap-3 mb-4">
                    <div className={cn("w-12 h-12 rounded-xl bg-gradient-to-br flex items-center justify-center", agent.groupColor)}>
                        <agent.groupIcon className="w-6 h-6 text-white" />
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white">{agent.name}</h3>
                        <p className="text-sm text-white/50">{agent.role}</p>
                    </div>
                </div>

                <p className="text-sm text-white/60 mb-4">{agent.description}</p>

                <div className="space-y-3">
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Status</span>
                        <Badge variant="secondary" className={cn(
                            "border-none",
                            agent.status === 'active' ? "bg-green-500/10 text-green-400" :
                            agent.status === 'error' ? "bg-red-500/10 text-red-400" :
                            "bg-yellow-500/10 text-yellow-400"
                        )}>
                            {agent.status}
                        </Badge>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Current Task</span>
                        <span className="text-sm text-white/70">{agent.currentTask || 'None'}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Last Active</span>
                        <span className="text-sm text-white/70">{agent.lastActive}</span>
                    </div>
                    {agent.error && (
                        <div className="flex items-center justify-between py-2 border-b border-white/5">
                            <span className="text-sm text-white/50 flex items-center gap-1">
                                <AlertCircle className="w-3 h-3 text-red-400" />
                                Error
                            </span>
                            <span className="text-sm text-red-400">{agent.error}</span>
                        </div>
                    )}
                </div>

                <div className="mt-4 border-t border-white/5 pt-4">
                    <div className="max-h-56 overflow-y-auto space-y-2 pr-1">
                        {messages.length === 0 ? (
                            <p className="text-xs text-white/30">Direct test chat with this OpenClaw agent.</p>
                        ) : messages.map((message, index) => (
                            <div
                                key={index}
                                className={cn(
                                    "rounded-lg px-3 py-2 text-xs",
                                    message.role === 'user' ? "bg-blue-500/10 text-blue-100" : "bg-white/[0.04] text-white/70"
                                )}
                            >
                                <p className="whitespace-pre-wrap">{message.content}</p>
                                {message.meta && <p className="mt-1 text-[10px] text-white/30">{message.meta}</p>}
                            </div>
                        ))}
                    </div>
                    <div className="mt-3 flex gap-2">
                        <Input
                            value={draft}
                            onChange={e => setDraft(e.target.value)}
                            onKeyDown={e => {
                                if (e.key === 'Enter') sendMessage();
                            }}
                            className="bg-white/5 border-white/10 text-white placeholder:text-white/30"
                            placeholder="Message agent..."
                        />
                        <Button
                            onClick={sendMessage}
                            disabled={sending || !draft.trim()}
                            className="bg-white/10 text-white hover:bg-white/15"
                        >
                            {sending ? '...' : 'Send'}
                        </Button>
                    </div>
                </div>

                <button onClick={onClose} className="mt-4 w-full py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white/60 hover:text-white text-sm transition-colors">
                    Close
                </button>
            </motion.div>
        </div>
    );
}

export default function AITeamView() {
    const [agents, setAgents] = useState(initialAgents);
    const [searchQuery, setSearchQuery] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [selectedAgent, setSelectedAgent] = useState(null);
    const [expandedGroups, setExpandedGroups] = useState({});
    const [lastUpdate, setLastUpdate] = useState(null);

    useEffect(() => {
        // Initialize all groups as expanded
        const initial = {};
        agentGroups.forEach(g => initial[g.name] = true);
        setExpandedGroups(initial);

        const loadAgents = async () => {
            const data = await fetchOpenClawAgents();
            const mapped = data.map(a => ({
                ...a,
                description: agentRoles[a.id]?.description || a.description || 'AI specialist agent',
                group: a.group || agentGroups.find(g => g.agents.includes(a.id))?.name || 'Specialists',
                groupColor: agentGroups.find(g => g.name === a.group || g.agents.includes(a.id))?.color || 'from-gray-500 to-gray-600',
                groupIcon: agentGroups.find(g => g.name === a.group || g.agents.includes(a.id))?.icon || Users,
            }));
            setAgents(mapped);
            setLastUpdate(new Date().toISOString());
        };

        loadAgents().catch(() => {});
        const timer = setInterval(() => loadAgents().catch(() => {}), POLL_INTERVAL_MS);
        return () => clearInterval(timer);
    }, []);

    const filteredAgents = agents.filter(agent => {
        const matchesSearch = agent.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             agent.role.toLowerCase().includes(searchQuery.toLowerCase());
        const normalizedStatus = agent.status === 'standby' ? 'idle' : agent.status;
        const matchesStatus = statusFilter === 'all' || normalizedStatus === statusFilter;
        return matchesSearch && matchesStatus;
    });

    const statusCounts = {
        all: agents.length,
        active: agents.filter(a => a.status === 'active').length,
        idle: agents.filter(a => ['idle', 'standby'].includes(a.status)).length,
        error: agents.filter(a => a.status === 'error').length,
    };

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div>
                    <h1 className="text-2xl font-bold text-white">AI Team</h1>
                    <p className="text-sm text-white/40 mt-1">
                        {agents.length} agents across {agentGroups.length} groups · updated {formatCheckedAt(lastUpdate)}
                    </p>
                </div>

                {/* Filters */}
                <div className="flex flex-col sm:flex-row gap-3">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
                        <Input
                            placeholder="Search agents..."
                            value={searchQuery}
                            onChange={e => setSearchQuery(e.target.value)}
                            className="pl-9 bg-white/5 border-white/10 text-white placeholder:text-white/30"
                        />
                    </div>
                    <div className="flex gap-2">
                        {Object.entries(statusCounts).map(([status, count]) => (
                            <button
                                key={status}
                                onClick={() => setStatusFilter(status)}
                                className={cn(
                                    "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors",
                                    statusFilter === status
                                        ? "bg-white/10 text-white"
                                        : "bg-white/5 text-white/40 hover:text-white/60"
                                )}
                            >
                                {status.charAt(0).toUpperCase() + status.slice(1)} ({count})
                            </button>
                        ))}
                    </div>
                </div>

                {/* Agent Groups */}
                <div className="space-y-6">
                    {agentGroups.map(group => {
                        const groupAgents = filteredAgents.filter(a => a.group === group.name);
                        if (groupAgents.length === 0) return null;

                        const isExpanded = expandedGroups[group.name];

                        return (
                            <Card key={group.name} className="bg-white/[0.02] border-white/5">
                                <CardHeader className="pb-3">
                                    <button
                                        onClick={() => setExpandedGroups(prev => ({ ...prev, [group.name]: !isExpanded }))}
                                        className="flex items-center gap-3 w-full"
                                    >
                                        <div className={cn("w-8 h-8 rounded-lg bg-gradient-to-br flex items-center justify-center", group.color)}>
                                            <group.icon className="w-4 h-4 text-white" />
                                        </div>
                                        <div className="text-left flex-1">
                                            <CardTitle className="text-sm text-white/80">{group.name}</CardTitle>
                                            <CardDescription className="text-white/40">
                                                {groupAgents.length} agent{groupAgents.length !== 1 ? 's' : ''}
                                            </CardDescription>
                                        </div>
                                        <ChevronDown className={cn("w-4 h-4 text-white/30 transition-transform", isExpanded && "rotate-180")} />
                                    </button>
                                </CardHeader>
                                {isExpanded && (
                                    <CardContent>
                                        <motion.div
                                            initial={{ opacity: 0 }}
                                            animate={{ opacity: 1 }}
                                            className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3"
                                        >
                                            {groupAgents.map(agent => (
                                                <AgentCard
                                                    key={agent.id}
                                                    agent={agent}
                                                    onClick={setSelectedAgent}
                                                />
                                            ))}
                                        </motion.div>
                                    </CardContent>
                                )}
                            </Card>
                        );
                    })}
                </div>

                {/* Agent Detail Modal */}
                <AgentDetailModal agent={selectedAgent} onClose={() => setSelectedAgent(null)} />
            </div>
        
    );
}
