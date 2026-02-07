import React, { useState, useCallback, useEffect } from 'react';
import {
  Plus,
  Trash2,
  Settings,
  Save,
  RotateCcw,
  Maximize2,
  Grid3x3,
  LayoutTemplate,
  Monitor,
  Cpu,
  HardDrive,
  AlertTriangle,
  Activity,
  TrendingUp,
  Users,
  Clock,
} from 'lucide-react';

/**
 * CustomDashboard Component
 *
 * Drag-and-drop customizable dashboard with widget library and templates.
 *
 * @param {Object} props - Component props
 * @param {Array} props.widgets - Available widget definitions
 * @param {Array} props.initialLayout - Initial dashboard layout
 * @param {Function} props.onLayoutChange - Callback when layout changes
 * @param {Function} props.onSaveDashboard - Callback to save dashboard
 * @param {Boolean} props.editable - Whether dashboard is editable
 */
export default function CustomDashboard({
  widgets = [],
  initialLayout = [],
  onLayoutChange,
  onSaveDashboard,
  editable = true,
}) {
  const [layout, setLayout] = useState(initialLayout);
  const [selectedWidget, setSelectedWidget] = useState(null);
  const [showWidgetLibrary, setShowWidgetLibrary] = useState(false);
  const [showTemplateDialog, setShowTemplateDialog] = useState(false);
  const [draggedWidget, setDraggedWidget] = useState(null);
  const [dashboardName, setDashboardName] = useState('My Dashboard');
  const [isFullscreen, setIsFullscreen] = useState(false);

  // Default widgets
  const defaultWidgets = [
    {
      id: 'container-status',
      type: 'container-status',
      title: 'Container Status',
      icon: Monitor,
      defaultSize: { w: 2, h: 2 },
      category: 'Infrastructure',
    },
    {
      id: 'cpu-usage',
      type: 'cpu-usage',
      title: 'CPU Usage',
      icon: Cpu,
      defaultSize: { w: 1, h: 2 },
      category: 'Metrics',
    },
    {
      id: 'memory-usage',
      type: 'memory-usage',
      title: 'Memory Usage',
      icon: HardDrive,
      defaultSize: { w: 1, h: 2 },
      category: 'Metrics',
    },
    {
      id: 'active-alerts',
      type: 'active-alerts',
      title: 'Active Alerts',
      icon: AlertTriangle,
      defaultSize: { w: 2, h: 1 },
      category: 'Monitoring',
    },
    {
      id: 'deployment-history',
      type: 'deployment-history',
      title: 'Deployment History',
      icon: Clock,
      defaultSize: { w: 2, h: 2 },
      category: 'Deployments',
    },
    {
      id: 'system-metrics',
      type: 'system-metrics',
      title: 'System Metrics',
      icon: Activity,
      defaultSize: { w: 2, h: 2 },
      category: 'Metrics',
    },
    {
      id: 'trend-chart',
      type: 'trend-chart',
      title: 'Trend Analysis',
      icon: TrendingUp,
      defaultSize: { w: 2, h: 2 },
      category: 'Analytics',
    },
    {
      id: 'user-activity',
      type: 'user-activity',
      title: 'User Activity',
      icon: Users,
      defaultSize: { w: 2, h: 1 },
      category: 'Monitoring',
    },
  ];

  // Dashboard templates
  const dashboardTemplates = [
    {
      id: 'operations',
      name: 'Operations Overview',
      description: 'Monitor system health and performance',
      icon: Activity,
      widgets: [
        { id: 'container-status', position: { x: 0, y: 0, w: 2, h: 2 } },
        { id: 'system-metrics', position: { x: 2, y: 0, w: 2, h: 2 } },
        { id: 'active-alerts', position: { x: 0, y: 2, w: 2, h: 1 } },
        { id: 'cpu-usage', position: { x: 2, y: 2, w: 1, h: 2 } },
        { id: 'memory-usage', position: { x: 3, y: 2, w: 1, h: 2 } },
      ],
    },
    {
      id: 'developer',
      name: 'Developer Dashboard',
      description: 'Track deployments and system status',
      icon: Code,
      widgets: [
        { id: 'deployment-history', position: { x: 0, y: 0, w: 2, h: 2 } },
        { id: 'container-status', position: { x: 2, y: 0, w: 2, h: 2 } },
        { id: 'trend-chart', position: { x: 0, y: 2, w: 2, h: 2 } },
        { id: 'active-alerts', position: { x: 2, y: 2, w: 2, h: 1 } },
      ],
    },
    {
      id: 'analytics',
      name: 'Analytics Dashboard',
      description: 'Deep dive into metrics and trends',
      icon: TrendingUp,
      widgets: [
        { id: 'trend-chart', position: { x: 0, y: 0, w: 2, h: 2 } },
        { id: 'system-metrics', position: { x: 2, y: 0, w: 2, h: 2 } },
        { id: 'user-activity', position: { x: 0, y: 2, w: 2, h: 1 } },
        { id: 'cpu-usage', position: { x: 2, y: 2, w: 1, h: 2 } },
        { id: 'memory-usage', position: { x: 3, y: 2, w: 1, h: 2 } },
      ],
    },
    {
      id: 'minimal',
      name: 'Minimal View',
      description: 'Essential metrics at a glance',
      icon: Grid3x3,
      widgets: [
        { id: 'container-status', position: { x: 0, y: 0, w: 2, h: 2 } },
        { id: 'active-alerts', position: { x: 2, y: 0, w: 2, h: 1 } },
      ],
    },
  ];

  // Initialize with default layout if none provided
  useEffect(() => {
    if (layout.length === 0) {
      loadTemplate('operations');
    }
  }, []);

  // Add widget to layout
  const addWidget = useCallback((widgetId) => {
    const widgetDef = defaultWidgets.find((w) => w.id === widgetId);
    if (!widgetDef) return;

    const newWidget = {
      id: `${widgetId}-${Date.now()}`,
      type: widgetId,
      title: widgetDef.title,
      position: {
        x: 0,
        y: layout.length > 0 ? Math.max(...layout.map((w) => w.position.y + w.position.h)) : 0,
        w: widgetDef.defaultSize.w,
        h: widgetDef.defaultSize.h,
      },
      config: {},
    };

    const updatedLayout = [...layout, newWidget];
    setLayout(updatedLayout);
    if (onLayoutChange) {
      onLayoutChange(updatedLayout);
    }
  }, [layout, onLayoutChange]);

  // Remove widget from layout
  const removeWidget = useCallback((widgetId) => {
    const updatedLayout = layout.filter((w) => w.id !== widgetId);
    setLayout(updatedLayout);
    if (onLayoutChange) {
      onLayoutChange(updatedLayout);
    }
    setSelectedWidget(null);
  }, [layout, onLayoutChange]);

  // Update widget position
  const updateWidgetPosition = useCallback((widgetId, newPosition) => {
    const updatedLayout = layout.map((w) =>
      w.id === widgetId ? { ...w, position: { ...w.position, ...newPosition } } : w
    );
    setLayout(updatedLayout);
    if (onLayoutChange) {
      onLayoutChange(updatedLayout);
    }
  }, [layout, onLayoutChange]);

  // Update widget config
  const updateWidgetConfig = useCallback((widgetId, config) => {
    const updatedLayout = layout.map((w) =>
      w.id === widgetId ? { ...w, config: { ...w.config, ...config } } : w
    );
    setLayout(updatedLayout);
    if (onLayoutChange) {
      onLayoutChange(updatedLayout);
    }
  }, [layout, onLayoutChange]);

  // Load template
  const loadTemplate = useCallback((templateId) => {
    const template = dashboardTemplates.find((t) => t.id === templateId);
    if (!template) return;

    const newLayout = template.widgets.map((w) => ({
      id: `${w.id}-${Date.now()}-${Math.random()}`,
      type: w.id,
      title: defaultWidgets.find((dw) => dw.id === w.id)?.title || w.id,
      position: w.position,
      config: {},
    }));

    setLayout(newLayout);
    setDashboardName(template.name);
    if (onLayoutChange) {
      onLayoutChange(newLayout);
    }
    setShowTemplateDialog(false);
  }, [onLayoutChange]);

  // Save dashboard
  const saveDashboard = useCallback(() => {
    if (onSaveDashboard) {
      onSaveDashboard({
        name: dashboardName,
        layout,
        createdAt: new Date().toISOString(),
      });
    }
    // Save to localStorage for persistence
    localStorage.setItem(
      'custom-dashboard',
      JSON.stringify({ name: dashboardName, layout })
    );
  }, [dashboardName, layout, onSaveDashboard]);

  // Reset dashboard
  const resetDashboard = useCallback(() => {
    setLayout([]);
    setDashboardName('My Dashboard');
    setShowTemplateDialog(true);
  }, []);

  // Handle drag start
  const handleDragStart = useCallback((e, widgetId) => {
    setDraggedWidget(widgetId);
    e.dataTransfer.effectAllowed = 'move';
  }, []);

  // Handle drag over
  const handleDragOver = useCallback((e) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
  }, []);

  // Handle drop
  const handleDrop = useCallback((e, targetWidgetId) => {
    e.preventDefault();
    if (!draggedWidget || draggedWidget === targetWidgetId) return;

    const draggedIndex = layout.findIndex((w) => w.id === draggedWidget);
    const targetIndex = layout.findIndex((w) => w.id === targetWidgetId);

    if (draggedIndex === -1 || targetIndex === -1) return;

    const newLayout = [...layout];
    const [removed] = newLayout.splice(draggedIndex, 1);
    newLayout.splice(targetIndex, 0, removed);

    setLayout(newLayout);
    if (onLayoutChange) {
      onLayoutChange(newLayout);
    }
    setDraggedWidget(null);
  }, [draggedWidget, layout, onLayoutChange]);

  // Get widget category color
  const getCategoryColor = (category) => {
    const colors = {
      Infrastructure: 'bg-blue-500',
      Metrics: 'bg-green-500',
      Monitoring: 'bg-purple-500',
      Deployments: 'bg-orange-500',
      Analytics: 'bg-pink-500',
    };
    return colors[category] || 'bg-gray-500';
  };

  return (
    <div className={`custom-dashboard ${isFullscreen ? 'fixed inset-0 z-50 bg-white dark:bg-gray-900' : ''}`}>
      {/* Header */}
      <div className="bg-white dark:bg-gray-800 border-b dark:border-gray-700 px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <LayoutTemplate className="w-6 h-6 text-gray-600 dark:text-gray-400" />
            <div>
              <input
                type="text"
                value={dashboardName}
                onChange={(e) => setDashboardName(e.target.value)}
                className="text-xl font-semibold bg-transparent border-none focus:outline-none focus:ring-2 focus:ring-blue-500 rounded px-2 py-1"
                disabled={!editable}
              />
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {layout.length} widgets
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            {/* Template Selector */}
            {editable && (
              <button
                onClick={() => setShowTemplateDialog(true)}
                className="flex items-center space-x-2 px-4 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <LayoutTemplate className="w-4 h-4" />
                <span>Templates</span>
              </button>
            )}

            {/* Widget Library */}
            {editable && (
              <button
                onClick={() => setShowWidgetLibrary(!showWidgetLibrary)}
                className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
              >
                <Plus className="w-4 h-4" />
                <span>Add Widget</span>
              </button>
            )}

            {/* Reset */}
            <button
              onClick={resetDashboard}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
              title="Reset Dashboard"
            >
              <RotateCcw className="w-4 h-4" />
            </button>

            {/* Fullscreen */}
            <button
              onClick={() => setIsFullscreen(!isFullscreen)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
              title="Toggle Fullscreen"
            >
              <Maximize2 className="w-4 h-4" />
            </button>

            {/* Save */}
            {editable && (
              <button
                onClick={saveDashboard}
                className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
              >
                <Save className="w-4 h-4" />
                <span>Save</span>
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="flex">
        {/* Widget Library Sidebar */}
        {showWidgetLibrary && (
          <div className="w-80 bg-white dark:bg-gray-800 border-r dark:border-gray-700 p-4 overflow-y-auto max-h-screen">
            <h3 className="text-lg font-semibold mb-4">Widget Library</h3>

            {Object.entries(
              defaultWidgets.reduce((acc, widget) => {
                if (!acc[widget.category]) {
                  acc[widget.category] = [];
                }
                acc[widget.category].push(widget);
                return acc;
              }, {})
            ).map(([category, categoryWidgets]) => (
              <div key={category} className="mb-6">
                <div className="flex items-center space-x-2 mb-2">
                  <div className={`w-2 h-2 rounded ${getCategoryColor(category)}`}></div>
                  <h4 className="font-medium text-sm">{category}</h4>
                </div>
                <div className="space-y-2">
                  {categoryWidgets.map((widget) => {
                    const Icon = widget.icon;
                    return (
                      <button
                        key={widget.id}
                        onClick={() => addWidget(widget.id)}
                        className="w-full flex items-center space-x-3 p-3 bg-gray-50 dark:bg-gray-900 rounded hover:bg-blue-50 dark:hover:bg-blue-900/20"
                      >
                        <Icon className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                        <div className="text-left flex-1">
                          <div className="font-medium text-sm">{widget.title}</div>
                          <div className="text-xs text-gray-500">
                            {widget.defaultSize.w}x{widget.defaultSize.h}
                          </div>
                        </div>
                        <Plus className="w-4 h-4 text-gray-400" />
                      </button>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Dashboard Grid */}
        <div className="flex-1 p-6">
          {layout.length === 0 ? (
            <div className="h-full flex items-center justify-center">
              <div className="text-center">
                <LayoutTemplate className="w-16 h-16 mx-auto mb-4 text-gray-400" />
                <h3 className="text-lg font-semibold mb-2">Your dashboard is empty</h3>
                <p className="text-gray-500 mb-4">Add widgets or start from a template</p>
                <div className="flex items-center justify-center space-x-2">
                  <button
                    onClick={() => setShowTemplateDialog(true)}
                    className="px-4 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
                  >
                    Use Template
                  </button>
                  <button
                    onClick={() => setShowWidgetLibrary(true)}
                    className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                  >
                    Add Widgets
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="grid grid-cols-4 gap-4">
              {layout.map((widget) => {
                const widgetDef = defaultWidgets.find((w) => w.id === widget.type);
                const Icon = widgetDef?.icon || Grid3x3;
                const isSelected = selectedWidget === widget.id;

                return (
                  <div
                    key={widget.id}
                    draggable={editable}
                    onDragStart={(e) => handleDragStart(e, widget.id)}
                    onDragOver={handleDragOver}
                    onDrop={(e) => handleDrop(e, widget.id)}
                    className={`
                      relative bg-white dark:bg-gray-800 rounded-lg shadow p-4
                      ${widget.position.w === 1 ? 'col-span-1' : 'col-span-2'}
                      ${widget.position.h === 1 ? 'row-span-1' : 'row-span-2'}
                      ${isSelected ? 'ring-2 ring-blue-500' : ''}
                      ${editable ? 'cursor-move' : ''}
                    `}
                    style={{ minHeight: widget.position.h === 1 ? '200px' : '400px' }}
                  >
                    {/* Widget Header */}
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center space-x-2">
                        <Icon className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                        <h4 className="font-medium">{widget.title}</h4>
                      </div>
                      {editable && (
                        <div className="flex items-center space-x-1">
                          <button
                            onClick={() => setSelectedWidget(isSelected ? null : widget.id)}
                            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
                          >
                            <Settings className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => removeWidget(widget.id)}
                            className="p-1 hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 rounded"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      )}
                    </div>

                    {/* Widget Content */}
                    <div className="h-[calc(100%-40px)]">
                      {renderWidgetContent(widget.type, widget.config)}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Template Dialog */}
      {showTemplateDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-2xl max-h-[80vh] overflow-y-auto">
            <h3 className="text-lg font-semibold mb-4">Choose a Template</h3>

            <div className="grid grid-cols-2 gap-4">
              {dashboardTemplates.map((template) => {
                const Icon = template.icon;
                return (
                  <button
                    key={template.id}
                    onClick={() => loadTemplate(template.id)}
                    className="p-4 border rounded hover:bg-blue-50 dark:hover:bg-blue-900/20 text-left"
                  >
                    <Icon className="w-8 h-8 mb-2 text-blue-600" />
                    <h4 className="font-medium mb-1">{template.name}</h4>
                    <p className="text-sm text-gray-500 mb-2">{template.description}</p>
                    <p className="text-xs text-gray-400">
                      {template.widgets.length} widgets
                    </p>
                  </button>
                );
              })}
            </div>

            <div className="flex justify-end mt-6">
              <button
                onClick={() => setShowTemplateDialog(false)}
                className="px-4 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Widget Config Dialog */}
      {selectedWidget && editable && (
        <WidgetConfigDialog
          widget={layout.find((w) => w.id === selectedWidget)}
          onClose={() => setSelectedWidget(null)}
          onSave={(config) => {
            updateWidgetConfig(selectedWidget, config);
            setSelectedWidget(null);
          }}
        />
      )}
    </div>
  );
}

/**
 * WidgetConfigDialog Component
 *
 * Dialog for configuring individual widgets.
 */
function WidgetConfigDialog({ widget, onClose, onSave }) {
  const [config, setConfig] = useState(widget?.config || {});

  if (!widget) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
        <h3 className="text-lg font-semibold mb-4">Configure {widget.title}</h3>

        <div className="space-y-4">
          {/* Refresh Interval */}
          <div>
            <label className="block text-sm font-medium mb-1">Refresh Interval</label>
            <select
              value={config.refreshInterval || 30}
              onChange={(e) => setConfig({ ...config, refreshInterval: parseInt(e.target.value) })}
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
            >
              <option value={10}>10 seconds</option>
              <option value={30}>30 seconds</option>
              <option value={60}>1 minute</option>
              <option value={300}>5 minutes</option>
            </select>
          </div>

          {/* Show Title */}
          <div className="flex items-center justify-between">
            <label className="text-sm font-medium">Show Title</label>
            <input
              type="checkbox"
              checked={config.showTitle !== false}
              onChange={(e) => setConfig({ ...config, showTitle: e.target.checked })}
              className="rounded"
            />
          </div>

          {/* Custom Title */}
          {config.showTitle !== false && (
            <div>
              <label className="block text-sm font-medium mb-1">Custom Title</label>
              <input
                type="text"
                value={config.customTitle || ''}
                onChange={(e) => setConfig({ ...config, customTitle: e.target.value })}
                placeholder={widget.title}
                className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
              />
            </div>
          )}

          {/* Theme */}
          <div>
            <label className="block text-sm font-medium mb-1">Theme</label>
            <select
              value={config.theme || 'default'}
              onChange={(e) => setConfig({ ...config, theme: e.target.value })}
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
            >
              <option value="default">Default</option>
              <option value="minimal">Minimal</option>
              <option value="detailed">Detailed</option>
            </select>
          </div>
        </div>

        <div className="flex justify-end space-x-2 mt-6">
          <button
            onClick={onClose}
            className="px-4 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
          >
            Cancel
          </button>
          <button
            onClick={() => onSave(config)}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

/**
 * Render widget content based on type
 */
function renderWidgetContent(type, config) {
  switch (type) {
    case 'container-status':
      return (
        <div className="h-full flex items-center justify-center">
          <div className="text-center">
            <Monitor className="w-12 h-12 mx-auto mb-2 text-green-500" />
            <p className="text-2xl font-bold">12</p>
            <p className="text-sm text-gray-500">Running Containers</p>
          </div>
        </div>
      );

    case 'cpu-usage':
      return (
        <div className="h-full flex items-center justify-center">
          <div className="text-center">
            <Cpu className="w-12 h-12 mx-auto mb-2 text-blue-500" />
            <p className="text-2xl font-bold">45%</p>
            <p className="text-sm text-gray-500">CPU Usage</p>
          </div>
        </div>
      );

    case 'memory-usage':
      return (
        <div className="h-full flex items-center justify-center">
          <div className="text-center">
            <HardDrive className="w-12 h-12 mx-auto mb-2 text-purple-500" />
            <p className="text-2xl font-bold">68%</p>
            <p className="text-sm text-gray-500">Memory Usage</p>
          </div>
        </div>
      );

    case 'active-alerts':
      return (
        <div className="h-full">
          <div className="space-y-2">
            {[1, 2, 3].map((i) => (
              <div key={i} className="flex items-center justify-between p-2 bg-red-50 dark:bg-red-900/20 rounded">
                <div className="flex items-center space-x-2">
                  <AlertTriangle className="w-4 h-4 text-red-600" />
                  <span className="text-sm">Alert {i}</span>
                </div>
                <span className="text-xs text-gray-500">2m ago</span>
              </div>
            ))}
          </div>
        </div>
      );

    case 'deployment-history':
      return (
        <div className="h-full overflow-y-auto">
          <div className="space-y-2">
            {['v1.2.0', 'v1.1.9', 'v1.1.8'].map((version, i) => (
              <div key={version} className="flex items-center justify-between p-2 bg-gray-50 dark:bg-gray-900 rounded">
                <div>
                  <p className="text-sm font-medium">{version}</p>
                  <p className="text-xs text-gray-500">
                    {i === 0 ? 'Deployed just now' : `${i * 5}m ago`}
                  </p>
                </div>
                <span className="text-xs text-green-600">Success</span>
              </div>
            ))}
          </div>
        </div>
      );

    case 'system-metrics':
      return (
        <div className="h-full grid grid-cols-2 gap-2">
          {[
            { label: 'CPU', value: '45%', color: 'text-blue-600' },
            { label: 'Memory', value: '68%', color: 'text-purple-600' },
            { label: 'Disk', value: '52%', color: 'text-green-600' },
            { label: 'Network', value: '23%', color: 'text-orange-600' },
          ].map((metric) => (
            <div key={metric.label} className="p-3 bg-gray-50 dark:bg-gray-900 rounded">
              <p className="text-xs text-gray-500">{metric.label}</p>
              <p className={`text-lg font-bold ${metric.color}`}>{metric.value}</p>
            </div>
          ))}
        </div>
      );

    case 'trend-chart':
      return (
        <div className="h-full flex items-center justify-center">
          <div className="text-center">
            <TrendingUp className="w-12 h-12 mx-auto mb-2 text-green-500" />
            <p className="text-sm text-gray-500">Trend Analysis</p>
            <p className="text-xs text-gray-400 mt-1">Visualization widget</p>
          </div>
        </div>
      );

    case 'user-activity':
      return (
        <div className="h-full overflow-y-auto">
          <div className="space-y-2">
            {['User A logged in', 'User B deployed', 'User C created'].map((activity, i) => (
              <div key={i} className="flex items-center space-x-2 p-2 bg-gray-50 dark:bg-gray-900 rounded">
                <Users className="w-4 h-4 text-gray-400" />
                <p className="text-sm">{activity}</p>
              </div>
            ))}
          </div>
        </div>
      );

    default:
      return (
        <div className="h-full flex items-center justify-center">
          <div className="text-center">
            <Grid3x3 className="w-12 h-12 mx-auto mb-2 text-gray-400" />
            <p className="text-sm text-gray-500">Widget: {type}</p>
          </div>
        </div>
      );
  }
}
