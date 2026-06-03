import React, { useEffect, useState } from 'react';
import { ExternalLink, Kanban, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { fetchHermesUiLinks } from '@/lib/hermes';

export default function MissionControlMinions() {
    const [links, setLinks] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetchHermesUiLinks()
            .then(setLinks)
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

    const minionsUrl = links?.minions_url;

    return (
        <div className="space-y-4 h-[calc(100vh-8rem)] flex flex-col">
            <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                    <h1 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Kanban className="w-6 h-6 text-blue-400" />
                        Minions Kanban
                    </h1>
                    <p className="text-sm text-white/40 mt-1">
                        Mission Control Hermes (CT188) · tarefas autónomas e cron
                    </p>
                </div>
                {minionsUrl && (
                    <Button
                        variant="outline"
                        size="sm"
                        className="bg-white/5 border-white/10 text-white/70"
                        asChild
                    >
                        <a href={minionsUrl} target="_blank" rel="noopener noreferrer">
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
                        <CardTitle className="text-red-300 text-sm">Minions indisponível</CardTitle>
                        <CardDescription className="text-red-200/70">{error}</CardDescription>
                    </CardHeader>
                </Card>
            )}

            {!loading && !error && minionsUrl && (
                <Card className="flex-1 min-h-0 bg-white/[0.02] border-white/5 overflow-hidden p-0">
                    <CardContent className="p-0 h-full">
                        <iframe
                            title="Hermes Minions Kanban"
                            src={minionsUrl}
                            className="w-full h-full min-h-[600px] border-0 bg-[#0a0a0f]"
                            allow="clipboard-write"
                        />
                    </CardContent>
                </Card>
            )}
        </div>
    );

}
