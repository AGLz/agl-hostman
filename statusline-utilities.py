#!/usr/bin/env python3
"""
Statusline Configuration Management Utilities
Helper scripts for managing statusline configurations and Visual Burn Rate features
"""

import os
import sys
import yaml
import json
import shutil
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Any
import subprocess
import time


class StatuslineManager:
    """Main utility class for managing statusline configurations"""

    def __init__(self):
        self.config_dirs = [
            Path.home() / '.config' / 'statusline',
            Path.home() / '.statusline',
            Path('/etc/statusline')
        ]
        self.backup_dir = Path.home() / '.config' / 'statusline' / 'backups'
        self.templates_dir = Path.home() / '.config' / 'statusline' / 'templates'

        # Ensure directories exist
        for dir_path in [self.config_dirs[0], self.backup_dir, self.templates_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)

    def find_config_file(self) -> Optional[Path]:
        """Find the active configuration file"""
        config_files = [
            'config.yaml',
            'statusline.yaml',
            '.statuslinerc'
        ]

        for config_dir in self.config_dirs:
            for config_file in config_files:
                config_path = config_dir / config_file
                if config_path.exists():
                    return config_path

        return None

    def load_config(self, config_path: Optional[Path] = None) -> Dict[str, Any]:
        """Load configuration from file"""
        if config_path is None:
            config_path = self.find_config_file()

        if config_path is None:
            return self.get_default_config()

        try:
            with open(config_path, 'r') as f:
                if config_path.suffix in ['.yaml', '.yml']:
                    return yaml.safe_load(f)
                elif config_path.suffix == '.json':
                    return json.load(f)
                else:
                    # Try YAML first, then JSON
                    try:
                        f.seek(0)
                        return yaml.safe_load(f)
                    except yaml.YAMLError:
                        f.seek(0)
                        return json.load(f)
        except Exception as e:
            print(f"Error loading config from {config_path}: {e}")
            return self.get_default_config()

    def save_config(self, config: Dict[str, Any], config_path: Optional[Path] = None):
        """Save configuration to file"""
        if config_path is None:
            config_path = self.config_dirs[0] / 'config.yaml'

        try:
            with open(config_path, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, indent=2)
            print(f"Configuration saved to {config_path}")
        except Exception as e:
            print(f"Error saving config to {config_path}: {e}")
            sys.exit(1)

    def backup_config(self, config_path: Optional[Path] = None) -> Path:
        """Create a backup of current configuration"""
        if config_path is None:
            config_path = self.find_config_file()

        if config_path is None:
            print("No configuration file found to backup")
            return None

        timestamp = int(time.time())
        backup_name = f"config_backup_{timestamp}.yaml"
        backup_path = self.backup_dir / backup_name

        try:
            shutil.copy2(config_path, backup_path)
            print(f"Configuration backed up to {backup_path}")
            return backup_path
        except Exception as e:
            print(f"Error creating backup: {e}")
            return None

    def list_templates(self) -> List[str]:
        """List available configuration templates"""
        templates = []

        # Check built-in templates
        builtin_templates = [
            'minimal', 'developer', 'sysadmin', 'powerline',
            'performance', 'accessibility'
        ]
        templates.extend(builtin_templates)

        # Check user templates
        if self.templates_dir.exists():
            for template_file in self.templates_dir.glob('*.yaml'):
                template_name = template_file.stem
                if template_name not in templates:
                    templates.append(f"{template_name} (custom)")

        return templates

    def apply_template(self, template_name: str) -> bool:
        """Apply a configuration template"""
        # First, create a backup
        self.backup_config()

        # Load template
        template_config = self.load_template(template_name)
        if template_config is None:
            print(f"Template '{template_name}' not found")
            return False

        # Apply template
        self.save_config(template_config)
        print(f"Template '{template_name}' applied successfully")

        # Trigger environment updates
        self.update_environments(template_config)
        return True

    def load_template(self, template_name: str) -> Optional[Dict[str, Any]]:
        """Load a specific template configuration"""
        # Check user templates first
        user_template_path = self.templates_dir / f"{template_name}.yaml"
        if user_template_path.exists():
            return self.load_config(user_template_path)

        # Check built-in templates
        builtin_templates = self.get_builtin_templates()
        if template_name in builtin_templates:
            return builtin_templates[template_name]

        return None

    def update_environments(self, config: Dict[str, Any]):
        """Update all configured environments with new settings"""
        environments = config.get('environments', {})

        # Update vim if configured
        if environments.get('vim', {}).get('enabled', False):
            self.update_vim_statusline(config)

        # Update tmux if configured
        if environments.get('tmux', {}).get('enabled', False):
            self.update_tmux_statusline(config)

        # Update shell if configured
        if environments.get('shell', {}).get('enabled', False):
            self.update_shell_prompt(config)

    def update_vim_statusline(self, config: Dict[str, Any]):
        """Update vim statusline configuration"""
        try:
            vim_config = config.get('environments', {}).get('vim', {})
            if not vim_config.get('enabled', False):
                return

            # Generate vim statusline script
            vim_script = self.generate_vim_script(vim_config)

            # Save to vim configuration
            vim_config_path = Path.home() / '.vim' / 'statusline.vim'
            vim_config_path.parent.mkdir(exist_ok=True)

            with open(vim_config_path, 'w') as f:
                f.write(vim_script)

            print("Vim statusline configuration updated")

        except Exception as e:
            print(f"Error updating vim configuration: {e}")

    def update_tmux_statusline(self, config: Dict[str, Any]):
        """Update tmux statusline configuration"""
        try:
            tmux_config = config.get('environments', {}).get('tmux', {})
            if not tmux_config.get('enabled', False):
                return

            # Generate tmux configuration
            tmux_script = self.generate_tmux_script(tmux_config)

            # Save to tmux configuration
            tmux_config_path = Path.home() / '.tmux' / 'statusline.conf'
            tmux_config_path.parent.mkdir(exist_ok=True)

            with open(tmux_config_path, 'w') as f:
                f.write(tmux_script)

            # Reload tmux if running
            subprocess.run(['tmux', 'source-file', str(tmux_config_path)],
                         capture_output=True, text=True)

            print("Tmux statusline configuration updated")

        except Exception as e:
            print(f"Error updating tmux configuration: {e}")

    def validate_config(self, config_path: Optional[Path] = None) -> bool:
        """Validate configuration file"""
        config = self.load_config(config_path)
        errors = []

        # Check required fields
        required_fields = ['global', 'environments']
        for field in required_fields:
            if field not in config:
                errors.append(f"Missing required field: {field}")

        # Validate burn rate configuration
        burn_rate_config = config.get('global', {}).get('visual_burn_rate', {})
        if burn_rate_config.get('enabled', False):
            # Check thresholds
            thresholds = burn_rate_config.get('thresholds', {})
            required_thresholds = ['low', 'medium', 'high', 'critical']
            for threshold in required_thresholds:
                if threshold not in thresholds:
                    errors.append(f"Missing burn rate threshold: {threshold}")

        # Print validation results
        if errors:
            print("Configuration validation failed:")
            for error in errors:
                print(f"  - {error}")
            return False
        else:
            print("Configuration validation passed")
            return True

    def get_default_config(self) -> Dict[str, Any]:
        """Return default configuration"""
        return {
            "version": "1.0",
            "global": {
                "visual_burn_rate": {
                    "enabled": True,
                    "update_interval": 1000,
                    "thresholds": {
                        "low": 30,
                        "medium": 70,
                        "high": 90,
                        "critical": 95
                    },
                    "indicators": {
                        "style": "bar",
                        "width": 10
                    }
                }
            },
            "environments": {
                "vim": {"enabled": False},
                "tmux": {"enabled": False},
                "shell": {"enabled": False}
            }
        }

    def get_builtin_templates(self) -> Dict[str, Dict[str, Any]]:
        """Return built-in template configurations"""
        return {
            "minimal": {
                "version": "1.0",
                "global": {
                    "visual_burn_rate": {
                        "enabled": True,
                        "update_interval": 2000,
                        "indicators": {"style": "dots", "width": 5}
                    }
                },
                "environments": {
                    "vim": {
                        "enabled": True,
                        "format": "{file} {modified} | {burn_rate} | {line_col}"
                    }
                }
            },
            "developer": {
                "version": "1.0",
                "global": {
                    "visual_burn_rate": {
                        "enabled": True,
                        "update_interval": 500,
                        "indicators": {"style": "bar", "width": 12},
                        "metrics": {
                            "cpu_enabled": True,
                            "memory_enabled": True,
                            "disk_io_enabled": True
                        }
                    }
                },
                "environments": {
                    "vim": {
                        "enabled": True,
                        "format": "{mode} | {file} | {burn_rate} | {line_col} | {time}"
                    },
                    "tmux": {"enabled": True},
                    "shell": {"enabled": True}
                }
            }
        }

    def generate_vim_script(self, vim_config: Dict[str, Any]) -> str:
        """Generate vim statusline script"""
        return f"""
" Auto-generated statusline configuration
" Generated by statusline configuration manager

function! StatuslineBurnRate()
    " Placeholder for burn rate integration
    return system('statusline-burn-rate --vim-format')
endfunction

set statusline={vim_config.get('format', '%f %m | %l:%c')}
set laststatus=2
"""

    def generate_tmux_script(self, tmux_config: Dict[str, Any]) -> str:
        """Generate tmux statusline script"""
        left_format = tmux_config.get('left_section', {}).get('format', '#{session_name}')
        right_format = tmux_config.get('right_section', {}).get('format', '%H:%M')

        return f"""
# Auto-generated tmux statusline configuration
# Generated by statusline configuration manager

set -g status-left '{left_format}'
set -g status-right '{right_format}'
set -g status-interval 1
"""


