import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
    Users,
    Search,
    Mail,
    Phone,
    Globe,
    MapPin,
    Filter,
    X,
    Shield,
    Server,
    Brain,
    User,
    AlertCircle
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';


const CATEGORIES = [
    { name: 'Internal Team', icon: Shield, color: 'from-blue-500 to-blue-600' },
    { name: 'Infrastructure', icon: Server, color: 'from-green-500 to-green-600' },
    { name: 'AI Agents', icon: Brain, color: 'from-purple-500 to-purple-600' },
    { name: 'External', icon: Globe, color: 'from-orange-500 to-orange-600' },
];

const SAMPLE_CONTACTS = [
    { id: 1, name: 'Andre Aguiar', email: 'andre@aglhost.com', role: 'Infrastructure Lead', category: 'Internal Team', timezone: 'America/Sao_Paulo', phone: '+55', status: 'active', notes: 'Primary admin for all systems' },
    { id: 2, name: 'AGL Admin', email: 'admin@aglhost.com', role: 'System Administrator', category: 'Internal Team', timezone: 'America/Sao_Paulo', status: 'active', notes: 'Shared admin account' },
    { id: 3, name: 'Main Agent', email: 'main@openclaw.local', role: 'Main Coordinator', category: 'AI Agents', timezone: 'UTC', status: 'active', notes: 'Primary OpenClaw agent' },
    { id: 4, name: 'DevOps Agent', email: 'devops@openclaw.local', role: 'DevOps Engineer', category: 'AI Agents', timezone: 'UTC', status: 'active', notes: 'Docker, CI/CD, deployment' },
    { id: 5, name: 'Security Agent', email: 'security@openclaw.local', role: 'Security Analyst', category: 'AI Agents', timezone: 'UTC', status: 'active', notes: 'Vulnerability scanning' },
    { id: 6, name: 'Infra Manager', email: 'infra@openclaw.local', role: 'Infrastructure Manager', category: 'AI Agents', timezone: 'UTC', status: 'idle', notes: 'Proxmox, hosts, network' },
    { id: 7, name: 'SRE Team Agent', email: 'sre@openclaw.local', role: 'Site Reliability', category: 'AI Agents', timezone: 'UTC', status: 'idle', notes: 'SLA monitoring, incident response' },
    { id: 8, name: 'n8n Service', email: 'n8n@aglhost.com', role: 'Workflow Automation', category: 'Infrastructure', timezone: 'UTC', status: 'active', notes: 'Running on CT202, LAN 192.168.0.202:5678' },
    { id: 9, name: 'Cloudflare Tunnel', email: 'cloudflare@aglhost.com', role: 'Tunnel Service', category: 'External', timezone: 'UTC', status: 'active', notes: 'Multiple tunnels: aglsrv1, aglsrv5e, fgsrv7' },
];

function ContactCard({ contact, onClick }) {
    const category = CATEGORIES.find(c => c.name === contact.category);

    return (
        <motion.div
            whileHover={{ y: -2 }}
            className="p-4 rounded-lg bg-white/[0.03] border border-white/5 hover:bg-white/[0.05] hover:border-white/10 transition-all cursor-pointer"
            onClick={() => onClick(contact)}
        >
            <div className="flex items-start gap-3">
                <Avatar className="w-10 h-10 border border-white/10">
                    <AvatarFallback className={cn("bg-gradient-to-br text-white text-sm", category?.color || 'from-gray-500 to-gray-600')}>
                        {contact.name.split(' ').map(n => n[0]).join('').substring(0, 2)}
                    </AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                        <h4 className="text-sm font-medium text-white/80 truncate">{contact.name}</h4>
                        <span className={cn(
                            "w-2 h-2 rounded-full",
                            contact.status === 'active' ? "bg-green-500" : "bg-yellow-500"
                        )} />
                    </div>
                    <p className="text-xs text-white/40 mt-0.5">{contact.role}</p>
                    <div className="flex items-center gap-2 mt-2 text-[10px] text-white/30">
                        <Mail className="w-3 h-3" />
                        <span className="truncate">{contact.email}</span>
                    </div>
                    {contact.timezone && (
                        <div className="flex items-center gap-2 mt-1 text-[10px] text-white/20">
                            <MapPin className="w-3 h-3" />
                            <span>{contact.timezone}</span>
                        </div>
                    )}
                </div>
            </div>
        </motion.div>
    );
}

