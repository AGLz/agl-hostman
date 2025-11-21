/**
 * Dashboard JavaScript - Real-time Updates & Interactivity
 * AGL Infrastructure Admin Platform - Phase 4
 *
 * Features:
 * - Laravel Echo real-time broadcasting
 * - Toast notification system
 * - Chart.js global configuration
 * - Dashboard event handlers
 * - Utility functions
 */

(function() {
    'use strict';

    // ========================================
    // Configuration
    // ========================================

    const DASHBOARD_CONFIG = {
        echo: {
            broadcaster: 'pusher',
            key: window.PUSHER_APP_KEY || 'local-key',
            cluster: window.PUSHER_APP_CLUSTER || 'mt1',
            wsHost: window.PUSHER_HOST || window.location.hostname,
            wsPort: window.PUSHER_PORT || 6001,
            wssPort: window.PUSHER_PORT || 6001,
            forceTLS: window.PUSHER_SCHEME === 'https',
            enabledTransports: ['ws', 'wss'],
            disableStats: true,
        },
        toast: {
            duration: 5000,
            position: 'top-right',
            maxToasts: 5,
        },
        refresh: {
            autoRefreshInterval: 30000, // 30 seconds
            chartUpdateThrottle: 1000, // 1 second
        },
        chart: {
            defaultColors: {
                cpu: 'rgb(59, 130, 246)',      // Blue
                memory: 'rgb(16, 185, 129)',   // Green
                disk: 'rgb(245, 158, 11)',     // Orange
                network: 'rgb(139, 92, 246)',  // Purple
            },
            defaultBackgroundAlpha: 0.1,
        },
    };

    // ========================================
    // Laravel Echo Initialization
    // ========================================

    let echoInstance = null;

    function initializeEcho() {
        if (typeof Echo === 'undefined') {
            console.warn('Laravel Echo not loaded. Real-time updates disabled.');
            return null;
        }

        try {
            echoInstance = new Echo(DASHBOARD_CONFIG.echo);

            // Subscribe to infrastructure alerts channel
            echoInstance.channel('infrastructure-alerts')
                .listen('.ContainerCritical', (event) => {
                    handleContainerCritical(event);
                })
                .listen('.ResourceExhaustionPredicted', (event) => {
                    handleResourceExhaustion(event);
                })
                .listen('.NodeOffline', (event) => {
                    handleNodeOffline(event);
                });

            console.log('Laravel Echo initialized successfully');
            return echoInstance;
        } catch (error) {
            console.error('Failed to initialize Laravel Echo:', error);
            return null;
        }
    }

    // ========================================
    // Event Handlers
    // ========================================

    function handleContainerCritical(event) {
        const message = `Container ${event.container} on ${event.node} is in critical state`;

        showToast('critical', 'Container Critical', message, {
            icon: 'exclamation-circle',
            actions: [
                {
                    label: 'View Details',
                    callback: () => {
                        window.location.href = `/monitoring?node=${event.node}&vmid=${event.vmid}`;
                    }
                }
            ]
        });

        // Trigger Livewire refresh
        if (window.Livewire) {
            window.Livewire.dispatch('containerCritical', event);
        }

        // Update favicon to show alert
        updateFaviconForAlert('critical');

        // Browser notification (if permitted)
        requestNotificationPermission(() => {
            showBrowserNotification('Container Critical', message);
        });
    }

    function handleResourceExhaustion(event) {
        const message = `${event.resource_type} predicted to reach ${Math.round(event.predicted_value)}% in ${event.horizon}`;

        showToast('warning', 'Resource Exhaustion Predicted', message, {
            icon: 'exclamation-triangle',
            actions: [
                {
                    label: 'View Prediction',
                    callback: () => {
                        // Scroll to predictive maintenance widget
                        document.querySelector('[wire\\:id*="predictive-maintenance"]')?.scrollIntoView({ behavior: 'smooth' });
                    }
                }
            ]
        });

        if (window.Livewire) {
            window.Livewire.dispatch('resourceExhaustionPredicted', event);
        }
    }

    function handleNodeOffline(event) {
        const message = `Node ${event.node} is offline`;

        showToast('critical', 'Node Offline', message, {
            icon: 'server',
            persistent: true,
        });

        if (window.Livewire) {
            window.Livewire.dispatch('nodeOffline', event);
        }

        updateFaviconForAlert('critical');
    }

    // ========================================
    // Toast Notification System
    // ========================================

    const toastQueue = [];
    let toastContainer = null;

    function createToastContainer() {
        if (toastContainer) return toastContainer;

        toastContainer = document.createElement('div');
        toastContainer.id = 'toast-container';
        toastContainer.className = 'fixed z-50 space-y-2';

        // Position based on config
        switch (DASHBOARD_CONFIG.toast.position) {
            case 'top-right':
                toastContainer.className += ' top-4 right-4';
                break;
            case 'top-left':
                toastContainer.className += ' top-4 left-4';
                break;
            case 'bottom-right':
                toastContainer.className += ' bottom-4 right-4';
                break;
            case 'bottom-left':
                toastContainer.className += ' bottom-4 left-4';
                break;
        }

        document.body.appendChild(toastContainer);
        return toastContainer;
    }

    function showToast(type, title, message, options = {}) {
        const container = createToastContainer();

        // Remove oldest toast if max reached
        if (toastQueue.length >= DASHBOARD_CONFIG.toast.maxToasts) {
            const oldestToast = toastQueue.shift();
            oldestToast.element.remove();
        }

        const toast = createToastElement(type, title, message, options);
        container.appendChild(toast.element);
        toastQueue.push(toast);

        // Animate in
        setTimeout(() => {
            toast.element.classList.remove('translate-x-full', 'opacity-0');
        }, 10);

        // Auto-dismiss unless persistent
        if (!options.persistent) {
            const duration = options.duration || DASHBOARD_CONFIG.toast.duration;
            toast.dismissTimer = setTimeout(() => {
                dismissToast(toast);
            }, duration);
        }

        return toast;
    }

    function createToastElement(type, title, message, options) {
        const colors = {
            critical: 'bg-red-50 dark:bg-red-900 border-red-200 dark:border-red-700 text-red-800 dark:text-red-200',
            warning: 'bg-yellow-50 dark:bg-yellow-900 border-yellow-200 dark:border-yellow-700 text-yellow-800 dark:text-yellow-200',
            success: 'bg-green-50 dark:bg-green-900 border-green-200 dark:border-green-700 text-green-800 dark:text-green-200',
            info: 'bg-blue-50 dark:bg-blue-900 border-blue-200 dark:border-blue-700 text-blue-800 dark:text-blue-200',
        };

        const icons = {
            'exclamation-circle': '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />',
            'exclamation-triangle': '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />',
            'check-circle': '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />',
            'info-circle': '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />',
            'server': '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01" />',
        };

        const element = document.createElement('div');
        element.className = `transform transition-all duration-300 translate-x-full opacity-0 max-w-md w-full ${colors[type] || colors.info} border-l-4 rounded-lg p-4 shadow-lg`;

        const iconSvg = icons[options.icon || 'info-circle'];

        let actionsHtml = '';
        if (options.actions && options.actions.length > 0) {
            actionsHtml = '<div class="mt-3 flex space-x-2">';
            options.actions.forEach(action => {
                actionsHtml += `
                    <button class="text-sm font-medium underline hover:no-underline" data-action="${action.label}">
                        ${action.label}
                    </button>
                `;
            });
            actionsHtml += '</div>';
        }

        element.innerHTML = `
            <div class="flex">
                <div class="flex-shrink-0">
                    <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        ${iconSvg}
                    </svg>
                </div>
                <div class="ml-3 flex-1">
                    <h3 class="text-sm font-medium">${escapeHtml(title)}</h3>
                    <p class="mt-1 text-sm">${escapeHtml(message)}</p>
                    ${actionsHtml}
                </div>
                <div class="ml-4 flex-shrink-0 flex">
                    <button class="toast-close inline-flex text-gray-400 hover:text-gray-500">
                        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                    </button>
                </div>
            </div>
        `;

        const toast = {
            element: element,
            type: type,
            title: title,
            message: message,
            dismissTimer: null,
        };

        // Close button handler
        element.querySelector('.toast-close').addEventListener('click', () => {
            dismissToast(toast);
        });

        // Action button handlers
        if (options.actions) {
            options.actions.forEach(action => {
                const button = element.querySelector(`[data-action="${action.label}"]`);
                if (button && action.callback) {
                    button.addEventListener('click', () => {
                        action.callback();
                        dismissToast(toast);
                    });
                }
            });
        }

        return toast;
    }

    function dismissToast(toast) {
        if (toast.dismissTimer) {
            clearTimeout(toast.dismissTimer);
        }

        toast.element.classList.add('translate-x-full', 'opacity-0');

        setTimeout(() => {
            toast.element.remove();
            const index = toastQueue.indexOf(toast);
            if (index > -1) {
                toastQueue.splice(index, 1);
            }
        }, 300);
    }

    // ========================================
    // Chart.js Global Configuration
    // ========================================

    function configureChartDefaults() {
        if (typeof Chart === 'undefined') {
            console.warn('Chart.js not loaded. Charts will not be available.');
            return;
        }

        Chart.defaults.font.family = "'Inter', 'system-ui', 'sans-serif'";
        Chart.defaults.color = getComputedStyle(document.documentElement).getPropertyValue('--text-color') || '#6B7280';
        Chart.defaults.responsive = true;
        Chart.defaults.maintainAspectRatio = false;

        // Default animation
        Chart.defaults.animation = {
            duration: 750,
            easing: 'easeInOutQuart',
        };

        // Default tooltip
        Chart.defaults.plugins.tooltip = {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: 'rgba(255, 255, 255, 0.1)',
            borderWidth: 1,
            padding: 12,
            displayColors: true,
            callbacks: {
                label: function(context) {
                    let label = context.dataset.label || '';
                    if (label) {
                        label += ': ';
                    }
                    if (context.parsed.y !== null) {
                        label += context.parsed.y.toFixed(1) + '%';
                    }
                    return label;
                }
            }
        };

        console.log('Chart.js defaults configured');
    }

    // ========================================
    // Browser Notifications
    // ========================================

    function requestNotificationPermission(callback) {
        if (!('Notification' in window)) {
            console.warn('Browser notifications not supported');
            return;
        }

        if (Notification.permission === 'granted') {
            callback();
        } else if (Notification.permission !== 'denied') {
            Notification.requestPermission().then(permission => {
                if (permission === 'granted') {
                    callback();
                }
            });
        }
    }

    function showBrowserNotification(title, body) {
        if (Notification.permission === 'granted') {
            const notification = new Notification(title, {
                body: body,
                icon: '/favicon.ico',
                badge: '/favicon.ico',
                tag: 'infrastructure-alert',
                requireInteraction: false,
            });

            notification.onclick = () => {
                window.focus();
                notification.close();
            };

            setTimeout(() => notification.close(), 5000);
        }
    }

    // ========================================
    // Favicon Alert Indicator
    // ========================================

    let originalFavicon = null;

    function updateFaviconForAlert(severity) {
        if (!originalFavicon) {
            originalFavicon = document.querySelector('link[rel="icon"]')?.href || '/favicon.ico';
        }

        // Create canvas to draw badge
        const canvas = document.createElement('canvas');
        canvas.width = 32;
        canvas.height = 32;
        const ctx = canvas.getContext('2d');

        // Draw red circle for alert
        ctx.fillStyle = severity === 'critical' ? '#EF4444' : '#F59E0B';
        ctx.beginPath();
        ctx.arc(24, 8, 8, 0, 2 * Math.PI);
        ctx.fill();

        // Update favicon
        const link = document.querySelector('link[rel="icon"]') || document.createElement('link');
        link.type = 'image/x-icon';
        link.rel = 'icon';
        link.href = canvas.toDataURL();
        document.head.appendChild(link);

        // Reset after 10 seconds
        setTimeout(() => {
            if (originalFavicon) {
                link.href = originalFavicon;
            }
        }, 10000);
    }

    // ========================================
    // Utility Functions
    // ========================================

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    function formatBytes(bytes, decimals = 2) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
    }

    function formatDuration(seconds) {
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);

        if (days > 0) {
            return `${days}d ${hours}h`;
        } else if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else {
            return `${minutes}m`;
        }
    }

    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    function throttle(func, limit) {
        let inThrottle;
        return function(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }

    // ========================================
    // Dashboard Refresh Logic
    // ========================================

    let autoRefreshTimer = null;

    function startAutoRefresh() {
        if (autoRefreshTimer) {
            clearInterval(autoRefreshTimer);
        }

        autoRefreshTimer = setInterval(() => {
            if (window.Livewire) {
                window.Livewire.dispatch('refreshDashboard');
            }
        }, DASHBOARD_CONFIG.refresh.autoRefreshInterval);

        console.log('Auto-refresh started');
    }

    function stopAutoRefresh() {
        if (autoRefreshTimer) {
            clearInterval(autoRefreshTimer);
            autoRefreshTimer = null;
            console.log('Auto-refresh stopped');
        }
    }

    // ========================================
    // Initialization
    // ========================================

    function initializeDashboard() {
        console.log('Initializing dashboard...');

        // Configure Chart.js
        configureChartDefaults();

        // Initialize Laravel Echo
        initializeEcho();

        // Setup Livewire listeners
        if (window.Livewire) {
            document.addEventListener('livewire:initialized', () => {
                console.log('Livewire initialized');

                // Listen for dashboard events
                window.Livewire.on('alert', (event) => {
                    showToast(event.type || 'info', event.title || 'Alert', event.message || '', event.options || {});
                });

                window.Livewire.on('dashboardUpdated', (event) => {
                    console.log('Dashboard updated:', event);
                });
            });
        }

        // Request notification permission
        requestNotificationPermission(() => {
            console.log('Notification permission granted');
        });

        // Start auto-refresh (optional, Livewire wire:poll handles this)
        // startAutoRefresh();

        console.log('Dashboard initialized successfully');
    }

    // ========================================
    // Public API
    // ========================================

    window.Dashboard = {
        showToast: showToast,
        dismissToast: dismissToast,
        startAutoRefresh: startAutoRefresh,
        stopAutoRefresh: stopAutoRefresh,
        formatBytes: formatBytes,
        formatDuration: formatDuration,
        config: DASHBOARD_CONFIG,
        echo: echoInstance,
    };

    // Auto-initialize on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeDashboard);
    } else {
        initializeDashboard();
    }

})();
