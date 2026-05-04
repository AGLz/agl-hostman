import React, { useState, useEffect } from 'react';
import { router } from '@inertiajs/react';
import axios from 'axios';

export default function NotificationsIndex() {
    const [channels, setChannels] = useState([]);
    const [rules, setRules] = useState([]);
    const [onCall, setOnCall] = useState(null);
    const [loading, setLoading] = useState(true);
    const [showChannelModal, setShowChannelModal] = useState(false);

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        try {
            const [channelsRes, rulesRes, onCallRes] = await Promise.all([
                axios.get('/api/notifications/channels'),
                axios.get('/api/notifications/rules'),
                axios.get('/api/notifications/on-call/current'),
            ]);

            setChannels(channelsRes.data.channels || []);
            setRules(rulesRes.data.rules || []);
            setOnCall(onCallRes.data.current);
        } catch (error) {
            console.error('Failed to load notifications data:', error);
        } finally {
            setLoading(false);
        }
    };

    const testChannel = async (channelId) => {
        try {
            await axios.post(`/api/notifications/channels/${channelId}/test`);
            alert('Test notification sent successfully!');
        } catch (error) {
            alert('Test notification failed: ' + error.message);
        }
    };

    const toggleChannel = async (channelId, enabled) => {
        try {
            await axios.put(`/api/notifications/channels/${channelId}`, { enabled: !enabled });
            loadData();
        } catch (error) {
            console.error('Failed to toggle channel:', error);
        }
    };

    if (loading) {
        return <div className="p-8">Loading...</div>;
    }

    return (
        <div className="p-8">
            <div className="mb-8">
                <h1 className="text-3xl font-bold mb-2">Smart Notifications</h1>
                <p className="text-gray-600">Manage notification channels, rules, and on-call schedules</p>
            </div>

            {/* On-Call Display */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                <h2 className="text-lg font-semibold mb-2">Current On-Call</h2>
                {onCall ? (
                    <div>
                        <p className="text-xl font-bold">{onCall.engineer_name}</p>
                        <p className="text-sm text-gray-600">{onCall.engineer_email}</p>
                        <p className="text-sm text-gray-500 mt-1">
                            Until: {new Date(onCall.end_time).toLocaleString()}
                        </p>
                    </div>
                ) : (
                    <p className="text-gray-600">No one is currently on-call</p>
                )}
            </div>

            {/* Notification Channels */}
            <div className="bg-white rounded-lg shadow mb-6">
                <div className="p-4 border-b flex justify-between items-center">
                    <h2 className="text-xl font-semibold">Notification Channels</h2>
                    <button
                        onClick={() => setShowChannelModal(true)}
                        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                    >
                        Add Channel
                    </button>
                </div>
                <div className="p-4">
                    {channels.length === 0 ? (
                        <p className="text-gray-500">No channels configured</p>
                    ) : (
                        <div className="space-y-2">
                            {channels.map((channel) => (
                                <div
                                    key={channel.id}
                                    className="flex items-center justify-between p-3 border rounded hover:bg-gray-50"
                                >
                                    <div className="flex items-center space-x-3">
                                        <span className={`w-3 h-3 rounded-full ${channel.enabled ? 'bg-green-500' : 'bg-gray-300'}`}></span>
                                        <div>
                                            <p className="font-medium">{channel.name}</p>
                                            <p className="text-sm text-gray-500">{channel.type}</p>
                                        </div>
                                    </div>
                                    <div className="flex space-x-2">
                                        <button
                                            onClick={() => testChannel(channel.id)}
                                            className="px-3 py-1 text-sm border rounded hover:bg-gray-100"
                                        >
                                            Test
                                        </button>
                                        <button
                                            onClick={() => toggleChannel(channel.id, channel.enabled)}
                                            className={`px-3 py-1 text-sm rounded ${
                                                channel.enabled
                                                    ? 'bg-red-100 text-red-700 hover:bg-red-200'
                                                    : 'bg-green-100 text-green-700 hover:bg-green-200'
                                            }`}
                                        >
                                            {channel.enabled ? 'Disable' : 'Enable'}
                                        </button>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>

            {/* Notification Rules */}
            <div className="bg-white rounded-lg shadow">
                <div className="p-4 border-b">
                    <h2 className="text-xl font-semibold">Notification Rules</h2>
                </div>
                <div className="p-4">
                    {rules.length === 0 ? (
                        <p className="text-gray-500">No rules configured</p>
                    ) : (
                        <div className="space-y-2">
                            {rules.map((rule) => (
                                <div
                                    key={rule.id}
                                    className="flex items-center justify-between p-3 border rounded"
                                >
                                    <div>
                                        <p className="font-medium">{rule.name}</p>
                                        <p className="text-sm text-gray-500">
                                            {rule.event_type} • Priority: {rule.priority}
                                        </p>
                                    </div>
                                    <span className={`px-2 py-1 text-xs rounded ${
                                        rule.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                                    }`}>
                                        {rule.enabled ? 'Active' : 'Disabled'}
                                    </span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
