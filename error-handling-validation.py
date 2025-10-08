#!/usr/bin/env python3
"""
Error Handling and Validation Framework
Comprehensive error handling, validation, and fallback mechanisms for statusline configuration
"""

import os
import sys
import logging
import traceback
from enum import Enum
from typing import Dict, List, Optional, Any, Union, Callable
from dataclasses import dataclass
import yaml
import psutil
from pathlib import Path


class ErrorSeverity(Enum):
    """Error severity levels"""
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class ErrorCategory(Enum):
    """Error category types"""
    CONFIGURATION = "configuration"
    SYSTEM = "system"
    PERMISSION = "permission"
    DEPENDENCY = "dependency"
    PERFORMANCE = "performance"
    VALIDATION = "validation"


@dataclass
class ValidationError:
    """Container for validation errors"""
    severity: ErrorSeverity
    category: ErrorCategory
    message: str
    field_path: str = ""
    suggestion: str = ""
    auto_fix_available: bool = False


@dataclass
class SystemCapabilities:
    """System capability assessment"""
    has_psutil: bool = True
    has_yaml: bool = True
    can_access_proc: bool = True
    can_write_config: bool = True
    memory_available_mb: int = 0
    cpu_count: int = 1
    platform: str = ""


class ConfigurationValidator:
    """Validates statusline configuration files and settings"""

    def __init__(self):
        self.errors: List[ValidationError] = []
        self.warnings: List[ValidationError] = []
        self.required_fields = [
            'version',
            'global',
            'global.visual_burn_rate',
            'environments'
        ]
        self.valid_styles = ['bar', 'dots', 'blocks', 'ascii']
        self.valid_environments = ['vim', 'tmux', 'shell', 'custom']

    def validate_configuration(self, config: Dict[str, Any]) -> bool:
        """Perform comprehensive configuration validation"""
        self.errors.clear()
        self.warnings.clear()

        try:
            # Validate structure
            self._validate_structure(config)

            # Validate global settings
            self._validate_global_settings(config.get('global', {}))

            # Validate environment settings
            self._validate_environments(config.get('environments', {}))

            # Validate burn rate specific settings
            self._validate_burn_rate_settings(
                config.get('global', {}).get('visual_burn_rate', {})
            )

            return len(self.errors) == 0

        except Exception as e:
            self.errors.append(ValidationError(
                severity=ErrorSeverity.CRITICAL,
                category=ErrorCategory.VALIDATION,
                message=f"Unexpected validation error: {str(e)}",
                suggestion="Check configuration file format and syntax"
            ))
            return False

    def _validate_structure(self, config: Dict[str, Any]):
        """Validate basic configuration structure"""
        for field_path in self.required_fields:
            if not self._has_nested_field(config, field_path):
                self.errors.append(ValidationError(
                    severity=ErrorSeverity.ERROR,
                    category=ErrorCategory.CONFIGURATION,
                    message=f"Missing required field: {field_path}",
                    field_path=field_path,
                    suggestion=f"Add the required field '{field_path}' to your configuration",
                    auto_fix_available=True
                ))

    def _validate_global_settings(self, global_config: Dict[str, Any]):
        """Validate global configuration settings"""
        # Validate color settings
        colors = global_config.get('colors', {})
        if colors:
            for color_name, color_value in colors.items():
                if not self._is_valid_color(color_value):
                    self.warnings.append(ValidationError(
                        severity=ErrorSeverity.WARNING,
                        category=ErrorCategory.CONFIGURATION,
                        message=f"Invalid color format for '{color_name}': {color_value}",
                        field_path=f"global.colors.{color_name}",
                        suggestion="Use hex format (#RRGGBB) or named colors"
                    ))

    def _validate_environments(self, environments: Dict[str, Any]):
        """Validate environment-specific settings"""
        for env_name, env_config in environments.items():
            if env_name not in self.valid_environments:
                self.warnings.append(ValidationError(
                    severity=ErrorSeverity.WARNING,
                    category=ErrorCategory.CONFIGURATION,
                    message=f"Unknown environment: {env_name}",
                    field_path=f"environments.{env_name}",
                    suggestion=f"Valid environments are: {', '.join(self.valid_environments)}"
                ))

            # Check if environment is enabled but has no configuration
            if env_config.get('enabled', False) and len(env_config) == 1:
                self.warnings.append(ValidationError(
                    severity=ErrorSeverity.WARNING,
                    category=ErrorCategory.CONFIGURATION,
                    message=f"Environment '{env_name}' is enabled but has no configuration",
                    field_path=f"environments.{env_name}",
                    suggestion="Add configuration options or disable the environment"
                ))

    def _validate_burn_rate_settings(self, burn_rate_config: Dict[str, Any]):
        """Validate burn rate specific settings"""
        if not burn_rate_config.get('enabled', True):
            return

        # Validate update interval
        update_interval = burn_rate_config.get('update_interval', 1000)
        if update_interval < 100:
            self.warnings.append(ValidationError(
                severity=ErrorSeverity.WARNING,
                category=ErrorCategory.PERFORMANCE,
                message=f"Update interval too low: {update_interval}ms",
                field_path="global.visual_burn_rate.update_interval",
                suggestion="Consider intervals >= 100ms to avoid high CPU usage"
            ))

        # Validate thresholds
        thresholds = burn_rate_config.get('thresholds', {})
        if thresholds:
            threshold_values = [
                thresholds.get('low', 0),
                thresholds.get('medium', 50),
                thresholds.get('high', 75),
                thresholds.get('critical', 90)
            ]

            if threshold_values != sorted(threshold_values):
                self.errors.append(ValidationError(
                    severity=ErrorSeverity.ERROR,
                    category=ErrorCategory.CONFIGURATION,
                    message="Thresholds must be in ascending order (low < medium < high < critical)",
                    field_path="global.visual_burn_rate.thresholds",
                    suggestion="Adjust threshold values to be in ascending order",
                    auto_fix_available=True
                ))

        # Validate indicators
        indicators = burn_rate_config.get('indicators', {})
        style = indicators.get('style', 'bar')
        if style not in self.valid_styles:
            self.errors.append(ValidationError(
                severity=ErrorSeverity.ERROR,
                category=ErrorCategory.CONFIGURATION,
                message=f"Invalid indicator style: {style}",
                field_path="global.visual_burn_rate.indicators.style",
                suggestion=f"Use one of: {', '.join(self.valid_styles)}",
                auto_fix_available=True
            ))

        width = indicators.get('width', 10)
        if not isinstance(width, int) or width < 1 or width > 50:
            self.warnings.append(ValidationError(
                severity=ErrorSeverity.WARNING,
                category=ErrorCategory.CONFIGURATION,
                message=f"Indicator width should be between 1-50: {width}",
                field_path="global.visual_burn_rate.indicators.width",
                suggestion="Use width between 5-20 for best results"
            ))

    def _has_nested_field(self, config: Dict[str, Any], field_path: str) -> bool:
        """Check if nested field exists in configuration"""
        parts = field_path.split('.')
        current = config

        for part in parts:
            if not isinstance(current, dict) or part not in current:
                return False
            current = current[part]

        return True

    def _is_valid_color(self, color: str) -> bool:
        """Validate color format"""
        if not isinstance(color, str):
            return False

        # Check hex format
        if color.startswith('#') and len(color) == 7:
            try:
                int(color[1:], 16)
                return True
            except ValueError:
                return False

        # Check named colors (basic set)
        named_colors = [
            'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white',
            'bright_black', 'bright_red', 'bright_green', 'bright_yellow',
            'bright_blue', 'bright_magenta', 'bright_cyan', 'bright_white'
        ]

        return color.lower() in named_colors

    def get_validation_report(self) -> str:
        """Generate human-readable validation report"""
        report = []

        if not self.errors and not self.warnings:
            return "✅ Configuration validation passed - no issues found"

        if self.errors:
            report.append(f"❌ Found {len(self.errors)} error(s):")
            for error in self.errors:
                report.append(f"  - {error.message}")
                if error.suggestion:
                    report.append(f"    💡 Suggestion: {error.suggestion}")

        if self.warnings:
            report.append(f"⚠️  Found {len(self.warnings)} warning(s):")
            for warning in self.warnings:
                report.append(f"  - {warning.message}")
                if warning.suggestion:
                    report.append(f"    💡 Suggestion: {warning.suggestion}")

        return "\n".join(report)


