import React, { useState } from 'react';
import { Download, FileText, FileSpreadsheet, Code, Calendar } from 'lucide-react';

/**
 * ExportButton Component
 *
 * Data export functionality with multiple formats and scheduled reports.
 *
 * @param {Object} props - Component props
 * @param {String} props.exportEndpoint - API endpoint for export
 * @param {Object} props.filters - Current active filters to apply to export
 * @param {Function} props.onExportComplete - Callback when export completes
 */
export default function ExportButton({
  exportEndpoint = '/api/export',
  filters = {},
  onExportComplete,
}) {
  const [showMenu, setShowMenu] = useState(false);
  const [isExporting, setIsExporting] = useState(false);
  const [exportFormat, setExportFormat] = useState(null);

  // Export formats
  const exportFormats = [
    {
      id: 'csv',
      label: 'Export as CSV',
      icon: FileSpreadsheet,
      description: 'Comma-separated values for spreadsheets',
      extension: 'csv',
      mimeType: 'text/csv',
    },
    {
      id: 'json',
      label: 'Export as JSON',
      icon: Code,
      description: 'JSON format for developers',
      extension: 'json',
      mimeType: 'application/json',
    },
    {
      id: 'pdf',
      label: 'Export as PDF',
      icon: FileText,
      description: 'PDF report for presentations',
      extension: 'pdf',
      mimeType: 'application/pdf',
    },
  ];

  // Handle export
  const handleExport = async (format) => {
    setIsExporting(true);
    setExportFormat(format);

    try {
      // Build export URL with filters
      const params = new URLSearchParams({
        format: format.id,
        ...buildFilterParams(filters),
      });

      // Fetch export data
      const response = await fetch(`${exportEndpoint}?${params}`, {
        method: 'GET',
        headers: {
          Accept: format.mimeType,
        },
      });

      if (!response.ok) {
        throw new Error('Export failed');
      }

      // Get blob
      const blob = await response.blob();

      // Create download link
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = generateFilename(format.extension);
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      // Notify parent
      if (onExportComplete) {
        onExportComplete(format.id);
      }
    } catch (error) {
      console.error('Export error:', error);
      alert('Export failed. Please try again.');
    } finally {
      setIsExporting(false);
      setExportFormat(null);
      setShowMenu(false);
    }
  };

  // Convert filters to URL params
  const buildFilterParams = (filters) => {
    const params = {};

    if (Array.isArray(filters)) {
      params.filters = JSON.stringify(filters);
    }

    return params;
  };

  // Generate filename with timestamp
  const generateFilename = (extension) => {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    return `export-${timestamp}.${extension}`;
  };

  return (
    <div className="export-button relative">
      {/* Export Button */}
      <button
        onClick={() => setShowMenu(!showMenu)}
        disabled={isExporting}
        className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isExporting ? (
          <>
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
            <span>Exporting...</span>
          </>
        ) : (
          <>
            <Download className="w-4 h-4" />
            <span>Export</span>
          </>
        )}
      </button>

      {/* Export Menu */}
      {showMenu && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 z-10"
            onClick={() => setShowMenu(false)}
          ></div>

          {/* Menu */}
          <div className="absolute right-0 mt-2 w-64 bg-white dark:bg-gray-800 rounded-lg shadow-lg z-20 border dark:border-gray-700">
            <div className="p-2">
              {exportFormats.map((format) => {
                const Icon = format.icon;
                return (
                  <button
                    key={format.id}
                    onClick={() => handleExport(format)}
                    disabled={isExporting}
                    className="w-full flex items-start space-x-3 px-3 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Icon className="w-5 h-5 text-gray-600 dark:text-gray-400 mt-0.5" />
                    <div className="text-left">
                      <div className="font-medium text-sm">{format.label}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">
                        {format.description}
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>

            <div className="border-t dark:border-gray-700 p-2">
              <button
                onClick={() => {
                  setShowMenu(false);
                  // TODO: Open schedule dialog
                  alert('Scheduled reports feature coming soon!');
                }}
                className="w-full flex items-center space-x-3 px-3 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
              >
                <Calendar className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                <div className="text-left">
                  <div className="font-medium text-sm">Schedule Report</div>
                  <div className="text-xs text-gray-500 dark:text-gray-400">
                    Automate recurring exports
                  </div>
                </div>
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

/**
 * ScheduledReportDialog Component
 *
 * Dialog for scheduling automated reports.
 */
export function ScheduledReportDialog({ isOpen, onClose, onSave }) {
  const [schedule, setSchedule] = useState({
    name: '',
    format: 'csv',
    frequency: 'daily',
    recipients: [],
    filters: {},
  });

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-lg">
        <h3 className="text-lg font-semibold mb-4">Schedule Report</h3>

        <div className="space-y-4">
          {/* Report Name */}
          <div>
            <label className="block text-sm font-medium mb-1">Report Name</label>
            <input
              type="text"
              value={schedule.name}
              onChange={(e) => setSchedule({ ...schedule, name: e.target.value })}
              placeholder="Daily Container Status Report"
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
            />
          </div>

          {/* Format */}
          <div>
            <label className="block text-sm font-medium mb-1">Export Format</label>
            <select
              value={schedule.format}
              onChange={(e) => setSchedule({ ...schedule, format: e.target.value })}
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
            >
              <option value="csv">CSV</option>
              <option value="json">JSON</option>
              <option value="pdf">PDF</option>
            </select>
          </div>

          {/* Frequency */}
          <div>
            <label className="block text-sm font-medium mb-1">Frequency</label>
            <select
              value={schedule.frequency}
              onChange={(e) => setSchedule({ ...schedule, frequency: e.target.value })}
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
            >
              <option value="hourly">Hourly</option>
              <option value="daily">Daily</option>
              <option value="weekly">Weekly</option>
              <option value="monthly">Monthly</option>
            </select>
          </div>

          {/* Recipients */}
          <div>
            <label className="block text-sm font-medium mb-1">Email Recipients</label>
            <textarea
              value={schedule.recipients.join('\n')}
              onChange={(e) => setSchedule({ ...schedule, recipients: e.target.value.split('\n') })}
              placeholder="Enter email addresses (one per line)"
              className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
              rows={3}
            />
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
            onClick={() => {
              onSave(schedule);
              onClose();
            }}
            disabled={!schedule.name}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
          >
            Schedule Report
          </button>
        </div>
      </div>
    </div>
  );
}

/**
 * ExportTemplateSelector Component
 *
 * Allows users to customize export templates.
 */
export function ExportTemplateSelector({ templates = [], selectedTemplate, onSelect }) {
  return (
    <div className="export-template-selector">
      <label className="block text-sm font-medium mb-2">Export Template</label>
      <select
        value={selectedTemplate || ''}
        onChange={(e) => onSelect(e.target.value)}
        className="w-full px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
      >
        <option value="">Default Template</option>
        {templates.map((template) => (
          <option key={template.id} value={template.id}>
            {template.name}
          </option>
        ))}
      </select>
      <p className="text-xs text-gray-500 mt-1">
        Customize which fields are included in the export
      </p>
    </div>
  );
}
