import React, { useState, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
    LayoutDashboard,
    Server,
    Shield,
    Settings,
    LogOut,
    Menu,
    X,
    Bell,
    User,
    ChevronRight,
    Search,
    Brain,
    Activity,
    Zap,
} from 'lucide-react';
import { Button } from './ui/button';
import { Avatar, AvatarFallback, AvatarImage } from './ui/avatar';
import { 
    DropdownMenu, 
    DropdownMenuContent, 
    DropdownMenuItem, 
    DropdownMenuLabel, 
    DropdownMenuSeparator, 
    DropdownMenuTrigger 
} from './ui/dropdown-menu';
import { Sheet, SheetContent, SheetTrigger } from './ui/sheet';
import { cn } from '@/lib/utils';

const sidebarItems = [
    { name: 'Infrastructure', href: '/', icon: LayoutDashboard },
    { name: 'Dokploy', href: '/dokploy', icon: Server },
    { name: 'AI Command', href: '/archon', icon: Brain },
    { name: 'Monitoring', href: '/monitoring', icon: Activity },
    { name: 'RBAC', href: '/admin/roles', icon: Shield },
    { name: 'Mission Control', href: '/mission-control', icon: Zap },
];

export default function DashboardLayout({ children }) {
    const location = useLocation();
    const [user, setUser] = useState(null);
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

    useEffect(() => {
        fetch('/api/user')
            .then(res => res.json())
            .then(data => setUser(data))
            .catch(err => console.error('Failed to fetch user:', err));
    }, []);

    const isActive = (path) => {
        if (path === '/') return location.pathname === '/';
        return location.pathname.startsWith(path);
    };

    const handleLogout = async () => {
        try {
            await fetch('/logout', {
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
        <div className="min-h-screen bg-gradient-premium">
            {/* Sidebar for Desktop */}
            <aside className="hidden lg:flex flex-col w-64 fixed h-full border-r bg-background/50 backdrop-blur-xl z-50">
                <div className="p-6 flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
                        <Shield className="text-primary-foreground w-5 h-5" />
                    </div>
                    <span className="font-bold text-xl tracking-tight">AGL Admin</span>
                </div>

                <nav className="flex-1 px-4 py-4 space-y-1">
                    {sidebarItems.map((item) => (
                        <Link
                            key={item.name}
                            to={item.href}
                            className={cn(
                                "flex items-center gap-3 px-3 py-2 rounded-lg transition-all duration-200 group text-sm font-medium",
                                isActive(item.href)
                                    ? "bg-primary text-primary-foreground shadow-md"
                                    : "text-muted-foreground hover:bg-muted hover:text-foreground"
                            )}
                        >
                            <item.icon className={cn(
                                "w-4 h-4",
                                isActive(item.href) ? "text-primary-foreground" : "group-hover:text-foreground"
                            )} />
                            {item.name}
                            {isActive(item.href) && <ChevronRight className="ml-auto w-3 h-3" />}
                        </Link>
                    ))}
                </nav>

                <div className="p-4 border-t bg-muted/30">
                    <div className="flex items-center gap-3 px-2 py-2">
                        <Avatar className="w-9 h-9 border-2 border-primary/20">
                            <AvatarImage src={user?.avatar_url} />
                            <AvatarFallback className="bg-primary/10 text-primary">
                                {user?.name?.charAt(0) || 'U'}
                            </AvatarFallback>
                        </Avatar>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-semibold truncate">{user?.name || 'Loading...'}</p>
                            <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
                        </div>
                    </div>
                </div>
            </aside>

            {/* Mobile Header */}
            <header className="lg:hidden flex items-center justify-between p-4 border-b bg-background/80 backdrop-blur-lg sticky top-0 z-40">
                <div className="flex items-center gap-2">
                    <Shield className="w-6 h-6 text-primary" />
                    <span className="font-bold">AGL Admin</span>
                </div>
                <Sheet>
                    <SheetTrigger asChild>
                        <Button variant="ghost" size="icon">
                            <Menu className="w-6 h-6" />
                        </Button>
                    </SheetTrigger>
                    <SheetContent side="left" className="w-64 p-0">
                        <div className="p-6 border-b">
                            <span className="font-bold text-xl">AGL Admin</span>
                        </div>
                        <nav className="p-4 space-y-1">
                            {sidebarItems.map((item) => (
                                <Link
                                    key={item.name}
                                    to={item.href}
                                    className={cn(
                                        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium",
                                        isActive(item.href)
                                            ? "bg-primary text-primary-foreground"
                                            : "text-muted-foreground hover:bg-muted"
                                    )}
                                >
                                    <item.icon className="w-4 h-4" />
                                    {item.name}
                                </Link>
                            ))}
                        </nav>
                    </SheetContent>
                </Sheet>
            </header>

            {/* Main Content Area */}
            <div className="lg:ml-64 flex flex-col min-h-screen">
                {/* Desktop Top Header */}
                <header className="hidden lg:flex items-center justify-between px-8 py-4 sticky top-0 bg-background/20 backdrop-blur-md z-30 border-b border-transparent hover:border-border transition-colors duration-300">
                    <div className="flex items-center gap-4 flex-1">
                        <div className="relative group w-full max-w-md">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground group-focus-within:text-primary transition-colors" />
                            <input 
                                type="text" 
                                placeholder="Search infrastructure..." 
                                className="w-full bg-muted/40 border-none rounded-full py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 transition-all"
                            />
                        </div>
                    </div>

                    <div className="flex items-center gap-4">
                        <Button variant="ghost" size="icon" className="relative">
                            <Bell className="w-5 h-5" />
                            <span className="absolute top-2 right-2 w-2 h-2 bg-primary rounded-full border-2 border-background"></span>
                        </Button>
                        
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                                <Button variant="ghost" className="relative h-10 w-10 rounded-full">
                                    <Avatar className="h-10 w-10">
                                        <AvatarImage src={user?.avatar_url} />
                                        <AvatarFallback>{user?.name?.charAt(0)}</AvatarFallback>
                                    </Avatar>
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent className="w-56" align="end" forceMount>
                                <DropdownMenuLabel className="font-normal">
                                    <div className="flex flex-col space-y-1">
                                        <p className="text-sm font-medium leading-none">{user?.name}</p>
                                        <p className="text-xs leading-none text-muted-foreground">
                                            {user?.email}
                                        </p>
                                    </div>
                                </DropdownMenuLabel>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem>
                                    <User className="mr-2 h-4 w-4" />
                                    <span>Profile</span>
                                </DropdownMenuItem>
                                <DropdownMenuItem>
                                    <Settings className="mr-2 h-4 w-4" />
                                    <span>Settings</span>
                                </DropdownMenuItem>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem onClick={handleLogout} className="text-destructive">
                                    <LogOut className="mr-2 h-4 w-4" />
                                    <span>Log out</span>
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </div>
                </header>

                <main className="flex-1 p-4 lg:p-8 animate-in-fade">
                    {children}
                </main>
            </div>
        </div>
    );
}
