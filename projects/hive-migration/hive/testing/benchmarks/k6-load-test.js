import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTimeTrend = new Trend('response_time');

// Configuration
const BASE_URL = __ENV.API_URL || 'https://api.falg.com.br';
const AUTH_TOKEN = __ENV.AUTH_TOKEN || '';

// Test options
export const options = {
    stages: [
        { duration: '30s', target: 10 },  // Ramp up to 10 users
        { duration: '1m', target: 10 },   // Stay at 10 users
        { duration: '30s', target: 50 },  // Ramp up to 50 users
        { duration: '1m', target: 50 },   // Stay at 50 users
        { duration: '30s', target: 100 }, // Ramp up to 100 users
        { duration: '1m', target: 100 },  // Stay at 100 users
        { duration: '30s', target: 0 },   // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'], // 95% of requests < 500ms
        errors: ['rate<0.01'],             // Error rate < 1%
    },
};

// Default headers
const headers = {
    'Authorization': `Bearer ${AUTH_TOKEN}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json',
};

export default function () {
    // Test 1: List cobrancas
    let response = http.get(`${BASE_URL}/api/cobrancas`, { headers });

    check(response, {
        'cobrancas status 200': (r) => r.status === 200,
        'cobrancas response time < 200ms': (r) => r.timings.duration < 200,
    });

    errorRate.add(response.status !== 200);
    responseTimeTrend.add(response.timings.duration);

    sleep(1);

    // Test 2: Get single recibo
    response = http.get(`${BASE_URL}/api/recibo/1`, { headers });

    check(response, {
        'recibo status 200 or 404': (r) => r.status === 200 || r.status === 404,
        'recibo response time < 500ms': (r) => r.timings.duration < 500,
    });

    errorRate.add(response.status !== 200 && response.status !== 404);
    responseTimeTrend.add(response.timings.duration);

    sleep(1);

    // Test 3: Health check (no auth required)
    response = http.get(`${BASE_URL}/api/health`);

    check(response, {
        'health status 200 or 404': (r) => r.status === 200 || r.status === 404,
        'health response time < 100ms': (r) => r.timings.duration < 100,
    });

    sleep(1);
}

// Summary function
export function handleSummary(data) {
    return {
        'summary.json': JSON.stringify(data, null, 2),
        'summary.html': generateHTMLReport(data),
    };
}

function generateHTMLReport(data) {
    const metrics = data.metrics;
    const httpReqDuration = metrics.http_req_duration || {};
    const errors = metrics.errors || {};

    return `
<!DOCTYPE html>
<html>
<head>
    <title>API Load Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>API Load Test Report</h1>
    <h2>Summary</h2>
    <table>
        <tr><th>Metric</th><th>Value</th><th>Threshold</th><th>Status</th></tr>
        <tr>
            <td>p95 Response Time</td>
            <td>${httpReqDuration.values?.['p(95)']?.toFixed(2) || 'N/A'}ms</td>
            <td>< 500ms</td>
            <td class="${(httpReqDuration.values?.['p(95)'] || 0) < 500 ? 'pass' : 'fail'}">
                ${(httpReqDuration.values?.['p(95)'] || 0) < 500 ? 'PASS' : 'FAIL'}
            </td>
        </tr>
        <tr>
            <td>Error Rate</td>
            <td>${((errors.value || 0) * 100).toFixed(2)}%</td>
            <td>< 1%</td>
            <td class="${(errors.value || 0) < 0.01 ? 'pass' : 'fail'}">
                ${(errors.value || 0) < 0.01 ? 'PASS' : 'FAIL'}
            </td>
        </tr>
    </table>
    <p>Generated: ${new Date().toISOString()}</p>
</body>
</html>
    `;
}
