/**
 * ContainerCreateForm Component
 *
 * Form for creating new LXC containers with validation
 */
import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Container, Cpu, HardDrive, Network } from 'lucide-react';
import { useContainerLifecycle } from '@/hooks/useContainerLifecycle';

export function ContainerCreateForm({ onSuccess, onCancel }) {
    const { createContainer, loading, error, clearError } = useContainerLifecycle();
    const [formData, setFormData] = useState({
        node: 'AGLSRV1',
        vmid: '',
        hostname: '',
        cores: 2,
        memory: 2048,
        swap: 512,
        disk: 8,
        storage: 'local-lvm',
        ostemplate: 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
        rootfs: '',
        password: '',
        ssh_keys: '',
        nameserver: '1.1.1.1',
        searchdomain: 'aglz.io',
        unprivileged: true,
        onboot: false,
        start: true,
    });

    const [validationErrors, setValidationErrors] = useState({});

    const handleChange = (e) => {
        const { name, value, type, checked } = e.target;
        setFormData(prev => ({
            ...prev,
            [name]: type === 'checkbox' ? checked : value,
        }));

        // Clear validation error for this field
        if (validationErrors[name]) {
            setValidationErrors(prev => ({ ...prev, [name]: null }));
        }
        clearError();
    };

    const validateForm = () => {
        const errors = {};

        // VMID validation
        if (!formData.vmid) {
            errors.vmid = 'VMID is required';
        } else if (formData.vmid < 100 || formData.vmid > 999999999) {
            errors.vmid = 'VMID must be between 100 and 999999999';
        }

        // Hostname validation
        if (!formData.hostname) {
            errors.hostname = 'Hostname is required';
        } else if (!/^[a-z0-9-]+$/.test(formData.hostname)) {
            errors.hostname = 'Hostname must contain only lowercase letters, numbers, and hyphens';
        }

        // Resources validation
        if (formData.cores < 1 || formData.cores > 128) {
            errors.cores = 'CPU cores must be between 1 and 128';
        }
        if (formData.memory < 128 || formData.memory > 524288) {
            errors.memory = 'Memory must be between 128MB and 524GB';
        }
        if (formData.disk < 1 || formData.disk > 1024) {
            errors.disk = 'Disk size must be between 1GB and 1TB';
        }

        // Password validation (if not using SSH keys)
        if (!formData.password && !formData.ssh_keys) {
            errors.password = 'Either password or SSH keys must be provided';
        }

        setValidationErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        if (!validateForm()) {
            return;
        }

        const config = {
            hostname: formData.hostname,
            cores: parseInt(formData.cores),
            memory: parseInt(formData.memory),
            swap: parseInt(formData.swap),
            rootfs: `${formData.storage}:${formData.disk}`,
            ostemplate: formData.ostemplate,
            password: formData.password || undefined,
            ssh_public_keys: formData.ssh_keys || undefined,
            nameserver: formData.nameserver,
            searchdomain: formData.searchdomain,
            unprivileged: formData.unprivileged ? 1 : 0,
            onboot: formData.onboot ? 1 : 0,
            start: formData.start ? 1 : 0,
        };

        const result = await createContainer(formData.node, parseInt(formData.vmid), config);

        if (result.success && onSuccess) {
            onSuccess(result.data);
        }
    };

    return (
        <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-6">
                <Container className="h-6 w-6 text-blue-600" />
                <h2 className="text-2xl font-bold text-gray-900">Create New Container</h2>
            </div>

            {error && (
                <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                    <p className="text-sm text-red-800">{error}</p>
                </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
                {/* Basic Configuration */}
                <div className="border-b pb-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4">Basic Configuration</h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Node *
                            </label>
                            <select
                                name="node"
                                value={formData.node}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                                <option value="AGLSRV1">AGLSRV1 (192.168.0.245)</option>
                                <option value="AGLSRV6">AGLSRV6 (10.6.0.12)</option>
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                VMID * (100-999999999)
                            </label>
                            <input
                                type="number"
                                name="vmid"
                                value={formData.vmid}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.vmid ? 'border-red-500' : 'border-gray-300'
                                }`}
                                min="100"
                                max="999999999"
                            />
                            {validationErrors.vmid && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.vmid}</p>
                            )}
                        </div>

                        <div className="md:col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Hostname * (lowercase, numbers, hyphens only)
                            </label>
                            <input
                                type="text"
                                name="hostname"
                                value={formData.hostname}
                                onChange={handleChange}
                                placeholder="my-container"
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.hostname ? 'border-red-500' : 'border-gray-300'
                                }`}
                            />
                            {validationErrors.hostname && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.hostname}</p>
                            )}
                        </div>
                    </div>
                </div>

                {/* Resources */}
                <div className="border-b pb-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
                        <Cpu className="h-5 w-5 text-gray-500" />
                        Resources
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                CPU Cores (1-128)
                            </label>
                            <input
                                type="number"
                                name="cores"
                                value={formData.cores}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.cores ? 'border-red-500' : 'border-gray-300'
                                }`}
                                min="1"
                                max="128"
                            />
                            {validationErrors.cores && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.cores}</p>
                            )}
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Memory (MB)
                            </label>
                            <input
                                type="number"
                                name="memory"
                                value={formData.memory}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.memory ? 'border-red-500' : 'border-gray-300'
                                }`}
                                min="128"
                                step="256"
                            />
                            {validationErrors.memory && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.memory}</p>
                            )}
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Swap (MB)
                            </label>
                            <input
                                type="number"
                                name="swap"
                                value={formData.swap}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                                min="0"
                                step="256"
                            />
                        </div>
                    </div>
                </div>

                {/* Storage */}
                <div className="border-b pb-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
                        <HardDrive className="h-5 w-5 text-gray-500" />
                        Storage
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Storage Location
                            </label>
                            <select
                                name="storage"
                                value={formData.storage}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            >
                                <option value="local-lvm">local-lvm</option>
                                <option value="local">local</option>
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Disk Size (GB)
                            </label>
                            <input
                                type="number"
                                name="disk"
                                value={formData.disk}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.disk ? 'border-red-500' : 'border-gray-300'
                                }`}
                                min="1"
                                max="1024"
                            />
                            {validationErrors.disk && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.disk}</p>
                            )}
                        </div>

                        <div className="md:col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                OS Template
                            </label>
                            <input
                                type="text"
                                name="ostemplate"
                                value={formData.ostemplate}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                        </div>
                    </div>
                </div>

                {/* Network & Security */}
                <div className="border-b pb-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
                        <Network className="h-5 w-5 text-gray-500" />
                        Network & Security
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Password (or use SSH keys)
                            </label>
                            <input
                                type="password"
                                name="password"
                                value={formData.password}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${
                                    validationErrors.password ? 'border-red-500' : 'border-gray-300'
                                }`}
                            />
                            {validationErrors.password && (
                                <p className="mt-1 text-sm text-red-600">{validationErrors.password}</p>
                            )}
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Nameserver
                            </label>
                            <input
                                type="text"
                                name="nameserver"
                                value={formData.nameserver}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                        </div>

                        <div className="md:col-span-2">
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                SSH Public Keys (optional)
                            </label>
                            <textarea
                                name="ssh_keys"
                                value={formData.ssh_keys}
                                onChange={handleChange}
                                rows="3"
                                placeholder="ssh-rsa AAAAB3..."
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                            />
                        </div>
                    </div>
                </div>

                {/* Options */}
                <div className="pb-6">
                    <h3 className="text-lg font-medium text-gray-900 mb-4">Options</h3>
                    <div className="space-y-3">
                        <label className="flex items-center gap-2">
                            <input
                                type="checkbox"
                                name="unprivileged"
                                checked={formData.unprivileged}
                                onChange={handleChange}
                                className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                            />
                            <span className="text-sm text-gray-700">Unprivileged container (recommended)</span>
                        </label>

                        <label className="flex items-center gap-2">
                            <input
                                type="checkbox"
                                name="onboot"
                                checked={formData.onboot}
                                onChange={handleChange}
                                className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                            />
                            <span className="text-sm text-gray-700">Start at boot</span>
                        </label>

                        <label className="flex items-center gap-2">
                            <input
                                type="checkbox"
                                name="start"
                                checked={formData.start}
                                onChange={handleChange}
                                className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                            />
                            <span className="text-sm text-gray-700">Start after creation</span>
                        </label>
                    </div>
                </div>

                {/* Actions */}
                <div className="flex justify-end gap-3 pt-4 border-t">
                    {onCancel && (
                        <Button type="button" variant="outline" onClick={onCancel} disabled={loading}>
                            Cancel
                        </Button>
                    )}
                    <Button type="submit" disabled={loading} className="min-w-32">
                        {loading ? 'Creating...' : 'Create Container'}
                    </Button>
                </div>
            </form>
        </div>
    );
}

export default ContainerCreateForm;
