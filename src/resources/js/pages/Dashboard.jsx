import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Activity, Server, Cpu, HardDrive, Network, Users, Workflow, Brain } from 'lucide-react';

function Dashboard() {
    const [user, setUser] = useState(null);
    const [locations, setLocations] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetchUserData();
        fetchLocations();
    }, []);

    const fetchUserData = async () => {
        try {
            const response = await fetch('/api/user', {
                headers: {
                    'Accept': 'application/json',
                },
            });
            if (response.ok) {
                const data = await response.json();
                setUser(data);
            }
        } catch (error) {
            console.error('Failed to fetch user data:', error);
        }
    };

    const fetchLocations = async () => {
        try {
            const response = await fetch('/api/infrastructure/locations', {
                headers: {
                    'Accept': 'application/json',
                },
            });
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

    const triggerMonitoring = async () => {
        const servers = locations
            .filter(loc => loc.type === 'datacenter')
            .map(loc => loc.code);

        try {
            const response = await fetch('/api/n8n/monitoring', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                },
                body: JSON.stringify({ servers }),
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('Monitoring triggered:', data);
            }
        } catch (error) {
            console.error('Failed to trigger monitoring:', error);
        }
    };

    return (
        <div className="min-h-screen bg-gray-50">
            {/* Header */}
            <header className="bg-white shadow">
                <div className="max-w-7xl mx-auto px-4 py-6 sm:px-6 lg:px-8">
                    <div className="flex justify-between items-center">
                        <h1 className="text-3xl font-bold text-gray-900">
                            AGL Infrastructure Admin
                        </h1>
                        <div className="flex items-center space-x-4">
                            <span className="text-sm text-gray-500">
                                {user ? `${user.name} (${user.email})` : 'Loading...'}
                            </span>
                            <Button variant="outline" size="sm">
                                Logout
                            </Button>
                        </div>
                    </div>
                </div>
            </header>

            {/* Main Content */}
            <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
                {/* Stats Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                    <StatCard
                        icon={<Server className="h-5 w-5" />}
                        title="Servers"
                        value={locations.filter(l => l.type === 'datacenter').length}
                        subtitle="Active datacenters"
                    />
                    <StatCard
                        icon={<Cpu className="h-5 w-5" />}
                        title="Containers"
                        value={locations.filter(l => l.type === 'container').length}
                        subtitle="Running containers"
                    />
                    <StatCard
                        icon={<Network className="h-5 w-5" />}
                        title="Networks"
                        value="3"
                        subtitle="WireGuard, LAN, Tailscale"
                    />
                    <StatCard
                        icon={<Activity className="h-5 w-5" />}
                        title="Status"
                        value="Healthy"
                        subtitle="All systems operational"
                    />
                </div>

                {/* Actions Bar */}
                <div className="bg-white shadow rounded-lg p-6 mb-8">
                    <h2 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
                    <div className="flex flex-wrap gap-2">
                        <Button onClick={triggerMonitoring} className="flex items-center gap-2">
                            <Activity className="h-4 w-4" />
                            Monitor Infrastructure
                        </Button>
                        <Button variant="outline" className="flex items-center gap-2">
                            <Workflow className="h-4 w-4" />
                            Execute Workflow
                        </Button>
                        <Button variant="outline" className="flex items-center gap-2">
                            <Brain className="h-4 w-4" />
                            AI Analysis
                        </Button>
                        <Button variant="outline" className="flex items-center gap-2">
                            <Users className="h-4 w-4" />
                            Manage Users
                        </Button>
                    </div>
                </div>

                {/* Locations Grid */}
                <div className="bg-white shadow rounded-lg">
                    <div className="px-6 py-4 border-b">
                        <h2 className="text-lg font-medium text-gray-900">Physical Locations</h2>
                    </div>
                    <div className="p-6">
                        {loading ? (
                            <div className="text-center py-4">Loading...</div>
                        ) : (
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                {locations.map(location => (
                                    <LocationCard key={location.id} location={location} />
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            </main>
        </div>
    );
}

function StatCard({ icon, title, value, subtitle }) {
    return (
        <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-2">
                <div className="text-gray-500">{icon}</div>
                <span className="text-2xl font-bold text-gray-900">{value}</span>
            </div>
            <div className="text-sm font-medium text-gray-900">{title}</div>
            <div className="text-xs text-gray-500">{subtitle}</div>
        </div>
    );
}

function LocationCard({ location }) {
    const getTypeIcon = () => {
        switch (location.type) {
            case 'datacenter':
                return <Server className="h-4 w-4" />;
            case 'container':
                return <Cpu className="h-4 w-4" />;
            case 'remote':
                return <Network className="h-4 w-4" />;
            default:
                return <HardDrive className="h-4 w-4" />;
        }
    };

    const getTypeColor = () => {
        switch (location.type) {
            case 'datacenter':
                return 'bg-blue-100 text-blue-800';
            case 'container':
                return 'bg-green-100 text-green-800';
            case 'remote':
                return 'bg-purple-100 text-purple-800';
            default:
                return 'bg-gray-100 text-gray-800';
        }
    };

    return (
        <div className="border rounded-lg p-4 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between mb-2">
                <div className="flex items-center gap-2">
                    {getTypeIcon()}
                    <h3 className="font-medium text-gray-900">{location.code}</h3>
                </div>
                <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${getTypeColor()}`}>
                    {location.type}
                </span>
            </div>
            <p className="text-sm text-gray-600 mb-2">{location.name}</p>
            <p className="text-xs text-gray-500">{location.description}</p>
            {location.ip_range && (
                <p className="text-xs text-gray-400 mt-2">IP: {location.ip_range}</p>
            )}
        </div>
    );
}

export default Dashboard;