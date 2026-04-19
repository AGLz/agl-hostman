#!/usr/bin/env python3
"""
Initialize a new skill from template.

Usage:
    python scripts/skills/init_skill.py NAME [--description DESC] [--category CAT] [--tags TAGS]

Creates a new skill directory with SKILL.md from template.
"""

import os
import sys
import re
import argparse
from pathlib import Path
from typing import Optional, List
from datetime import datetime


# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = PROJECT_ROOT / ".claude" / "skills"


SKILL_TEMPLATE = """---
name: {name}
description: {description}
tags: {tags}
version: 1.0.0
---

# {title}

This Skill provides Claude Code with specific guidance on how to adhere to coding standards as they relate to how it should handle {scope}.

## When to use this skill:

{when_to_use}

## Instructions

For details, refer to the information provided in this file:
[{reference}](../../../path/to/standards/{reference_file}.md)

## Examples

### Example 1: {example_title}
```bash
# Command or task example
Task("Task description", "Detailed task instructions", "agent-type")
```

**Outcome**: Describe what this accomplishes.

### Example 2: Another use case
```bash
# Another example
```

**Outcome**: Description of results.

## Related Skills

- `related-skill-name` - Brief description of relationship
- `another-skill` - How it connects to this skill

## Success Criteria

When using this skill, successful outcomes include:

- [ ] **Criterion 1**: Description of first success metric
- [ ] **Criterion 2**: Description of second success metric
- [ ] **Criterion 3**: Description of third success metric
"""

CATEGORY_TEMPLATES = {
    "backend": {
        "scope": "backend development, API design, and server-side architecture",
        "reference": "backend standards",
        "reference_file": "backend",
        "when_to_use": [
            "- Creating or modifying REST API endpoints and routes",
            "- Working on controller files or request handlers",
            "- Implementing database models and migrations",
            "- Setting up middleware and authentication",
            "- Writing server-side business logic",
            "- Working with files like `routes.js`, `controllers/`, `models/`"
        ]
    },
    "frontend": {
        "scope": "frontend development, UI components, and user experience",
        "reference": "frontend standards",
        "reference_file": "frontend",
        "when_to_use": [
            "- Creating or modifying React/Vue/Angular components",
            "- Working on CSS, styling, or responsive design",
            "- Implementing accessibility features",
            "- Managing component state and props",
            "- Building reusable UI elements",
            "- Working with files like `components/`, `styles/`, `views/`"
        ]
    },
    "devops": {
        "scope": "DevOps, infrastructure, deployment, and CI/CD pipelines",
        "reference": "DevOps standards",
        "reference_file": "devops",
        "when_to_use": [
            "- Setting up CI/CD pipelines",
            "- Configuring Docker containers and orchestration",
            "- Managing cloud infrastructure (AWS, GCP, Azure)",
            "- Implementing monitoring and alerting",
            "- Managing secrets and configuration",
            "- Working with files like `Dockerfile`, `terraform/`, `.github/workflows/`"
        ]
    },
    "testing": {
        "scope": "testing strategies, test implementation, and quality assurance",
        "reference": "testing standards",
        "reference_file": "testing",
        "when_to_use": [
            "- Writing unit tests, integration tests, or E2E tests",
            "- Setting up test frameworks and fixtures",
            "- Implementing test data factories and mocks",
            "- Measuring test coverage and quality",
            "- Debugging test failures",
            "- Working with files like `tests/`, `spec/`, `__tests__/`"
        ]
    },
    "documentation": {
        "scope": "documentation, technical writing, and knowledge management",
        "reference": "documentation standards",
        "reference_file": "docs",
        "when_to_use": [
            "- Writing technical documentation",
            "- Creating API documentation and guides",
            "- Maintaining README and CONTRIBUTING files",
            "- Documenting architecture and design decisions",
            "- Creating code examples and tutorials",
            "- Working with files like `docs/`, `README.md`, `*.md`"
        ]
    },
    "security": {
        "scope": "security best practices, vulnerability management, and secure coding",
        "reference": "security standards",
        "reference_file": "security",
        "when_to_use": [
            "- Implementing authentication and authorization",
            "- Managing secrets and sensitive data",
            "- Conducting security audits and reviews",
            "- Implementing secure communication (HTTPS, encryption)",
            "- Following OWASP guidelines",
            "- Working with authentication, authorization, and data protection"
        ]
    },
    "performance": {
        "scope": "performance optimization, monitoring, and efficiency",
        "reference": "performance standards",
        "reference_file": "performance",
        "when_to_use": [
            "- Optimizing database queries and caching",
            "- Improving application response times",
            "- Setting up performance monitoring",
            "- Conducting load testing and profiling",
            "- Optimizing asset delivery and bundling",
            "- Working with performance-critical code paths"
        ]
    },
    "methodology": {
        "scope": "development methodology, workflows, and best practices",
        "reference": "methodology standards",
        "reference_file": "methodology",
        "when_to_use": [
            "- Setting up development workflows",
            "- Implementing code review processes",
            "- Managing feature branches and releases",
            "- Following agile/scrum practices",
            "- Applying TDD or BDD methodologies",
            "- Working with team processes and conventions"
        ]
    }
}


