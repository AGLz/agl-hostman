import React from 'react';
import { Card, CardContent } from '@/Components/ui/card';
import { Badge } from '@/Components/ui/badge';
import { Button } from '@/Components/ui/button';
import { Checkbox } from '@/Components/ui/checkbox';
import {
    Server, Box, Network, HardDrive, AlertCircle, CheckCircle, Clock, VolumeX
} from 'lucide-react';

/**
 * AlertCard - Individual alert display card
 *
 * Features:
 * - Color-coded left border by severity
 * - Icon by source type
 * - Timestamp with relative time
 * - Quick actions: Acknowledge, Resolve, Mute (15m/1h/24h)
 * - Metadata display on hover
 * - Checkbox for bulk selection
 *
 * @param {Object} props
 * @param {Object} props.alert - Alert object
 * @param {Function} props.onAcknowledge - Callback when acknowledged
 * @param {Function} props.onResolve - Callback when resolved
 * @param {Function} props.onMute - Callback when muted
 * @param {Function} props.onSelect - Callback when checkbox toggled
 * @param {boolean} props.selected - Whether alert is selected
 * @param {Function} props.onClick - Callback when card clicked
 */
export function AlertCard({
    alert,
    onAcknowledge,
    onResolve,
    onMute,
    onSelect,
    selected = false,
    onClick
}) {
    const getSourceIcon = (source) => {
        const iconClass = "w-5 h-5";
        switch (source) {
            case 'server': return <Server className={iconClass} />;
            case 'container': return <Box className={iconClass} />;
            case 'network': return <Network className={iconClass} />;
            case 'storage': return <HardDrive className={iconClass} />;
            default: return <AlertCircle className={iconClass} />;
        }
    };

    const getSeverityColor = (severity) => {
        if (severity >= 90) return 'border-l-red-600 bg-red-50';
        if (severity >= 70) return 'border-l-orange-500 bg-orange-50';
        if (severity >= 40) return 'border-l-yellow-500 bg-yellow-50';
        return 'border-l-blue-500 bg-blue-50';
    };

    const getTypeColor = (type) => {
        switch (type) {
            case 'critical': return 'bg-red-100 text-red-800 border-red-300';
            case 'warning': return 'bg-yellow-100 text-yellow-800 border-yellow-300';
            case 'info': return 'bg-blue-100 text-blue-800 border-blue-300';
            default: return 'bg-gray-100 text-gray-800 border-gray-300';
        }
    };

    const getRelativeTime = (timestamp) => {
        const now = new Date();
        const then = new Date(timestamp);
        const diffMs = now - then;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 1) return 'just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        return `${diffDays}d ago`;
    };

    const canAcknowledge = alert.status === 'active';
    const canResolve = alert.status !== 'resolved';

    return (
        <Card
            className={`border-l-4 ${getSeverityColor(alert.severity)} hover:shadow-md transition-shadow cursor-pointer`}
            onClick={onClick}
        >
            <CardContent className="p-4">
                <div className="flex items-start gap-4">
                    {/* Selection checkbox */}
                    <Checkbox
                        checked={selected}
                        onCheckedChange={(checked) => {
                            onSelect?.(checked);
                        }}
                        onClick={(e) => e.stopPropagation()}
                        className="mt-1"
                    />

                    {/* Source icon */}
                    <div className="flex-shrink-0 mt-1">
                        {getSourceIcon(alert.source)}
                    </div>

                    {/* Alert content */}
                    <div className="flex-grow min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-2">
                            <div className="flex-grow min-w-0">
                                <h3 className="font-semibold text-gray-900 truncate">{alert.title}</h3>
                                <p className="text-sm text-gray-600 line-clamp-2">{alert.message}</p>
                            </div>
                            <Badge className={`flex-shrink-0 ${getTypeColor(alert.type)}`}>
                                {alert.type}
                            </Badge>
                        </div>

                        {/* Metadata */}
                        <div className="flex items-center gap-3 text-xs text-gray-500 mb-3">
                            <span className="flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                {getRelativeTime(alert.created_at)}
                            </span>
                            {alert.source_id && (
                                <span>• {alert.source}: {alert.source_id}</span>
                            )}
                            <span>• Severity: {alert.severity}/100</span>
                            {alert.status === 'acknowledged' && (
                                <span className="flex items-center gap-1 text-yellow-600">
                                    <CheckCircle className="w-3 h-3" />
                                    Acknowledged
                                </span>
                            )}
                            {alert.muted_until && new Date(alert.muted_until) > new Date() && (
                                <span className="flex items-center gap-1 text-gray-600">
                                    <VolumeX className="w-3 h-3" />
                                    Muted
                                </span>
                            )}
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
                            {canAcknowledge && (
                                <Button
                                    variant="outline"
                                    size="sm"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        onAcknowledge?.();
                                    }}
                                    className="h-7 text-xs"
                                >
                                    Acknowledge
                                </Button>
                            )}
                            {canResolve && (
                                <Button
                                    variant="outline"
                                    size="sm"
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        onResolve?.();
                                    }}
                                    className="h-7 text-xs"
                                >
                                    Resolve
                                </Button>
                            )}
                            {alert.status === 'active' && (
                                <div className="relative group">
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        className="h-7 text-xs"
                                    >
                                        Mute ▼
                                    </Button>
                                    <div className="hidden group-hover:block absolute left-0 top-full mt-1 bg-white border rounded shadow-lg z-10">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                onMute?.(15);
                                            }}
                                            className="w-full justify-start text-xs"
                                        >
                                            15 minutes
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                onMute?.(60);
                                            }}
                                            className="w-full justify-start text-xs"
                                        >
                                            1 hour
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                onMute?.(1440);
                                            }}
                                            className="w-full justify-start text-xs"
                                        >
                                            24 hours
                                        </Button>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            </CardContent>
        </Card>
    );
}
