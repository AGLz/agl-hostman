import React from 'react';
import AuthenticatedLayout from '@/Layouts/AuthenticatedLayout';
import { Head } from '@inertiajs/react';
import TopologyVisualizer from '@/Components/Network/TopologyVisualizer';

export default function Topology({ auth, title, description }) {
    return (
        <AuthenticatedLayout
            user={auth.user}
            header={
                <div>
                    <h2 className="font-semibold text-xl text-gray-800 dark:text-gray-200 leading-tight">
                        {title || 'Network Topology Visualizer'}
                    </h2>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                        {description || 'Interactive 3D/2D visualization of WireGuard mesh network'}
                    </p>
                </div>
            }
        >
            <Head title={title || 'Network Topology'} />

            <div className="h-screen-minus-header">
                <TopologyVisualizer />
            </div>
        </AuthenticatedLayout>
    );
}
