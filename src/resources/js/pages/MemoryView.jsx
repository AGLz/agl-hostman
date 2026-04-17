import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
    Database,
    Search,
    Filter,
    FileText,
    Calendar,
    Tag,
    Clock,
    ChevronRight,
    X,
    Brain,
    Server,
    Shield,
    Terminal,
    Archive
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';


const CATEGORIES = [
    { name: 'Infrastructure', icon: Server, color: 'from-blue-500 to-blue-600' },
    { name: 'Agents', icon: Brain, color: 'from-purple-500 to-purple-600' },
    { name: 'Procedures', icon: Shield, color: 'from-green-500 to-green-600' },
    { name: 'Troubleshooting', icon: Terminal, color: 'from-orange-500 to-orange-600' },
    { name: 'Archive', icon: Archive, color: 'from-gray-500 to-gray-600' },
];

const SAMPLE_MEMORIES = [
    { id: 1, title: 'LiteLLM qwen3.5-flash configuration', category: 'Infrastructure', date: '2026-04-13', preview: 'Updated all models to use qwen3.5-flash as default. Removed Z.AI direct subscription. Configured openrouter glm-4.5-air as fallback...', tags: ['litellm', 'qwen', 'config'] },
    { id: 2, title: 'OpenClaw agent health check IPs', category: 'Procedures', date: '2026-04-13', preview: 'Fixed n8n health check to use LAN IP 192.168.0.202:5678 instead of Tailscale. wg-easy uses FGSRV06 at 100.83.51.9:51821...', tags: ['openclaw', 'monitoring', 'networking'] },
    { id: 3, title: 'Proxmox CT inventory - AGLSRV1', category: 'Infrastructure', date: '2026-04-12', preview: '42 containers running on AGLSRV1. Key services: CT102 Pi-hole, CT117 Cloudflared, CT179 agldv03 dev, CT200 Ollama...', tags: ['proxmox', 'inventory'] },
    { id: 4, title: 'Mission Control dashboard implementation', category: 'Agents', date: '2026-04-13', preview: 'Created new Mission Control layout with 7 screens: Dashboard, Tasks Board, AI Team, Memory, Calendar, Contacts, Settings...', tags: ['dashboard', 'react', 'mission-control'] },
    { id: 5, title: 'WireGuard mesh topology', category: 'Infrastructure', date: '2026-04-10', preview: '14 nodes in WireGuard mesh. Hub at FGSRV6 (10.6.0.5). All sites connected via 10.6.0.0/24 network...', tags: ['wireguard', 'networking'] },
    { id: 6, title: 'Docker compose stack optimization', category: 'Procedures', date: '2026-04-08', preview: 'Reduced monitoring stack resource usage. Moved Grafana from port 3001 to 3002 to free up port for OpenClaw...', tags: ['docker', 'optimization'] },
    { id: 7, title: 'Security audit findings - March 2026', category: 'Troubleshooting', date: '2026-03-28', preview: 'Found meshagent memory leaks on AGLSRV1 (30+ instances, some using 10-22GB RAM). Resolution: kill leaking processes...', tags: ['security', 'memory-leak'] },
    { id: 8, title: 'OpenClaw skills installation guide', category: 'Archive', date: '2026-04-05', preview: 'Installed 16 new skills from ClawHub: debug-pro, docker-essentials, tdd-guide, pr-reviewer, n8n-monitor...', tags: ['openclaw', 'skills'] },
];

function MemoryCard({ memory, onClick }) {
    const category = CATEGORIES.find(c => c.name === memory.category);

    return (
        <motion.div
            whileHover={{ y: -2 }}
            className="p-4 rounded-lg bg-white/[0.03] border border-white/5 hover:bg-white/[0.05] hover:border-white/10 transition-all cursor-pointer"
            onClick={() => onClick(memory)}
        >
            <div className="flex items-start gap-3">
                {category && (
                    <div className={cn("w-8 h-8 rounded-lg bg-gradient-to-br flex items-center justify-center shrink-0", category.color)}>
                        <category.icon className="w-4 h-4 text-white" />
                    </div>
                )}
                <div className="flex-1 min-w-0">
                    <h4 className="text-sm font-medium text-white/80 line-clamp-1">{memory.title}</h4>
                    <p className="text-xs text-white/40 mt-1 line-clamp-2">{memory.preview}</p>
                    <div className="flex items-center gap-3 mt-3">
                        <span className="text-[10px] text-white/30 flex items-center gap-1">
                            <Calendar className="w-3 h-3" />
                            {new Date(memory.date).toLocaleDateString('en', { month: 'short', day: 'numeric' })}
                        </span>
                        <span className="text-[10px] text-white/20">
                            {memory.category}
                        </span>
                    </div>
                    <div className="flex gap-1 mt-2 flex-wrap">
                        {memory.tags?.map(tag => (
                            <Badge key={tag} variant="secondary" className="bg-white/5 text-white/30 border-none text-[9px]">
                                {tag}
                            </Badge>
                        ))}
                    </div>
                </div>
            </div>
        </motion.div>
    );
}

