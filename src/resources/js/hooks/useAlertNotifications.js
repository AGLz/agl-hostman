import { useEffect, useCallback, useState } from 'react';
import { useWebSocket } from './useWebSocket';

/**
 * useAlertNotifications - Custom hook for browser notifications
 *
 * Features:
 * - Browser Notification API integration
 * - Sound alerts for critical notifications
 * - Do Not Disturb hours support
 * - Badge count for unread alerts
 * - WebSocket listener for new alerts
 *
 * @param {Object} options
 * @param {boolean} options.enabled - Enable notifications (default: true)
 * @param {boolean} options.soundEnabled - Enable sound alerts (default: true)
 * @param {string} options.soundUrl - URL to critical alert sound
 * @param {string} options.dndStart - DND start time (HH:MM format)
 * @param {string} options.dndEnd - DND end time (HH:MM format)
 * @returns {Object} Notification state and actions
 */
export function useAlertNotifications({
    enabled = true,
    soundEnabled = true,
    soundUrl = '/sounds/alert-critical.mp3',
    dndStart = '22:00',
    dndEnd = '08:00'
} = {}) {
    const [permission, setPermission] = useState('default');
    const [unreadCount, setUnreadCount] = useState(0);
    const [audioElement, setAudioElement] = useState(null);

    // WebSocket connection for real-time alerts
    const { connected, lastMessage } = useWebSocket({
        channel: 'alerts',
        events: ['alert.created']
    });

    /**
     * Request notification permission
     */
    const requestPermission = useCallback(async () => {
        if (!('Notification' in window)) {
            console.warn('Browser does not support notifications');
            return false;
        }

        const result = await Notification.requestPermission();
        setPermission(result);
        return result === 'granted';
    }, []);

    /**
     * Check if currently in Do Not Disturb hours
     */
    const isInDndHours = useCallback(() => {
        const now = new Date();
        const currentTime = now.getHours() * 60 + now.getMinutes();

        const [dndStartHour, dndStartMin] = dndStart.split(':').map(Number);
        const [dndEndHour, dndEndMin] = dndEnd.split(':').map(Number);

        const dndStartTime = dndStartHour * 60 + dndStartMin;
        const dndEndTime = dndEndHour * 60 + dndEndMin;

        // Handle overnight DND (e.g., 22:00 to 08:00)
        if (dndStartTime > dndEndTime) {
            return currentTime >= dndStartTime || currentTime < dndEndTime;
        }

        // Normal DND window
        return currentTime >= dndStartTime && currentTime < dndEndTime;
    }, [dndStart, dndEnd]);

    /**
     * Show browser notification
     */
    const showNotification = useCallback((alert) => {
        if (!enabled || permission !== 'granted' || isInDndHours()) {
            return;
        }

        const notification = new Notification(alert.title, {
            body: alert.message,
            icon: '/images/alert-icon.png',
            badge: '/images/alert-badge.png',
            tag: alert.id, // Prevents duplicate notifications
            requireInteraction: alert.type === 'critical',
            data: { alertId: alert.id, type: alert.type }
        });

        notification.onclick = () => {
            window.focus();
            // Navigate to alert center
            window.location.href = '/alerts';
            notification.close();
        };

        // Auto-close after 10 seconds for non-critical alerts
        if (alert.type !== 'critical') {
            setTimeout(() => notification.close(), 10000);
        }
    }, [enabled, permission, isInDndHours]);

    /**
     * Play sound alert
     */
    const playSound = useCallback(() => {
        if (!soundEnabled || !audioElement || isInDndHours()) {
            return;
        }

        audioElement.currentTime = 0;
        audioElement.play().catch(err => {
            console.error('Failed to play alert sound:', err);
        });
    }, [soundEnabled, audioElement, isInDndHours]);

    /**
     * Handle new alert from WebSocket
     */
    useEffect(() => {
        if (!lastMessage || lastMessage.event !== 'alert.created') {
            return;
        }

        const alert = lastMessage.alert;

        // Only notify for critical and warning alerts
        if (!alert.should_notify) {
            return;
        }

        // Show browser notification
        showNotification(alert);

        // Play sound for critical alerts
        if (alert.type === 'critical') {
            playSound();
        }

        // Increment unread count
        setUnreadCount(prev => prev + 1);
    }, [lastMessage, showNotification, playSound]);

    /**
     * Initialize audio element
     */
    useEffect(() => {
        if (!soundEnabled) return;

        const audio = new Audio(soundUrl);
        audio.preload = 'auto';
        setAudioElement(audio);

        return () => {
            if (audio) {
                audio.pause();
                audio.src = '';
            }
        };
    }, [soundEnabled, soundUrl]);

    /**
     * Initialize notification permission
     */
    useEffect(() => {
        if ('Notification' in window) {
            setPermission(Notification.permission);
        }
    }, []);

    /**
     * Clear unread count
     */
    const clearUnreadCount = useCallback(() => {
        setUnreadCount(0);
    }, []);

    return {
        permission,
        requestPermission,
        unreadCount,
        clearUnreadCount,
        connected,
        isInDndHours: isInDndHours()
    };
}
