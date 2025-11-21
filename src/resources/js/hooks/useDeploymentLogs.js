import { useState, useEffect, useRef } from 'react';

export function useDeploymentLogs(applicationId) {
    const [logs, setLogs] = useState([]);
    const [isConnected, setIsConnected] = useState(false);
    const [error, setError] = useState(null);
    const eventSourceRef = useRef(null);

    useEffect(() => {
        if (!applicationId) return;

        // Connect to SSE endpoint for live logs
        const connectToLogs = () => {
            try {
                const url = `/api/dokploy/applications/${applicationId}/logs/stream`;
                eventSourceRef.current = new EventSource(url);

                eventSourceRef.current.onopen = () => {
                    setIsConnected(true);
                    setError(null);
                };

                eventSourceRef.current.onmessage = (event) => {
                    try {
                        const logEntry = JSON.parse(event.data);
                        setLogs((prevLogs) => [...prevLogs, logEntry]);
                    } catch (err) {
                        console.error('Failed to parse log entry:', err);
                    }
                };

                eventSourceRef.current.onerror = (err) => {
                    console.error('SSE error:', err);
                    setIsConnected(false);
                    setError('Connection lost. Retrying...');

                    // Reconnect after 5 seconds
                    setTimeout(() => {
                        if (eventSourceRef.current) {
                            eventSourceRef.current.close();
                        }
                        connectToLogs();
                    }, 5000);
                };
            } catch (err) {
                console.error('Failed to connect to logs:', err);
                setError('Failed to connect to log stream');
            }
        };

        // Fetch initial logs
        const fetchInitialLogs = async () => {
            try {
                const response = await fetch(`/api/dokploy/applications/${applicationId}/logs`, {
                    headers: {
                        'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                    },
                });

                if (response.ok) {
                    const data = await response.json();
                    setLogs(data.logs || []);
                }
            } catch (err) {
                console.error('Failed to fetch initial logs:', err);
            }
        };

        fetchInitialLogs();
        connectToLogs();

        // Cleanup
        return () => {
            if (eventSourceRef.current) {
                eventSourceRef.current.close();
            }
        };
    }, [applicationId]);

    return {
        logs,
        isConnected,
        error,
    };
}

export function useWebSocketLogs(applicationId) {
    const [logs, setLogs] = useState([]);
    const [isConnected, setIsConnected] = useState(false);
    const wsRef = useRef(null);

    useEffect(() => {
        if (!applicationId) return;

        // Connect to WebSocket for real-time logs
        const connectWebSocket = () => {
            try {
                const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
                const url = `${protocol}//${window.location.host}/ws/dokploy/applications/${applicationId}/logs`;

                wsRef.current = new WebSocket(url);

                wsRef.current.onopen = () => {
                    setIsConnected(true);
                    console.log('WebSocket connected');
                };

                wsRef.current.onmessage = (event) => {
                    try {
                        const logEntry = JSON.parse(event.data);
                        setLogs((prevLogs) => [...prevLogs, logEntry]);
                    } catch (err) {
                        console.error('Failed to parse log entry:', err);
                    }
                };

                wsRef.current.onerror = (err) => {
                    console.error('WebSocket error:', err);
                    setIsConnected(false);
                };

                wsRef.current.onclose = () => {
                    setIsConnected(false);
                    console.log('WebSocket disconnected');

                    // Reconnect after 3 seconds
                    setTimeout(connectWebSocket, 3000);
                };
            } catch (err) {
                console.error('Failed to connect WebSocket:', err);
            }
        };

        connectWebSocket();

        // Cleanup
        return () => {
            if (wsRef.current) {
                wsRef.current.close();
            }
        };
    }, [applicationId]);

    return {
        logs,
        isConnected,
    };
}
