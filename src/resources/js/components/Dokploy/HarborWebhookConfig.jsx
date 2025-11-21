import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Copy, Check, ExternalLink, RefreshCw, Webhook } from 'lucide-react';

function HarborWebhookConfig() {
    const [copied, setCopied] = useState(false);
    const [testing, setTesting] = useState(false);
    const [testResult, setTestResult] = useState(null);

    const webhookUrl = `${window.location.origin}/api/dokploy/webhooks/harbor`;

    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(webhookUrl);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (error) {
            console.error('Failed to copy:', error);
        }
    };

    const handleTest = async () => {
        setTesting(true);
        setTestResult(null);

        try {
            const response = await fetch('/api/dokploy/webhooks/harbor/test', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('api_token')}`,
                },
                body: JSON.stringify({
                    repository: 'test-app',
                    tag: 'latest',
                }),
            });

            const data = await response.json();
            setTestResult({
                success: response.ok,
                message: data.message || 'Test completed',
            });
        } catch (error) {
            setTestResult({
                success: false,
                message: error.message || 'Test failed',
            });
        } finally {
            setTesting(false);
        }
    };

    return (
        <div className="bg-white rounded-lg shadow">
            {/* Header */}
            <div className="px-6 py-4 border-b">
                <div className="flex items-center gap-2">
                    <Webhook className="h-5 w-5 text-gray-500" />
                    <h3 className="text-lg font-medium text-gray-900">Harbor Webhook Configuration</h3>
                </div>
                <p className="text-sm text-gray-500 mt-1">
                    Configure Harbor to trigger automatic deployments on image push
                </p>
            </div>

            {/* Content */}
            <div className="p-6 space-y-6">
                {/* Webhook URL */}
                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                        Webhook URL
                    </label>
                    <div className="flex gap-2">
                        <input
                            type="text"
                            value={webhookUrl}
                            readOnly
                            className="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-sm font-mono"
                        />
                        <Button
                            variant="outline"
                            onClick={handleCopy}
                            className="flex items-center gap-2"
                        >
                            {copied ? (
                                <>
                                    <Check className="h-4 w-4" />
                                    Copied
                                </>
                            ) : (
                                <>
                                    <Copy className="h-4 w-4" />
                                    Copy
                                </>
                            )}
                        </Button>
                    </div>
                </div>

                {/* Setup Instructions */}
                <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-3">Setup Instructions</h4>
                    <ol className="space-y-3 text-sm text-gray-600">
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                1
                            </span>
                            <div className="flex-1">
                                <p>Go to Harbor (harbor.aglz.io:5000) and navigate to your project</p>
                            </div>
                        </li>
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                2
                            </span>
                            <div className="flex-1">
                                <p>Click on <strong>Webhooks</strong> in the left sidebar</p>
                            </div>
                        </li>
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                3
                            </span>
                            <div className="flex-1">
                                <p>Click <strong>+ New Webhook</strong></p>
                            </div>
                        </li>
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                4
                            </span>
                            <div className="flex-1">
                                <p>Configure the webhook:</p>
                                <ul className="mt-2 ml-4 space-y-1 list-disc">
                                    <li><strong>Name:</strong> Dokploy Auto Deploy</li>
                                    <li><strong>Notify Type:</strong> http</li>
                                    <li><strong>Endpoint URL:</strong> Use the URL above</li>
                                    <li><strong>Event Type:</strong> Check "Artifact pushed"</li>
                                    <li><strong>Enabled:</strong> Check the box</li>
                                </ul>
                            </div>
                        </li>
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                5
                            </span>
                            <div className="flex-1">
                                <p>Click <strong>Test Endpoint</strong> to verify connectivity</p>
                            </div>
                        </li>
                        <li className="flex gap-3">
                            <span className="flex-shrink-0 flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-medium">
                                6
                            </span>
                            <div className="flex-1">
                                <p>Click <strong>Continue</strong> to save the webhook</p>
                            </div>
                        </li>
                    </ol>
                </div>

                {/* Event Types */}
                <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-3">Supported Events</h4>
                    <div className="bg-gray-50 rounded-lg p-4">
                        <ul className="space-y-2 text-sm">
                            <li className="flex items-center gap-2">
                                <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                                <strong>PUSH_ARTIFACT:</strong> Triggers automatic redeployment
                            </li>
                            <li className="flex items-center gap-2">
                                <div className="w-2 h-2 bg-gray-400 rounded-full"></div>
                                <strong>DELETE_ARTIFACT:</strong> Ignored (no action)
                            </li>
                            <li className="flex items-center gap-2">
                                <div className="w-2 h-2 bg-gray-400 rounded-full"></div>
                                <strong>Other events:</strong> Logged but no action taken
                            </li>
                        </ul>
                    </div>
                </div>

                {/* Image Matching */}
                <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-3">Image Matching</h4>
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                        <p className="text-sm text-blue-900">
                            <strong>Important:</strong> The webhook will automatically match pushed images to Dokploy applications.
                            Ensure your Dokploy application's Docker image matches the Harbor repository name.
                        </p>
                        <div className="mt-3 text-sm text-blue-800">
                            <p><strong>Example:</strong></p>
                            <ul className="ml-4 mt-2 space-y-1 font-mono text-xs">
                                <li>Harbor image: <span className="bg-white px-2 py-1 rounded">harbor.aglz.io:5000/agl/my-app:latest</span></li>
                                <li>Dokploy config: <span className="bg-white px-2 py-1 rounded">harbor.aglz.io:5000/agl/my-app:latest</span></li>
                            </ul>
                        </div>
                    </div>
                </div>

                {/* Test Webhook */}
                <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-3">Test Webhook</h4>
                    <div className="flex gap-3">
                        <Button
                            onClick={handleTest}
                            disabled={testing}
                            variant="outline"
                            className="flex items-center gap-2"
                        >
                            <RefreshCw className={`h-4 w-4 ${testing ? 'animate-spin' : ''}`} />
                            {testing ? 'Testing...' : 'Test Webhook'}
                        </Button>
                        <a
                            href="https://harbor.aglz.io:5000"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-2 px-4 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50"
                        >
                            Open Harbor
                            <ExternalLink className="h-4 w-4" />
                        </a>
                    </div>
                    {testResult && (
                        <div className={`mt-3 p-3 rounded-lg text-sm ${
                            testResult.success
                                ? 'bg-green-50 text-green-800 border border-green-200'
                                : 'bg-red-50 text-red-800 border border-red-200'
                        }`}>
                            {testResult.message}
                        </div>
                    )}
                </div>

                {/* Additional Info */}
                <div className="bg-gray-50 rounded-lg p-4">
                    <h4 className="text-sm font-medium text-gray-700 mb-2">Additional Information</h4>
                    <ul className="space-y-1 text-xs text-gray-600">
                        <li>• Webhooks are processed asynchronously</li>
                        <li>• Only applications with matching Docker images will be redeployed</li>
                        <li>• Check Dokploy logs if redeployment doesn't trigger</li>
                        <li>• Webhook authentication is handled automatically</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}

export default HarborWebhookConfig;
