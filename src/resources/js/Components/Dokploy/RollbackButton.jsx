import React, { useState } from 'react';
import { RotateCcw, X, Clock, GitBranch } from 'lucide-react';
import { format } from 'date-fns';

export default function RollbackButton({ applicationId, deployments, currentDeployment }) {
    const [showModal, setShowModal] = useState(false);
    const [selectedDeployment, setSelectedDeployment] = useState(null);
    const [isRollingBack, setIsRollingBack] = useState(false);

    const handleRollback = async () => {
        if (!selectedDeployment) return;

        setIsRollingBack(true);
        try {
            // TODO: Implement rollback API call
            const response = await fetch(`/api/dokploy/deployments/${selectedDeployment.id}/rollback`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                },
            });

            if (response.ok) {
                window.location.reload(); // Refresh to show new deployment
            }
        } catch (error) {
            console.error('Rollback failed:', error);
            alert('Rollback failed. Please try again.');
        } finally {
            setIsRollingBack(false);
            setShowModal(false);
        }
    };

    return (
        <>
            <button
                onClick={() => setShowModal(true)}
                className="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
            >
                <RotateCcw className="w-5 h-5" />
                Rollback
            </button>

            {/* Modal */}
            {showModal && (
                <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
                    <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-2xl w-full max-h-[80vh] overflow-hidden">
                        {/* Header */}
                        <div className="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700">
                            <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                                Rollback to Previous Deployment
                            </h2>
                            <button
                                onClick={() => setShowModal(false)}
                                className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                <X className="w-5 h-5 text-gray-600 dark:text-gray-300" />
                            </button>
                        </div>

                        {/* Content */}
                        <div className="p-6 overflow-y-auto max-h-[calc(80vh-180px)]">
                            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                                Select a previous deployment to rollback to. This will redeploy the selected version.
                            </p>

                            {/* Current Deployment */}
                            {currentDeployment && (
                                <div className="mb-4 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
                                    <div className="flex items-center gap-2 mb-2">
                                        <GitBranch className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                                        <span className="text-sm font-medium text-blue-900 dark:text-blue-200">
                                            Current Deployment
                                        </span>
                                    </div>
                                    <div className="grid grid-cols-2 gap-2 text-sm">
                                        <div>
                                            <span className="text-gray-600 dark:text-gray-400">Version:</span>
                                            <span className="ml-2 font-medium text-gray-900 dark:text-white">
                                                {currentDeployment.version || 'Latest'}
                                            </span>
                                        </div>
                                        <div>
                                            <span className="text-gray-600 dark:text-gray-400">Deployed:</span>
                                            <span className="ml-2 font-medium text-gray-900 dark:text-white">
                                                {format(new Date(currentDeployment.created_at), 'MMM dd, HH:mm')}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            )}

                            {/* Previous Deployments */}
                            <div className="space-y-2">
                                {deployments.map((deployment) => (
                                    <button
                                        key={deployment.id}
                                        onClick={() => setSelectedDeployment(deployment)}
                                        className={`w-full text-left p-4 rounded-lg border-2 transition ${
                                            selectedDeployment?.id === deployment.id
                                                ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20'
                                                : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                                        }`}
                                    >
                                        <div className="flex items-center justify-between mb-2">
                                            <div className="flex items-center gap-2">
                                                <Clock className="w-4 h-4 text-gray-400" />
                                                <span className="text-sm font-medium text-gray-900 dark:text-white">
                                                    {format(new Date(deployment.created_at), 'MMM dd, yyyy HH:mm')}
                                                </span>
                                            </div>
                                            <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                                                deployment.status === 'done'
                                                    ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                                                    : 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
                                            }`}>
                                                {deployment.status}
                                            </span>
                                        </div>
                                        <div className="text-sm text-gray-600 dark:text-gray-400">
                                            {deployment.title || 'No description'}
                                        </div>
                                        {deployment.version && (
                                            <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                                                Version: {deployment.version}
                                            </div>
                                        )}
                                    </button>
                                ))}
                            </div>

                            {deployments.length === 0 && (
                                <div className="text-center py-8 text-gray-500 dark:text-gray-400">
                                    No previous deployments available for rollback
                                </div>
                            )}
                        </div>

                        {/* Footer */}
                        <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200 dark:border-gray-700">
                            <button
                                onClick={() => setShowModal(false)}
                                className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={handleRollback}
                                disabled={!selectedDeployment || isRollingBack}
                                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 transition"
                            >
                                {isRollingBack ? (
                                    <>
                                        <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                        Rolling back...
                                    </>
                                ) : (
                                    <>
                                        <RotateCcw className="w-5 h-5" />
                                        Rollback to Selected
                                    </>
                                )}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </>
    );
}
