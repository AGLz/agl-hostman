#!/usr/bin/env python3
"""
MCP Server Prometheus Exporter
Part of AGL-25: MCP Server Optimization

Exports MCP server health metrics for Prometheus scraping.
"""

import json
import os
import sys
import time
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import subprocess

# Configuration
HEALTH_FILE = Path("/mnt/overpower/apps/dev/agl/agl-hostman/logs/mcp-monitoring/mcp-health-status.json")
PORT = 9099

class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP request handler for Prometheus metrics"""

    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

    def do_GET(self):
        """Handle GET requests"""
        if self.path == "/metrics":
            self.send_metrics()
        elif self.path == "/health":
            self.send_health()
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

    def send_metrics(self):
        """Send Prometheus metrics"""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.end_headers()

        metrics = self.generate_metrics()
        self.wfile.write(metrics.encode())

    def send_health(self):
        """Send health status"""
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()

        health = {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat()
        }
        self.wfile.write(json.dumps(health).encode())

    def generate_metrics(self):
        """Generate Prometheus metrics from health data"""
        metrics = []

        # Help metrics
        metrics.append("# HELP mcp_server_up MCP server availability (1=up, 0=down)")
        metrics.append("# TYPE mcp_server_up gauge")
        metrics.append("# HELP mcp_server_response_time_ms MCP server response time in milliseconds")
        metrics.append("# TYPE mcp_server_response_time_ms gauge")
        metrics.append("# HELP mcp_restart_total Total number of MCP server restarts")
        metrics.append("# TYPE mcp_restart_total counter")
        metrics.append("# HELP mcp_scrape_success Success of health data scrape (1=success, 0=failure)")
        metrics.append("# TYPE mcp_scrape_success gauge")

        # Load health data
        try:
            if HEALTH_FILE.exists():
                with open(HEALTH_FILE, "r") as f:
                    health_data = json.load(f)

                # Server metrics
                for server in health_data.get("servers", []):
                    name = server.get("name", "unknown")
                    status = server.get("status", "unknown")
                    response_time = server.get("response_time", "0ms").replace("ms", "")

                    # Server up metric
                    up_value = 1 if status == "healthy" else 0
                    metrics.append(f'mcp_server_up{{server="{name}"}} {up_value}')

                    # Response time metric
                    try:
                        rt_value = int(response_time)
                        metrics.append(f'mcp_server_response_time_ms{{server="{name}"}} {rt_value}')
                    except ValueError:
                        pass

                # Overall metrics
                total = health_data.get("total_servers", 0)
                healthy = health_data.get("healthy_count", 0)
                metrics.append(f'mcp_total_servers {total}')
                metrics.append(f'mcp_healthy_servers {healthy}')
                metrics.append(f'mcp_unhealthy_servers {total - healthy}')

                # Scrape success
                metrics.append("mcp_scrape_success 1")

            else:
                # No health data available
                metrics.append("mcp_scrape_success 0")

        except Exception as e:
            metrics.append(f"# Error loading health data: {e}")
            metrics.append("mcp_scrape_success 0")

        return "\n".join(metrics) + "\n"

def run_health_check():
    """Run the health check script"""
    try:
        script_path = "/mnt/overpower/apps/dev/agl/agl-hostman/scripts/mcp-monitoring/mcp-health-check.sh"
        result = subprocess.run(
            [script_path, "check"],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode == 0
    except Exception:
        return False

def main():
    """Main entry point"""
    # Run initial health check
    print(f"[{datetime.now()}] Starting MCP Prometheus Exporter on port {PORT}")
    print(f"[{datetime.now()}] Health file: {HEALTH_FILE}")
    print(f"[{datetime.now()}] Running initial health check...")

    if run_health_check():
        print(f"[{datetime.now()}] Initial health check completed")
    else:
        print(f"[{datetime.now()}] Initial health check failed")

    # Start HTTP server
    server = HTTPServer(("0.0.0.0", PORT), MetricsHandler)
    print(f"[{datetime.now()}] Metrics server started at http://localhost:{PORT}/metrics")
    print(f"[{datetime.now()}] Press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\n[{datetime.now()}] Shutting down...")
        server.shutdown()

if __name__ == "__main__":
    main()
