/**
 * ContainerActionsMenu Component
 *
 * Dropdown menu for container lifecycle operations (clone, migrate, backup, snapshot, rollback)
 */
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    MoreVertical,
    Copy,
    ArrowRight,
    Archive,
    Camera,
    RotateCcw,
    Play,
    Square,
    Trash2,
} from 'lucide-react';
import { useContainerLifecycle } from '@/hooks/useContainerLifecycle';

export function ContainerActionsMenu({ container, onActionComplete }) {
    const [isOpen, setIsOpen] = useState(false);
    const [showDialog, setShowDialog] = useState(null);
    const {
        cloneContainer,
        migrateContainer,
        backupContainer,
        createSnapshot,
        loading,
        error,
        clearError
    } = useContainerLifecycle(container.vmid);

    const handleAction = async (action) => {
        setIsOpen(false);
        setShowDialog(action);
    };

    const closeDialog = () => {
        setShowDialog(null);
        clearError();
    };

    const actions = [
        {
            id: 'clone',
            label: 'Clone Container',
            icon: <Copy className="h-4 w-4" />,
            description: 'Create a copy of this container',
            color: 'text-blue-600',
        },
        {
            id: 'migrate',
            label: 'Migrate',
            icon: <ArrowRight className="h-4 w-4" />,
            description: 'Move to another node',
            color: 'text-purple-600',
        },
        {
            id: 'backup',
            label: 'Create Backup',
            icon: <Archive className="h-4 w-4" />,
            description: 'Create full backup',
            color: 'text-green-600',
        },
        {
            id: 'snapshot',
            label: 'Create Snapshot',
            icon: <Camera className="h-4 w-4" />,
            description: 'Quick point-in-time snapshot',
            color: 'text-yellow-600',
        },
    ];

    return (
        <div className="relative">
            {/* Menu Button */}
            <Button
                variant="outline"
                size="icon"
                onClick={() => setIsOpen(!isOpen)}
                className="relative"
            >
                <MoreVertical className="h-4 w-4" />
            </Button>

            {/* Dropdown Menu */}
            {isOpen && (
                <>
                    {/* Backdrop */}
                    <div
                        className="fixed inset-0 z-10"
                        onClick={() => setIsOpen(false)}
                    />

                    {/* Menu */}
                    <div className="absolute right-0 mt-2 w-64 bg-white rounded-lg shadow-lg border border-gray-200 z-20">
                        <div className="py-2">
                            {actions.map((action) => (
                                <button
                                    key={action.id}
                                    onClick={() => handleAction(action.id)}
                                    className="w-full px-4 py-3 hover:bg-gray-50 flex items-start gap-3 text-left transition-colors"
                                >
                                    <div className={action.color}>{action.icon}</div>
                                    <div className="flex-1 min-w-0">
                                        <div className="font-medium text-gray-900 text-sm">
                                            {action.label}
                                        </div>
                                        <div className="text-xs text-gray-500 mt-0.5">
                                            {action.description}
                                        </div>
                                    </div>
                                </button>
                            ))}
                        </div>
                    </div>
                </>
            )}

            {/* Dialogs */}
            {showDialog === 'clone' && (
                <CloneDialog
                    container={container}
                    onClose={closeDialog}
                    onConfirm={async (newVmid, hostname) => {
                        const result = await cloneContainer(container.vmid, newVmid, {
                            hostname,
                        });
                        closeDialog();
                        if (result.success && onActionComplete) {
                            onActionComplete('clone', result.data);
                        }
                    }}
                    loading={loading}
                    error={error}
                />
            )}

            {showDialog === 'migrate' && (
                <MigrateDialog
                    container={container}
                    onClose={closeDialog}
                    onConfirm={async (targetNode, online) => {
                        const result = await migrateContainer(container.vmid, targetNode, {
                            online: online ? 1 : 0,
                        });
                        closeDialog();
                        if (result.success && onActionComplete) {
                            onActionComplete('migrate', result.data);
                        }
                    }}
                    loading={loading}
                    error={error}
                />
            )}

            {showDialog === 'backup' && (
                <BackupDialog
                    container={container}
                    onClose={closeDialog}
                    onConfirm={async (options) => {
                        const result = await backupContainer(container.vmid, options);
                        closeDialog();
                        if (result.success && onActionComplete) {
                            onActionComplete('backup', result.data);
                        }
                    }}
                    loading={loading}
                    error={error}
                />
            )}

            {showDialog === 'snapshot' && (
                <SnapshotDialog
                    container={container}
                    onClose={closeDialog}
                    onConfirm={async (snapname, description) => {
                        const result = await createSnapshot(container.vmid, snapname, description);
                        closeDialog();
                        if (result.success && onActionComplete) {
                            onActionComplete('snapshot', result.data);
                        }
                    }}
                    loading={loading}
                    error={error}
                />
            )}
        </div>
    );
}

