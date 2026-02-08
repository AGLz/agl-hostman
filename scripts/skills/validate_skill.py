#!/usr/bin/env python3
"""
Validate skill structure (frontmatter, required fields).

Usage:
    python scripts/skills/validate_skill.py SKILL_NAME
    python scripts/skills/validate_skill.py --all

Validates:
    - SKILL.md file exists
    - YAML frontmatter is present
    - Required fields: name, description
    - Optional fields: tags, version
    - Proper markdown formatting
"""

import os
import sys
import re
import argparse
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from datetime import datetime


# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = PROJECT_ROOT / ".claude" / "skills"


class ValidationError:
    """Represents a validation error or warning."""

    def __init__(self, level: str, message: str, line: Optional[int] = None):
        self.level = level  # 'error' or 'warning'
        self.message = message
        self.line = line

    def __str__(self):
        line_str = f" (line {self.line})" if self.line is not None else ""
        return f"[{self.level.upper()}]{line_str} {self.message}"


def parse_frontmatter(content: str) -> Tuple[Dict[str, str], List[str]]:
    """Parse YAML frontmatter and return dict and raw lines."""
    lines = content.split('\n')

    if not lines or not lines[0].startswith('---'):
        return {}, lines

    frontmatter = {}
    frontmatter_lines = []
    body_start = 0

    for i, line in enumerate(lines[1:], 1):
        if line.startswith('---'):
            body_start = i
            break
        frontmatter_lines.append(line)

    # Parse key-value pairs
    for line in frontmatter_lines:
        if ':' in line:
            key, value = line.split(':', 1)
            frontmatter[key.strip()] = value.strip()

    return frontmatter, lines[body_start + 1:]


def validate_frontmatter(frontmatter: Dict[str, str]) -> List[ValidationError]:
    """Validate frontmatter fields."""
    errors = []

    # Required fields
    if 'name' not in frontmatter or not frontmatter['name']:
        errors.append(ValidationError('error', "Missing required field: 'name'"))

    if 'description' not in frontmatter or not frontmatter['description']:
        errors.append(ValidationError('error', "Missing required field: 'description'"))

    # Validate field lengths
    if 'name' in frontmatter:
        name_len = len(frontmatter['name'])
        if name_len == 0:
            errors.append(ValidationError('error', "Field 'name' cannot be empty"))
        elif name_len < 3:
            errors.append(ValidationError('warning', "Field 'name' is very short (< 3 characters)"))
        elif name_len > 100:
            errors.append(ValidationError('warning', f"Field 'name' is very long ({name_len} characters)"))

    if 'description' in frontmatter:
        desc_len = len(frontmatter['description'])
        if desc_len == 0:
            errors.append(ValidationError('error', "Field 'description' cannot be empty"))
        elif desc_len < 20:
            errors.append(ValidationError('warning', "Field 'description' is very short (< 20 characters)"))
        elif desc_len < 50:
            errors.append(ValidationError('info', "Field 'description' could be more descriptive (< 50 characters)"))

    # Optional fields
    if 'tags' in frontmatter and frontmatter['tags']:
        tags = frontmatter['tags'].split(',')
        if len(tags) > 10:
            errors.append(ValidationError('warning', f"Too many tags ({len(tags)}), consider using fewer"))

    if 'version' in frontmatter:
        version = frontmatter['version']
        if not re.match(r'^\d+\.\d+(\.\d+)?$', version):
            errors.append(ValidationError('warning', f"Version '{version}' doesn't follow semantic versioning (e.g., 1.0.0)"))

    return errors


def validate_markdown_body(body_lines: List[str]) -> List[ValidationError]:
    """Validate markdown body content."""
    errors = []

    if not body_lines:
        errors.append(ValidationError('warning', "Skill has no body content"))
        return errors

    # Check for heading
    has_heading = any(line.startswith('#') for line in body_lines[:5])
    if not has_heading:
        errors.append(ValidationError('warning', "Skill should start with a heading (# Name)"))

    # Check for common sections
    body_text = '\n'.join(body_lines).lower()

    common_sections = {
        'when to use': 'When to use this skill',
        'instructions': 'Instructions',
        'examples': 'Usage examples',
        'related': 'Related skills'
    }

    for section_key, section_name in common_sections.items():
        if section_key not in body_text:
            errors.append(ValidationError('info', f"Consider adding '{section_name}' section"))

    # Check for reference links
    has_reference = any('[' in line and '](' in line for line in body_lines)
    if not has_reference:
        errors.append(ValidationError('info', "Skill should reference documentation or standards"))

    return errors


