import '../css/app.css';
import { createInertiaApp } from '@inertiajs/react';
import { createRoot } from 'react-dom/client';

createInertiaApp({
    title: (title) => (title ? `${title} — ${import.meta.env.VITE_APP_NAME ?? 'AGL'}` : (import.meta.env.VITE_APP_NAME ?? 'AGL')),
    resolve: (name) => {
        const pages = import.meta.glob('./Pages/**/*.jsx');
        const path = `./Pages/${name}.jsx`;
        const resolver = pages[path];
        if (!resolver) {
            throw new Error(`Página Inertia em falta: ${path}`);
        }
        return resolver();
    },
    setup({ el, App, props }) {
        createRoot(el).render(<App {...props} />);
    },
    progress: {
        color: '#0d9488',
    },
});
