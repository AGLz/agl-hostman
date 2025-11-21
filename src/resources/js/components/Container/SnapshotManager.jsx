/**
 * SnapshotManager Component
 *
 * UI for managing container snapshots (list, create, rollback, delete)
 */
import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Camera, RotateCcw, Trash2, Calendar, AlertCircle, RefreshCw } from 'lucide-react';
import { useContainerLifecycle } from '@/hooks/useContainerLifecycle';

export function SnapshotManager({ container }) {
    const {
        listSnapshots,
        createSnapshot,
        rollbackToSnapshot,
        loading,
        error,
        snapshots,
        clearError,
    } = useContainerLifecycle(container.vmid);

    const [showCreateDialog, setShowCreateDialog] = useState(false);
    const [rollbackDialog, setRollbackDialog] = useState(null);
    const [isRefreshing, setIsRefreshing] = useState(false);

    useEffect(() => {
        loadSnapshots();
    }, []);

    const loadSnapshots = async () => {
        setIsRefreshing(true);
        await listSnapshots(container.vmid);
        setIsRefreshing(false);
    };

    const handleCreateSnapshot = async (snapname, description) => {
        const result = await createSnapshot(container.vmid, snapname, description);
        if (result.success) {
            setShowCreateDialog(false);
            await loadSnapshots();
        }
    };

    const handleRollback = async (snapname) => {
        const result = await rollbackToSnapshot(container.vmid, snapname);
        if (result.success) {
            setRollbackDialog(null);
            await loadSnapshots();
        }
    };

    return (
        <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-6">
                <div className="flex items-center gap-3">
                    <Camera className="h-6 w-6 text-yellow-600" />
                    <div>
                        <h2 className="text-2xl font-bold text-gray-900">Snapshots</h2>
                        <p className="text-sm text-gray-500">
                            Container {container.vmid} ({container.name})
                        </p>
                    </div>
                </div>

                <div className="flex gap-2">
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={loadSnapshots}
                        disabled={isRefreshing}
                    >
                        <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
                    </Button>
                    <Button onClick={() => setShowCreateDialog(true)} disabled={loading}>
                        <Camera className="h-4 w-4 mr-2" />
                        Create Snapshot
                    </Button>
                </div>
            </div>

            {error && (
                <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-start gap-3">
                    <AlertCircle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                        <p className="text-sm font-medium text-red-800">Error</p>
                        <p className="text-sm text-red-700 mt-1">{error}</p>
                    </div>
                    <button
                        onClick={clearError}
                        className="text-red-600 hover:text-red-800"
                    >
                        ×
                    </button>
                </div>
            )}

            {/* Snapshots List */}
            {loading && snapshots.length === 0 ? (
                <div className="text-center py-12">
                    <RefreshCw className="h-8 w-8 text-gray-400 animate-spin mx-auto mb-3" />
                    <p className="text-gray-500">Loading snapshots...</p>
                </div>
            ) : snapshots.length === 0 ? (
                <div className="text-center py-12 border-2 border-dashed border-gray-300 rounded-lg">
                    <Camera className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                    <p className="text-gray-900 font-medium mb-1">No snapshots</p>
                    <p className="text-sm text-gray-500 mb-4">
                        Create a snapshot to save the current container state
                    </p>
                    <Button onClick={() => setShowCreateDialog(true)}>
                        Create First Snapshot
                    </Button>
                </div>
            ) : (
                <div className="space-y-3">
                    {snapshots.map((snapshot) => (
                        <SnapshotCard
                            key={snapshot.name}
                            snapshot={snapshot}
                            onRollback={() => setRollbackDialog(snapshot)}
                            disabled={loading}
                        />
                    ))}
                </div>
            )}

            {/* Create Snapshot Dialog */}
            {showCreateDialog && (
                <CreateSnapshotDialog
                    onClose={() => {
                        setShowCreateDialog(false);
                        clearError();
                    }}
                    onConfirm={handleCreateSnapshot}
                    loading={loading}
                    error={error}
                />
            )}

            {/* Rollback Confirmation Dialog */}
            {rollbackDialog && (
                <RollbackDialog
                    snapshot={rollbackDialog}
                    container={container}
                    onClose={() => {
                        setRollbackDialog(null);
                        clearError();
                    }}
                    onConfirm={() => handleRollback(rollbackDialog.name)}
                    loading={loading}
                    error={error}
                />
            )}
        </div>
    );
}

