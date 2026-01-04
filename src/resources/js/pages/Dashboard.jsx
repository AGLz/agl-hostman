import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { 
    Activity, 
    Server, 
    Cpu, 
    Network, 
    Zap, 
    ShieldCheck, 
    Terminal,
    ArrowUpRight,
    Search,
    Filter
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Skeleton } from '@/components/ui/skeleton';

const container = {
    hidden: { opacity: 0 },
    show: {
        opacity: 1,
        transition: {
            staggerChildren: 0.1
        }
    }
};

const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0 }
};

export default function Dashboard() {
    const [locations, setLocations] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchLocations();
    }, []);

    const fetchLocations = async () => {
        try {
            const response = await fetch('/api/infrastructure/locations');
            if (response.ok) {
                const data = await response.json();
                setLocations(data);
            }
        } catch (error) {
            console.error('Failed to fetch locations:', error);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="space-y-8">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight text-gradient">Infrastructure Overview</h1>
                    <p className="text-muted-foreground">Monitor and manage your global hybrid infrastructure</p>
                </div>
                <div className="flex items-center gap-2">
                    <Button variant="outline" size="sm" className="glass">
                        <Filter className="w-4 h-4 mr-2" />
                        Filter
                    </Button>
                    <Button size="sm" className="bg-primary hover:bg-primary/90 shadow-lg shadow-primary/20">
                        <Zap className="w-4 h-4 mr-2" />
                        Quick Action
                    </Button>
                </div>
            </div>

            {/* Stats Grid */}
            <motion.div 
                variants={container}
                initial="hidden"
                animate="show"
                className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4"
            >
                <StatCard 
                    title="Active Servers" 
                    value={locations.filter(l => l.type === 'datacenter').length} 
                    icon={Server}
                    trend="+2 this month"
                    color="text-blue-500"
                />
                <StatCard 
                    title="Containers" 
                    value={locations.filter(l => l.type === 'container').length} 
                    icon={Cpu}
                    trend="99.9% uptime"
                    color="text-green-500"
                />
                <StatCard 
                    title="Network Status" 
                    value="Optimal" 
                    icon={Network}
                    trend="3 active meshes"
                    color="text-purple-500"
                />
                <StatCard 
                    title="Security" 
                    value="Protected" 
                    icon={ShieldCheck}
                    trend="Zero threats"
                    color="text-amber-500"
                />
            </motion.div>

            <Tabs defaultValue="locations" className="w-full">
                <div className="flex items-center justify-between mb-4">
                    <TabsList className="glass p-1">
                        <TabsTrigger value="locations">Locations</TabsTrigger>
                        <TabsTrigger value="performance">Performance</TabsTrigger>
                        <TabsTrigger value="security">Security Log</TabsTrigger>
                    </TabsList>
                </div>

                <TabsContent value="locations" className="mt-0">
                    <Card className="glass border-none shadow-2xl overflow-hidden">
                        <CardHeader className="flex flex-row items-center justify-between">
                            <div>
                                <CardTitle>Physical & Virtual Locations</CardTitle>
                                <CardDescription>Managing connectivity across Proxmox and WireGuard</CardDescription>
                            </div>
                            <Button variant="ghost" size="sm" className="text-primary">
                                View Map <ArrowUpRight className="ml-1 w-4 h-4" />
                            </Button>
                        </CardHeader>
                        <CardContent>
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                                {loading ? (
                                    Array(6).fill(0).map((_, i) => (
                                        <div key={i} className="space-y-3">
                                            <Skeleton className="h-24 w-full rounded-xl" />
                                            <Skeleton className="h-4 w-3/4" />
                                        </div>
                                    ))
                                ) : (
                                    locations.map((location) => (
                                        <LocationDetails key={location.id} location={location} />
                                    ))
                                )}
                            </div>
                        </CardContent>
                    </Card>
                </TabsContent>

                <TabsContent value="performance">
                    <Card className="glass border-none">
                        <CardHeader>
                            <CardTitle>Resource Utilization</CardTitle>
                            <CardDescription>Real-time cluster performance metrics</CardDescription>
                        </CardHeader>
                        <CardContent className="h-64 flex items-center justify-center text-muted-foreground italic">
                            Charts and detailed metrics loading...
                        </CardContent>
                    </Card>
                </TabsContent>

                <TabsContent value="security">
                    <Card className="glass border-none">
                        <CardHeader>
                            <CardTitle>Audit Log</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="space-y-4">
                                <LogItem action="User Login" user="Andre G." time="2 mins ago" />
                                <LogItem action="SSH Access" user="System" time="15 mins ago" />
                                <LogItem action="Config Update" user="Service-Account" time="1 hour ago" />
                            </div>
                        </CardContent>
                    </Card>
                </TabsContent>
            </Tabs>
        </div>
    );
}

function StatCard({ title, value, icon: Icon, trend, color }) {
    return (
        <motion.div variants={item}>
            <Card className="glass border-none hover:shadow-2xl transition-all duration-300 hover:-translate-y-1">
                <CardContent className="p-6">
                    <div className="flex items-center justify-between mb-4">
                        <div className={cn("p-2 rounded-lg bg-gray-100 dark:bg-gray-800", color)}>
                            <Icon className="w-5 h-5" />
                        </div>
                        <Badge variant="secondary" className="bg-green-100 text-green-700 hover:bg-green-200 border-none">
                            {trend}
                        </Badge>
                    </div>
                    <div>
                        <p className="text-sm font-medium text-muted-foreground">{title}</p>
                        <h3 className="text-2xl font-bold">{value}</h3>
                    </div>
                </CardContent>
            </Card>
        </motion.div>
    );
}

function LocationDetails({ location }) {
    const isDatacenter = location.type === 'datacenter';
    
    return (
        <motion.div 
            variants={item}
            className="group relative p-6 rounded-2xl border bg-card/30 hover:bg-card/50 transition-all duration-300"
        >
            <div className="flex items-start justify-between mb-4">
                <div className={cn(
                    "w-12 h-12 rounded-xl flex items-center justify-center text-white shadow-lg",
                    isDatacenter ? "bg-blue-600 shadow-blue-500/20" : "bg-purple-600 shadow-purple-500/20"
                )}>
                    {isDatacenter ? <Server className="w-6 h-6" /> : <Terminal className="w-6 h-6" />}
                </div>
                <Badge variant="outline" className="capitalize bg-background/50">
                    {location.type}
                </Badge>
            </div>
            
            <h4 className="text-lg font-bold mb-1">{location.code}</h4>
            <p className="text-sm text-foreground/80 mb-2">{location.name}</p>
            <p className="text-xs text-muted-foreground line-clamp-2">{location.description}</p>
            
            <div className="mt-6 pt-4 border-t flex items-center justify-between text-xs font-medium">
                <span className="text-muted-foreground">Network</span>
                <span>{location.ip_range || 'Mesh Only'}</span>
            </div>
        </motion.div>
    );
}

function LogItem({ action, user, time }) {
    return (
        <div className="flex items-center justify-between p-3 rounded-lg hover:bg-muted/50 transition-colors">
            <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-primary" />
                <span className="text-sm font-medium">{action}</span>
            </div>
            <div className="flex items-center gap-4 text-xs text-muted-foreground">
                <span>{user}</span>
                <span>{time}</span>
            </div>
        </div>
    );
}