def slugify(name: str) -> str:
    """Convert a name to a directory-safe slug."""
    # Convert to lowercase and replace spaces with hyphens
    slug = name.lower().replace(' ', '-')
    # Remove special characters except hyphens
    slug = re.sub(r'[^\w-]', '', slug)
    # Remove multiple consecutive hyphens
    slug = re.sub(r'-+', '-', slug)
    # Remove leading/trailing hyphens
    slug = slug.strip('-')
    return slug


def get_category_template(category: str) -> dict:
    """Get template configuration for a category."""
    # Try exact match
    if category in CATEGORY_TEMPLATES:
        return CATEGORY_TEMPLATES[category]

    # Try partial match
    for key, template in CATEGORY_TEMPLATES.items():
        if key in category.lower() or category.lower() in key:
            return template

    # Default template
    return {
        "scope": f"{category} development and implementation",
        "reference": f"{category} standards",
        "reference_file": category.lower().replace(' ', '-'),
        "when_to_use": [
            f"- Working on {category} related tasks",
            f"- Implementing {category} features",
            f"- Following {category} best practices"
        ]
    }


def create_skill(
    name: str,
    description: Optional[str] = None,
    category: str = "methodology",
    tags: Optional[List[str]] = None
) -> tuple[bool, str]:
    """Create a new skill from template."""
    # Generate directory name
    slug = slugify(name)
    skill_dir = SKILLS_DIR / slug

    # Check if already exists
    if skill_dir.exists():
        return False, f"Skill already exists: {slug}"

    # Create directory
    try:
        skill_dir.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        return False, f"Could not create skill directory: {e}"

    # Get template
    template = get_category_template(category)

    # Default description if not provided
    if not description:
        description = f"Best practices and standards for {name.lower()}"

    # Default tags
    if not tags:
        tags = [category, name.lower()]

    # Format when to use section
    when_to_use = '\n'.join(template["when_to_use"])

    # Generate content
    content = SKILL_TEMPLATE.format(
        name=name,
        title=name,
        description=description,
        tags=", ".join(tags),
        scope=template["scope"],
        reference=template["reference"],
        reference_file=template["reference_file"],
        when_to_use=when_to_use,
        example_title=f"Using {name}",
    )

    # Write SKILL.md
    skill_file = skill_dir / "SKILL.md"
    try:
        with open(skill_file, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        return False, f"Could not write SKILL.md: {e}"

    return True, str(skill_file.relative_to(PROJECT_ROOT))


def main():
    parser = argparse.ArgumentParser(
        description="Initialize a new Claude Code skill from template",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/skills/init_skill.py "API Design" --category backend
  python scripts/skills/init_skill.py "React Components" --description "Best practices for React" --tags frontend,react
  python scripts/skills/init_skill.py "Docker Setup" --category devops --tags devops,docker,containers

Available categories:
  backend, frontend, devops, testing, documentation, security, performance, methodology
        """
    )
    parser.add_argument(
        "name",
        help="Skill name (e.g., 'API Design', 'React Components')"
    )
    parser.add_argument(
        "--description", "-d",
        help="Skill description (default: auto-generated)"
    )
    parser.add_argument(
        "--category", "-c",
        default="methodology",
        choices=list(CATEGORY_TEMPLATES.keys()),
        help="Skill category (default: methodology)"
    )
    parser.add_argument(
        "--tags", "-t",
        help="Comma-separated tags (default: category,name)"
    )

    args = parser.parse_args()

    # Parse tags
    tags = None
    if args.tags:
        tags = [t.strip() for t in args.tags.split(",")]

    # Create skill
    success, result = create_skill(
        args.name,
        args.description,
        args.category,
        tags
    )

    if success:
        print(f"✓ Created skill: {args.name}")
        print(f"  Location: {result}")
        print(f"\nNext steps:")
        print(f"  1. Edit the skill: {PROJECT_ROOT}/{result}")
        print(f"  2. Validate: python scripts/skills/validate_skill.py {args.category}-{args.name.lower().replace(' ', '-')}")
        return 0
    else:
        print(f"✗ Error: {result}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