function SnapshotCard({ snapshot, onRollback, disabled }) {
    const formatDate = (timestamp) => {
        if (!timestamp) return 'Unknown';
        const date = new Date(timestamp * 1000);
        return date.toLocaleString();
    };

    return (
        <div className="border rounded-lg p-4 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between">
                <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-2">
                        <h3 className="font-semibold text-gray-900">{snapshot.name}</h3>
                        {snapshot.name === 'current' && (
                            <span className="px-2 py-0.5 bg-green-100 text-green-800 text-xs font-medium rounded">
                                Current
                            </span>
                        )}
                    </div>

                    {snapshot.description && (
                        <p className="text-sm text-gray-600 mb-2">{snapshot.description}</p>
                    )}

                    <div className="flex items-center gap-4 text-xs text-gray-500">
                        <div className="flex items-center gap-1">
                            <Calendar className="h-3 w-3" />
                            <span>{formatDate(snapshot.snaptime)}</span>
                        </div>
                        {snapshot.vmstate && (
                            <span className="px-2 py-0.5 bg-blue-100 text-blue-800 rounded">
                                Includes RAM
                            </span>
                        )}
                    </div>
                </div>

                {snapshot.name !== 'current' && (
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={onRollback}
                        disabled={disabled}
                        className="flex-shrink-0 ml-4"
                    >
                        <RotateCcw className="h-4 w-4 mr-2" />
                        Rollback
                    </Button>
                )}
            </div>
        </div>
    );
}

function CreateSnapshotDialog({ onClose, onConfirm, loading, error }) {
    const [snapname, setSnapname] = useState('');
    const [description, setDescription] = useState('');

    const generateName = () => {
        const now = new Date();
        const name = `snapshot-${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}-${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}`;
        setSnapname(name);
    };

    useEffect(() => {
        if (!snapname) {
            generateName();
        }
    }, []);

    return (
        <>
            <div className="fixed inset-0 bg-black bg-opacity-50 z-40" onClick={onClose} />
            <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                        Create Snapshot
                    </h3>

                    {error && (
                        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
                            <p className="text-sm text-red-800">{error}</p>
                        </div>
                    )}

                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Snapshot Name *
                            </label>
                            <input
                                type="text"
                                value={snapname}
                                onChange={(e) => setSnapname(e.target.value)}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="pre-update"
                            />
                            <p className="mt-1 text-xs text-gray-500">
                                Use lowercase letters, numbers, and hyphens
                            </p>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Description
                            </label>
                            <textarea
                                value={description}
                                onChange={(e) => setDescription(e.target.value)}
                                rows="3"
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="Before system update..."
                            />
                        </div>

                        <div className="flex justify-end gap-2 pt-4">
                            <Button variant="outline" onClick={onClose} disabled={loading}>
                                Cancel
                            </Button>
                            <Button
                                onClick={() => onConfirm(snapname, description)}
                                disabled={loading || !snapname}
                            >
                                {loading ? 'Creating...' : 'Create Snapshot'}
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

function RollbackDialog({ snapshot, container, onClose, onConfirm, loading, error }) {
    return (
        <>
            <div className="fixed inset-0 bg-black bg-opacity-50 z-40" onClick={onClose} />
            <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                        Confirm Rollback
                    </h3>

                    <div className="space-y-4">
                        <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-md">
                            <div className="flex items-start gap-3">
                                <AlertCircle className="h-5 w-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                                <div>
                                    <p className="text-sm font-medium text-yellow-900">
                                        Warning: This action cannot be undone
                                    </p>
                                    <p className="text-sm text-yellow-800 mt-1">
                                        Rolling back will revert container {container.vmid} to the state
                                        saved in snapshot "{snapshot.name}". All changes made after this
                                        snapshot will be lost.
                                    </p>
                                </div>
                            </div>
                        </div>

                        {error && (
                            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                                <p className="text-sm text-red-800">{error}</p>
                            </div>
                        )}

                        <div className="text-sm text-gray-600">
                            <p>
                                <strong>Snapshot:</strong> {snapshot.name}
                            </p>
                            {snapshot.description && (
                                <p className="mt-1">
                                    <strong>Description:</strong> {snapshot.description}
                                </p>
                            )}
                        </div>

                        <div className="flex justify-end gap-2 pt-4">
                            <Button variant="outline" onClick={onClose} disabled={loading}>
                                Cancel
                            </Button>
                            <Button
                                variant="destructive"
                                onClick={onConfirm}
                                disabled={loading}
                            >
                                {loading ? 'Rolling back...' : 'Confirm Rollback'}
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

export default SnapshotManager;