class SystemCompatibilityChecker:
    """Checks system compatibility and available features"""

    def __init__(self):
        self.capabilities = SystemCapabilities()
        self._assess_capabilities()

    def _assess_capabilities(self):
        """Assess system capabilities"""
        # Check psutil availability
        try:
            import psutil
            self.capabilities.has_psutil = True
            self.capabilities.memory_available_mb = psutil.virtual_memory().available // 1024 // 1024
            self.capabilities.cpu_count = psutil.cpu_count()
        except ImportError:
            self.capabilities.has_psutil = False

        # Check YAML support
        try:
            import yaml
            self.capabilities.has_yaml = True
        except ImportError:
            self.capabilities.has_yaml = False

        # Check /proc access
        self.capabilities.can_access_proc = os.path.exists('/proc') and os.access('/proc', os.R_OK)

        # Check config write permissions
        config_dirs = [
            Path.home() / '.config' / 'statusline',
            Path.home() / '.statusline'
        ]

        for config_dir in config_dirs:
            try:
                config_dir.mkdir(parents=True, exist_ok=True)
                test_file = config_dir / '.test_write'
                test_file.touch()
                test_file.unlink()
                self.capabilities.can_write_config = True
                break
            except (OSError, PermissionError):
                continue

        # Platform detection
        self.capabilities.platform = sys.platform

    def check_compatibility(self) -> List[ValidationError]:
        """Check system compatibility and return issues"""
        issues = []

        if not self.capabilities.has_psutil:
            issues.append(ValidationError(
                severity=ErrorSeverity.CRITICAL,
                category=ErrorCategory.DEPENDENCY,
                message="psutil package not available - system metrics cannot be collected",
                suggestion="Install psutil: pip install psutil"
            ))

        if not self.capabilities.has_yaml:
            issues.append(ValidationError(
                severity=ErrorSeverity.WARNING,
                category=ErrorCategory.DEPENDENCY,
                message="PyYAML not available - only JSON configuration supported",
                suggestion="Install PyYAML: pip install PyYAML"
            ))

        if not self.capabilities.can_access_proc:
            issues.append(ValidationError(
                severity=ErrorSeverity.WARNING,
                category=ErrorCategory.SYSTEM,
                message="Cannot access /proc - some system metrics may be unavailable",
                suggestion="Run with appropriate permissions or use basic metrics only"
            ))

        if not self.capabilities.can_write_config:
            issues.append(ValidationError(
                severity=ErrorSeverity.ERROR,
                category=ErrorCategory.PERMISSION,
                message="Cannot write configuration files to standard locations",
                suggestion="Check permissions for ~/.config/statusline/ directory"
            ))

        if self.capabilities.memory_available_mb < 50:
            issues.append(ValidationError(
                severity=ErrorSeverity.WARNING,
                category=ErrorCategory.PERFORMANCE,
                message="Low memory available - consider reducing update frequency",
                suggestion="Use performance-optimized template or increase update interval"
            ))

        return issues

    def get_capability_report(self) -> str:
        """Generate system capability report"""
        report = [
            "🔍 System Compatibility Report:",
            f"  Platform: {self.capabilities.platform}",
            f"  CPU cores: {self.capabilities.cpu_count}",
            f"  Available memory: {self.capabilities.memory_available_mb} MB",
            f"  psutil available: {'✅' if self.capabilities.has_psutil else '❌'}",
            f"  YAML support: {'✅' if self.capabilities.has_yaml else '❌'}",
            f"  /proc access: {'✅' if self.capabilities.can_access_proc else '❌'}",
            f"  Config writable: {'✅' if self.capabilities.can_write_config else '❌'}"
        ]

        return "\n".join(report)