function MemoryDetail({ memory, onClose }) {
    if (!memory) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-2xl mx-4 bg-[#1a1a24] border border-white/10 rounded-xl p-6 max-h-[80vh] overflow-y-auto"
                onClick={e => e.stopPropagation()}
            >
                <div className="flex items-start justify-between mb-4">
                    <div>
                        <h3 className="text-lg font-semibold text-white">{memory.title}</h3>
                        <div className="flex items-center gap-3 mt-2">
                            <Badge variant="secondary" className="bg-white/5 text-white/40 border-none text-[10px]">
                                {memory.category}
                            </Badge>
                            <span className="text-xs text-white/30 flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                {new Date(memory.date).toLocaleDateString('en', { year: 'numeric', month: 'long', day: 'numeric' })}
                            </span>
                        </div>
                    </div>
                    <button onClick={onClose} className="text-white/40 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="prose prose-invert prose-sm max-w-none">
                    <p className="text-sm text-white/70 leading-relaxed">{memory.preview}</p>
                    <p className="text-sm text-white/50 mt-4">
                        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                        Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
                    </p>
                    <p className="text-sm text-white/50 mt-4">
                        Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
                        Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
                    </p>
                </div>

                <div className="flex gap-1 mt-6 flex-wrap">
                    {memory.tags?.map(tag => (
                        <Badge key={tag} variant="secondary" className="bg-white/5 text-white/30 border-none text-[10px]">
                            <Tag className="w-2.5 h-2.5 mr-0.5" />
                            {tag}
                        </Badge>
                    ))}
                </div>

                <button
                    onClick={onClose}
                    className="mt-6 w-full py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white/60 hover:text-white text-sm transition-colors"
                >
                    Close
                </button>
            </motion.div>
        </div>
    );
}

export default function MemoryView() {
    const [memories, setMemories] = useState(SAMPLE_MEMORIES);
    const [searchQuery, setSearchQuery] = useState('');
    const [categoryFilter, setCategoryFilter] = useState('All');
    const [selectedMemory, setSelectedMemory] = useState(null);
    const [sortBy, setSortBy] = useState('date');

    const filteredMemories = memories.filter(memory => {
        const matchesSearch = memory.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             memory.preview.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             memory.tags?.some(t => t.toLowerCase().includes(searchQuery.toLowerCase()));
        const matchesCategory = categoryFilter === 'All' || memory.category === categoryFilter;
        return matchesSearch && matchesCategory;
    }).sort((a, b) => {
        if (sortBy === 'date') return new Date(b.date) - new Date(a.date);
        if (sortBy === 'title') return a.title.localeCompare(b.title);
        return 0;
    });

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div>
                    <h1 className="text-2xl font-bold text-white">Memory</h1>
                    <p className="text-sm text-white/40 mt-1">Searchable knowledge base from OpenClaw sessions</p>
                </div>

                {/* Filters */}
                <div className="flex flex-col sm:flex-row gap-3">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
                        <Input
                            placeholder="Search memories..."
                            value={searchQuery}
                            onChange={e => setSearchQuery(e.target.value)}
                            className="pl-9 bg-white/5 border-white/10 text-white placeholder:text-white/30"
                        />
                    </div>
                    <div className="flex gap-2">
                        <select
                            value={categoryFilter}
                            onChange={e => setCategoryFilter(e.target.value)}
                            className="bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                        >
                            <option value="All">All Categories</option>
                            {CATEGORIES.map(c => (
                                <option key={c.name} value={c.name}>{c.name}</option>
                            ))}
                        </select>
                        <select
                            value={sortBy}
                            onChange={e => setSortBy(e.target.value)}
                            className="bg-white/5 border border-white/10 rounded-lg px-3 py-2 text-sm text-white"
                        >
                            <option value="date">Newest First</option>
                            <option value="title">Alphabetical</option>
                        </select>
                    </div>
                </div>

                {/* Category Pills */}
                <div className="flex gap-2 flex-wrap">
                    <button
                        onClick={() => setCategoryFilter('All')}
                        className={cn(
                            "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-1.5",
                            categoryFilter === 'All' ? "bg-white/10 text-white" : "bg-white/5 text-white/40 hover:text-white/60"
                        )}
                    >
                        <Database className="w-3.5 h-3.5" />
                        All ({memories.length})
                    </button>
                    {CATEGORIES.map(cat => {
                        const count = memories.filter(m => m.category === cat.name).length;
                        return (
                            <button
                                key={cat.name}
                                onClick={() => setCategoryFilter(cat.name)}
                                className={cn(
                                    "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-1.5",
                                    categoryFilter === cat.name ? "bg-white/10 text-white" : "bg-white/5 text-white/40 hover:text-white/60"
                                )}
                            >
                                <cat.icon className="w-3.5 h-3.5" />
                                {cat.name} ({count})
                            </button>
                        );
                    })}
                </div>

                {/* Memory Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filteredMemories.map(memory => (
                        <MemoryCard
                            key={memory.id}
                            memory={memory}
                            onClick={setSelectedMemory}
                        />
                    ))}
                </div>

                {filteredMemories.length === 0 && (
                    <div className="flex flex-col items-center justify-center py-16 text-white/30">
                        <FileText className="w-12 h-12 mb-3" />
                        <p className="text-sm">No memories found</p>
                        <p className="text-xs mt-1">Try adjusting your search or filters</p>
                    </div>
                )}

                {/* Memory Detail Modal */}
                <MemoryDetail memory={selectedMemory} onClose={() => setSelectedMemory(null)} />
            </div>
        
    );
}
