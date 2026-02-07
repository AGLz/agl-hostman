import React from 'react';
import { useWebSocket } from '../hooks/useWebSocket';

/**
 * ConnectionStatus Component
 *
 * Displays real-time WebSocket connection status with visual indicators
 * and reconnection countdown
 */
export function ConnectionStatus({ position = 'top-right' }) {
    const {
        isConnected,
        connectionState,
        reconnectAttempts,
        nextReconnectIn,
        reconnect
    } = useWebSocket({
        enableReconnect: true,
        reconnectInterval: 1000,
        maxReconnectInterval: 30000,
        reconnectDecay: 1.5,
        maxReconnectAttempts: 10,
    });

    const getStatusIcon = () => {
        switch (connectionState) {
            case 'connected':
                return (
                    <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 1 1 0 002zm0 4a1 1 0 10-2 1 1 0 002zm0 4a1 1 0 10-2 1 1 0 002z" clipRule="evenodd" />
                    </svg>
                );
            case 'connecting':
            case 'reconnecting':
                return (
                    <svg className="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                );
            case 'disconnected':
            case 'error':
                return (
                    <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293-1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                    </svg>
                );
            default:
                return null;
        }
    };

    const getStatusColor = () => {
        switch (connectionState) {
            case 'connected':
                return 'bg-green-500';
            case 'connecting':
            case 'reconnecting':
                return 'bg-yellow-500';
            case 'disconnected':
            case 'error':
                return 'bg-red-500';
            default:
                return 'bg-gray-500';
        }
    };

    const getStatusText = () => {
        switch (connectionState) {
            case 'connected':
                return 'Connected';
            case 'connecting':
                return 'Connecting...';
            case 'reconnecting':
                return `Reconnecting (${reconnectAttempts}/${10})`;
            case 'disconnected':
                return 'Disconnected';
            case 'error':
                return 'Connection Error';
            default:
                return 'Unknown';
        }
    };

    const formatTime = (ms) => {
        if (!ms) return '';
        const seconds = Math.ceil(ms / 1000);
        return `${seconds}s`;
    };

    const getPositionClasses = () => {
        switch (position) {
            case 'top-left':
                return 'top-4 left-4';
            case 'top-right':
                return 'top-4 right-4';
            case 'bottom-left':
                return 'bottom-4 left-4';
            case 'bottom-right':
                return 'bottom-4 right-4';
            default:
                return 'top-4 right-4';
        }
    };

    return (
        <div className={`fixed ${getPositionClasses()} z-50`}>
            <div className="flex items-center space-x-2 bg-gray-900 text-white px-4 py-2 rounded-lg shadow-lg border border-gray-700">
                {/* Status indicator */}
                <div className="flex items-center space-x-2">
                    <div className={`w-3 h-3 rounded-full ${getStatusColor()}`}>
                        {connectionState === 'connecting' || connectionState === 'reconnecting' ? (
                            <div className="w-full h-full rounded-full animate-ping opacity-75 bg-current" />
                        ) : null}
                    </div>
                    <span className="text-sm font-medium">{getStatusText()}</span>
                </div>

                {/* Reconnection info */}
                {connectionState === 'reconnecting' && nextReconnectIn && (
                    <div className="text-xs text-gray-400">
                        <span>Next attempt in {formatTime(nextReconnectIn)}</span>
                    </div>
                )}

                {/* Manual reconnect button */}
                {connectionState === 'disconnected' || connectionState === 'error' ? (
                    <button
                        onClick={reconnect}
                        className="text-xs bg-blue-600 hover:bg-blue-700 px-3 py-1 rounded transition-colors"
                    >
                        Reconnect
                    </button>
                ) : null}

                {/* Last update timestamp */}
                {isConnected && (
                    <div className="text-xs text-gray-400">
                        <span>Live</span>
                    </div>
                )}
            </div>
        </div>
    );
}

/**
 * Minimal ConnectionStatus Component
 *
 * Smaller version for tight spaces
 */
export function ConnectionStatusMini() {
    const { isConnected, connectionState } = useWebSocket();

    const getStatusColor = () => {
        switch (connectionState) {
            case 'connected':
                return 'bg-green-500';
            case 'connecting':
            case 'reconnecting':
                return 'bg-yellow-500 animate-pulse';
            case 'disconnected':
            case 'error':
                return 'bg-red-500';
            default:
                return 'bg-gray-500';
        }
    };

    return (
        <div className="flex items-center space-x-1" title={`Connection: ${connectionState}`}>
            <div className={`w-2 h-2 rounded-full ${getStatusColor()}`} />
            <span className="text-xs text-gray-500">{connectionState}</span>
        </div>
    );
}

export default ConnectionStatus;
