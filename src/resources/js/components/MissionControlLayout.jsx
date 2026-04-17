import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { motion } from 'framer-motion';
import {
    LayoutDashboard,
    Kanban,
    Users,
    Brain,
    Calendar,
    Database,
    Settings,
    BookOpen,
    Menu,
    X,
    ChevronRight,
    Zap,
    Bell,
    User,
    LogOut,
    Activity,
    Server,
    Shield,
    Monitor,
    ChevronDown,
    ExternalLink,
    Building2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
} from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';

// Main navigation sections
const navSections = [
    {
        label: 'Dashboards',
        items: [
            { name: 'Mission Control', href: '/mission-control', icon: LayoutDashboard },
            { name: 'Infrastructure', href: '/infrastructure', icon: Server },
            { name: 'Dokploy', href: '/dokploy', icon: Monitor },
            { name: 'AI Command', href: '/archon', icon: Brain },
            { name: 'Monitoring', href: '/monitoring', icon: Activity },
            { name: 'RBAC', href: '/admin/roles', icon: Shield },
        ],
    },
    {
        label: 'Mission Control',
        items: [
            { name: 'Tasks Board', href: '/mission-control/tasks', icon: Kanban },
            { name: 'AI Team', href: '/mission-control/team', icon: Users },
            { name: 'Teams', href: '/mission-control/teams', icon: Building2 },
            { name: 'OpenClaw', href: '/mission-control/openclaw', icon: Brain },
            { name: 'Memory', href: '/mission-control/memory', icon: Database },
            { name: 'Calendar', href: '/mission-control/calendar', icon: Calendar },
            { name: 'Contacts', href: '/mission-control/contacts', icon: BookOpen },
            { name: 'Settings', href: '/mission-control/settings', icon: Settings },
        ],
    },
];

