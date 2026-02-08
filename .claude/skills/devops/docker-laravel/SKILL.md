---
name: Docker Laravel
description: Docker containerization for Laravel applications with multi-stage builds, Docker Compose orchestration, volume management, and production-ready container patterns. Use this skill when containerizing Laravel applications, creating Dockerfile with multi-stage builds for optimized image size, configuring docker-compose.yml for local development and production environments, managing persistent volumes for storage and logs, setting up PHP-FPM, Nginx, and Redis containers, configuring container networking and service discovery, implementing health checks and startup dependencies, optimizing layer caching for faster builds, managing environment-specific configurations, creating development vs production image variants, debugging container issues, setting up Docker logging drivers, implementing container resource limits, or orchestrating multi-container Laravel applications with databases, queues, and caching services. Essential for reproducible development environments, consistent deployment across infrastructure, isolated dependency management, team onboarding with docker-compose up, zero-downtime deployments, scaling containerized services, and maintaining parity between development and production environments.
---

# Docker Laravel

This Skill provides Claude Code with specific guidance on Docker containerization for Laravel applications.

## When to use this skill:

- Creating or optimizing Dockerfile for Laravel applications
- Setting up multi-stage builds for production images
- Configuring docker-compose.yml for local development
- Managing persistent volumes for logs, storage, and databases
- Setting up PHP-FPM, Nginx, Redis, and MySQL/PostgreSQL containers
- Configuring container networking and service discovery
- Implementing health checks and container startup dependencies
- Optimizing Docker layer caching for faster builds
- Managing environment-specific container configurations
- Creating separate development and production image variants
- Debugging container startup and runtime issues
- Setting up Docker logging drivers and log rotation
- Implementing container resource limits (CPU, memory)
- Orchestration of multi-container Laravel applications

## Instructions

For details, refer to the information provided in this file:
[assets/docker-guide.md](assets/docker-guide.md)

## Key Templates

- **Dockerfile**: Multi-stage production Dockerfile
- **docker-compose.yml**: Local development orchestration
- **docker-compose.prod.yml**: Production deployment configuration
- **nginx.conf**: Nginx configuration for Laravel
- **php.ini**: Custom PHP configuration
