/**
 * BackupRestorePanel Component
 *
 * UI for managing container backups (list, create, restore)
 */
import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Archive, RotateCcw, Download, RefreshCw, AlertCircle, HardDrive } from 'lucide-react';
import { useContainerLifecycle } from '@/hooks/useContainerLifecycle';

export function BackupRestorePanel({ container, node }) {
    const {
        listBackups,
        backupContainer,
        restoreContainer,
        loading,
        error,
        backups,
        clearError,
    } = useContainerLifecycle(container?.vmid);

    const [showCreateDialog, setShowCreateDialog] = useState(false);
    const [restoreDialog, setRestoreDialog] = useState(null);
    const [isRefreshing, setIsRefreshing] = useState(false);
    const [selectedNode, setSelectedNode] = useState(node || 'AGLSRV1');

    useEffect(() => {
        loadBackups();
    }, [selectedNode, container]);

    const loadBackups = async () => {
        setIsRefreshing(true);
        await listBackups(selectedNode, container?.vmid);
        setIsRefreshing(false);
    };

    const handleCreateBackup = async (options) => {
        if (!container) return;
        const result = await backupContainer(container.vmid, options);
        if (result.success) {
            setShowCreateDialog(false);
            await loadBackups();
        }
    };

    const handleRestore = async (storage, volume, vmid) => {
        const result = await restoreContainer(storage, volume, vmid);
        if (result.success) {
            setRestoreDialog(null);
            await loadBackups();
        }
    };

    return (
        <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-6">
                <div className="flex items-center gap-3">
                    <Archive className="h-6 w-6 text-green-600" />
                    <div>
                        <h2 className="text-2xl font-bold text-gray-900">Backups</h2>
                        <p className="text-sm text-gray-500">
                            {container ? `Container ${container.vmid} (${container.name})` : 'All containers'}
                        </p>
                    </div>
                </div>

                <div className="flex gap-2 items-center">
                    <select
                        value={selectedNode}
                        onChange={(e) => setSelectedNode(e.target.value)}
                        className="px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                        <option value="AGLSRV1">AGLSRV1</option>
                        <option value="AGLSRV6">AGLSRV6</option>
                    </select>

                    <Button
                        variant="outline"
                        size="sm"
                        onClick={loadBackups}
                        disabled={isRefreshing}
                    >
                        <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
                    </Button>

                    {container && (
                        <Button onClick={() => setShowCreateDialog(true)} disabled={loading}>
                            <Archive className="h-4 w-4 mr-2" />
                            Create Backup
                        </Button>
                    )}
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

            {/* Backups List */}
            {loading && backups.length === 0 ? (
                <div className="text-center py-12">
                    <RefreshCw className="h-8 w-8 text-gray-400 animate-spin mx-auto mb-3" />
                    <p className="text-gray-500">Loading backups...</p>
                </div>
            ) : backups.length === 0 ? (
                <div className="text-center py-12 border-2 border-dashed border-gray-300 rounded-lg">
                    <Archive className="h-12 w-12 text-gray-400 mx-auto mb-3" />
                    <p className="text-gray-900 font-medium mb-1">No backups found</p>
                    <p className="text-sm text-gray-500 mb-4">
                        {container
                            ? 'Create a backup to save the complete container state'
                            : 'No backups available on this node'}
                    </p>
                    {container && (
                        <Button onClick={() => setShowCreateDialog(true)}>
                            Create First Backup
                        </Button>
                    )}
                </div>
            ) : (
                <div className="space-y-3">
                    {backups.map((backup, index) => (
                        <BackupCard
                            key={index}
                            backup={backup}
                            onRestore={() => setRestoreDialog(backup)}
                            disabled={loading}
                        />
                    ))}
                </div>
            )}

            {/* Create Backup Dialog */}
            {showCreateDialog && (
                <CreateBackupDialog
                    container={container}
                    onClose={() => {
                        setShowCreateDialog(false);
                        clearError();
                    }}
                    onConfirm={handleCreateBackup}
                    loading={loading}
                    error={error}
                />
            )}

            {/* Restore Dialog */}
            {restoreDialog && (
                <RestoreDialog
                    backup={restoreDialog}
                    onClose={() => {
                        setRestoreDialog(null);
                        clearError();
                    }}
                    onConfirm={(storage, volume, vmid) => handleRestore(storage, volume, vmid)}
                    loading={loading}
                    error={error}
                />
            )}
        </div>
    );
}

function BackupCard({ backup, onRestore, disabled }) {
    const formatSize = (bytes) => {
        if (!bytes) return 'Unknown';
        const gb = bytes / (1024 * 1024 * 1024);
        return `${gb.toFixed(2)} GB`;
    };

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
                        <h3 className="font-semibold text-gray-900 truncate">{backup.volid}</h3>
                        <span className="px-2 py-0.5 bg-green-100 text-green-800 text-xs font-medium rounded">
                            {backup.format || 'tar.zst'}
                        </span>
                    </div>

                    <div className="grid grid-cols-2 gap-4 text-xs text-gray-500 mb-3">
                        <div>
                            <span className="font-medium">VMID:</span> {backup.vmid}
                        </div>
                        <div>
                            <span className="font-medium">Size:</span> {formatSize(backup.size)}
                        </div>
                        <div>
                            <span className="font-medium">Created:</span> {formatDate(backup.ctime)}
                        </div>
                        <div>
                            <span className="font-medium">Storage:</span> {backup.storage || 'local'}
                        </div>
                    </div>

                    {backup.notes && (
                        <p className="text-sm text-gray-600 mt-2">{backup.notes}</p>
                    )}
                </div>

                <div className="flex flex-col gap-2 ml-4 flex-shrink-0">
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={onRestore}
                        disabled={disabled}
                    >
                        <RotateCcw className="h-4 w-4 mr-2" />
                        Restore
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        disabled
                    >
                        <Download className="h-4 w-4 mr-2" />
                        Download
                    </Button>
                </div>
            </div>
        </div>
    );
}

