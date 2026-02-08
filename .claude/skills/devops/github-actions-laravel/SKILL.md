---
name: GitHub Actions Laravel
description: CI/CD pipeline automation for Laravel projects using GitHub Actions with automated testing, code quality checks, security scanning, deployment workflows, environment secrets management, and production-ready release strategies. Use this skill when creating GitHub Actions workflows for Laravel applications, setting up automated testing pipelines with PHPUnit and Pest, configuring code quality checks with PHPStan, Pint, and Larastan, implementing security vulnerability scanning with Composer audit and security tools, building and pushing Docker images to container registries, deploying to staging and production environments, managing GitHub Secrets for sensitive credentials, setting up environment-specific deployments (staging, production), implementing workflow triggers (push, pull_request, manual), configuring matrix builds for multiple PHP versions, running database migrations and seeders in CI, caching Composer dependencies for faster builds, running Laravel Dusk browser tests in CI, setting up deployment notifications and status checks, implementing rollback strategies, or creating release workflows with semantic versioning. Essential for automating repetitive development tasks, catching bugs early with automated tests, ensuring code quality standards across teams, securing applications with vulnerability scanning, accelerating deployment cycles with reliable pipelines, maintaining deployment history and rollback capabilities, and enabling continuous integration and delivery practices.
---

# GitHub Actions Laravel

This Skill provides Claude Code with specific guidance on CI/CD pipelines for Laravel applications.

## When to use this skill:

- Creating GitHub Actions workflows for Laravel projects
- Setting up automated testing with PHPUnit/Pest
- Configuring code quality checks (PHPStan, Larastan, Pint)
- Implementing security vulnerability scanning
- Building and pushing Docker images to registries
- Deploying to staging and production environments
- Managing GitHub Secrets and environment variables
- Configuring workflow triggers and conditions
- Setting up matrix builds for multiple PHP versions
- Running database migrations and seeders in CI
- Caching Composer dependencies for faster builds
- Running Laravel Dusk browser tests
- Setting up deployment notifications
- Implementing rollback strategies
- Creating release workflows with versioning

## Instructions

For details, refer to the information provided in this file:
[assets/cicd-guide.md](assets/cicd-guide.md)

## Key Templates

- **ci.yml**: Continuous Integration workflow
- **deploy-staging.yml**: Staging deployment workflow
- **deploy-production.yml**: Production deployment workflow
- **docker-build.yml**: Docker image build and push
- **security-scan.yml**: Security vulnerability scanning