class GracefulDegradation:
    """Handles graceful degradation when features are unavailable"""

    def __init__(self, capabilities: SystemCapabilities):
        self.capabilities = capabilities

    def get_fallback_config(self, original_config: Dict[str, Any]) -> Dict[str, Any]:
        """Generate fallback configuration based on system capabilities"""
        fallback_config = original_config.copy()

        # Adjust based on available features
        burn_rate_config = fallback_config.get('global', {}).get('visual_burn_rate', {})

        if not self.capabilities.has_psutil:
            # Disable metrics that require psutil
            burn_rate_config['enabled'] = False
            fallback_config.setdefault('global', {})['visual_burn_rate'] = burn_rate_config

        if self.capabilities.memory_available_mb < 100:
            # Use performance-optimized settings
            burn_rate_config['update_interval'] = max(
                burn_rate_config.get('update_interval', 1000), 2000
            )
            burn_rate_config['indicators'] = {
                'style': 'ascii',
                'width': 5,
                'use_color': False
            }

        return fallback_config

    def create_minimal_config(self) -> Dict[str, Any]:
        """Create minimal configuration that works in any environment"""
        return {
            'version': '1.0',
            'global': {
                'visual_burn_rate': {
                    'enabled': self.capabilities.has_psutil,
                    'update_interval': 3000,
                    'indicators': {
                        'style': 'ascii',
                        'width': 5,
                        'use_color': False
                    },
                    'metrics': {
                        'cpu_enabled': True,
                        'memory_enabled': False,
                        'disk_io_enabled': False,
                        'network_enabled': False
                    }
                }
            },
            'environments': {
                'vim': {'enabled': False},
                'tmux': {'enabled': False},
                'shell': {'enabled': False}
            }
        }


