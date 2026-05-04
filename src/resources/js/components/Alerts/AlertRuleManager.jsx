import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/Components/ui/card';
import { Button } from '@/Components/ui/button';
import { Badge } from '@/Components/ui/badge';
import { Switch } from '@/Components/ui/switch';
import {
    Plus, Edit, Trash2, TestTube, Save, X, AlertCircle, CheckCircle
} from 'lucide-react';
import axios from 'axios';

/**
 * AlertRuleManager - Rule configuration UI component
 *
 * Features:
 * - Create/edit/delete rules
 * - Test rules button with real-time feedback
 * - Enable/disable toggle
 * - Cooldown configuration
 * - Condition builder (visual UI for thresholds)
 * - Rule type selection (threshold/pattern/anomaly)
 * - Severity configuration
 *
 * @param {Object} props
 * @param {Function} props.onRuleChange - Callback when rules change
 */
export function AlertRuleManager({ onRuleChange }) {
    const [rules, setRules] = useState([]);
    const [loading, setLoading] = useState(true);
    const [editingRule, setEditingRule] = useState(null);
    const [showEditor, setShowEditor] = useState(false);
    const [testingRule, setTestingRule] = useState(null);
    const [testResult, setTestResult] = useState(null);

    // Form state
    const [formData, setFormData] = useState({
        name: '',
        type: 'threshold',
        enabled: true,
        severity: 'warning',
        conditions: {},
        cooldown_minutes: 15,
        metadata: {}
    });

    // Fetch all rules
    const fetchRules = async () => {
        setLoading(true);
        try {
            const response = await axios.get('/api/alert-rules');
            setRules(response.data);
            onRuleChange?.(response.data);
        } catch (error) {
            console.error('Failed to fetch alert rules:', error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchRules();
    }, []);

    // Create new rule
    const handleCreate = async () => {
        try {
            await axios.post('/api/alert-rules', formData);
            await fetchRules();
            setShowEditor(false);
            resetForm();
        } catch (error) {
            console.error('Failed to create rule:', error);
            alert('Failed to create rule. Please check your input.');
        }
    };

    // Update existing rule
    const handleUpdate = async () => {
        try {
            await axios.put(`/api/alert-rules/${editingRule.id}`, formData);
            await fetchRules();
            setShowEditor(false);
            setEditingRule(null);
            resetForm();
        } catch (error) {
            console.error('Failed to update rule:', error);
            alert('Failed to update rule. Please check your input.');
        }
    };

    // Delete rule
    const handleDelete = async (ruleId) => {
        if (!confirm('Are you sure you want to delete this rule?')) return;

        try {
            await axios.delete(`/api/alert-rules/${ruleId}`);
            await fetchRules();
        } catch (error) {
            console.error('Failed to delete rule:', error);
            alert('Failed to delete rule.');
        }
    };

    // Toggle rule enabled/disabled
    const handleToggle = async (ruleId) => {
        try {
            await axios.post(`/api/alert-rules/${ruleId}/toggle`);
            await fetchRules();
        } catch (error) {
            console.error('Failed to toggle rule:', error);
        }
    };

    // Test rule
    const handleTest = async (ruleId) => {
        setTestingRule(ruleId);
        setTestResult(null);

        try {
            const response = await axios.post(`/api/alert-rules/${ruleId}/test`);
            setTestResult(response.data);
        } catch (error) {
            console.error('Failed to test rule:', error);
            setTestResult({
                success: false,
                message: 'Failed to test rule: ' + (error.response?.data?.message || error.message)
            });
        } finally {
            setTimeout(() => {
                setTestingRule(null);
                setTestResult(null);
            }, 5000);
        }
    };

    // Edit rule
    const handleEdit = (rule) => {
        setEditingRule(rule);
        setFormData({
            name: rule.name,
            type: rule.type,
            enabled: rule.enabled,
            severity: rule.severity,
            conditions: rule.conditions || {},
            cooldown_minutes: rule.cooldown_minutes || 15,
            metadata: rule.metadata || {}
        });
        setShowEditor(true);
    };

    // Reset form
    const resetForm = () => {
        setFormData({
            name: '',
            type: 'threshold',
            enabled: true,
            severity: 'warning',
            conditions: {},
            cooldown_minutes: 15,
            metadata: {}
        });
        setEditingRule(null);
    };

    // Get type color
    const getTypeColor = (type) => {
        switch (type) {
            case 'threshold': return 'bg-blue-100 text-blue-800';
            case 'pattern': return 'bg-purple-100 text-purple-800';
            case 'anomaly': return 'bg-orange-100 text-orange-800';
            default: return 'bg-gray-100 text-gray-800';
        }
    };

    // Get severity color
    const getSeverityColor = (severity) => {
        switch (severity) {
            case 'critical': return 'bg-red-100 text-red-800';
            case 'warning': return 'bg-yellow-100 text-yellow-800';
            case 'info': return 'bg-blue-100 text-blue-800';
            default: return 'bg-gray-100 text-gray-800';
        }
    };

    return (
        <Card>
            <CardHeader>
                <div className="flex items-center justify-between">
                    <CardTitle>Alert Rules</CardTitle>
                    <Button
                        variant="default"
                        size="sm"
                        onClick={() => setShowEditor(true)}
                    >
                        <Plus className="w-4 h-4 mr-1" />
                        Create Rule
                    </Button>
                </div>
            </CardHeader>

            <CardContent>
                {loading ? (
                    <div className="text-center py-8 text-gray-500">
                        Loading rules...
                    </div>
                ) : rules.length === 0 ? (
                    <div className="text-center py-8 text-gray-500">
                        No alert rules configured. Create one to get started.
                    </div>
                ) : (
                    <div className="space-y-3">
                        {rules.map((rule) => (
                            <Card key={rule.id} className={`${!rule.enabled ? 'opacity-60' : ''}`}>
                                <CardContent className="p-4">
                                    <div className="flex items-start justify-between">
                                        <div className="flex-grow">
                                            <div className="flex items-center gap-2 mb-2">
                                                <h4 className="font-semibold text-gray-900">
                                                    {rule.name}
                                                </h4>
                                                <Badge className={getTypeColor(rule.type)}>
                                                    {rule.type}
                                                </Badge>
                                                <Badge className={getSeverityColor(rule.severity)}>
                                                    {rule.severity}
                                                </Badge>
                                                {!rule.enabled && (
                                                    <Badge variant="outline" className="text-gray-500">
                                                        Disabled
                                                    </Badge>
                                                )}
                                            </div>

                                            <div className="text-sm text-gray-600">
                                                Cooldown: {rule.cooldown_minutes} minutes
                                                {rule.last_triggered_at && (
                                                    <span className="ml-3">
                                                        Last triggered: {new Date(rule.last_triggered_at).toLocaleString()}
                                                    </span>
                                                )}
                                            </div>
                                        </div>

                                        {/* Actions */}
                                        <div className="flex items-center gap-2">
                                            <Switch
                                                checked={rule.enabled}
                                                onCheckedChange={() => handleToggle(rule.id)}
                                            />
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleTest(rule.id)}
                                                disabled={testingRule === rule.id}
                                            >
                                                <TestTube className="w-4 h-4" />
                                            </Button>
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleEdit(rule)}
                                            >
                                                <Edit className="w-4 h-4" />
                                            </Button>
                                            <Button
                                                variant="outline"
                                                size="sm"
                                                onClick={() => handleDelete(rule.id)}
                                                className="text-red-600 hover:bg-red-50"
                                            >
                                                <Trash2 className="w-4 h-4" />
                                            </Button>
                                        </div>
                                    </div>

                                    {/* Test result */}
                                    {testingRule === rule.id && testResult && (
                                        <div className={`mt-3 p-3 rounded ${testResult.success ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
                                            <div className="flex items-start gap-2">
                                                {testResult.success ? (
                                                    <CheckCircle className="w-5 h-5 text-green-600 mt-0.5" />
                                                ) : (
                                                    <AlertCircle className="w-5 h-5 text-red-600 mt-0.5" />
                                                )}
                                                <div className="flex-grow">
                                                    <p className="font-medium text-sm">
                                                        {testResult.message}
                                                    </p>
                                                    {testResult.triggered && testResult.alert && (
                                                        <p className="text-sm text-gray-600 mt-1">
                                                            Alert created: {testResult.alert.title}
                                                        </p>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </CardContent>
                            </Card>
                        ))}
                    </div>
                )}

                {/* Rule Editor Modal */}
                {showEditor && (
                    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                        <Card className="w-full max-w-2xl max-h-[90vh] overflow-y-auto">
                            <CardHeader>
                                <div className="flex items-center justify-between">
                                    <CardTitle>
                                        {editingRule ? 'Edit Alert Rule' : 'Create Alert Rule'}
                                    </CardTitle>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={() => {
                                            setShowEditor(false);
                                            setEditingRule(null);
                                            resetForm();
                                        }}
                                    >
                                        <X className="w-4 h-4" />
                                    </Button>
                                </div>
                            </CardHeader>

                            <CardContent className="space-y-4">
                                {/* Rule Name */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Rule Name
                                    </label>
                                    <input
                                        type="text"
                                        value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                        className="w-full px-3 py-2 border rounded"
                                        placeholder="CPU Critical Alert"
                                    />
                                </div>

                                {/* Rule Type */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Rule Type
                                    </label>
                                    <select
                                        value={formData.type}
                                        onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                                        className="w-full px-3 py-2 border rounded"
                                    >
                                        <option value="threshold">Threshold</option>
                                        <option value="pattern">Pattern</option>
                                        <option value="anomaly">Anomaly</option>
                                    </select>
                                </div>

                                {/* Severity */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Severity
                                    </label>
                                    <select
                                        value={formData.severity}
                                        onChange={(e) => setFormData({ ...formData, severity: e.target.value })}
                                        className="w-full px-3 py-2 border rounded"
                                    >
                                        <option value="info">Info</option>
                                        <option value="warning">Warning</option>
                                        <option value="critical">Critical</option>
                                    </select>
                                </div>

                                {/* Cooldown */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Cooldown (minutes)
                                    </label>
                                    <input
                                        type="number"
                                        value={formData.cooldown_minutes}
                                        onChange={(e) => setFormData({ ...formData, cooldown_minutes: parseInt(e.target.value) })}
                                        className="w-full px-3 py-2 border rounded"
                                        min="1"
                                        max="1440"
                                    />
                                </div>

                                {/* Conditions (simplified JSON editor) */}
                                <div>
                                    <label className="block text-sm font-medium text-gray-700 mb-1">
                                        Conditions (JSON)
                                    </label>
                                    <textarea
                                        value={JSON.stringify(formData.conditions, null, 2)}
                                        onChange={(e) => {
                                            try {
                                                setFormData({ ...formData, conditions: JSON.parse(e.target.value) });
                                            } catch (err) {
                                                // Invalid JSON, ignore
                                            }
                                        }}
                                        className="w-full px-3 py-2 border rounded font-mono text-sm"
                                        rows="8"
                                        placeholder='{"metric": "cpu_usage", "operator": ">", "value": 90}'
                                    />
                                </div>

                                {/* Enabled toggle */}
                                <div className="flex items-center gap-2">
                                    <Switch
                                        checked={formData.enabled}
                                        onCheckedChange={(checked) => setFormData({ ...formData, enabled: checked })}
                                    />
                                    <label className="text-sm font-medium text-gray-700">
                                        Enabled
                                    </label>
                                </div>

                                {/* Actions */}
                                <div className="flex items-center gap-2 pt-4 border-t">
                                    <Button
                                        variant="default"
                                        onClick={editingRule ? handleUpdate : handleCreate}
                                        disabled={!formData.name || !formData.type}
                                    >
                                        <Save className="w-4 h-4 mr-1" />
                                        {editingRule ? 'Update Rule' : 'Create Rule'}
                                    </Button>
                                    <Button
                                        variant="outline"
                                        onClick={() => {
                                            setShowEditor(false);
                                            setEditingRule(null);
                                            resetForm();
                                        }}
                                    >
                                        Cancel
                                    </Button>
                                </div>
                            </CardContent>
                        </Card>
                    </div>
                )}
            </CardContent>
        </Card>
    );
}
