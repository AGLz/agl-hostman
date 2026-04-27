#!/usr/bin/env python3
"""
List all available skills with descriptions.

Usage:
    python scripts/skills/list_skills.py [--format FORMAT] [--category CATEGORY]

Options:
    FORMAT      Output format: table, json, or simple [default: table]
    CATEGORY    Filter by skill category (optional)
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime


# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = PROJECT_ROOT / ".claude" / "skills"


def parse_frontmatter(content: str) -> Dict[str, Optional[str]]:
    """Parse YAML frontmatter from markdown content."""
    lines = content.split('\n')
    if not lines or not lines[0].startswith('---'):
        return {"name": None, "description": None}

    frontmatter = {}
    for i, line in enumerate(lines[1:], 1):
        if line.startswith('---'):
            break
        if ':' in line:
            key, value = line.split(':', 1)
            frontmatter[key.strip()] = value.strip()

    return {
        "name": frontmatter.get("name"),
        "description": frontmatter.get("description")
    }


def get_skills(category: Optional[str] = None) -> List[Dict[str, str]]:
    """Get all skills from the skills directory."""
    skills = []

    if not SKILLS_DIR.exists():
        print(f"Error: Skills directory not found: {SKILLS_DIR}", file=sys.stderr)
        return skills

    for skill_path in sorted(SKILLS_DIR.iterdir()):
        if not skill_path.is_dir():
            continue

        skill_file = skill_path / "SKILL.md"
        if not skill_file.exists():
            continue

        try:
            with open(skill_file, 'r', encoding='utf-8') as f:
                content = f.read()

            frontmatter = parse_frontmatter(content)
            name = frontmatter.get("name") or skill_path.name
            description = frontmatter.get("description") or "No description available"

            # Extract category from skill structure
            skill_category = categorize_skill(name, description)

            # Filter by category if specified
            if category and category.lower() not in skill_category.lower():
                continue

            skills.append({
                "name": name,
                "directory": skill_path.name,
                "description": description,
                "category": skill_category,
                "path": str(skill_file.relative_to(PROJECT_ROOT))
            })
        except Exception as e:
            print(f"Warning: Could not read skill {skill_path.name}: {e}", file=sys.stderr)

    return skills


def categorize_skill(name: str, description: str) -> str:
    """Categorize a skill based on name and description."""
    name_lower = name.lower()
    desc_lower = description.lower()

    if any(x in name_lower for x in ['backend', 'api', 'migrations', 'models', 'queries']):
        return 'Backend Development'
    elif any(x in name_lower for x in ['frontend', 'css', 'accessibility', 'responsive']):
        return 'Frontend Development'
    elif any(x in name_lower for x in ['github', 'workflow', 'pr', 'release']):
        return 'GitHub & Repository'
    elif any(x in name_lower for x in ['swarm', 'hive-mind', 'coordination', 'orchestration']):
        return 'Swarm & Coordination'
    elif any(x in name_lower for x in ['v3', 'claude-flow', 'memory', 'mcp', 'performance']):
        return 'Claude Flow V3'
    elif any(x in name_lower for x in ['global', 'conventions', 'tech-stack']):
        return 'Global Standards'
    elif any(x in name_lower for x in ['testing', 'tdd', 'verification']):
        return 'Testing & Quality'
    elif any(x in name_lower for x in ['agentdb', 'reasoningbank', 'learning']):
        return 'AI & Learning'
    elif any(x in name_lower for x in ['sparc', 'architecture', 'design']):
        return 'Methodology'
    elif 'devops' in name_lower or 'infrastructure' in name_lower:
        return 'DevOps & Infrastructure'
    else:
        return 'Other'


def format_table(skills: List[Dict[str, str]]) -> str:
    """Format skills as a table."""
    if not skills:
        return "No skills found."

    # Calculate column widths
    name_width = max(len(s["name"]) for s in skills)
    name_width = max(name_width, len("Skill Name"))
    desc_width = max(min(len(s["description"]), 60) for s in skills)
    desc_width = max(desc_width, len("Description"))

    output = []
    output.append(f"{'Skill Name':<{name_width}} | {'Description':<{desc_width}} | {'Category'}")
    output.append("-" * (name_width + desc_width + len(" | Category") + 6))

    for skill in skills:
        desc = skill["description"][:desc_width - 3] + "..." if len(skill["description"]) > desc_width else skill["description"]
        output.append(f"{skill['name']:<{name_width}} | {desc:<{desc_width}} | {skill['category']}")

    return "\n".join(output)


def format_json(skills: List[Dict[str, str]]) -> str:
    """Format skills as JSON."""
    return json.dumps(skills, indent=2)


def format_simple(skills: List[Dict[str, str]]) -> str:
    """Format skills as a simple list."""
    if not skills:
        return "No skills found."

    output = []
    for skill in skills:
        output.append(f"• {skill['name']}")
        output.append(f"  Category: {skill['category']}")
        output.append(f"  Path: {skill['path']}")
        if skill['description'] != "No description available":
            output.append(f"  {skill['description'][:100]}{'...' if len(skill['description']) > 100 else ''}")
        output.append("")

    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description="List all available Claude Code skills",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/skills/list_skills.py
  python scripts/skills/list_skills.py --format json
  python scripts/skills/list_skills.py --category "Backend Development"
        """
    )
    parser.add_argument(
        "--format", "-f",
        choices=["table", "json", "simple"],
        default="table",
        help="Output format (default: table)"
    )
    parser.add_argument(
        "--category", "-c",
        help="Filter by skill category"
    )

    args = parser.parse_args()

    skills = get_skills(args.category)

    if args.format == "json":
        print(format_json(skills))
    elif args.format == "simple":
        print(format_simple(skills))
    else:
        print(format_table(skills))

    # Print summary
    print(f"\nTotal: {len(skills)} skill(s)")


if __name__ == "__main__":
    main()