def validate_skill_file(skill_path: Path) -> Tuple[bool, List[ValidationError]]:
    """Validate a single skill file."""
    errors = []

    # Check if SKILL.md exists
    skill_file = skill_path / "SKILL.md"
    if not skill_file.exists():
        errors.append(ValidationError('error', f"SKILL.md not found in {skill_path.name}"))
        return False, errors

    # Read content
    try:
        with open(skill_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        errors.append(ValidationError('error', f"Could not read SKILL.md: {e}"))
        return False, errors

    # Check empty file
    if not content.strip():
        errors.append(ValidationError('error', "SKILL.md is empty"))
        return False, errors

    # Parse frontmatter
    frontmatter, body_lines = parse_frontmatter(content)

    if not frontmatter:
        errors.append(ValidationError('error', "No YAML frontmatter found (must start with '---')"))

    # Validate frontmatter
    errors.extend(validate_frontmatter(frontmatter))

    # Validate body
    errors.extend(validate_markdown_body(body_lines))

    # Determine if valid (no errors)
    is_valid = all(e.level != 'error' for e in errors)

    return is_valid, errors


def validate_all_skills() -> Dict[str, Tuple[bool, List[ValidationError]]]:
    """Validate all skills in the skills directory."""
    results = {}

    if not SKILLS_DIR.exists():
        print(f"Error: Skills directory not found: {SKILLS_DIR}", file=sys.stderr)
        return results

    for skill_path in sorted(SKILLS_DIR.iterdir()):
        if not skill_path.is_dir():
            continue

        is_valid, errors = validate_skill_file(skill_path)
        results[skill_path.name] = (is_valid, errors)

    return results


def print_validation_results(
    skill_name: str,
    is_valid: bool,
    errors: List[ValidationError],
    verbose: bool = False
) -> None:
    """Print validation results for a single skill."""
    icon = "✓" if is_valid else "✗"
    status = "VALID" if is_valid else "INVALID"
    color = "\033[92m" if is_valid else "\033[91m"
    reset = "\033[0m"

    print(f"{color}{icon} {skill_name}: {status}{reset}")

    if errors and verbose:
        for error in errors:
            if error.level == 'error':
                print(f"  {error}")
            elif error.level == 'warning' and verbose > 1:
                print(f"  {error}")
            elif error.level == 'info' and verbose > 2:
                print(f"  {error}")


def main():
    parser = argparse.ArgumentParser(
        description="Validate Claude Code skill structure and content",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/skills/validate_skill.py backend-api
  python scripts/skills/validate_skill.py --all
  python scripts/skills/validate_skill.py --all --verbose
  python scripts/skills/validate_skill.py --all --fix
        """
    )
    parser.add_argument(
        "skill",
        nargs="?",
        help="Skill directory name to validate (or use --all)"
    )
    parser.add_argument(
        "--all", "-a",
        action="store_true",
        help="Validate all skills"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="count",
        default=1,
        help="Increase verbosity (warnings: -v, info: -vv)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON"
    )

    args = parser.parse_args()

    if not args.all and not args.skill:
        parser.print_help()
        return 1

    if args.all:
        results = validate_all_skills()

        if args.json:
            import json
            json_results = {
                skill: {
                    "valid": is_valid,
                    "errors": [
                        {"level": e.level, "message": e.message, "line": e.line}
                        for e in errors
                    ]
                }
                for skill, (is_valid, errors) in results.items()
            }
            print(json.dumps(json_results, indent=2))
        else:
            print(f"Validating {len(results)} skill(s)...\n")

            valid_count = sum(1 for _, (is_valid, _) in results.items() if is_valid)
            invalid_count = len(results) - valid_count

            for skill_name, (is_valid, errors) in results.items():
                print_validation_results(skill_name, is_valid, errors, args.verbose)

            print(f"\nSummary: {valid_count} valid, {invalid_count} invalid")

            return 0 if invalid_count == 0 else 1
    else:
        skill_path = SKILLS_DIR / args.skill
        if not skill_path.exists():
            print(f"Error: Skill not found: {args.skill}", file=sys.stderr)
            return 1

        is_valid, errors = validate_skill_file(skill_path)

        if args.json:
            import json
            json_result = {
                "valid": is_valid,
                "errors": [
                    {"level": e.level, "message": e.message, "line": e.line}
                    for e in errors
                ]
            }
            print(json.dumps(json_result, indent=2))
        else:
            print_validation_results(args.skill, is_valid, errors, args.verbose)

        return 0 if is_valid else 1


if __name__ == "__main__":
    sys.exit(main())