// Clone Dialog
function CloneDialog({ container, onClose, onConfirm, loading, error }) {
    const [newVmid, setNewVmid] = useState('');
    const [hostname, setHostname] = useState(`${container.name}-clone`);

    return (
        <Dialog title="Clone Container" onClose={onClose}>
            <div className="space-y-4">
                <p className="text-sm text-gray-600">
                    Create a clone of container {container.vmid} ({container.name})
                </p>

                {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                        <p className="text-sm text-red-800">{error}</p>
                    </div>
                )}

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                        New VMID *
                    </label>
                    <input
                        type="number"
                        value={newVmid}
                        onChange={(e) => setNewVmid(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        placeholder="200"
                        min="100"
                    />
                </div>

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                        Hostname
                    </label>
                    <input
                        type="text"
                        value={hostname}
                        onChange={(e) => setHostname(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    />
                </div>

                <div className="flex justify-end gap-2 pt-4">
                    <Button variant="outline" onClick={onClose} disabled={loading}>
                        Cancel
                    </Button>
                    <Button
                        onClick={() => onConfirm(parseInt(newVmid), hostname)}
                        disabled={loading || !newVmid}
                    >
                        {loading ? 'Cloning...' : 'Clone'}
                    </Button>
                </div>
            </div>
        </Dialog>
    );
}

// Migrate Dialog
function MigrateDialog({ container, onClose, onConfirm, loading, error }) {
    const [targetNode, setTargetNode] = useState('AGLSRV6');
    const [online, setOnline] = useState(false);

    return (
        <Dialog title="Migrate Container" onClose={onClose}>
            <div className="space-y-4">
                <p className="text-sm text-gray-600">
                    Migrate container {container.vmid} to another node
                </p>

                {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                        <p className="text-sm text-red-800">{error}</p>
                    </div>
                )}

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                        Target Node *
                    </label>
                    <select
                        value={targetNode}
                        onChange={(e) => setTargetNode(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                        <option value="AGLSRV1">AGLSRV1</option>
                        <option value="AGLSRV6">AGLSRV6</option>
                    </select>
                </div>

                <label className="flex items-center gap-2">
                    <input
                        type="checkbox"
                        checked={online}
                        onChange={(e) => setOnline(e.target.checked)}
                        className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                    />
                    <span className="text-sm text-gray-700">
                        Online migration (keep container running)
                    </span>
                </label>

                <div className="flex justify-end gap-2 pt-4">
                    <Button variant="outline" onClick={onClose} disabled={loading}>
                        Cancel
                    </Button>
                    <Button onClick={() => onConfirm(targetNode, online)} disabled={loading}>
                        {loading ? 'Migrating...' : 'Migrate'}
                    </Button>
                </div>
            </div>
        </Dialog>
    );
}

// Backup Dialog
function BackupDialog({ container, onClose, onConfirm, loading, error }) {
    const [mode, setMode] = useState('snapshot');
    const [compress, setCompress] = useState('zstd');
    const [storage, setStorage] = useState('local');

    return (
        <Dialog title="Create Backup" onClose={onClose}>
            <div className="space-y-4">
                <p className="text-sm text-gray-600">
                    Create backup of container {container.vmid}
                </p>

                {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                        <p className="text-sm text-red-800">{error}</p>
                    </div>
                )}

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                        Backup Mode
                    </label>
                    <select
                        value={mode}
                        onChange={(e) => setMode(e.target.value)}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                    >
                        <option value="snapshot">Snapshot (fastest)</option>
                        <option value="suspend">Suspend</option>
                        <option value="stop">Stop</option>
                    </select>
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
                        <option value="zstd">Zstandard (recommended)</option>
                        <option value="lzo">LZO</option>
                        <option value="gzip">GZIP</option>
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
                        <option value="local">Local</option>
                        <option value="remote-backup">Remote Backup</option>
                    </select>
                </div>

                <div className="flex justify-end gap-2 pt-4">
                    <Button variant="outline" onClick={onClose} disabled={loading}>
                        Cancel
                    </Button>
                    <Button
                        onClick={() => onConfirm({ mode, compress, storage })}
                        disabled={loading}
                    >
                        {loading ? 'Creating...' : 'Create Backup'}
                    </Button>
                </div>
            </div>
        </Dialog>
    );
}

// Snapshot Dialog
function SnapshotDialog({ container, onClose, onConfirm, loading, error }) {
    const [snapname, setSnapname] = useState('');
    const [description, setDescription] = useState('');

    return (
        <Dialog title="Create Snapshot" onClose={onClose}>
            <div className="space-y-4">
                <p className="text-sm text-gray-600">
                    Create snapshot of container {container.vmid}
                </p>

                {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                        <p className="text-sm text-red-800">{error}</p>
                    </div>
                )}

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
                </div>

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                        Description
                    </label>
                    <textarea
                        value={description}
                        onChange={(e) => setDescription(e.target.value)}
                        rows="2"
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        placeholder="Before system update"
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
        </Dialog>
    );
}

// Reusable Dialog Component
function Dialog({ title, children, onClose }) {
    return (
        <>
            {/* Backdrop */}
            <div className="fixed inset-0 bg-black bg-opacity-50 z-40" onClick={onClose} />

            {/* Dialog */}
            <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">{title}</h3>
                    {children}
                </div>
            </div>
        </>
    );
}

export default ContainerActionsMenu;
