import React, { useState } from 'react';
import { Rocket, Loader } from 'lucide-react';

export default function DeployButton({ applicationId, onDeploy, disabled = false, variant = 'primary' }) {
    const [isDeploying, setIsDeploying] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);

    const handleDeploy = async () => {
        if (!showConfirm) {
            setShowConfirm(true);
            return;
        }

        setIsDeploying(true);
        try {
            await onDeploy();
        } catch (error) {
            console.error('Deploy failed:', error);
        } finally {
            setIsDeploying(false);
            setShowConfirm(false);
        }
    };

    const handleCancel = () => {
        setShowConfirm(false);
    };

    if (showConfirm) {
        return (
            <div className="flex items-center gap-2">
                <button
                    onClick={handleDeploy}
                    disabled={isDeploying}
                    className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition"
                >
                    {isDeploying ? (
                        <Loader className="w-5 h-5 animate-spin" />
                    ) : (
                        <Rocket className="w-5 h-5" />
                    )}
                    Confirm Deploy
                </button>
                <button
                    onClick={handleCancel}
                    disabled={isDeploying}
                    className="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 transition"
                >
                    Cancel
                </button>
            </div>
        );
    }

    const variantClasses = {
        primary: 'bg-blue-600 hover:bg-blue-700 text-white',
        success: 'bg-green-600 hover:bg-green-700 text-white',
        secondary: 'border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-300',
    };

    return (
        <button
            onClick={handleDeploy}
            disabled={disabled || isDeploying}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg disabled:opacity-50 transition ${variantClasses[variant] || variantClasses.primary}`}
        >
            {isDeploying ? (
                <Loader className="w-5 h-5 animate-spin" />
            ) : (
                <Rocket className="w-5 h-5" />
            )}
            Deploy
        </button>
    );
}