export default function MissionControlLayout({ children }) {
    const location = useLocation();
    const [user, setUser] = useState(null);
    const [agentStatus, setAgentStatus] = useState({ active: 0, total: 0 });
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

    useEffect(() => {
        fetch('/api/user')
            .then(res => {
                if (res.status === 401) {
                    window.location.href = '/auth/login';
                    return null;
                }
                return res.json();
            })
            .then(data => {
                if (data) setUser(data);
            })
            .catch(err => console.error('Failed to fetch user:', err));

        // Fetch agent status
        fetch('/api/agent-status')
            .then(res => res.json())
            .then(data => setAgentStatus(data))
            .catch(() => setAgentStatus({ active: 0, total: 0 }));
    }, []);

    const isActive = (path) => {
        if (path === '/mission-control') return location.pathname === '/mission-control';
        return location.pathname.startsWith(path);
    };

    // Check if any nav item is active
    const isNavActive = (href) => {
        if (href === '/mission-control') return location.pathname === '/mission-control';
        return location.pathname === href || (href !== '/' && location.pathname.startsWith(href));
    };

    const handleLogout = async () => {
        try {
            await fetch('/auth/logout', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || '',
                },
            });
            window.location.href = '/auth/login';
        } catch (error) {
            console.error('Logout failed:', error);
        }
    };

    return (
        <div className="min-h-screen bg-[#0a0a0f] text-white">
            {/* Sidebar for Desktop */}
            <aside className="hidden lg:flex flex-col w-64 fixed h-full border-r border-white/5 bg-[#0d0d14] z-50">
                {/* Logo */}
                <div className="p-6 flex items-center gap-3 border-b border-white/5">
                    <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                        <Zap className="text-white w-4 h-4" />
                    </div>
                    <div>
                        <span className="font-bold text-sm tracking-tight">Mission Control</span>
                        <p className="text-[10px] text-white/40 -mt-1">AGL Infrastructure</p>
                    </div>
                </div>

                {/* Agent Status */}
                <div className="px-4 py-3 border-b border-white/5">
                    <div className="flex items-center justify-between text-xs">
                        <span className="text-white/50">Agents</span>
                        <Badge variant="secondary" className="bg-green-500/10 text-green-400 border-none text-[10px]">
                            {agentStatus.active}/{agentStatus.total} active
                        </Badge>
                    </div>
                    <div className="mt-2 flex gap-1">
                        {Array.from({ length: Math.min(agentStatus.total, 12) }).map((_, i) => (
                            <div
                                key={i}
                                className={cn(
                                    "h-1 flex-1 rounded-full transition-all duration-300",
                                    i < agentStatus.active ? "bg-green-500" : "bg-white/10"
                                )}
                            />
                        ))}
                    </div>
                </div>

                {/* Navigation */}
                <nav className="flex-1 px-3 py-4 space-y-4 overflow-y-auto">
                    {navSections.map((section) => (
                        <div key={section.label}>
                            <p className="px-3 text-[10px] font-semibold text-white/30 uppercase tracking-wider mb-1">
                                {section.label}
                            </p>
                            <div className="space-y-0.5">
                                {section.items.map((item) => (
                                    <Link
                                        key={item.name}
                                        to={item.href}
                                        className={cn(
                                            "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-200 group text-sm font-medium",
                                            isNavActive(item.href)
                                                ? "bg-white/10 text-white shadow-sm"
                                                : "text-white/50 hover:bg-white/5 hover:text-white/80"
                                        )}
                                    >
                                        <item.icon className={cn(
                                            "w-4 h-4",
                                            isNavActive(item.href) ? "text-white" : "group-hover:text-white/80"
                                        )} />
                                        {item.name}
                                        {isNavActive(item.href) && <ChevronRight className="ml-auto w-3 h-3 text-white/40" />}
                                    </Link>
                                ))}
                            </div>
                        </div>
                    ))}
                </nav>

                {/* User */}
                <div className="p-4 border-t border-white/5 bg-white/[0.02]">
                    <div className="flex items-center gap-3">
                        <Avatar className="w-8 h-8 border border-white/10">
                            <AvatarFallback className="bg-white/10 text-white/60 text-xs">
                                {user?.name?.charAt(0) || 'U'}
                            </AvatarFallback>
                        </Avatar>
                        <div className="flex-1 min-w-0">
                            <p className="text-xs font-medium truncate text-white/80">{user?.name || 'Loading...'}</p>
                            <p className="text-[10px] text-white/40 truncate">{user?.email}</p>
                        </div>
                        <Button
                            variant="ghost"
                            size="icon"
                            className="w-7 h-7 text-white/40 hover:text-white"
                            onClick={handleLogout}
                        >
                            <LogOut className="w-3.5 h-3.5" />
                        </Button>
                    </div>
                </div>
            </aside>

            {/* Mobile Header */}
            <header className="lg:hidden flex items-center justify-between p-4 border-b border-white/5 bg-[#0d0d14] sticky top-0 z-40">
                <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
                        <Zap className="text-white w-3.5 h-3.5" />
                    </div>
                    <span className="font-bold text-sm">Mission Control</span>
                </div>
                <Button variant="ghost" size="icon" className="text-white/60" onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}>
                    {isMobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
                </Button>
            </header>

            {/* Mobile Menu */}
            {isMobileMenuOpen && (
                <div className="lg:hidden fixed inset-0 z-50 bg-[#0a0a0f] pt-16">
                    <nav className="p-4 space-y-4 overflow-y-auto max-h-[calc(100vh-4rem)]">
                        {navSections.map((section) => (
                            <div key={section.label}>
                                <p className="text-[10px] font-semibold text-white/30 uppercase tracking-wider mb-2">
                                    {section.label}
                                </p>
                                <div className="space-y-1">
                                    {section.items.map((item) => (
                                        <Link
                                            key={item.name}
                                            to={item.href}
                                            onClick={() => setIsMobileMenuOpen(false)}
                                            className={cn(
                                                "flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium",
                                                isNavActive(item.href)
                                                    ? "bg-white/10 text-white"
                                                    : "text-white/50 hover:bg-white/5"
                                            )}
                                        >
                                            <item.icon className="w-5 h-5" />
                                            {item.name}
                                        </Link>
                                    ))}
                                </div>
                            </div>
                        ))}
                    </nav>
                </div>
            )}

            {/* Main Content */}
            <div className="lg:ml-64 min-h-screen">
                {/* Top Bar */}
                <header className="hidden lg:flex items-center justify-between px-8 py-4 sticky top-0 bg-[#0a0a0f]/80 backdrop-blur-md z-30 border-b border-white/5">
                    <div className="flex items-center gap-2">
                        <Activity className="w-4 h-4 text-green-400" />
                        <span className="text-sm text-white/60">All systems operational</span>
                    </div>
                    <div className="flex items-center gap-4">
                        <Button variant="ghost" size="icon" className="relative text-white/60 hover:text-white">
                            <Bell className="w-4 h-4" />
                            <span className="absolute top-1 right-1 w-1.5 h-1.5 bg-blue-500 rounded-full" />
                        </Button>
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                                <Button variant="ghost" className="flex items-center gap-2 text-white/80 hover:text-white">
                                    <Avatar className="w-7 h-7 border border-white/10">
                                        <AvatarFallback className="bg-white/10 text-white/60 text-xs">
                                            {user?.name?.charAt(0) || 'U'}
                                        </AvatarFallback>
                                    </Avatar>
                                    <span className="text-sm">{user?.name?.split(' ')[0]}</span>
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="bg-[#1a1a24] border-white/10">
                                <DropdownMenuLabel className="text-white/80">
                                    {user?.name}
                                    <p className="text-xs text-white/40 font-normal">{user?.email}</p>
                                </DropdownMenuLabel>
                                <DropdownMenuSeparator className="bg-white/10" />
                                <DropdownMenuItem className="text-white/60" onClick={handleLogout}>
                                    <LogOut className="w-3.5 h-3.5 mr-2" />
                                    Sign out
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </div>
                </header>

                {/* Page Content */}
                <motion.main
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.3 }}
                    className="p-6 lg:p-8"
                >
                    {children}
                </motion.main>
            </div>
        </div>
    );
}
