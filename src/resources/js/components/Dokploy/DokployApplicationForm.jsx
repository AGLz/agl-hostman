import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { X, Save } from 'lucide-react';

function DokployApplicationForm({ onClose, onSuccess, editApplication = null }) {
    const [formData, setFormData] = useState({
        name: '',
        appName: '',
        projectId: '',
        description: '',
        sourceType: 'docker',
        dockerImage: '',
        repository: '',
        branch: 'main',
        buildPath: '/',
    });
    const [projects, setProjects] = useState([]);
    const [loading, setLoading] = useState(false);
    const [errors, setErrors] = useState({});

    useEffect(() => {
        fetchProjects();
        if (editApplication) {
            setFormData({
                name: editApplication.name || '',
                appName: editApplication.appName || '',
                projectId: editApplication.projectId || '',
                description: editApplication.description || '',
                sourceType: editApplication.sourceType || 'docker',
                dockerImage: editApplication.dockerImage || '',
                repository: editApplication.repository || '',
                branch: editApplication.branch || 'main',
                buildPath: editApplication.buildPath || '/',
            });
        }
    }, [editApplication]);

    const fetchProjects = async () => {
        try {
            const response = await fetch('/api/dokploy/projects', {
                headers: {
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
            });
            if (response.ok) {
                const data = await response.json();
                setProjects(data.data || []);
            }
        } catch (error) {
            console.error('Failed to fetch projects:', error);
        }
    };

    const handleChange = (e) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
        // Clear error for this field
        if (errors[name]) {
            setErrors(prev => ({ ...prev, [name]: null }));
        }
    };

    const validateForm = () => {
        const newErrors = {};

        if (!formData.name.trim()) {
            newErrors.name = 'Name is required';
        }
        if (!formData.appName.trim()) {
            newErrors.appName = 'App name is required';
        }
        if (!formData.projectId) {
            newErrors.projectId = 'Project is required';
        }
        if (formData.sourceType === 'docker' && !formData.dockerImage.trim()) {
            newErrors.dockerImage = 'Docker image is required';
        }
        if (formData.sourceType === 'github' && !formData.repository.trim()) {
            newErrors.repository = 'Repository is required';
        }

        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
    };

    const handleSubmit = async (e) => {
        e.preventDefault();

        if (!validateForm()) {
            return;
        }

        setLoading(true);

        try {
            const response = await fetch('/api/dokploy/applications', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
                body: JSON.stringify(formData),
            });

            if (response.ok) {
                const data = await response.json();
                console.log('Application created:', data);
                onSuccess && onSuccess(data);
                onClose();
            } else {
                const errorData = await response.json();
                if (errorData.errors) {
                    setErrors(errorData.errors);
                }
            }
        } catch (error) {
            console.error('Failed to create application:', error);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
                {/* Header */}
                <div className="px-6 py-4 border-b flex items-center justify-between">
                    <h2 className="text-lg font-medium text-gray-900">
                        {editApplication ? 'Edit Application' : 'Create New Application'}
                    </h2>
                    <button
                        onClick={onClose}
                        className="text-gray-400 hover:text-gray-600"
                    >
                        <X className="h-5 w-5" />
                    </button>
                </div>

                {/* Form */}
                <form onSubmit={handleSubmit} className="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
                    <div className="space-y-4">
                        {/* Basic Info */}
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Name *
                                </label>
                                <input
                                    type="text"
                                    name="name"
                                    value={formData.name}
                                    onChange={handleChange}
                                    className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                                        errors.name ? 'border-red-300' : 'border-gray-300'
                                    }`}
                                    placeholder="my-application"
                                />
                                {errors.name && (
                                    <p className="text-xs text-red-600 mt-1">{errors.name}</p>
                                )}
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    App Name *
                                </label>
                                <input
                                    type="text"
                                    name="appName"
                                    value={formData.appName}
                                    onChange={handleChange}
                                    className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                                        errors.appName ? 'border-red-300' : 'border-gray-300'
                                    }`}
                                    placeholder="my-app"
                                />
                                {errors.appName && (
                                    <p className="text-xs text-red-600 mt-1">{errors.appName}</p>
                                )}
                            </div>
                        </div>

                        {/* Project Selection */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Project *
                            </label>
                            <select
                                name="projectId"
                                value={formData.projectId}
                                onChange={handleChange}
                                className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                                    errors.projectId ? 'border-red-300' : 'border-gray-300'
                                }`}
                            >
                                <option value="">Select a project</option>
                                {projects.map(project => (
                                    <option key={project.projectId} value={project.projectId}>
                                        {project.name}
                                    </option>
                                ))}
                            </select>
                            {errors.projectId && (
                                <p className="text-xs text-red-600 mt-1">{errors.projectId}</p>
                            )}
                        </div>

                        {/* Description */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Description
                            </label>
                            <textarea
                                name="description"
                                value={formData.description}
                                onChange={handleChange}
                                rows={3}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                placeholder="Application description"
                            />
                        </div>

                        {/* Source Type */}
                        <div>
                            <label className="block text-sm font-medium text-gray-700 mb-1">
                                Source Type *
                            </label>
                            <select
                                name="sourceType"
                                value={formData.sourceType}
                                onChange={handleChange}
                                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                            >
                                <option value="docker">Docker Image</option>
                                <option value="github">GitHub</option>
                                <option value="gitlab">GitLab</option>
                                <option value="git">Custom Git</option>
                            </select>
                        </div>

                        {/* Docker Image (if sourceType is docker) */}
                        {formData.sourceType === 'docker' && (
                            <div>
                                <label className="block text-sm font-medium text-gray-700 mb-1">
                                    Docker Image *
                                </label>
                                <input
                                    type="text"
                                    name="dockerImage"
                                    value={formData.dockerImage}
                                    onChange={handleChange}
                                    className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                                        errors.dockerImage ? 'border-red-300' : 'border-gray-300'
                                    }`}
                                    placeholder="harbor.aglz.io:5000/agl/my-app:latest"
                                />
                                {errors.dockerImage && (
                                    <p className="text-xs text-red-600 mt-1">{errors.dockerImage}</p>
                                )}
                                <p className="text-xs text-gray-500 mt-1">
                                    Use Harbor registry: harbor.aglz.io:5000/agl/your-image:tag
                                </p>
                            </div>
                        )}

                        {/* Git Repository (if sourceType is not docker) */}
                        {formData.sourceType !== 'docker' && (
                            <div className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Repository URL *
                                    </label>
                                    <input
                                        type="text"
                                        name="repository"
                                        value={formData.repository}
                                        onChange={handleChange}
                                        className={`w-full px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent ${
                                            errors.repository ? 'border-red-300' : 'border-gray-300'
                                        }`}
                                        placeholder="https://github.com/username/repo"
                                    />
                                    {errors.repository && (
                                        <p className="text-xs text-red-600 mt-1">{errors.repository}</p>
                                    )}
                                </div>

                                <div className="grid grid-cols-2 gap-4">
                                    <div>
                                        <label className="block text-sm font-medium text-gray-700 mb-1">
                                            Branch
                                        </label>
                                        <input
                                            type="text"
                                            name="branch"
                                            value={formData.branch}
                                            onChange={handleChange}
                                            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                            placeholder="main"
                                        />
                                    </div>

                                    <div>
                                        <label className="block text-sm font-medium text-gray-700 mb-1">
                                            Build Path
                                        </label>
                                        <input
                                            type="text"
                                            name="buildPath"
                                            value={formData.buildPath}
                                            onChange={handleChange}
                                            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                                            placeholder="/"
                                        />
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </form>

                {/* Footer */}
                <div className="px-6 py-4 border-t flex items-center justify-end gap-3">
                    <Button
                        type="button"
                        variant="outline"
                        onClick={onClose}
                        disabled={loading}
                    >
                        Cancel
                    </Button>
                    <Button
                        onClick={handleSubmit}
                        disabled={loading}
                        className="flex items-center gap-2"
                    >
                        {loading ? (
                            <>Creating...</>
                        ) : (
                            <>
                                <Save className="h-4 w-4" />
                                {editApplication ? 'Update' : 'Create'} Application
                            </>
                        )}
                    </Button>
                </div>
            </div>
        </div>
    );
}

export default DokployApplicationForm;
