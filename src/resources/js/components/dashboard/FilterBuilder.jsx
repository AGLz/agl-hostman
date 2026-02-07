import React, { useState, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { X, Plus, Save, Filter } from 'lucide-react';

/**
 * FilterBuilder Component
 *
 * Advanced multi-field filtering with saved presets and URL sharing.
 *
 * @param {Object} props - Component props
 * @param {Array} props.availableFields - Available filter fields
 * @param {Function} props.onFilterChange - Callback when filters change
 * @param {Array} props.savedPresets - Saved filter presets
 * @param {Function} props.onSavePreset - Callback to save a preset
 */
export default function FilterBuilder({
  availableFields = [],
  onFilterChange,
  savedPresets = [],
  onSavePreset,
}) {
  const [searchParams, setSearchParams] = useSearchParams();
  const [filters, setFilters] = useState([]);
  const [showSaveDialog, setShowSaveDialog] = useState(false);
  const [presetName, setPresetName] = useState('');

  // Initialize filters from URL
  React.useEffect(() => {
    const filtersFromUrl = searchParams.get('filters');
    if (filtersFromUrl) {
      try {
        setFilters(JSON.parse(filtersFromUrl));
      } catch (e) {
        console.error('Invalid filters in URL:', e);
      }
    }
  }, [searchParams]);

  // Add a new filter
  const addFilter = useCallback(() => {
    const newFilter = {
      id: `filter-${Date.now()}`,
      field: availableFields[0]?.name || '',
      operator: 'eq',
      value: '',
      logicalOperator: filters.length > 0 ? 'AND' : null,
    };
    setFilters([...filters, newFilter]);
  }, [availableFields, filters]);

  // Remove a filter
  const removeFilter = useCallback((filterId) => {
    const updatedFilters = filters.filter((f) => f.id !== filterId);
    // Update logical operator for next filter
    if (updatedFilters.length > 0) {
      updatedFilters[0].logicalOperator = null;
    }
    setFilters(updatedFilters);
    applyFilters(updatedFilters);
  }, [filters]);

  // Update a filter
  const updateFilter = useCallback((filterId, updates) => {
    const updatedFilters = filters.map((f) =>
      f.id === filterId ? { ...f, ...updates } : f
    );
    setFilters(updatedFilters);
    applyFilters(updatedFilters);
  }, [filters]);

  // Apply filters and update URL
  const applyFilters = useCallback((filterList) => {
    const validFilters = filterList.filter((f) => f.field && f.value);

    // Update URL
    if (validFilters.length > 0) {
      setSearchParams({ filters: JSON.stringify(validFilters) });
    } else {
      searchParams.delete('filters');
      setSearchParams(searchParams);
    }

    // Notify parent
    if (onFilterChange) {
      onFilterChange(validFilters);
    }
  }, [setSearchParams, onFilterChange]);

  // Clear all filters
  const clearFilters = useCallback(() => {
    setFilters([]);
    searchParams.delete('filters');
    setSearchParams(searchParams);
    if (onFilterChange) {
      onFilterChange([]);
    }
  }, [setSearchParams, onFilterChange, searchParams]);

  // Load a preset
  const loadPreset = useCallback((preset) => {
    setFilters(preset.filters);
    applyFilters(preset.filters);
  }, [applyFilters]);

  // Save current filters as preset
  const savePreset = useCallback(() => {
    if (!presetName.trim()) return;

    const preset = {
      id: `preset-${Date.now()}`,
      name: presetName,
      filters: filters.filter((f) => f.field && f.value),
      createdAt: new Date().toISOString(),
    };

    if (onSavePreset) {
      onSavePreset(preset);
    }

    setPresetName('');
    setShowSaveDialog(false);
  }, [presetName, filters, onSavePreset]);

  // Get field definition
  const getField = (fieldName) => {
    return availableFields.find((f) => f.name === fieldName);
  };

  // Get available operators for field type
  const getOperatorsForType = (type) => {
    const operators = {
      string: [
        { value: 'eq', label: 'Equals' },
        { value: 'ne', label: 'Not Equals' },
        { value: 'contains', label: 'Contains' },
        { value: 'startsWith', label: 'Starts With' },
        { value: 'endsWith', label: 'Ends With' },
      ],
      number: [
        { value: 'eq', label: 'Equals' },
        { value: 'ne', label: 'Not Equals' },
        { value: 'gt', label: 'Greater Than' },
        { value: 'gte', label: 'Greater Than or Equal' },
        { value: 'lt', label: 'Less Than' },
        { value: 'lte', label: 'Less Than or Equal' },
      ],
      date: [
        { value: 'eq', label: 'Equals' },
        { value: 'ne', label: 'Not Equals' },
        { value: 'gt', label: 'After' },
        { value: 'gte', label: 'On or After' },
        { value: 'lt', label: 'Before' },
        { value: 'lte', label: 'On or Before' },
        { value: 'between', label: 'Between' },
      ],
      enum: [
        { value: 'eq', label: 'Equals' },
        { value: 'ne', label: 'Not Equals' },
        { value: 'in', label: 'In' },
        { value: 'notIn', label: 'Not In' },
      ],
      boolean: [
        { value: 'eq', label: 'Is' },
      ],
    };

    return operators[type] || operators.string;
  };

  return (
    <div className="filter-builder bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-2">
          <Filter className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <h3 className="text-lg font-semibold">Filters</h3>
          <span className="text-sm text-gray-500">
            {filters.length} {filters.length === 1 ? 'filter' : 'filters'}
          </span>
        </div>

        <div className="flex items-center space-x-2">
          {/* Presets Dropdown */}
          {savedPresets.length > 0 && (
            <select
              className="text-sm border rounded px-3 py-2 bg-white dark:bg-gray-700 dark:border-gray-600"
              onChange={(e) => {
                const preset = savedPresets.find((p) => p.id === e.target.value);
                if (preset) loadPreset(preset);
              }}
              value=""
            >
              <option value="">Load Preset...</option>
              {savedPresets.map((preset) => (
                <option key={preset.id} value={preset.id}>
                  {preset.name}
                </option>
              ))}
            </select>
          )}

          {/* Save Preset Button */}
          <button
            onClick={() => setShowSaveDialog(true)}
            className="flex items-center space-x-1 text-sm px-3 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
            disabled={filters.length === 0}
          >
            <Save className="w-4 h-4" />
            <span>Save Preset</span>
          </button>

          {/* Clear Filters */}
          {filters.length > 0 && (
            <button
              onClick={clearFilters}
              className="text-sm text-red-600 hover:text-red-700"
            >
              Clear All
            </button>
          )}
        </div>
      </div>

      {/* Filter List */}
      <div className="space-y-3 mb-4">
        {filters.map((filter, index) => {
          const field = getField(filter.field);
          const operators = field ? getOperatorsForType(field.type) : [];

          return (
            <div key={filter.id} className="flex items-center space-x-2 p-3 bg-gray-50 dark:bg-gray-900 rounded">
              {/* Logical Operator */}
              {index === 0 ? null : (
                <select
                  value={filter.logicalOperator}
                  onChange={(e) => updateFilter(filter.id, { logicalOperator: e.target.value })}
                  className="text-sm border rounded px-2 py-1 bg-white dark:bg-gray-700 dark:border-gray-600"
                >
                  <option value="AND">AND</option>
                  <option value="OR">OR</option>
                </select>
              )}

              {/* Field Selector */}
              <select
                value={filter.field}
                onChange={(e) => updateFilter(filter.id, { field: e.target.value, operator: 'eq', value: '' })}
                className="flex-1 text-sm border rounded px-3 py-2 bg-white dark:bg-gray-700 dark:border-gray-600"
              >
                <option value="">Select field...</option>
                {availableFields.map((field) => (
                  <option key={field.name} value={field.name}>
                    {field.label}
                  </option>
                ))}
              </select>

              {/* Operator Selector */}
              <select
                value={filter.operator}
                onChange={(e) => updateFilter(filter.id, { operator: e.target.value })}
                className="text-sm border rounded px-3 py-2 bg-white dark:bg-gray-700 dark:border-gray-600"
                disabled={!field}
              >
                {operators.map((op) => (
                  <option key={op.value} value={op.value}>
                    {op.label}
                  </option>
                ))}
              </select>

              {/* Value Input */}
              {field?.type === 'enum' ? (
                <select
                  value={filter.value}
                  onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                  className="flex-1 text-sm border rounded px-3 py-2 bg-white dark:bg-gray-700 dark:border-gray-600"
                >
                  <option value="">Select value...</option>
                  {field.options?.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              ) : field?.type === 'boolean' ? (
                <select
                  value={filter.value}
                  onChange={(e) => updateFilter(filter.id, { value: e.target.value === 'true' })}
                  className="flex-1 text-sm border rounded px-3 py-2 bg-white dark:bg-gray-700 dark:border-gray-600"
                >
                  <option value="">Select...</option>
                  <option value="true">True</option>
                  <option value="false">False</option>
                </select>
              ) : field?.type === 'date' ? (
                <input
                  type="date"
                  value={filter.value}
                  onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                  className="flex-1 text-sm border rounded px-3 py-2 dark:bg-gray-700 dark:border-gray-600"
                />
              ) : field?.type === 'number' ? (
                <input
                  type="number"
                  value={filter.value}
                  onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                  className="flex-1 text-sm border rounded px-3 py-2 dark:bg-gray-700 dark:border-gray-600"
                />
              ) : (
                <input
                  type="text"
                  value={filter.value}
                  onChange={(e) => updateFilter(filter.id, { value: e.target.value })}
                  placeholder={field?.placeholder || 'Enter value...'}
                  className="flex-1 text-sm border rounded px-3 py-2 dark:bg-gray-700 dark:border-gray-600"
                />
              )}

              {/* Remove Button */}
              <button
                onClick={() => removeFilter(filter.id)}
                className="p-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          );
        })}

        {filters.length === 0 && (
          <div className="text-center py-8 text-gray-500">
            <p className="mb-4">No filters applied</p>
            <button
              onClick={addFilter}
              className="inline-flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              <Plus className="w-4 h-4" />
              <span>Add Filter</span>
            </button>
          </div>
        )}
      </div>

      {/* Add Filter Button */}
      {filters.length > 0 && (
        <button
          onClick={addFilter}
          className="w-full flex items-center justify-center space-x-2 px-4 py-2 border-2 border-dashed border-gray-300 rounded hover:border-blue-500 hover:text-blue-600 dark:border-gray-600 dark:hover:border-blue-500"
        >
          <Plus className="w-4 h-4" />
          <span>Add Filter</span>
        </button>
      )}

      {/* Save Preset Dialog */}
      {showSaveDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
            <h3 className="text-lg font-semibold mb-4">Save Filter Preset</h3>
            <input
              type="text"
              value={presetName}
              onChange={(e) => setPresetName(e.target.value)}
              placeholder="Preset name..."
              className="w-full mb-4 px-3 py-2 border rounded dark:bg-gray-700 dark:border-gray-600"
              autoFocus
            />
            <div className="flex justify-end space-x-2">
              <button
                onClick={() => setShowSaveDialog(false)}
                className="px-4 py-2 border rounded hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                Cancel
              </button>
              <button
                onClick={savePreset}
                disabled={!presetName.trim()}
                className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
              >
                Save
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
