import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import DokployDashboard from './pages/DokployDashboard';
import InfrastructureDashboard from './pages/InfrastructureDashboard';
import MetricsDashboard from './pages/MetricsDashboard';
import ScrumBoard from './pages/ScrumBoard';
import './bootstrap';

import DashboardLayout from './components/DashboardLayout';

// Lazy-load Inertia-style Pages para rotas do sidebar
const ArchonIndex = React.lazy(() => import('./Pages/Archon/Index'));
const DokployIndex = React.lazy(() => import('./Pages/Dokploy/Index'));
const MemoryDashboard = React.lazy(() => import('./Pages/Memory/Dashboard'));
const NetworkTopology = React.lazy(() => import('./Pages/Network/Topology'));
const NotificationsIndex = React.lazy(() => import('./Pages/Notifications/Index'));

function App() {
    return (
        <BrowserRouter>
            <DashboardLayout>
                <React.Suspense fallback={<div className="flex items-center justify-center h-64 text-muted-foreground">A carregar...</div>}>
                    <Routes>
                        {/* Dashboard principal */}
                        <Route path="/" element={<Dashboard />} />

                        {/* Infraestrutura detalhada / Monitoring */}
                        <Route path="/infrastructure" element={<InfrastructureDashboard />} />
                        <Route path="/monitoring" element={<InfrastructureDashboard />} />

                        {/* Métricas avançadas */}
                        <Route path="/metrics" element={<MetricsDashboard />} />

                        {/* Dokploy */}
                        <Route path="/dokploy" element={<DokployDashboard />} />
                        <Route path="/dokploy/*" element={<DokployIndex />} />

                        {/* AI Command Center */}
                        <Route path="/archon/*" element={<ArchonIndex />} />

                        {/* Scrum Board */}
                        <Route path="/scrum" element={<ScrumBoard />} />

                        {/* Memory */}
                        <Route path="/memory" element={<MemoryDashboard />} />

                        {/* Network */}
                        <Route path="/network" element={<NetworkTopology />} />

                        {/* Notifications */}
                        <Route path="/notifications" element={<NotificationsIndex />} />

                        {/* Fallback → dashboard */}
                        <Route path="*" element={<Dashboard />} />
                    </Routes>
                </React.Suspense>
            </DashboardLayout>
        </BrowserRouter>
    );
}

const root = ReactDOM.createRoot(document.getElementById('app'));
root.render(<App />);
