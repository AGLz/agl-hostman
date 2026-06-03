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
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';
import { chatWithHermesAgent, fetchHermesStatus, formatAgentLastActive, formatCheckedAt, POLL_INTERVAL_MS } from '@/lib/hermes';
import { useSearchParams } from 'react-router-dom';

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
                { name: 'Hermes Quartet', type: 'team', members: ['jarvis', 'elon', 'satya', 'werner'], status: 'active' },
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

const EMPTY_AGENTS = {};

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

function AgentChatPanel({ agentId, agent, onClose }) {
    const [messages, setMessages] = useState([]);
    const [draft, setDraft] = useState('Responda apenas: pong');
    const [sending, setSending] = useState(false);

    const sendMessage = async () => {
        const text = draft.trim();
        if (!text || sending) return;

        const nextMessages = [...messages, { role: 'user', content: text }];
        setMessages(nextMessages);
        setDraft('');
        setSending(true);

        try {
            const response = await chatWithHermesAgent(agentId, text, messages);
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
            <div className="w-full max-w-xl mx-4 rounded-xl bg-[#1a1a24] border border-white/10 p-5" onClick={e => e.stopPropagation()}>
                <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                        <Brain className="w-5 h-5 text-white" />
                    </div>
                    <div>
                        <h3 className="text-lg font-semibold text-white">{agent.name}</h3>
                        <p className="text-sm text-white/40">{agent.role} · {agentId}</p>
                    </div>
                </div>

                <div className="h-72 overflow-y-auto rounded-lg bg-black/20 border border-white/5 p-3 space-y-2">
                    {messages.length === 0 ? (
                        <p className="text-sm text-white/30">Chat de teste com agente Hermes.</p>
                    ) : messages.map((message, index) => (
                        <div
                            key={index}
                            className={cn(
                                "rounded-lg px-3 py-2 text-sm",
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
                    <Button onClick={sendMessage} disabled={sending || !draft.trim()} className="bg-white/10 text-white hover:bg-white/15">
                        {sending ? '...' : 'Send'}
                    </Button>
                </div>
            </div>
        </div>
    );
}

function AgentCard({ agentId, agent, onChat }) {
    const statusConfig = {
        active: { color: 'bg-green-500/10 text-green-400 border-green-500/30', icon: CheckCircle, label: 'Active' },
        standby: { color: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30', icon: Pause, label: 'Standby' },
        inactive: { color: 'bg-gray-500/10 text-gray-400 border-gray-500/30', icon: XCircle, label: 'Inactive' },
        error: { color: 'bg-red-500/10 text-red-400 border-red-500/30', icon: AlertCircle, label: 'Error' },
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
                    <span className="text-white/60">{formatAgentLastActive(agent.lastActive)}</span>
                </div>
                <div className="flex items-center justify-between text-white/40">
                    <span className="flex items-center gap-1">
                        <Terminal className="w-3 h-3" />
                        Agent ID
                    </span>
                    <span className="text-white/60 font-mono">{agentId}</span>
                </div>
            </div>

            <Button
                variant="outline"
                size="sm"
                className="mt-3 w-full bg-white/5 border-white/10 text-white/60 hover:text-white"
                onClick={() => onChat(agentId, agent)}
            >
                <MessageSquare className="w-3.5 h-3.5 mr-1.5" />
                Test chat
            </Button>
        </motion.div>
    );
}

function HermesQuartetStatus() {
    const [agents, setAgents] = useState(EMPTY_AGENTS);
    const [loading, setLoading] = useState(true);
    const [lastUpdate, setLastUpdate] = useState(new Date());
    const [selectedChat, setSelectedChat] = useState(null);
    const [gateway, setGateway] = useState('unknown');
    const [source, setSource] = useState('unknown');
    const [error, setError] = useState(null);

    const loadStatus = async () => {
        const data = await fetchHermesStatus();
        if (data.agents) {
            const nextAgents = Array.isArray(data.agents)
                ? Object.fromEntries(data.agents.map(agent => [agent.id, agent]))
                : data.agents;
            setAgents(nextAgents);
        }
        setGateway(data.gateway || 'unknown');
        setSource(data.source || 'unknown');
        setLastUpdate(data.checked_at ? new Date(data.checked_at) : new Date());
        setError(null);
    };

    useEffect(() => {
        loadStatus().catch(err => setError(err.message)).finally(() => setLoading(false));
        const timer = setInterval(() => loadStatus().catch(err => setError(err.message)), POLL_INTERVAL_MS);
        return () => clearInterval(timer);
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
                    <div>
                        <h3 className="text-lg font-semibold text-white">Hermes Quartet</h3>
                        <p className="text-xs text-white/30">{gateway} · {source}</p>
                    </div>
                    <Button
                        variant="outline"
                        size="sm"
                        className="bg-white/5 border-white/10 text-white/60"
                        onClick={() => {
                            setLoading(true);
                            loadStatus()
                                .finally(() => setLoading(false));
                        }}
                    >
                        <RefreshCw className={cn("w-3.5 h-3.5 mr-1.5", loading && "animate-spin")} />
                        Refresh
                    </Button>
                </div>
                {error && (
                    <div className="mb-4 rounded-lg border border-red-500/20 bg-red-500/10 px-3 py-2 text-sm text-red-200">
                        {error}
                    </div>
                )}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {Object.entries(agents).map(([id, agent]) => (
                        <AgentCard key={id} agentId={id} agent={agent} onChat={(agentId, agent) => setSelectedChat({ agentId, agent })} />
                    ))}
                </div>
                <p className="text-xs text-white/30 mt-4">
                    Last updated: {formatCheckedAt(lastUpdate)}
                </p>
            </div>
            {selectedChat && (
                <AgentChatPanel
                    agentId={selectedChat.agentId}
                    agent={selectedChat.agent}
                    onClose={() => setSelectedChat(null)}
                />
            )}
        </div>
    );
}

export default function TeamsView() {
    const [selectedNode, setSelectedNode] = useState(null);
    const [searchParams] = useSearchParams();
    const [activeTab, setActiveTab] = useState(() => {
        if (searchParams.get('tab') === 'hermes') return 'hermes';
        if (typeof window !== 'undefined' && window.location.pathname.includes('openclaw')) return 'hermes';
        return 'org';
    });
    const [agents, setAgents] = useState(EMPTY_AGENTS);

    useEffect(() => {
        const loadAgents = async () => {
            const data = await fetchHermesStatus();
            if (!data.agents) return;

            setAgents(Array.isArray(data.agents)
                ? Object.fromEntries(data.agents.map(agent => [agent.id, agent]))
                : data.agents);
        };

        loadAgents().catch(() => {});
        const timer = setInterval(() => loadAgents().catch(() => {}), POLL_INTERVAL_MS);
        return () => clearInterval(timer);
    }, []);

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-white">Teams & Agents</h1>
                    <p className="text-sm text-white/40 mt-1">Hierarquia AGL e quartet Hermes (CT188)</p>
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
                        variant={activeTab === 'hermes' ? 'default' : 'outline'}
                        size="sm"
                        onClick={() => setActiveTab('hermes')}
                        className={cn(
                            activeTab === 'hermes' 
                                ? "bg-white/10 text-white" 
                                : "bg-white/5 border-white/10 text-white/60"
                        )}
                    >
                        <Brain className="w-4 h-4 mr-1.5" />
                        Hermes
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
                                        const agent = agents[memberId];
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
                <HermesQuartetStatus />
            )}
        </div>
    );
}
