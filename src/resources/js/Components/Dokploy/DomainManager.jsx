import React, { useState } from 'react';
import { Globe, Plus, Trash2, Shield, CheckCircle, XCircle, Settings } from 'lucide-react';

export default function DomainManager({ applicationId, domains }) {
    const [showAddModal, setShowAddModal] = useState(false);
    const [newDomain, setNewDomain] = useState({
        host: '',
        https: true,
        certificateType: 'letsencrypt',
        path: '',
        port: 80,
    });

    const handleAddDomain = async () => {
        try {
            const response = await fetch(`/api/dokploy/domains`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
                body: JSON.stringify({
                    ...newDomain,
                    applicationId,
                }),
            });

            if (response.ok) {
                window.location.reload();
            }
        } catch (error) {
            console.error('Failed to add domain:', error);
            alert('Failed to add domain. Please try again.');
        }
    };

    const handleDeleteDomain = async (domainId) => {
        if (!confirm('Are you sure you want to delete this domain?')) {
            return;
        }

        try {
            const response = await fetch(`/api/dokploy/domains/${domainId}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (response.ok) {
                window.location.reload();
            }
        } catch (error) {
            console.error('Failed to delete domain:', error);
            alert('Failed to delete domain. Please try again.');
        }
    };

    return (
        <div>
            <div className="flex items-center justify-between mb-6">
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">
                    Domain Configuration
                </h3>
                <button
                    onClick={() => setShowAddModal(true)}
                    className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
                >
                    <Plus className="w-4 h-4" />
                    Add Domain
                </button>
            </div>

            {/* Domains List */}
            {domains && domains.length > 0 ? (
                <div className="space-y-3">
                    {domains.map((domain) => (
                        <div
                            key={domain.id}
                            className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600"
                        >
                            <div className="flex items-center gap-4 flex-1">
                                <Globe className="w-5 h-5 text-gray-400" />
                                <div className="flex-1">
                                    <div className="flex items-center gap-2">
                                        <a
                                            href={`${domain.https ? 'https' : 'http'}://${domain.host}${domain.path || ''}`}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            className="font-medium text-blue-600 dark:text-blue-400 hover:underline"
                                        >
                                            {domain.host}{domain.path}
                                        </a>
                                        {domain.https && (
                                            <Shield className="w-4 h-4 text-green-600" />
                                        )}
                                    </div>
                                    <div className="flex items-center gap-3 mt-1 text-xs text-gray-500 dark:text-gray-400">
                                        <span>Port: {domain.port}</span>
                                        <span>•</span>
                                        <span>SSL: {domain.certificateType}</span>
                                        {domain.status && (
                                            <>
                                                <span>•</span>
                                                <span className="flex items-center gap-1">
                                                    {domain.status === 'active' ? (
                                                        <CheckCircle className="w-3 h-3 text-green-600" />
                                                    ) : (
                                                        <XCircle className="w-3 h-3 text-red-600" />
                                                    )}
                                                    {domain.status}
                                                </span>
                                            </>
                                        )}
                                    </div>
                                </div>
                            </div>

                            <div className="flex items-center gap-2">
                                <button
                                    className="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-600 transition"
                                    title="Configure domain"
                                >
                                    <Settings className="w-4 h-4 text-gray-600 dark:text-gray-300" />
                                </button>
                                <button
                                    onClick={() => handleDeleteDomain(domain.id)}
                                    className="p-2 rounded-lg hover:bg-red-100 dark:hover:bg-red-900 transition"
                                    title="Delete domain"
                                >
                                    <Trash2 className="w-4 h-4 text-red-600" />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>
            ) : (
                <div className="text-center py-12 bg-gray-50 dark:bg-gray-700 rounded-lg">
                    <Globe className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                    <p className="text-gray-500 dark:text-gray-400">
                        No domains configured yet
                    </p>
                    <button
                        onClick={() => setShowAddModal(true)}
                        className="mt-4 text-blue-600 dark:text-blue-400 hover:underline"
                    >
                        Add your first domain
                    </button>
                </div>
            )}

            {/* Add Domain Modal */}
            {showAddModal && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-lg w-full">
                        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
                            <h3 className="text-xl font-bold text-gray-900 dark:text-white">
                                Add New Domain
                            </h3>
                        </div>

                        <div className="p-6 space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                                    Domain Name
                                </label>
                                <input
                                    type="text"
                                    value={newDomain.host}
                                    onChange={(e) => setNewDomain({ ...newDomain, host: e.target.value })}
                                    placeholder="example.com"
                                    className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                                    Path (Optional)
                                </label>
                                <input
                                    type="text"
                                    value={newDomain.path}
                                    onChange={(e) => setNewDomain({ ...newDomain, path: e.target.value })}
                                    placeholder="/api"
                                    className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                                        Port
                                    </label>
                                    <input
                                        type="number"
                                        value={newDomain.port}
                                        onChange={(e) => setNewDomain({ ...newDomain, port: parseInt(e.target.value) })}
                                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                                        SSL Certificate
                                    </label>
                                    <select
                                        value={newDomain.certificateType}
                                        onChange={(e) => setNewDomain({ ...newDomain, certificateType: e.target.value })}
                                        className="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500"
                                    >
                                        <option value="letsencrypt">Let's Encrypt</option>
                                        <option value="custom">Custom</option>
                                        <option value="none">None (HTTP)</option>
                                    </select>
                                </div>
                            </div>

                            <div className="flex items-center">
                                <input
                                    type="checkbox"
                                    id="https"
                                    checked={newDomain.https}
                                    onChange={(e) => setNewDomain({ ...newDomain, https: e.target.checked })}
                                    className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                                />
                                <label htmlFor="https" className="ml-2 text-sm text-gray-700 dark:text-gray-300">
                                    Enable HTTPS
                                </label>
                            </div>
                        </div>

                        <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200 dark:border-gray-700">
                            <button
                                onClick={() => setShowAddModal(false)}
                                className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleAddDomain}
                                disabled={!newDomain.host}
                                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition"
                            >
                                Add Domain
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
