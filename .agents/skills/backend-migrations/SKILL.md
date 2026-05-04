---
name: Backend Migrations
description: Create and manage database schema migrations with proper versioning, reversibility, and zero-downtime deployment strategies. Use this skill when creating new migration files in directories like migrations/, db/migrate/, or alembic/versions/, modifying existing database schemas, adding or removing tables and columns, creating or dropping database indexes (using concurrent options on large tables), setting up foreign key constraints and relationships, implementing data migrations or transformations, writing rollback/down methods for migration reversibility, planning database changes for zero-downtime deployments, working with migration tools like Alembic, Django migrations, Sequelize, Knex, Flyway, or Rails migrations, managing migration version control and naming conventions (using descriptive names), separating schema changes from data migrations for safer rollbacks, handling backwards compatibility during high-availability deployments, or troubleshooting migration failures. Apply when working with migration files like *_create_users.rb, 001_initial_schema.sql, 20231201_add_indexes.py, or any database versioning and schema evolution tasks. Essential for maintaining database integrity across development, staging, and production environments while ensuring safe deployment and rollback capabilities.
---

# Backend Migrations

This Skill provides Codex with specific guidance on how to adhere to coding standards as they relate to how it should handle backend migrations.

## When to use this skill:

- Creating new database migration files
- Modifying existing database schema
- Adding, altering, or removing tables and columns
- Creating or dropping database indexes
- Implementing data migrations or transformations
- Setting up foreign key constraints or relationships
- Writing rollback/down methods for reversibility
- Planning zero-downtime database deployments
- Working with migration tools like Alembic, Django migrations, Sequelize, or Rails migrations
- Working with files in `migrations/`, `db/migrate/`, or similar directories

## Instructions

For details, refer to the information provided in this file:
[backend migrations](../../../agent-os/standards/backend/migrations.md)
