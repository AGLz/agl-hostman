#!/usr/bin/env python3
"""
Visual Burn Rate Engine
Core implementation for real-time system resource monitoring and visualization
"""

import os
import sys
import time
import json
import threading
from collections import deque
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple, Any
import psutil


@dataclass
class BurnRateMetrics:
    """Container for system metrics"""
    cpu_percent: float = 0.0
    memory_percent: float = 0.0
    disk_io_percent: float = 0.0
    network_io_percent: float = 0.0
    timestamp: float = 0.0


@dataclass
class BurnRateConfig:
    """Configuration for burn rate calculation"""
    update_interval: int = 1000  # milliseconds
    history_length: int = 60     # seconds
    cpu_weight: float = 0.4
    memory_weight: float = 0.3
    disk_io_weight: float = 0.2
    network_weight: float = 0.1
    smoothing_enabled: bool = True
    smoothing_window: int = 5


class SmoothingFilter:
    """Exponential smoothing filter for burn rate values"""

    def __init__(self, window_size: int = 5):
        self.window_size = window_size
        self.values = deque(maxlen=window_size)
        self.alpha = 2.0 / (window_size + 1)  # Exponential smoothing factor

    def apply(self, new_value: float) -> float:
        """Apply exponential smoothing to new value"""
        self.values.append(new_value)

        if len(self.values) == 1:
            return new_value

        # Exponential weighted moving average
        smoothed = new_value
        for i, value in enumerate(reversed(self.values[:-1])):
            weight = (1 - self.alpha) ** (i + 1)
            smoothed = self.alpha * smoothed + weight * value

        return smoothed


class SystemMetricsCollector:
    """Collects system metrics for burn rate calculation"""

    def __init__(self):
        self.last_disk_io = None
        self.last_network_io = None
        self.last_timestamp = None

    def collect_metrics(self) -> BurnRateMetrics:
        """Collect current system metrics"""
        current_time = time.time()
        metrics = BurnRateMetrics(timestamp=current_time)

        try:
            # CPU percentage
            metrics.cpu_percent = psutil.cpu_percent(interval=None)

            # Memory percentage
            memory = psutil.virtual_memory()
            metrics.memory_percent = memory.percent

            # Disk I/O percentage (calculated as rate of change)
            current_disk_io = psutil.disk_io_counters()
            if current_disk_io and self.last_disk_io and self.last_timestamp:
                time_delta = current_time - self.last_timestamp
                if time_delta > 0:
                    read_rate = (current_disk_io.read_bytes - self.last_disk_io.read_bytes) / time_delta
                    write_rate = (current_disk_io.write_bytes - self.last_disk_io.write_bytes) / time_delta
                    total_rate = read_rate + write_rate

                    # Normalize to percentage (rough approximation)
                    # Assuming 100MB/s as 100% for demonstration
                    max_rate = 100 * 1024 * 1024  # 100MB/s
                    metrics.disk_io_percent = min(100.0, (total_rate / max_rate) * 100)

            self.last_disk_io = current_disk_io
            self.last_timestamp = current_time

            # Network I/O percentage (similar to disk I/O)
            current_network_io = psutil.net_io_counters()
            if current_network_io and self.last_network_io:
                # Similar calculation as disk I/O
                # Implementation details omitted for brevity
                pass

            self.last_network_io = current_network_io

        except (OSError, AttributeError) as e:
            print(f"Error collecting system metrics: {e}")

        return metrics


