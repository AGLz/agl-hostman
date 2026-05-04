---
name: Global Coding Style
description: Maintain consistent code formatting, naming conventions, and structure across the entire codebase with automated tooling including ESLint, Prettier, RuboCop, Black, or project-specific linters. Use this skill when writing or refactoring any code regardless of file type or framework, working with configuration files like .eslintrc.js, .prettierrc, .rubocop.yml, pyproject.toml, or editor settings like .editorconfig, applying naming conventions for variables (camelCase, snake_case, PascalCase), functions, classes, and files consistently across the codebase, configuring automated formatters to enforce consistent indentation (spaces vs tabs, 2-space or 4-space), line breaks, and code structure, writing meaningful, descriptive names that reveal intent while avoiding abbreviations and single-letter variables (except in narrow contexts like loop counters), keeping functions small and focused on a single task for better readability and testability (ideally under 20-30 lines), removing dead code including unused imports, commented-out code blocks, and unreachable code paths rather than leaving them as clutter, applying DRY (Don't Repeat Yourself) principle by extracting common logic into reusable functions or modules to avoid duplication, ensuring backward compatibility only when specifically required (not as default practice), setting up pre-commit hooks or CI checks to automatically enforce style rules, maintaining consistent code style across multiple languages in polyglot projects, or resolving linter warnings and errors before committing code. Essential for maintaining readable and maintainable code across teams, reducing code review friction over style debates, ensuring new team members can quickly understand codebase patterns, enabling faster code reviews focused on logic rather than formatting, and preventing style inconsistencies that accumulate over time.
---

# Global Coding Style

This Skill provides Codex with specific guidance on how to adhere to coding standards as they relate to how it should handle global coding style.

## When to use this skill:

- Writing or refactoring any code in any programming language
- Naming variables, functions, classes, or files
- Structuring and formatting code for readability
- Removing dead code, unused imports, or commented-out blocks
- Implementing small, focused functions with single responsibilities
- Applying DRY (Don't Repeat Yourself) principles
- Setting up or configuring linters and formatters (ESLint, Prettier, RuboCop)
- Ensuring consistent indentation and line breaks
- Avoiding abbreviations in favor of descriptive names
- Refactoring code for better structure and clarity
- Working with any code files across the entire project

## Instructions

For details, refer to the information provided in this file:
[global coding style](../../../agent-os/standards/global/coding-style.md)