function CreateBackupDialog({ container, onClose, onConfirm, loading, error }) {
    const [mode, setMode] = useState('snapshot');
    const [compress, setCompress] = useState('zstd');
    const [storage, setStorage] = useState('local');
    const [notes, setNotes] = useState('');

    return (
        <>
            <div className="fixed inset-0 bg-black bg-opacity-50 z-40" onClick={onClose} />
            <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                        Create Backup
                    </h3>

                    {error && (
                        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
                            <p className="text-sm text-red-800">{error}</p>
                        </div>
                    )}

                    <div className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Backup Mode
                            </label>
                            <select
                                value={mode}
                                onChange={(e) => setMode(e.target.value)}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                                <option value="snapshot">Snapshot (fastest, requires LVM)</option>
                                <option value="suspend">Suspend (pauses container)</option>
                                <option value="stop">Stop (cleanest, requires downtime)</option>
                            </select>
                            <p className="mt-1 text-xs text-gray-500">
                                {mode === 'snapshot' && 'Uses LVM snapshots for fast backup without downtime'}
                                {mode === 'suspend' && 'Suspends container temporarily during backup'}
                                {mode === 'stop' && 'Stops container before backup, ensures consistency'}
                            </p>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Compression
                            </label>
                            <select
                                value={compress}
                                onChange={(e) => setCompress(e.target.value)}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                                <option value="zstd">Zstandard (recommended - fast, high ratio)</option>
                                <option value="lzo">LZO (fastest, lower ratio)</option>
                                <option value="gzip">GZIP (slower, good ratio)</option>
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Storage Location
                            </label>
                            <select
                                value={storage}
                                onChange={(e) => setStorage(e.target.value)}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                                <option value="local">Local Storage</option>
                                <option value="remote-backup">Remote Backup Storage</option>
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Notes (optional)
                            </label>
                            <textarea
                                value={notes}
                                onChange={(e) => setNotes(e.target.value)}
                                rows="2"
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                placeholder="Backup notes..."
                            />
                        </div>

                        <div className="flex justify-end gap-2 pt-4">
                            <Button variant="outline" onClick={onClose} disabled={loading}>
                                Cancel
                            </Button>
                            <Button
                                onClick={() => onConfirm({ mode, compress, storage, notes })}
                                disabled={loading}
                            >
                                {loading ? 'Creating Backup...' : 'Create Backup'}
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

function RestoreDialog({ backup, onClose, onConfirm, loading, error }) {
    const [newVmid, setNewVmid] = useState('');
    const [useOriginalVmid, setUseOriginalVmid] = useState(true);

    const handleConfirm = () => {
        const vmid = useOriginalVmid ? backup.vmid : parseInt(newVmid);
        onConfirm(backup.storage || 'local', backup.volid, vmid);
    };

    return (
        <>
            <div className="fixed inset-0 bg-black bg-opacity-50 z-40" onClick={onClose} />
            <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">
                        Restore from Backup
                    </h3>

                    <div className="space-y-4">
                        <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-md">
                            <div className="flex items-start gap-3">
                                <AlertCircle className="h-5 w-5 text-yellow-600 flex-shrink-0 mt-0.5" />
                                <div>
                                    <p className="text-sm font-medium text-yellow-900">
                                        Warning
                                    </p>
                                    <p className="text-sm text-yellow-800 mt-1">
                                        Restoring to an existing VMID will overwrite that container.
                                        Make sure the VMID is not in use or you want to replace it.
                                    </p>
                                </div>
                            </div>
                        </div>

                        {error && (
                            <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                                <p className="text-sm text-red-800">{error}</p>
                            </div>
                        )}

                        <div className="text-sm text-gray-600 space-y-1">
                            <p>
                                <strong>Backup:</strong> {backup.volid}
                            </p>
                            <p>
                                <strong>Original VMID:</strong> {backup.vmid}
                            </p>
                            <p>
                                <strong>Size:</strong> {(backup.size / (1024 * 1024 * 1024)).toFixed(2)} GB
                            </p>
                        </div>

                        <div className="space-y-3">
                            <label className="flex items-center gap-2">
                                <input
                                    type="radio"
                                    checked={useOriginalVmid}
                                    onChange={() => setUseOriginalVmid(true)}
                                    className="w-4 h-4 text-blue-600"
                                />
                                <span className="text-sm text-gray-700">
                                    Restore to original VMID ({backup.vmid})
                                </span>
                            </label>

                            <label className="flex items-center gap-2">
                                <input
                                    type="radio"
                                    checked={!useOriginalVmid}
                                    onChange={() => setUseOriginalVmid(false)}
                                    className="w-4 h-4 text-blue-600"
                                />
                                <span className="text-sm text-gray-700">
                                    Restore to different VMID
                                </span>
                            </label>

                            {!useOriginalVmid && (
                                <input
                                    type="number"
                                    value={newVmid}
                                    onChange={(e) => setNewVmid(e.target.value)}
                                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                    placeholder="New VMID (100-999999999)"
                                    min="100"
                                />
                            )}
                        </div>

                        <div className="flex justify-end gap-2 pt-4">
                            <Button variant="outline" onClick={onClose} disabled={loading}>
                                Cancel
                            </Button>
                            <Button
                                onClick={handleConfirm}
                                disabled={loading || (!useOriginalVmid && !newVmid)}
                            >
                                {loading ? 'Restoring...' : 'Restore Container'}
                            </Button>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}

export default BackupRestorePanel;
