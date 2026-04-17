import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import {
    Users,
    Building2,
    GitBranch,
    User,
    ChevronRight,
    ChevronDown,
    Activity,
    Clock,
    CheckCircle,
    AlertCircle,
    XCircle,
    Brain,
    Terminal,
    MessageSquare,
    Play,
    Pause,
    RefreshCw,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

// Organization structure data
const ORG_STRUCTURE = {
    name: 'AGL Infrastructure',
    type: 'company',
    children: [
        {
            name: 'Infrastructure Team',
            type: 'department',
            icon: Building2,
            children: [
                { name: 'DevOps', type: 'team', members: ['devops-agent'], status: 'active' },
                { name: 'SRE', type: 'team', members: ['sre-team'], status: 'active' },
                { name: 'Infra Manager', type: 'team', members: ['infra-manager'], status: 'active' },
            ],
        },
        {
            name: 'AI & Automation',
            type: 'department',
            icon: Brain,
            children: [
                { name: 'OpenClaw Agents', type: 'team', members: ['main', 'security', 'release-manager'], status: 'active' },
                { name: 'Scrum Agents', type: 'team', members: ['scr-agl-hostman', 'scr-api8', 'scr-api9', 'scr-crowbar'], status: 'active' },
            ],
        },
        {
            name: 'Executive',
            type: 'department',
            icon: Users,
            children: [
                { name: 'Leadership', type: 'team', members: ['altman', 'musk', 'gates', 'hassabis', 'hinton', 'karpathy', 'nadella', 'pichai'], status: 'standby' },
            ],
        },
    ],
};

// OpenClaw agents data
const OPENCLAW_AGENTS = {
    main: { name: 'Main Agent', role: 'Coordinator', status: 'active', sessions: 12, lastActive: '2m ago' },
    devops: { name: 'DevOps Agent', role: 'DevOps Engineer', status: 'active', sessions: 8, lastActive: '5m ago' },
    security: { name: 'Security Agent', role: 'Security Analyst', status: 'active', sessions: 15, lastActive: '1m ago' },
    'sre-team': { name: 'SRE Team', role: 'Site Reliability', status: 'active', sessions: 6, lastActive: '10m ago' },
    'infra-manager': { name: 'Infra Manager', role: 'Infrastructure Manager', status: 'active', sessions: 4, lastActive: '15m ago' },
    'release-manager': { name: 'Release Manager', role: 'Release Coordination', status: 'standby', sessions: 2, lastActive: '1h ago' },
    'scr-agl-hostman': { name: 'Scrum - Hostman', role: 'Project Tracking', status: 'active', sessions: 20, lastActive: '3m ago' },
    'scr-api8': { name: 'Scrum - API8', role: 'API Tracking', status: 'standby', sessions: 5, lastActive: '30m ago' },
    'scr-api9': { name: 'Scrum - API9', role: 'API Tracking', status: 'standby', sessions: 3, lastActive: '45m ago' },
    'scr-crowbar': { name: 'Scrum - Crowbar', role: 'Project Tracking', status: 'standby', sessions: 1, lastActive: '2h ago' },
    altman: { name: 'Altman', role: 'AI Advisor', status: 'standby', sessions: 0, lastActive: '1d ago' },
    musk: { name: 'Musk', role: 'Strategy Advisor', status: 'standby', sessions: 0, lastActive: '2d ago' },
    gates: { name: 'Gates', role: 'Tech Advisor', status: 'standby', sessions: 0, lastActive: '3d ago' },
    hassabis: { name: 'Hassabis', role: 'AI Research', status: 'standby', sessions: 0, lastActive: '1d ago' },
    hinton: { name: 'Hinton', role: 'AI Research', status: 'standby', sessions: 0, lastActive: '4d ago' },
    karpathy: { name: 'Karpathy', role: 'ML Advisor', status: 'standby', sessions: 0, lastActive: '2d ago' },
    nadella: { name: 'Nadella', role: 'Cloud Strategy', status: 'standby', sessions: 0, lastActive: '3d ago' },
    pichai: { name: 'Pichai', role: 'AI Strategy', status: 'standby', sessions: 0, lastActive: '2d ago' },
};

function OrgTreeNode({ node, level = 0, onSelect }) {
    const [isExpanded, setIsExpanded] = useState(true);
    const Icon = node.icon || GitBranch;
    
    const getStatusColor = (status) => {
        switch (status) {
            case 'active': return 'bg-green-500';
            case 'standby': return 'bg-yellow-500';
            case 'inactive': return 'bg-gray-500';
            default: return 'bg-gray-500';
        }
    };

    const handleClick = () => {
        if (node.children) {
            setIsExpanded(!isExpanded);
        } else {
            onSelect?.(node);
        }
    };

    return (
        <div className="select-none">
            <div
                className={cn(
                    "flex items-center gap-2 py-2 px-3 rounded-lg cursor-pointer transition-colors",
                    "hover:bg-white/5"
                )}
                style={{ marginLeft: `${level * 20}px` }}
                onClick={handleClick}
            >
                {node.children && (
                    <button className="text-white/40 hover:text-white/80">
                        {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                    </button>
                )}
                {!node.children && <div className="w-4" />}
                
                <div className={cn(
                    "w-8 h-8 rounded-lg flex items-center justify-center",
                    node.type === 'company' ? "bg-gradient-to-br from-blue-500 to-purple-600" :
                    node.type === 'department' ? "bg-gradient-to-br from-green-500 to-emerald-600" :
                    "bg-gradient-to-br from-orange-500 to-red-600"
                )}>
                    <Icon className="w-4 h-4 text-white" />
                </div>
                
                <div className="flex-1">
                    <p className="text-sm font-medium text-white/80">{node.name}</p>
                    {node.members && (
                        <p className="text-xs text-white/40">{node.members.length} agents</p>
                    )}
                </div>
                
                {node.status && (
                    <div className="flex items-center gap-1.5">
                        <div className={cn("w-2 h-2 rounded-full", getStatusColor(node.status))} />
                        <span className="text-xs text-white/40 capitalize">{node.status}</span>
                    </div>
                )}
            </div>
            
            {isExpanded && node.children && (
                <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                >
                    {node.children.map((child, i) => (
                        <OrgTreeNode key={i} node={child} level={level + 1} onSelect={onSelect} />
                    ))}
                </motion.div>
            )}
        </div>
    );
}

function AgentCard({ agentId, agent }) {
    const statusConfig = {
        active: { color: 'bg-green-500/10 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Active' },
        standby: { color: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30', icon: Pause, label: 'Standby' },
        inactive: { color: 'bg-gray-500/10 text-gray-400 border-gray-500/30', icon: XCircle, label: 'Inactive' },
    };
    const status = statusConfig[agent.status] || statusConfig.inactive;
    const StatusIcon = status.icon;

    return (
        <motion.div
            whileHover={{ y: -2 }}
            className="p-4 rounded-lg bg-white/[0.03] border border-white/5 hover:bg-white/[0.05] hover:border-white/10 transition-all"
        >
            <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                        <Brain className="w-5 h-5 text-white" />
                    </div>
                    <div>
                        <p className="text-sm font-medium text-white/80">{agent.name}</p>
                        <p className="text-xs text-white/40">{agent.role}</p>
                    </div>
                </div>
                <Badge variant="secondary" className={cn("text-[10px] border", status.color)}>
                    <StatusIcon className="w-3 h-3 mr-1" />
                    {status.label}
                </Badge>
            </div>
            
            <div className="space-y-2 text-xs">
                <div className="flex items-center justify-between text-white/40">
                    <span className="flex items-center gap-1">
                        <MessageSquare className="w-3 h-3" />
                        Sessions
                    </span>
                    <span className="text-white/60">{agent.sessions}</span>
                </div>
                <div className="flex items-center justify-between text-white/40">
                    <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        Last active
                    </span>
                    <span className="text-white/60">{agent.lastActive}</span>
                </div>
                <div className="flex items-center justify-between text-white/40">
                    <span className="flex items-center gap-1">
                        <Terminal className="w-3 h-3" />
                        Agent ID
                    </span>
                    <span className="text-white/60 font-mono">{agentId}</span>
                </div>
            </div>
        </motion.div>
    );
}

function OpenClawStatus() {
    const [agents, setAgents] = useState(OPENCLAW_AGENTS);
    const [loading, setLoading] = useState(true);
    const [lastUpdate, setLastUpdate] = useState(new Date());

    useEffect(() => {
        // Fetch real OpenClaw data
        fetch('/api/openclaw/status')
            .then(res => res.json())
            .then(data => {
                if (data.agents) {
                    setAgents(prev => ({ ...prev, ...data.agents }));
                }
                setLastUpdate(new Date());
            })
            .catch(() => {})
            .finally(() => setLoading(false));
    }, []);

    const stats = {
        total: Object.keys(agents).length,
        active: Object.values(agents).filter(a => a.status === 'active').length,
        standby: Object.values(agents).filter(a => a.status === 'standby').length,
        totalSessions: Object.values(agents).reduce((sum, a) => sum + (a.sessions || 0), 0),
    };

    return (
        <div className="space-y-6">
            {/* Stats */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <Card className="bg-white/[0.03] border-white/5">
                    <CardContent className="p-4">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-lg bg-blue-500/10 flex items-center justify-center">
                                <Users className="w-5 h-5 text-blue-400" />
                            </div>
                            <div>
                                <p className="text-2xl font-bold text-white">{stats.total}</p>
                                <p className="text-xs text-white/40">Total Agents</p>
                            </div>
                        </div>
                    </CardContent>
                </Card>
                <Card className="bg-white/[0.03] border-white/5">
                    <CardContent className="p-4">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center">
                                <Activity className="w-5 h-5 text-green-400" />
                            </div>
                            <div>
                                <p className="text-2xl font-bold text-green-400">{stats.active}</p>
                                <p className="text-xs text-white/40">Active</p>
                            </div>
                        </div>
                    </CardContent>
                </Card>
                <Card className="bg-white/[0.03] border-white/5">
                    <CardContent className="p-4">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-lg bg-yellow-500/10 flex items-center justify-center">
                                <Pause className="w-5 h-5 text-yellow-400" />
                            </div>
                            <div>
                                <p className="text-2xl font-bold text-yellow-400">{stats.standby}</p>
                                <p className="text-xs text-white/40">Standby</p>
                            </div>
                        </div>
                    </CardContent>
                </Card>
                <Card className="bg-white/[0.03] border-white/5">
                    <CardContent className="p-4">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center">
                                <MessageSquare className="w-5 h-5 text-purple-400" />
                            </div>
                            <div>
                                <p className="text-2xl font-bold text-purple-400">{stats.totalSessions}</p>
                                <p className="text-xs text-white/40">Total Sessions</p>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>

            {/* Agents Grid */}
            <div>
                <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-white">OpenClaw Agents</h3>
                    <Button
                        variant="outline"
                        size="sm"
                        className="bg-white/5 border-white/10 text-white/60"
                        onClick={() => {
                            setLoading(true);
                            fetch('/api/openclaw/status')
                                .then(res => res.json())
                                .then(data => {
                                    if (data.agents) setAgents(prev => ({ ...prev, ...data.agents }));
                                    setLastUpdate(new Date());
                                })
                                .finally(() => setLoading(false));
                        }}
                    >
                        <RefreshCw className={cn("w-3.5 h-3.5 mr-1.5", loading && "animate-spin")} />
                        Refresh
                    </Button>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {Object.entries(agents).map(([id, agent]) => (
                        <AgentCard key={id} agentId={id} agent={agent} />
                    ))}
                </div>
                <p className="text-xs text-white/30 mt-4">
                    Last updated: {lastUpdate.toLocaleTimeString()}
                </p>
            </div>
        </div>
    );
}

export default function TeamsView() {
    const [selectedNode, setSelectedNode] = useState(null);
    const [activeTab, setActiveTab] = useState('org'); // 'org' or 'openclaw'

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-white">Teams & Agents</h1>
                    <p className="text-sm text-white/40 mt-1">Organization hierarchy and OpenClaw agents</p>
                </div>
                <div className="flex gap-2">
                    <Button
                        variant={activeTab === 'org' ? 'default' : 'outline'}
                        size="sm"
                        onClick={() => setActiveTab('org')}
                        className={cn(
                            activeTab === 'org' 
                                ? "bg-white/10 text-white" 
                                : "bg-white/5 border-white/10 text-white/60"
                        )}
                    >
                        <GitBranch className="w-4 h-4 mr-1.5" />
                        Organization
                    </Button>
                    <Button
                        variant={activeTab === 'openclaw' ? 'default' : 'outline'}
                        size="sm"
                        onClick={() => setActiveTab('openclaw')}
                        className={cn(
                            activeTab === 'openclaw' 
                                ? "bg-white/10 text-white" 
                                : "bg-white/5 border-white/10 text-white/60"
                        )}
                    >
                        <Brain className="w-4 h-4 mr-1.5" />
                        OpenClaw
                    </Button>
                </div>
            </div>

            {/* Content */}
            {activeTab === 'org' ? (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader>
                            <CardTitle className="text-white/80 flex items-center gap-2">
                                <Building2 className="w-5 h-5" />
                                Organization Structure
                            </CardTitle>
                            <CardDescription>Team hierarchy and agent assignments</CardDescription>
                        </CardHeader>
                        <CardContent>
                            <OrgTreeNode node={ORG_STRUCTURE} onSelect={setSelectedNode} />
                        </CardContent>
                    </Card>

                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader>
                            <CardTitle className="text-white/80 flex items-center gap-2">
                                <Users className="w-5 h-5" />
                                {selectedNode ? selectedNode.name : 'Select a team'}
                            </CardTitle>
                            <CardDescription>
                                {selectedNode 
                                    ? `${selectedNode.members?.length || 0} agents assigned`
                                    : 'Click on a team to view assigned agents'
                                }
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            {selectedNode && selectedNode.members ? (
                                <div className="space-y-3">
                                    {selectedNode.members.map(memberId => {
                                        const agent = OPENCLAW_AGENTS[memberId];
                                        return agent ? (
                                            <div key={memberId} className="flex items-center gap-3 p-3 rounded-lg bg-white/[0.03]">
                                                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                                                    <Brain className="w-4 h-4 text-white" />
                                                </div>
                                                <div className="flex-1">
                                                    <p className="text-sm font-medium text-white/80">{agent.name}</p>
                                                    <p className="text-xs text-white/40">{agent.role}</p>
                                                </div>
                                                <Badge variant="secondary" className={cn(
                                                    "text-[10px] border",
                                                    agent.status === 'active' ? "bg-green-500/10 text-green-400 border-green-500/30" :
                                                    "bg-yellow-500/10 text-yellow-400 border-yellow-500/30"
                                                )}>
                                                    {agent.status}
                                                </Badge>
                                            </div>
                                        ) : null;
                                    })}
                                </div>
                            ) : (
                                <div className="flex flex-col items-center justify-center py-12 text-white/30">
                                    <Users className="w-12 h-12 mb-3" />
                                    <p className="text-sm">Select a team to view agents</p>
                                </div>
                            )}
                        </CardContent>
                    </Card>
                </div>
            ) : (
                <OpenClawStatus />
            )}
        </div>
    );
}
