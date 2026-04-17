import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import MissionControlLayout from './components/MissionControlLayout';
import TeamsView from './pages/TeamsView';
import MissionControlDashboard from './pages/MissionControlDashboard';
import AITeamView from './pages/AITeamView';
import TasksBoard from './pages/TasksBoard';
import MemoryView from './pages/MemoryView';
import CalendarView from './pages/CalendarView';
import ContactsView from './pages/ContactsView';
import MissionControlSettings from './pages/MissionControlSettings';
import DokployDashboard from './pages/DokployDashboard';
import InfrastructureDashboard from './pages/InfrastructureDashboard';
import MetricsDashboard from './pages/MetricsDashboard';
import ScrumBoard from './pages/ScrumBoard';
import './bootstrap';

import DashboardLayout from './components/DashboardLayout';

// Lazy-load Inertia-style Pages
const ArchonIndex = React.lazy(() => import('./Pages/Archon/Index'));
const DokployIndex = React.lazy(() => import('./Pages/Dokploy/Index'));
const NetworkTopology = React.lazy(() => import('./Pages/Network/Topology'));
const NotificationsIndex = React.lazy(() => import('./Pages/Notifications/Index'));

function App() {
    return (
        <BrowserRouter>
            <MissionControlLayout>
                <React.Suspense fallback={<div className="flex items-center justify-center h-64 text-white/40">A carregar...</div>}>
                    <Routes>
                        {/* Mission Control - Main pages */}
                        <Route path="/mission-control" element={<MissionControlDashboard />} />
                        <Route path="/mission-control/tasks" element={<TasksBoard />} />
                        <Route path="/mission-control/team" element={<AITeamView />} />
                        <Route path="/mission-control/teams" element={<TeamsView />} />
                        <Route path="/mission-control/openclaw" element={<TeamsView />} />
                        <Route path="/mission-control/memory" element={<MemoryView />} />
                        <Route path="/mission-control/calendar" element={<CalendarView />} />
                        <Route path="/mission-control/contacts" element={<ContactsView />} />
                        <Route path="/mission-control/settings" element={<MissionControlSettings />} />

                        {/* Dashboard principal → Mission Control */}
                        <Route path="/" element={<MissionControlDashboard />} />

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

                        {/* Network */}
                        <Route path="/network" element={<NetworkTopology />} />

                        {/* Notifications */}
                        <Route path="/notifications" element={<NotificationsIndex />} />

                        {/* Fallback → Mission Control */}
                        <Route path="*" element={<MissionControlDashboard />} />
                    </Routes>
                </React.Suspense>
            </MissionControlLayout>
        </BrowserRouter>
    );
}

const root = ReactDOM.createRoot(document.getElementById('app'));
root.render(<App />);
