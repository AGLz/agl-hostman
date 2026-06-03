import React, { useEffect, useState } from 'react';
import { ExternalLink, Loader2, Box } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { fetchHermesUiLinks, setStudioAccessCookie } from '@/lib/hermes';

export default function MissionControlStudio() {
    const [links, setLinks] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetchHermesUiLinks()
            .then((data) => {
                setLinks(data);
                if (data.studio_access_token) {
                    setStudioAccessCookie(data.studio_access_token);
                }
            })
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

    const studioUrl = links?.studio_url;

    return (
        <div className="space-y-4 h-[calc(100vh-8rem)] flex flex-col">
            <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                    <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Box className="w-6 h-6 text-purple-400" />
                        Claw3D Studio
                    </h1>
                    <p className="text-sm text-white/40 mt-1">
                        Escritório 3D Hermes (CT188) · gateway {links?.claw3d_ws_url || '—'}
                    </p>
                </div>
                {studioUrl && (
                    <Button
                        variant="outline"
                        size="sm"
                        className="bg-white/5 border-white/10 text-white/70"
                        asChild
                    >
                        <a href={studioUrl} target="_blank" rel="noopener noreferrer">
                            <ExternalLink className="w-3.5 h-3.5 mr-1.5" />
                            Abrir em nova aba
                        </a>
                    </Button>
                )}
            </div>

            {loading && (
                <Card className="flex-1 bg-white/[0.02] border-white/5 flex items-center justify-center">
                    <Loader2 className="w-6 h-6 animate-spin text-white/40" />
                </Card>
            )}

            {error && (
                <Card className="bg-red-500/10 border-red-500/20">
                    <CardHeader>
                        <CardTitle className="text-red-300 text-sm">Studio indisponível</CardTitle>
                        <CardDescription className="text-red-200/70">{error}</CardDescription>
                    </CardHeader>
                </Card>
            )}

            {!loading && !error && studioUrl && (
                <Card className="flex-1 min-h-0 bg-white/[0.02] border-white/5 overflow-hidden p-0">
                    <CardContent className="p-0 h-full">
                        <iframe
                            title="Claw3D Hermes Studio"
                            src={studioUrl}
                            className="w-full h-full min-h-[600px] border-0 bg-[#0a0a0f]"
                            allow="clipboard-write; fullscreen"
                        />
                    </CardContent>
                </Card>
            )}

            {!loading && !error && links && (
                <p className="text-[11px] text-white/30">
                    Minions Kanban:{' '}
                    <a className="text-blue-400 hover:underline" href={links.minions_url} target="_blank" rel="noreferrer">
                        {links.minions_url}
                    </a>
                    {' · '}
                    Dashboard Nous:{' '}
                    <a className="text-blue-400 hover:underline" href={links.dashboard_url} target="_blank" rel="noreferrer">
                        {links.dashboard_url}
                    </a>
                </p>
            )}
        </div>
    );
}
