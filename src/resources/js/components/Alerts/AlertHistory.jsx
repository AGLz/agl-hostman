import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/Components/ui/card';
import { Button } from '@/Components/ui/button';
import { Badge } from '@/Components/ui/badge';
import {
    Clock, Filter, Download, ChevronLeft, ChevronRight,
    Calendar, AlertCircle, CheckCircle, XCircle
} from 'lucide-react';
import axios from 'axios';

/**
 * AlertHistory - Historical timeline view component
 *
 * Features:
 * - Timeline visualization with vertical connector lines
 * - Filter by date range (7d/30d/90d/custom)
 * - Export to CSV functionality
 * - Pagination (20 per page)
 * - Status indicators (active/acknowledged/resolved)
 * - Relative and absolute timestamps
 *
 * @param {Object} props
 * @param {number} props.days - Initial days to load (default: 7)
 */
export function AlertHistory({ days = 7 }) {
    const [alerts, setAlerts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [currentPage, setCurrentPage] = useState(1);
    const [totalPages, setTotalPages] = useState(1);
    const [dateRange, setDateRange] = useState(days);
    const [customStartDate, setCustomStartDate] = useState('');
    const [customEndDate, setCustomEndDate] = useState('');
    const [showCustomDate, setShowCustomDate] = useState(false);

    const perPage = 20;

    // Fetch historical alerts
    const fetchHistory = async (page = 1, customDays = null) => {
        setLoading(true);
        try {
            const params = {
                page,
                per_page: perPage,
                days: customDays || dateRange
            };

            if (showCustomDate && customStartDate && customEndDate) {
                params.start_date = customStartDate;
                params.end_date = customEndDate;
                delete params.days;
            }

            const response = await axios.get('/api/alerts/history', { params });
            setAlerts(response.data.data || []);
            setCurrentPage(response.data.current_page || 1);
            setTotalPages(response.data.last_page || 1);
        } catch (error) {
            console.error('Failed to fetch alert history:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchHistory(1);
    }, [dateRange, showCustomDate]);

    // Export to CSV
    const handleExportCSV = async () => {
        try {
            const params = {
                days: dateRange,
                format: 'csv'
            };

            if (showCustomDate && customStartDate && customEndDate) {
                params.start_date = customStartDate;
                params.end_date = customEndDate;
                delete params.days;
            }

            const response = await axios.get('/api/alerts/history', {
                params,
                responseType: 'blob'
            });

            const url = window.URL.createObjectURL(new Blob([response.data]));
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `alert-history-${new Date().toISOString().split('T')[0]}.csv`);
            document.body.appendChild(link);
            link.click();
            link.remove();
        } catch (error) {
            console.error('Failed to export CSV:', error);
        }
    };

    // Get status icon and color
    const getStatusDisplay = (status) => {
        switch (status) {
            case 'active':
                return {
                    icon: <AlertCircle className="w-4 h-4" />,
                    color: 'text-red-600 bg-red-100',
                    label: 'Active'
                };
            case 'acknowledged':
                return {
                    icon: <CheckCircle className="w-4 h-4" />,
                    color: 'text-yellow-600 bg-yellow-100',
                    label: 'Acknowledged'
                };
            case 'resolved':
                return {
                    icon: <XCircle className="w-4 h-4" />,
                    color: 'text-green-600 bg-green-100',
                    label: 'Resolved'
                };
            default:
                return {
                    icon: <AlertCircle className="w-4 h-4" />,
                    color: 'text-gray-600 bg-gray-100',
                    label: status
                };
        }
    };

    // Get type color
    const getTypeColor = (type) => {
        switch (type) {
            case 'critical': return 'bg-red-100 text-red-800 border-red-300';
            case 'warning': return 'bg-yellow-100 text-yellow-800 border-yellow-300';
            case 'info': return 'bg-blue-100 text-blue-800 border-blue-300';
            default: return 'bg-gray-100 text-gray-800 border-gray-300';
        }
    };

    // Format timestamp
    const formatTimestamp = (timestamp) => {
        const date = new Date(timestamp);
        return date.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    // Get relative time
    const getRelativeTime = (timestamp) => {
        const now = new Date();
        const then = new Date(timestamp);
        const diffMs = now - then;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        return `${diffDays}d ago`;
    };

    return (
        <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2">
                        <Clock className="w-5 h-5" />
                        Alert History
                    </CardTitle>

                    {/* Filter controls */}
                    <div className="flex items-center gap-2">
                        <div className="flex items-center gap-1">
                            <Button
                                variant={dateRange === 7 && !showCustomDate ? 'default' : 'outline'}
                                size="sm"
                                onClick={() => {
                                    setDateRange(7);
                                    setShowCustomDate(false);
                                }}
                            >
                                7 days
                            </Button>
                            <Button
                                variant={dateRange === 30 && !showCustomDate ? 'default' : 'outline'}
                                size="sm"
                                onClick={() => {
                                    setDateRange(30);
                                    setShowCustomDate(false);
                                }}
                            >
                                30 days
                            </Button>
                            <Button
                                variant={dateRange === 90 && !showCustomDate ? 'default' : 'outline'}
                                size="sm"
                                onClick={() => {
                                    setDateRange(90);
                                    setShowCustomDate(false);
                                }}
                            >
                                90 days
                            </Button>
                            <Button
                                variant={showCustomDate ? 'default' : 'outline'}
                                size="sm"
                                onClick={() => setShowCustomDate(!showCustomDate)}
                            >
                                <Calendar className="w-4 h-4 mr-1" />
                                Custom
                            </Button>
                        </div>

                        <Button
                            variant="outline"
                            size="sm"
                            onClick={handleExportCSV}
                        >
                            <Download className="w-4 h-4 mr-1" />
                            Export CSV
                        </Button>
                    </div>
                </div>

                {/* Custom date range */}
                {showCustomDate && (
                    <div className="flex items-center gap-2 mt-4">
                        <input
                            type="date"
                            value={customStartDate}
                            onChange={(e) => setCustomStartDate(e.target.value)}
                            className="px-3 py-2 border rounded text-sm"
                        />
                        <span className="text-sm text-gray-500">to</span>
                        <input
                            type="date"
                            value={customEndDate}
                            onChange={(e) => setCustomEndDate(e.target.value)}
                            className="px-3 py-2 border rounded text-sm"
                        />
                        <Button
                            variant="default"
                            size="sm"
                            onClick={() => fetchHistory(1)}
                            disabled={!customStartDate || !customEndDate}
                        >
                            Apply
                        </Button>
                    </div>
                )}
            </CardHeader>

            <CardContent>
                {loading ? (
                    <div className="text-center py-8 text-gray-500">
                        Loading history...
                    </div>
                ) : alerts.length === 0 ? (
                    <div className="text-center py-8 text-gray-500">
                        No alerts found for this time period
                    </div>
                ) : (
                    <>
                        {/* Timeline */}
                        <div className="space-y-4">
                            {alerts.map((alert, index) => {
                                const statusDisplay = getStatusDisplay(alert.status);
                                const isLast = index === alerts.length - 1;

                                return (
                                    <div key={alert.id} className="flex gap-4">
                                        {/* Timeline connector */}
                                        <div className="flex flex-col items-center">
                                            <div className={`p-2 rounded-full ${statusDisplay.color}`}>
                                                {statusDisplay.icon}
                                            </div>
                                            {!isLast && (
                                                <div className="w-0.5 h-full bg-gray-200 my-2" />
                                            )}
                                        </div>

                                        {/* Alert content */}
                                        <div className="flex-grow pb-4">
                                            <div className="bg-white border rounded-lg p-4 hover:shadow-md transition-shadow">
                                                <div className="flex items-start justify-between mb-2">
                                                    <div className="flex-grow">
                                                        <h4 className="font-semibold text-gray-900">
                                                            {alert.title}
                                                        </h4>
                                                        <p className="text-sm text-gray-600 mt-1">
                                                            {alert.message}
                                                        </p>
                                                    </div>
                                                    <Badge className={getTypeColor(alert.type)}>
                                                        {alert.type}
                                                    </Badge>
                                                </div>

                                                {/* Metadata */}
                                                <div className="flex items-center gap-3 text-xs text-gray-500 mt-3">
                                                    <span className="font-medium">
                                                        {formatTimestamp(alert.created_at)}
                                                    </span>
                                                    <span>•</span>
                                                    <span>{getRelativeTime(alert.created_at)}</span>
                                                    <span>•</span>
                                                    <span>Severity: {alert.severity}/100</span>
                                                    {alert.source_id && (
                                                        <>
                                                            <span>•</span>
                                                            <span>{alert.source}: {alert.source_id}</span>
                                                        </>
                                                    )}
                                                    <Badge className={`${statusDisplay.color} ml-auto`}>
                                                        {statusDisplay.label}
                                                    </Badge>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* Pagination */}
                        {totalPages > 1 && (
                            <div className="flex items-center justify-between mt-6 pt-4 border-t">
                                <span className="text-sm text-gray-500">
                                    Page {currentPage} of {totalPages}
                                </span>
                                <div className="flex items-center gap-2">
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={() => fetchHistory(currentPage - 1)}
                                        disabled={currentPage === 1}
                                    >
                                        <ChevronLeft className="w-4 h-4 mr-1" />
                                        Previous
                                    </Button>
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={() => fetchHistory(currentPage + 1)}
                                        disabled={currentPage === totalPages}
                                    >
                                        Next
                                        <ChevronRight className="w-4 h-4 ml-1" />
                                    </Button>
                                </div>
                            </div>
                        )}
                    </>
                )}
            </CardContent>
        </Card>
    );
}
