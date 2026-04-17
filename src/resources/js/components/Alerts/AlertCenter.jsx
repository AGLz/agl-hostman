import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/Components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/Components/ui/tabs';
import { Input } from '@/Components/ui/input';
import { Button } from '@/Components/ui/button';
import { Badge } from '@/Components/ui/badge';
import { AlertCard } from './AlertCard';
import { useAlerts } from '@/hooks/useAlerts';
import { Search, Filter, RefreshCw, CheckCheck, Download } from 'lucide-react';

/**
 * AlertCenter - Main alert management panel
 *
 * Features:
 * - Filter by type (critical/warning/info)
 * - Filter by status (active/acknowledged/resolved)
 * - Filter by source (server/container/network/storage)
 * - Search by title or message
 * - Sort by severity or timestamp
 * - Bulk actions (acknowledge, resolve)
 * - Real-time updates via WebSocket
 * - Export to CSV
 *
 * @param {Object} props
 * @param {Array} props.initialAlerts - Initial alerts from server
 * @param {Function} props.onAlertClick - Callback when alert clicked
 * @param {Function} props.onAcknowledge - Callback when alert acknowledged
 * @param {Function} props.onResolve - Callback when alert resolved
 */
export function AlertCenter({
    initialAlerts = [],
    onAlertClick,
    onAcknowledge,
    onResolve
}) {
    const [activeTab, setActiveTab] = useState('active');
    const [searchQuery, setSearchQuery] = useState('');
    const [filterType, setFilterType] = useState('all');
    const [filterSource, setFilterSource] = useState('all');
    const [selectedAlerts, setSelectedAlerts] = useState([]);

    const {
        alerts,
        stats,
        loading,
        refreshAlerts,
        acknowledgeAlert,
        resolveAlert
    } = useAlerts({
        initialAlerts,
        status: activeTab
    });

    // Filter alerts based on search and filters
    const filteredAlerts = alerts.filter(alert => {
        // Search filter
        if (searchQuery) {
            const query = searchQuery.toLowerCase();
            const matchesTitle = alert.title.toLowerCase().includes(query);
            const matchesMessage = alert.message.toLowerCase().includes(query);
            if (!matchesTitle && !matchesMessage) return false;
        }

        // Type filter
        if (filterType !== 'all' && alert.type !== filterType) {
            return false;
        }

        // Source filter
        if (filterSource !== 'all' && alert.source !== filterSource) {
            return false;
        }

        return true;
    });

    // Sort alerts by severity (high to low), then by timestamp (newest first)
    const sortedAlerts = [...filteredAlerts].sort((a, b) => {
        if (a.severity !== b.severity) {
            return b.severity - a.severity;
        }
        return new Date(b.created_at) - new Date(a.created_at);
    });

    // Handle bulk acknowledge
    const handleBulkAcknowledge = async () => {
        for (const alertId of selectedAlerts) {
            await acknowledgeAlert(alertId);
        }
        setSelectedAlerts([]);
    };

    // Handle bulk resolve
    const handleBulkResolve = async () => {
        for (const alertId of selectedAlerts) {
            await resolveAlert(alertId);
        }
        setSelectedAlerts([]);
    };

    // Export to CSV
    const handleExportCSV = () => {
        const headers = ['Type', 'Title', 'Source', 'Severity', 'Status', 'Created At'];
        const rows = sortedAlerts.map(alert => [
            alert.type,
            alert.title,
            alert.source,
            alert.severity,
            alert.status,
            new Date(alert.created_at).toISOString()
        ]);

        const csv = [
            headers.join(','),
            ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
        ].join('\n');

        const blob = new Blob([csv], { type: 'text/csv' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `alerts-${new Date().toISOString()}.csv`;
        a.click();
        URL.revokeObjectURL(url);
    };

    return (
        <div className="space-y-6">
            {/* Header with stats */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                <Card>
                    <CardHeader className="pb-2">
                        <CardDescription>Total Alerts</CardDescription>
                        <CardTitle className="text-3xl">{stats.total || 0}</CardTitle>
                    </CardHeader>
                </Card>
                <Card>
                    <CardHeader className="pb-2">
                        <CardDescription>Active</CardDescription>
                        <CardTitle className="text-3xl text-red-600">{stats.active || 0}</CardTitle>
                    </CardHeader>
                </Card>
                <Card>
                    <CardHeader className="pb-2">
                        <CardDescription>Acknowledged</CardDescription>
                        <CardTitle className="text-3xl text-yellow-600">{stats.acknowledged || 0}</CardTitle>
                    </CardHeader>
                </Card>
                <Card>
                    <CardHeader className="pb-2">
                        <CardDescription>Resolved Today</CardDescription>
                        <CardTitle className="text-3xl text-green-600">{stats.resolved_today || 0}</CardTitle>
                    </CardHeader>
                </Card>
            </div>

            {/* Main alert panel */}
            <Card>
                <CardHeader>
                    <div className="flex items-center justify-between">
                        <div>
                            <CardTitle>Alert Center</CardTitle>
                            <CardDescription>Manage and monitor infrastructure alerts</CardDescription>
                        </div>
                        <div className="flex gap-2">
                            {selectedAlerts.length > 0 && (
                                <>
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={handleBulkAcknowledge}
                                    >
                                        <CheckCheck className="w-4 h-4 mr-2" />
                                        Acknowledge ({selectedAlerts.length})
                                    </Button>
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={handleBulkResolve}
                                    >
                                        Resolve ({selectedAlerts.length})
                                    </Button>
                                </>
                            )}
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={handleExportCSV}
                            >
                                <Download className="w-4 h-4 mr-2" />
                                Export CSV
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={refreshAlerts}
                                disabled={loading}
                            >
                                <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                            </Button>
                        </div>
                    </div>
                </CardHeader>
                <CardContent>
                    {/* Search and filters */}
                    <div className="flex flex-col md:flex-row gap-4 mb-6">
                        <div className="flex-1 relative">
                            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                            <Input
                                placeholder="Search alerts..."
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                                className="pl-10"
                            />
                        </div>
                        <div className="flex gap-2">
                            <select
                                value={filterType}
                                onChange={(e) => setFilterType(e.target.value)}
                                className="px-3 py-2 border border-gray-300 rounded-md text-sm"
                            >
                                <option value="all">All Types</option>
                                <option value="critical">Critical</option>
                                <option value="warning">Warning</option>
                                <option value="info">Info</option>
                            </select>
                            <select
                                value={filterSource}
                                onChange={(e) => setFilterSource(e.target.value)}
                                className="px-3 py-2 border border-gray-300 rounded-md text-sm"
                            >
                                <option value="all">All Sources</option>
                                <option value="server">Server</option>
                                <option value="container">Container</option>
                                <option value="network">Network</option>
                                <option value="storage">Storage</option>
                                <option value="system">System</option>
                            </select>
                        </div>
                    </div>

                    {/* Tabs */}
                    <Tabs value={activeTab} onValueChange={setActiveTab}>
                        <TabsList className="grid w-full grid-cols-3">
                            <TabsTrigger value="active">
                                Active
                                {stats.active > 0 && (
                                    <Badge variant="destructive" className="ml-2">{stats.active}</Badge>
                                )}
                            </TabsTrigger>
                            <TabsTrigger value="acknowledged">
                                Acknowledged
                                {stats.acknowledged > 0 && (
                                    <Badge variant="secondary" className="ml-2">{stats.acknowledged}</Badge>
                                )}
                            </TabsTrigger>
                            <TabsTrigger value="resolved">Resolved</TabsTrigger>
                        </TabsList>

                        <TabsContent value={activeTab} className="mt-6 space-y-4">
                            {sortedAlerts.length === 0 ? (
                                <div className="text-center py-12 text-gray-500">
                                    {searchQuery || filterType !== 'all' || filterSource !== 'all'
                                        ? 'No alerts match your filters'
                                        : `No ${activeTab} alerts`
                                    }
                                </div>
                            ) : (
                                sortedAlerts.map(alert => (
                                    <AlertCard
                                        key={alert.id}
                                        alert={alert}
                                        onAcknowledge={() => {
                                            acknowledgeAlert(alert.id);
                                            onAcknowledge?.(alert.id);
                                        }}
                                        onResolve={() => {
                                            resolveAlert(alert.id);
                                            onResolve?.(alert.id);
                                        }}
                                        onSelect={(selected) => {
                                            if (selected) {
                                                setSelectedAlerts([...selectedAlerts, alert.id]);
                                            } else {
                                                setSelectedAlerts(selectedAlerts.filter(id => id !== alert.id));
                                            }
                                        }}
                                        selected={selectedAlerts.includes(alert.id)}
                                        onClick={() => onAlertClick?.(alert)}
                                    />
                                ))
                            )}
                        </TabsContent>
                    </Tabs>
                </CardContent>
            </Card>
        </div>
    );
}