class VisualIndicatorGenerator:
    """Generates visual indicators for burn rate display"""

    def __init__(self, config: Dict[str, Any]):
        self.style = config.get('style', 'bar')
        self.width = config.get('width', 10)
        self.colors = config.get('colors', {})
        self.use_color = config.get('use_color', True)

    def generate_indicator(self, burn_rate: float, thresholds: Dict[str, float]) -> str:
        """Generate visual indicator based on burn rate"""
        color_code = self._get_color_code(burn_rate, thresholds)

        if self.style == 'bar':
            return self._generate_bar(burn_rate, color_code)
        elif self.style == 'dots':
            return self._generate_dots(burn_rate, color_code)
        elif self.style == 'blocks':
            return self._generate_blocks(burn_rate, color_code)
        elif self.style == 'ascii':
            return self._generate_ascii(burn_rate, color_code)
        else:
            return f"{burn_rate:.1f}%"

    def _generate_bar(self, burn_rate: float, color_code: str) -> str:
        """Generate horizontal bar indicator"""
        filled_width = int((burn_rate / 100) * self.width)
        empty_width = self.width - filled_width

        filled_chars = "█" * filled_width
        empty_chars = "░" * empty_width

        if self.use_color and color_code:
            return f"{color_code}{filled_chars}\033[0m{empty_chars}"
        else:
            return f"{filled_chars}{empty_chars}"

    def _generate_dots(self, burn_rate: float, color_code: str) -> str:
        """Generate dot pattern indicator"""
        dots_count = int((burn_rate / 100) * self.width)
        dots = "●" * dots_count
        spaces = "·" * (self.width - dots_count)

        if self.use_color and color_code:
            return f"{color_code}{dots}\033[0m{spaces}"
        else:
            return f"{dots}{spaces}"

    def _generate_blocks(self, burn_rate: float, color_code: str) -> str:
        """Generate block pattern indicator"""
        blocks_count = int((burn_rate / 100) * self.width)
        blocks = "▮" * blocks_count
        empty_blocks = "▯" * (self.width - blocks_count)

        if self.use_color and color_code:
            return f"{color_code}{blocks}\033[0m{empty_blocks}"
        else:
            return f"{blocks}{empty_blocks}"

    def _generate_ascii(self, burn_rate: float, color_code: str) -> str:
        """Generate ASCII art indicator"""
        filled_width = int((burn_rate / 100) * self.width)
        empty_width = self.width - filled_width

        filled_chars = "=" * filled_width
        empty_chars = "-" * empty_width

        indicator = f"[{filled_chars}{empty_chars}]"

        if self.use_color and color_code:
            return f"{color_code}{indicator}\033[0m"
        else:
            return indicator

    def _get_color_code(self, burn_rate: float, thresholds: Dict[str, float]) -> str:
        """Get ANSI color code based on burn rate and thresholds"""
        if not self.use_color:
            return ""

        if burn_rate >= thresholds.get('critical', 95):
            return "\033[91m"  # Bright red
        elif burn_rate >= thresholds.get('high', 85):
            return "\033[93m"  # Bright yellow
        elif burn_rate >= thresholds.get('medium', 70):
            return "\033[92m"  # Bright green
        else:
            return "\033[94m"  # Bright blue


