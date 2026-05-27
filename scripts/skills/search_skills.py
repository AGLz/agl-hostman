#!/usr/bin/env python3
"""
Search skills by keyword, tag, or category.

Usage:
    python scripts/skills/search_skills.py QUERY [--fields FIELD,...] [--format FORMAT]

Options:
    QUERY       Search keyword or phrase
    --fields    Fields to search: name,description,all [default: all]
    --format    Output format: table, json, detailed [default: detailed]
    --fuzzy     Enable fuzzy matching (default: exact match)
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Set
from difflib import SequenceMatcher


# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = PROJECT_ROOT / ".claude" / "skills"


def parse_frontmatter(content: str) -> Dict[str, str]:
    """Parse YAML frontmatter from markdown content."""
    lines = content.split('\n')
    if not lines or not lines[0].startswith('---'):
        return {"name": "", "description": "", "tags": []}

    frontmatter = {}
    for i, line in enumerate(lines[1:], 1):
        if line.startswith('---'):
            break
        if ':' in line:
            key, value = line.split(':', 1)
            frontmatter[key.strip()] = value.strip()

    return {
        "name": frontmatter.get("name", ""),
        "description": frontmatter.get("description", ""),
        "tags": frontmatter.get("tags", "").split(",") if frontmatter.get("tags") else []
    }


def fuzzy_match(query: str, text: str, threshold: float = 0.6) -> bool:
    """Check if query fuzzy matches text."""
    query = query.lower()
    text = text.lower()

    # Direct substring match
    if query in text:
        return True

    # Word-based matching
    query_words = set(query.split())
    text_words = set(text.split())

    if query_words & text_words:
        return True

    # Fuzzy ratio matching
    ratio = SequenceMatcher(None, query, text).ratio()
    return ratio >= threshold


def search_skills(
    query: str,
    fields: List[str] = ["name", "description"],
    fuzzy: bool = False
) -> List[Dict[str, str]]:
    """Search skills by query in specified fields."""
    results = []

    if not SKILLS_DIR.exists():
        print(f"Error: Skills directory not found: {SKILLS_DIR}", file=sys.stderr)
        return results

    query_lower = query.lower()

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
            name = frontmatter.get("name", "")
            description = frontmatter.get("description", "")
            tags = frontmatter.get("tags", [])
            directory = skill_path.name

            # Build search text
            search_fields = {
                "name": name,
                "description": description,
                "directory": directory,
                "tags": " ".join(tags)
            }

            # Search in specified fields
            match_found = False
            matched_fields = []

            for field in fields:
                if field == "all":
                    field_text = f"{name} {description} {' '.join(tags)}"
                    if fuzzy:
                        if fuzzy_match(query, field_text):
                            match_found = True
                            matched_fields.append(field)
                    else:
                        if query_lower in field_text.lower():
                            match_found = True
                            matched_fields.append(field)
                elif field in search_fields:
                    field_text = search_fields[field]
                    if fuzzy:
                        if fuzzy_match(query, field_text):
                            match_found = True
                            matched_fields.append(field)
                    else:
                        if query_lower in field_text.lower():
                            match_found = True
                            matched_fields.append(field)

            if match_found:
                results.append({
                    "name": name,
                    "directory": directory,
                    "description": description,
                    "tags": tags,
                    "matched_fields": matched_fields,
                    "path": str(skill_file.relative_to(PROJECT_ROOT))
                })
        except Exception as e:
            print(f"Warning: Could not read skill {skill_path.name}: {e}", file=sys.stderr)

    return results


def format_table(results: List[Dict[str, str]], query: str) -> str:
    """Format search results as a table."""
    if not results:
        return f'No results found for "{query}".'

    name_width = max(len(r["name"]) for r in results)
    name_width = max(name_width, len("Skill Name"))

    output = []
    output.append(f"{'Skill Name':<{name_width}} | {'Matched In'} | {'Description'}")
    output.append("-" * (name_width + 50))

    for result in results:
        desc = result["description"][:40] + "..." if len(result["description"]) > 40 else result["description"]
        matched = ", ".join(result["matched_fields"])
        output.append(f"{result['name']:<{name_width}} | {matched:<12} | {desc}")

    return "\n".join(output)


def format_json(results: List[Dict[str, str]]) -> str:
    """Format search results as JSON."""
    return json.dumps(results, indent=2)


def format_detailed(results: List[Dict[str, str]], query: str) -> str:
    """Format search results with detailed information."""
    if not results:
        return f'No results found for "{query}".'

    output = [f"Found {len(results)} result(s) for \"{query}\"\n"]

    for i, result in enumerate(results, 1):
        output.append(f"{i}. {result['name']}")
        output.append(f"   Directory: {result['directory']}")
        output.append(f"   Matched in: {', '.join(result['matched_fields'])}")
        output.append(f"   Path: {result['path']}")

        if result['tags']:
            output.append(f"   Tags: {', '.join(result['tags'])}")

        # Show description with highlighted query
        desc = result['description']
        output.append(f"   Description: {desc[:200]}{'...' if len(desc) > 200 else ''}")
        output.append("")

    return "\n".join(output)


def main():
    parser = argparse.ArgumentParser(
        description="Search Claude Code skills by keyword or tag",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/skills/search_skills.py "API"
  python scripts/skills/search_skills.py "testing" --format json
  python scripts/skills/search_skills.py "github" --fields name,description
  python scripts/skills/search_skills.py "pr" --fuzzy
        """
    )
    parser.add_argument(
        "query",
        help="Search keyword or phrase"
    )
    parser.add_argument(
        "--fields", "-f",
        default="all",
        help="Fields to search: name, description, directory, tags, all (default: all)"
    )
    parser.add_argument(
        "--format",
        choices=["table", "json", "detailed"],
        default="detailed",
        help="Output format (default: detailed)"
    )
    parser.add_argument(
        "--fuzzy",
        action="store_true",
        help="Enable fuzzy matching"
    )

    args = parser.parse_args()

    # Parse fields
    fields = [f.strip() for f in args.fields.split(",")]
    if "all" in fields:
        fields = ["all"]

    results = search_skills(args.query, fields, args.fuzzy)

    if args.format == "json":
        print(format_json(results))
    elif args.format == "table":
        print(format_table(results, args.query))
    else:
        print(format_detailed(results, args.query))

    return 0 if results else 1


if __name__ == "__main__":
    sys.exit(main())
