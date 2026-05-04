import React, { useEffect, useState } from 'react';
import { X, AlertCircle, AlertTriangle, Info, CheckCircle } from 'lucide-react';
import { Card, CardContent } from '@/Components/ui/card';
import { Button } from '@/Components/ui/button';

/**
 * AlertNotification - Toast notification component
 *
 * Features:
 * - Auto-dismiss timing (5s info, 10s warning, manual critical)
 * - Sound alert for critical (optional)
 * - Inline acknowledge/resolve buttons
 * - Stack limit: Max 3 simultaneous
 * - Position: Top-right corner
 * - Slide-in animation
 *
 * @param {Object} props
 * @param {Object} props.alert - Alert object
 * @param {Function} props.onAcknowledge - Callback when acknowledged
 * @param {Function} props.onResolve - Callback when resolved
 * @param {Function} props.onDismiss - Callback when dismissed
 * @param {boolean} props.soundEnabled - Play sound for critical alerts
 * @param {number} props.index - Position in stack (0 = top)
 */
export function AlertNotification({
    alert,
    onAcknowledge,
    onResolve,
    onDismiss,
    soundEnabled = true,
    index = 0
}) {
    const [isVisible, setIsVisible] = useState(false);
    const [isExiting, setIsExiting] = useState(false);

    // Auto-dismiss timing based on alert type
    const getAutoDismissDelay = (type) => {
        switch (type) {
            case 'info': return 5000; // 5 seconds
            case 'warning': return 10000; // 10 seconds
            case 'critical': return null; // Manual dismiss only
            default: return 5000;
        }
    };

    // Get icon based on alert type
    const getIcon = (type) => {
        const iconClass = "w-5 h-5";
        switch (type) {
            case 'critical': return <AlertCircle className={`${iconClass} text-red-600`} />;
            case 'warning': return <AlertTriangle className={`${iconClass} text-yellow-600`} />;
            case 'info': return <Info className={`${iconClass} text-blue-600`} />;
            default: return <AlertCircle className={`${iconClass} text-gray-600`} />;
        }
    };

    // Get background color based on alert type
    const getBackgroundColor = (type) => {
        switch (type) {
            case 'critical': return 'bg-red-50 border-red-300';
            case 'warning': return 'bg-yellow-50 border-yellow-300';
            case 'info': return 'bg-blue-50 border-blue-300';
            default: return 'bg-gray-50 border-gray-300';
        }
    };

    // Play sound for critical alerts
    useEffect(() => {
        if (soundEnabled && alert.type === 'critical') {
            const audio = new Audio('/sounds/alert-critical.mp3');
            audio.play().catch(err => {
                console.error('Failed to play alert sound:', err);
            });
        }
    }, [soundEnabled, alert.type]);

    // Slide-in animation
    useEffect(() => {
        setTimeout(() => setIsVisible(true), 10);
    }, []);

    // Auto-dismiss timer
    useEffect(() => {
        const delay = getAutoDismissDelay(alert.type);
        if (delay === null) return;

        const timer = setTimeout(() => {
            handleDismiss();
        }, delay);

        return () => clearTimeout(timer);
    }, [alert.type]);

    const handleDismiss = () => {
        setIsExiting(true);
        setTimeout(() => {
            onDismiss?.();
        }, 300); // Match animation duration
    };

    const handleAcknowledge = () => {
        onAcknowledge?.();
        handleDismiss();
    };

    const handleResolve = () => {
        onResolve?.();
        handleDismiss();
    };

    // Calculate vertical position based on index (stacking)
    const topPosition = 16 + (index * 100); // 16px base + 100px per notification

    return (
        <div
            className={`
                fixed right-4 z-50 w-96
                transition-all duration-300 ease-in-out
                ${isVisible && !isExiting ? 'translate-x-0 opacity-100' : 'translate-x-full opacity-0'}
            `}
            style={{ top: `${topPosition}px` }}
        >
            <Card className={`border-l-4 shadow-lg ${getBackgroundColor(alert.type)}`}>
                <CardContent className="p-4">
                    <div className="flex items-start gap-3">
                        {/* Icon */}
                        <div className="flex-shrink-0 mt-0.5">
                            {getIcon(alert.type)}
                        </div>

                        {/* Content */}
                        <div className="flex-grow min-w-0">
                            <div className="flex items-start justify-between gap-2 mb-1">
                                <h4 className="font-semibold text-gray-900 text-sm">
                                    {alert.title}
                                </h4>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    onClick={handleDismiss}
                                    className="h-5 w-5 p-0 hover:bg-gray-200"
                                >
                                    <X className="w-4 h-4" />
                                </Button>
                            </div>

                            <p className="text-sm text-gray-700 mb-3 line-clamp-2">
                                {alert.message}
                            </p>

                            {/* Action buttons */}
                            <div className="flex items-center gap-2">
                                {alert.status === 'active' && (
                                    <>
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={handleAcknowledge}
                                            className="h-7 text-xs"
                                        >
                                            <CheckCircle className="w-3 h-3 mr-1" />
                                            Acknowledge
                                        </Button>
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={handleResolve}
                                            className="h-7 text-xs"
                                        >
                                            Resolve
                                        </Button>
                                    </>
                                )}
                            </div>

                            {/* Auto-dismiss indicator */}
                            {getAutoDismissDelay(alert.type) !== null && (
                                <div className="mt-2">
                                    <div className="h-1 bg-gray-200 rounded-full overflow-hidden">
                                        <div
                                            className="h-full bg-gray-400 rounded-full animate-shrink"
                                            style={{
                                                animationDuration: `${getAutoDismissDelay(alert.type)}ms`
                                            }}
                                        />
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </CardContent>
            </Card>
        </div>
    );
}

/**
 * AlertNotificationStack - Container for managing multiple notifications
 *
 * Features:
 * - Stack limit: Max 3 simultaneous
 * - Auto-dismiss oldest when limit reached
 * - Position management
 *
 * @param {Object} props
 * @param {Array} props.alerts - Array of alerts to display
 * @param {Function} props.onAcknowledge - Callback when acknowledged
 * @param {Function} props.onResolve - Callback when resolved
 * @param {Function} props.onDismiss - Callback when dismissed
 * @param {boolean} props.soundEnabled - Play sound for critical alerts
 * @param {number} props.maxStack - Maximum simultaneous notifications (default: 3)
 */
export function AlertNotificationStack({
    alerts,
    onAcknowledge,
    onResolve,
    onDismiss,
    soundEnabled = true,
    maxStack = 3
}) {
    // Limit to maxStack most recent alerts
    const visibleAlerts = alerts.slice(0, maxStack);

    return (
        <>
            {visibleAlerts.map((alert, index) => (
                <AlertNotification
                    key={alert.id}
                    alert={alert}
                    onAcknowledge={() => onAcknowledge?.(alert.id)}
                    onResolve={() => onResolve?.(alert.id)}
                    onDismiss={() => onDismiss?.(alert.id)}
                    soundEnabled={soundEnabled}
                    index={index}
                />
            ))}
        </>
    );
}