class BurnRateEngine:
    """Main burn rate calculation and management engine"""

    def __init__(self, config: Dict[str, Any]):
        self.config = BurnRateConfig(
            update_interval=config.get('update_interval', 1000),
            history_length=config.get('history_length', 60),
            cpu_weight=config.get('calculation', {}).get('weights', {}).get('cpu', 0.4),
            memory_weight=config.get('calculation', {}).get('weights', {}).get('memory', 0.3),
            disk_io_weight=config.get('calculation', {}).get('weights', {}).get('disk_io', 0.2),
            network_weight=config.get('calculation', {}).get('weights', {}).get('network', 0.1),
            smoothing_enabled=config.get('calculation', {}).get('smoothing', {}).get('enabled', True),
            smoothing_window=config.get('calculation', {}).get('smoothing', {}).get('window_size', 5)
        )

        self.thresholds = config.get('thresholds', {
            'low': 30,
            'medium': 70,
            'high': 85,
            'critical': 95
        })

        self.metrics_collector = SystemMetricsCollector()
        self.visual_generator = VisualIndicatorGenerator(
            config.get('indicators', {})
        )

        self.history = deque(maxlen=self.config.history_length)
        self.smoothing_filter = SmoothingFilter(self.config.smoothing_window)

        self.current_burn_rate = 0.0
        self.running = False
        self.thread = None

    def start(self):
        """Start the burn rate monitoring engine"""
        if self.running:
            return

        self.running = True
        self.thread = threading.Thread(target=self._monitoring_loop, daemon=True)
        self.thread.start()

    def stop(self):
        """Stop the burn rate monitoring engine"""
        self.running = False
        if self.thread:
            self.thread.join()

    def _monitoring_loop(self):
        """Main monitoring loop running in separate thread"""
        while self.running:
            try:
                metrics = self.metrics_collector.collect_metrics()
                burn_rate = self._calculate_burn_rate(metrics)

                if self.config.smoothing_enabled:
                    burn_rate = self.smoothing_filter.apply(burn_rate)

                self.current_burn_rate = burn_rate
                self.history.append({
                    'timestamp': metrics.timestamp,
                    'burn_rate': burn_rate,
                    'metrics': metrics
                })

                # Sleep for the configured interval
                time.sleep(self.config.update_interval / 1000.0)

            except Exception as e:
                print(f"Error in monitoring loop: {e}")
                time.sleep(1)  # Sleep 1 second on error

    def _calculate_burn_rate(self, metrics: BurnRateMetrics) -> float:
        """Calculate weighted burn rate from system metrics"""
        weighted_sum = (
            metrics.cpu_percent * self.config.cpu_weight +
            metrics.memory_percent * self.config.memory_weight +
            metrics.disk_io_percent * self.config.disk_io_weight +
            metrics.network_io_percent * self.config.network_weight
        )

        total_weight = (
            self.config.cpu_weight +
            self.config.memory_weight +
            self.config.disk_io_weight +
            self.config.network_weight
        )

        return min(100.0, max(0.0, weighted_sum / total_weight))

    def get_current_burn_rate(self) -> float:
        """Get the current burn rate percentage"""
        return self.current_burn_rate

    def get_visual_indicator(self, burn_rate: Optional[float] = None) -> str:
        """Get visual indicator for current or specified burn rate"""
        if burn_rate is None:
            burn_rate = self.current_burn_rate

        return self.visual_generator.generate_indicator(burn_rate, self.thresholds)

    def get_status_info(self) -> Dict[str, Any]:
        """Get comprehensive status information"""
        latest_entry = self.history[-1] if self.history else None

        return {
            'burn_rate': self.current_burn_rate,
            'visual_indicator': self.get_visual_indicator(),
            'status_text': self._get_status_text(self.current_burn_rate),
            'metrics': latest_entry['metrics'] if latest_entry else None,
            'timestamp': latest_entry['timestamp'] if latest_entry else time.time(),
            'history_length': len(self.history)
        }

    def _get_status_text(self, burn_rate: float) -> str:
        """Get textual status description"""
        if burn_rate >= self.thresholds.get('critical', 95):
            return "CRITICAL"
        elif burn_rate >= self.thresholds.get('high', 85):
            return "HIGH"
        elif burn_rate >= self.thresholds.get('medium', 70):
            return "MEDIUM"
        else:
            return "LOW"


def main():
    """Command line interface for burn rate engine"""
    import argparse

    parser = argparse.ArgumentParser(description='Visual Burn Rate Engine')
    parser.add_argument('--config', help='Configuration file path')
    parser.add_argument('--format', choices=['percentage', 'visual', 'json', 'vim', 'tmux'],
                       default='percentage', help='Output format')
    parser.add_argument('--daemon', action='store_true', help='Run as daemon')
    parser.add_argument('--interval', type=int, default=1000, help='Update interval in ms')

    args = parser.parse_args()

    # Load configuration
    config = {
        'update_interval': args.interval,
        'thresholds': {'low': 30, 'medium': 70, 'high': 85, 'critical': 95},
        'indicators': {'style': 'bar', 'width': 10, 'use_color': True}
    }

    if args.config:
        try:
            import yaml
            with open(args.config) as f:
                file_config = yaml.safe_load(f)
                config.update(file_config.get('global', {}).get('visual_burn_rate', {}))
        except Exception as e:
            print(f"Error loading config: {e}")

    # Create and start engine
    engine = BurnRateEngine(config)

    if args.daemon:
        # Run as daemon
        engine.start()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            engine.stop()
    else:
        # Single shot execution
        engine.start()
        time.sleep(1)  # Give it a moment to collect initial metrics

        status = engine.get_status_info()

        if args.format == 'percentage':
            print(f"{status['burn_rate']:.1f}")
        elif args.format == 'visual':
            print(status['visual_indicator'])
        elif args.format == 'json':
            print(json.dumps(status, default=str))
        elif args.format == 'vim':
            print(f"🔥{status['visual_indicator']} {status['burn_rate']:.1f}%")
        elif args.format == 'tmux':
            print(f"#{{{status['visual_indicator']}}} {status['burn_rate']:.1f}%")

        engine.stop()


if __name__ == '__main__':
    main()