class ErrorRecovery:
    """Handles error recovery and auto-fixing"""

    def __init__(self, validator: ConfigurationValidator):
        self.validator = validator

    def attempt_auto_fix(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Attempt to auto-fix configuration errors"""
        fixed_config = config.copy()

        for error in self.validator.errors:
            if error.auto_fix_available:
                fixed_config = self._apply_auto_fix(fixed_config, error)

        return fixed_config

    def _apply_auto_fix(self, config: Dict[str, Any], error: ValidationError) -> Dict[str, Any]:
        """Apply specific auto-fix for an error"""
        if error.field_path == "global.visual_burn_rate.thresholds":
            # Fix threshold ordering
            thresholds = config.get('global', {}).get('visual_burn_rate', {}).get('thresholds', {})
            config.setdefault('global', {}).setdefault('visual_burn_rate', {})['thresholds'] = {
                'low': 30,
                'medium': 70,
                'high': 85,
                'critical': 95
            }

        elif "indicators.style" in error.field_path:
            # Fix invalid indicator style
            config.setdefault('global', {}).setdefault('visual_burn_rate', {}) \
                  .setdefault('indicators', {})['style'] = 'bar'

        # Add more auto-fixes as needed

        return config


def main():
    """Command line interface for validation and error checking"""
    import argparse

    parser = argparse.ArgumentParser(description='Statusline Configuration Validator')
    parser.add_argument('config_file', help='Configuration file to validate')
    parser.add_argument('--fix', action='store_true', help='Attempt to auto-fix errors')
    parser.add_argument('--system-check', action='store_true', help='Check system compatibility')
    parser.add_argument('--fallback', action='store_true', help='Generate fallback configuration')

    args = parser.parse_args()

    # Load configuration
    try:
        with open(args.config_file) as f:
            if args.config_file.endswith('.json'):
                import json
                config = json.load(f)
            else:
                import yaml
                config = yaml.safe_load(f)
    except Exception as e:
        print(f"Error loading configuration file: {e}")
        sys.exit(1)

    # System compatibility check
    if args.system_check:
        compatibility_checker = SystemCompatibilityChecker()
        print(compatibility_checker.get_capability_report())

        issues = compatibility_checker.check_compatibility()
        if issues:
            print("\n🚨 Compatibility Issues:")
            for issue in issues:
                print(f"  {issue.severity.value.upper()}: {issue.message}")
                if issue.suggestion:
                    print(f"    💡 {issue.suggestion}")

    # Validate configuration
    validator = ConfigurationValidator()
    is_valid = validator.validate_configuration(config)

    print("\n" + validator.get_validation_report())

    # Auto-fix if requested
    if args.fix and validator.errors:
        recovery = ErrorRecovery(validator)
        fixed_config = recovery.attempt_auto_fix(config)

        # Save fixed configuration
        fixed_filename = args.config_file.replace('.yaml', '_fixed.yaml').replace('.json', '_fixed.json')
        with open(fixed_filename, 'w') as f:
            if fixed_filename.endswith('.json'):
                import json
                json.dump(fixed_config, f, indent=2)
            else:
                import yaml
                yaml.dump(fixed_config, f, default_flow_style=False, indent=2)

        print(f"\n🔧 Auto-fixed configuration saved to: {fixed_filename}")

    # Generate fallback configuration if requested
    if args.fallback:
        compatibility_checker = SystemCompatibilityChecker()
        degradation = GracefulDegradation(compatibility_checker.capabilities)
        fallback_config = degradation.get_fallback_config(config)

        fallback_filename = args.config_file.replace('.yaml', '_fallback.yaml').replace('.json', '_fallback.json')
        with open(fallback_filename, 'w') as f:
            if fallback_filename.endswith('.json'):
                import json
                json.dump(fallback_config, f, indent=2)
            else:
                import yaml
                yaml.dump(fallback_config, f, default_flow_style=False, indent=2)

        print(f"🛡️  Fallback configuration saved to: {fallback_filename}")

    sys.exit(0 if is_valid else 1)


if __name__ == '__main__':
    main()