function ContactDetail({ contact, onClose }) {
    if (!contact) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-md mx-4 bg-[#1a1a24] border border-white/10 rounded-xl p-6"
                onClick={e => e.stopPropagation()}
            >
                <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                        <Avatar className="w-12 h-12 border border-white/10">
                            <AvatarFallback className="bg-gradient-to-br from-blue-500 to-purple-600 text-white text-lg">
                                {contact.name.split(' ').map(n => n[0]).join('').substring(0, 2)}
                            </AvatarFallback>
                        </Avatar>
                        <div>
                            <h3 className="text-lg font-semibold text-white">{contact.name}</h3>
                            <p className="text-sm text-white/50">{contact.role}</p>
                        </div>
                    </div>
                    <button onClick={onClose} className="text-white/40 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="space-y-4">
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Status</span>
                        <Badge variant="secondary" className={cn(
                            "border-none",
                            contact.status === 'active' ? "bg-green-500/10 text-green-400" : "bg-yellow-500/10 text-yellow-400"
                        )}>
                            {contact.status}
                        </Badge>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Email</span>
                        <span className="text-sm text-white/70">{contact.email}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Category</span>
                        <span className="text-sm text-white/70">{contact.category}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                        <span className="text-sm text-white/50">Timezone</span>
                        <span className="text-sm text-white/70">{contact.timezone}</span>
                    </div>
                    {contact.notes && (
                        <div>
                            <span className="text-sm text-white/50">Notes</span>
                            <p className="text-sm text-white/60 mt-1">{contact.notes}</p>
                        </div>
                    )}
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

export default function ContactsView() {
    const [contacts, setContacts] = useState(SAMPLE_CONTACTS);
    const [searchQuery, setSearchQuery] = useState('');
    const [categoryFilter, setCategoryFilter] = useState('All');
    const [selectedContact, setSelectedContact] = useState(null);

    const filteredContacts = contacts.filter(contact => {
        const matchesSearch = contact.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             contact.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
                             contact.role.toLowerCase().includes(searchQuery.toLowerCase());
        const matchesCategory = categoryFilter === 'All' || contact.category === categoryFilter;
        return matchesSearch && matchesCategory;
    });

    const statusCounts = {
        active: contacts.filter(c => c.status === 'active').length,
        idle: contacts.filter(c => c.status === 'idle').length,
    };

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div>
                    <h1 className="text-2xl font-bold text-white">Contacts</h1>
                    <p className="text-sm text-white/40 mt-1">Team members, agents, and external contacts</p>
                </div>

                {/* Stats */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardContent className="p-4">
                            <p className="text-2xl font-bold text-white">{contacts.length}</p>
                            <p className="text-xs text-white/40">Total Contacts</p>
                        </CardContent>
                    </Card>
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardContent className="p-4">
                            <p className="text-2xl font-bold text-green-400">{statusCounts.active}</p>
                            <p className="text-xs text-white/40">Active</p>
                        </CardContent>
                    </Card>
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardContent className="p-4">
                            <p className="text-2xl font-bold text-yellow-400">{statusCounts.idle}</p>
                            <p className="text-xs text-white/40">Idle</p>
                        </CardContent>
                    </Card>
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardContent className="p-4">
                            <p className="text-2xl font-bold text-white">{CATEGORIES.length}</p>
                            <p className="text-xs text-white/40">Categories</p>
                        </CardContent>
                    </Card>
                </div>

                {/* Filters */}
                <div className="flex flex-col sm:flex-row gap-3">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/30" />
                        <Input
                            placeholder="Search contacts..."
                            value={searchQuery}
                            onChange={e => setSearchQuery(e.target.value)}
                            className="pl-9 bg-white/5 border-white/10 text-white placeholder:text-white/30"
                        />
                    </div>
                    <div className="flex gap-2 flex-wrap">
                        <button
                            onClick={() => setCategoryFilter('All')}
                            className={cn(
                                "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors",
                                categoryFilter === 'All' ? "bg-white/10 text-white" : "bg-white/5 text-white/40 hover:text-white/60"
                            )}
                        >
                            All
                        </button>
                        {CATEGORIES.map(cat => (
                            <button
                                key={cat.name}
                                onClick={() => setCategoryFilter(cat.name)}
                                className={cn(
                                    "px-3 py-1.5 rounded-lg text-xs font-medium transition-colors flex items-center gap-1.5",
                                    categoryFilter === cat.name ? "bg-white/10 text-white" : "bg-white/5 text-white/40 hover:text-white/60"
                                )}
                            >
                                <cat.icon className="w-3.5 h-3.5" />
                                {cat.name}
                            </button>
                        ))}
                    </div>
                </div>

                {/* Contacts Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filteredContacts.map(contact => (
                        <ContactCard
                            key={contact.id}
                            contact={contact}
                            onClick={setSelectedContact}
                        />
                    ))}
                </div>

                {filteredContacts.length === 0 && (
                    <div className="flex flex-col items-center justify-center py-16 text-white/30">
                        <Users className="w-12 h-12 mb-3" />
                        <p className="text-sm">No contacts found</p>
                        <p className="text-xs mt-1">Try adjusting your search or filters</p>
                    </div>
                )}

                {/* Contact Detail Modal */}
                <ContactDetail contact={selectedContact} onClose={() => setSelectedContact(null)} />
            </div>
        
    );
}
