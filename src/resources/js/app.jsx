import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import DokployDashboard from './pages/DokployDashboard';
import './bootstrap';

import DashboardLayout from './components/DashboardLayout';

function App() {
    return (
        <BrowserRouter>
            <DashboardLayout>
                <Routes>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/dokploy" element={<DokployDashboard />} />
                </Routes>
            </DashboardLayout>
        </BrowserRouter>
    );
}

const root = ReactDOM.createRoot(document.getElementById('app'));
root.render(<App />);