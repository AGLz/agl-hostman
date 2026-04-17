import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
    Calendar as CalendarIcon,
    Clock,
    ChevronLeft,
    ChevronRight,
    Plus,
    X,
    Activity,
    Server,
    Shield,
    Zap,
    AlertCircle,
    CheckCircle,
    RefreshCw
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';


const EVENT_CATEGORIES = {
    maintenance: { label: 'Maintenance', color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
    cron: { label: 'Cron Jobs', color: 'bg-green-500/20 text-green-400 border-green-500/30' },
    deployment: { label: 'Deployment', color: 'bg-purple-500/20 text-purple-400 border-purple-500/30' },
    monitoring: { label: 'Monitoring', color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' },
    security: { label: 'Security', color: 'bg-red-500/20 text-red-400 border-red-500/30' },
};

const SAMPLE_EVENTS = [
    { id: 1, title: 'LiteLLM config reload', date: '2026-04-13', time: '14:30', category: 'maintenance', status: 'completed', description: 'Reload config after qwen3.5-flash changes' },
    { id: 2, title: 'OpenClaw update check', date: '2026-04-13', time: '18:00', category: 'cron', status: 'completed', description: 'Scheduled update check via cron' },
    { id: 3, title: 'Mission Control deployment', date: '2026-04-14', time: '09:00', category: 'deployment', status: 'scheduled', description: 'Deploy new Mission Control dashboard pages' },
    { id: 4, title: 'Security scan - all hosts', date: '2026-04-14', time: '02:00', category: 'security', status: 'scheduled', description: 'Automated vulnerability scan' },
    { id: 5, title: 'Database backup', date: '2026-04-14', time: '03:00', category: 'maintenance', status: 'scheduled', description: 'Daily PostgreSQL backup' },
    { id: 6, title: 'Proxmox cluster health check', date: '2026-04-14', time: '06:00', category: 'monitoring', status: 'scheduled', description: 'Check all Proxmox hosts and containers' },
    { id: 7, title: 'Grafana update', date: '2026-04-15', time: '10:00', category: 'deployment', status: 'scheduled', description: 'Update Grafana to latest version' },
    { id: 8, title: 'WireGuard mesh verification', date: '2026-04-15', time: '12:00', category: 'monitoring', status: 'scheduled', description: 'Verify all 14 WG nodes are connected' },
];

function CalendarDay({ day, events, isCurrentMonth, isToday, onClick }) {
    const dayEvents = events.filter(e => new Date(e.date).getDate() === day);

    return (
        <button
            onClick={() => onClick(day, dayEvents)}
            className={cn(
                "relative min-h-[80px] p-2 rounded-lg border transition-all text-left",
                isToday
                    ? "border-blue-500/30 bg-blue-500/5"
                    : "border-white/5 hover:bg-white/[0.03]",
                !isCurrentMonth && "opacity-30"
            )}
        >
            <span className={cn(
                "text-xs font-medium",
                isToday ? "text-blue-400" : "text-white/50"
            )}>
                {day}
            </span>

            <div className="mt-1 space-y-0.5">
                {dayEvents.slice(0, 2).map(event => {
                    const cat = EVENT_CATEGORIES[event.category];
                    return (
                        <div
                            key={event.id}
                            className={cn("text-[9px] px-1 py-0.5 rounded truncate", cat.color)}
                        >
                            {event.title}
                        </div>
                    );
                })}
                {dayEvents.length > 2 && (
                    <div className="text-[9px] text-white/30">+{dayEvents.length - 2} more</div>
                )}
            </div>
        </button>
    );
}

function EventDetail({ events, onClose }) {
    if (!events || events.length === 0) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm" onClick={onClose}>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-md mx-4 bg-[#1a1a24] border border-white/10 rounded-xl p-6 max-h-[80vh] overflow-y-auto"
                onClick={e => e.stopPropagation()}
            >
                <div className="flex items-center justify-between mb-4">
                    <h3 className="text-lg font-semibold text-white">
                        {events[0].date} - {events.length} event{events.length > 1 ? 's' : ''}
                    </h3>
                    <button onClick={onClose} className="text-white/40 hover:text-white">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="space-y-3">
                    {events.map(event => {
                        const cat = EVENT_CATEGORIES[event.category];
                        return (
                            <div key={event.id} className="p-3 rounded-lg bg-white/[0.03] border border-white/5">
                                <div className="flex items-start justify-between">
                                    <div>
                                        <p className="text-sm font-medium text-white/80">{event.title}</p>
                                        <p className="text-xs text-white/40 mt-1">{event.description}</p>
                                    </div>
                                    <Badge variant="secondary" className={cn("text-[10px] border", cat.color)}>
                                        {cat.label}
                                    </Badge>
                                </div>
                                <div className="flex items-center gap-3 mt-2 text-xs text-white/30">
                                    <span className="flex items-center gap-1">
                                        <Clock className="w-3 h-3" />
                                        {event.time}
                                    </span>
                                    <span className={cn(
                                        "flex items-center gap-1",
                                        event.status === 'completed' ? "text-green-400/60" : "text-yellow-400/60"
                                    )}>
                                        {event.status === 'completed' ? (
                                            <CheckCircle className="w-3 h-3" />
                                        ) : (
                                            <AlertCircle className="w-3 h-3" />
                                        )}
                                        {event.status}
                                    </span>
                                </div>
                            </div>
                        );
                    })}
                </div>

                <button
                    onClick={onClose}
                    className="mt-4 w-full py-2 rounded-lg bg-white/5 hover:bg-white/10 text-white/60 hover:text-white text-sm transition-colors"
                >
                    Close
                </button>
            </motion.div>
        </div>
    );
}

export default function CalendarView() {
    const [currentDate, setCurrentDate] = useState(new Date());
    const [selectedDay, setSelectedDay] = useState(null);
    const [selectedEvents, setSelectedEvents] = useState(null);

    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    const today = new Date();

    const firstDayOfMonth = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const daysInPrevMonth = new Date(year, month, 0).getDate();

    const calendarDays = [];

    // Previous month days
    for (let i = firstDayOfMonth - 1; i >= 0; i--) {
        calendarDays.push({ day: daysInPrevMonth - i, currentMonth: false, date: new Date(year, month - 1, daysInPrevMonth - i) });
    }

    // Current month days
    for (let i = 1; i <= daysInMonth; i++) {
        const isToday = i === today.getDate() && month === today.getMonth() && year === today.getFullYear();
        calendarDays.push({ day: i, currentMonth: true, isToday, date: new Date(year, month, i) });
    }

    // Next month days
    const remainingDays = 42 - calendarDays.length;
    for (let i = 1; i <= remainingDays; i++) {
        calendarDays.push({ day: i, currentMonth: false, date: new Date(year, month + 1, i) });
    }

    const monthEvents = SAMPLE_EVENTS.filter(e => {
        const eventDate = new Date(e.date);
        return eventDate.getMonth() === month && eventDate.getFullYear() === year;
    });

    const upcomingEvents = SAMPLE_EVENTS
        .filter(e => new Date(e.date) >= today)
        .sort((a, b) => new Date(a.date) - new Date(b.date))
        .slice(0, 5);

    const handleDayClick = (day, events) => {
        if (events.length > 0) {
            setSelectedEvents(events);
        }
    };

    return (
        
            <div className="space-y-6">
                {/* Header */}
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-bold text-white">Calendar</h1>
                        <p className="text-sm text-white/40 mt-1">Scheduled tasks, cron jobs, and maintenance windows</p>
                    </div>
                    <Button className="bg-blue-600 hover:bg-blue-700 text-white">
                        <Plus className="w-4 h-4 mr-1.5" />
                        New Event
                    </Button>
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Calendar */}
                    <Card className="lg:col-span-2 bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-3">
                            <div className="flex items-center justify-between">
                                <CardTitle className="text-white/80">
                                    {currentDate.toLocaleDateString('en', { month: 'long', year: 'numeric' })}
                                </CardTitle>
                                <div className="flex gap-2">
                                    <Button
                                        variant="ghost"
                                        size="icon"
                                        className="text-white/40 hover:text-white"
                                        onClick={() => setCurrentDate(new Date(year, month - 1))}
                                    >
                                        <ChevronLeft className="w-4 h-4" />
                                    </Button>
                                    <Button
                                        variant="ghost"
                                        size="icon"
                                        className="text-white/40 hover:text-white"
                                        onClick={() => setCurrentDate(new Date(year, month + 1))}
                                    >
                                        <ChevronRight className="w-4 h-4" />
                                    </Button>
                                </div>
                            </div>
                        </CardHeader>
                        <CardContent>
                            {/* Day headers */}
                            <div className="grid grid-cols-7 gap-1 mb-2">
                                {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                                    <div key={day} className="text-center text-[10px] text-white/30 font-medium py-1">
                                        {day}
                                    </div>
                                ))}
                            </div>

                            {/* Calendar grid */}
                            <div className="grid grid-cols-7 gap-1">
                                {calendarDays.map((dayInfo, i) => {
                                    const dayEvents = monthEvents.filter(e => new Date(e.date).getDate() === dayInfo.day && dayInfo.currentMonth);
                                    return (
                                        <CalendarDay
                                            key={i}
                                            day={dayInfo.day}
                                            events={dayEvents}
                                            isCurrentMonth={dayInfo.currentMonth}
                                            isToday={dayInfo.isToday}
                                            onClick={handleDayClick}
                                        />
                                    );
                                })}
                            </div>
                        </CardContent>
                    </Card>

                    {/* Upcoming Events */}
                    <Card className="bg-white/[0.02] border-white/5">
                        <CardHeader className="pb-3">
                            <CardTitle className="text-sm text-white/80 flex items-center gap-2">
                                <CalendarIcon className="w-4 h-4 text-blue-400" />
                                Upcoming Events
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="space-y-3">
                                {upcomingEvents.map(event => {
                                    const cat = EVENT_CATEGORIES[event.category];
                                    return (
                                        <div
                                            key={event.id}
                                            className="p-3 rounded-lg bg-white/[0.03] border border-white/5 hover:bg-white/[0.05] transition-colors"
                                        >
                                            <div className="flex items-start justify-between">
                                                <p className="text-xs font-medium text-white/70">{event.title}</p>
                                                <Badge variant="secondary" className={cn("text-[9px] border", cat.color)}>
                                                    {cat.label}
                                                </Badge>
                                            </div>
                                            <div className="flex items-center gap-2 mt-2 text-[10px] text-white/30">
                                                <span className="flex items-center gap-1">
                                                    <Clock className="w-3 h-3" />
                                                    {new Date(event.date).toLocaleDateString('en', { month: 'short', day: 'numeric' })} at {event.time}
                                                </span>
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>

                            {/* Cron Jobs Summary */}
                            <div className="mt-6 pt-4 border-t border-white/5">
                                <h4 className="text-xs text-white/40 mb-3 flex items-center gap-2">
                                    <RefreshCw className="w-3 h-3" />
                                    Active Cron Jobs
                                </h4>
                                <div className="space-y-2">
                                    {[
                                        { name: 'websites-monitor', interval: '15m', status: 'failing' },
                                        { name: 'critical-services-monitor', interval: '5m', status: 'failing' },
                                        { name: 'storage-health-check', interval: '60m', status: 'failing' },
                                        { name: 'host-health-check', interval: '30m', status: 'failing' },
                                        { name: 'ai-stack-health', interval: '60m', status: 'failing' },
                                    ].map(cron => (
                                        <div key={cron.name} className="flex items-center justify-between text-xs">
                                            <span className="text-white/50 truncate">{cron.name}</span>
                                            <div className="flex items-center gap-2">
                                                <span className="text-white/30">{cron.interval}</span>
                                                <span className={cn(
                                                    "w-1.5 h-1.5 rounded-full",
                                                    cron.status === 'failing' ? "bg-red-500" : "bg-green-500"
                                                )} />
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                </div>

                {/* Event Detail Modal */}
                <EventDetail events={selectedEvents} onClose={() => setSelectedEvents(null)} />
            </div>
        
    );
}