def main():
    """Main command line interface"""
    parser = argparse.ArgumentParser(description='Statusline Configuration Manager')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # List templates command
    list_parser = subparsers.add_parser('list', help='List available templates')

    # Apply template command
    apply_parser = subparsers.add_parser('apply', help='Apply a template')
    apply_parser.add_argument('template', help='Template name to apply')

    # Validate configuration command
    validate_parser = subparsers.add_parser('validate', help='Validate configuration')
    validate_parser.add_argument('--config', help='Configuration file to validate')

    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Backup current configuration')

    # Initialize command
    init_parser = subparsers.add_parser('init', help='Initialize statusline configuration')
    init_parser.add_argument('--template', default='minimal', help='Initial template to use')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    manager = StatuslineManager()

    if args.command == 'list':
        print("Available templates:")
        for template in manager.list_templates():
            print(f"  - {template}")

    elif args.command == 'apply':
        success = manager.apply_template(args.template)
        sys.exit(0 if success else 1)

    elif args.command == 'validate':
        config_path = Path(args.config) if args.config else None
        valid = manager.validate_config(config_path)
        sys.exit(0 if valid else 1)

    elif args.command == 'backup':
        backup_path = manager.backup_config()
        sys.exit(0 if backup_path else 1)

    elif args.command == 'init':
        # Initialize with default configuration
        default_config = manager.get_default_config()
        config_path = manager.config_dirs[0] / 'config.yaml'
        manager.save_config(default_config, config_path)

        # Apply template if specified
        if args.template != 'default':
            manager.apply_template(args.template)

        print(f"Statusline configuration initialized at {config_path}")


if __name__ == '__main__':
    main()