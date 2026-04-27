---
name: Backend Models
description: Define database models and ORM entities with proper naming conventions, relationships, validations, and data integrity constraints. Use this skill when creating new ORM model classes in files like models.py, User.rb, entities/, models/, *.model.ts, or entity definition files, defining database table structures and column specifications, setting up model relationships (one-to-many, many-to-many, belongs-to, has-many), implementing model-level validations and business logic, adding timestamps (created_at, updated_at, deleted_at) for auditing and debugging, defining foreign key constraints with appropriate cascade behaviors (CASCADE, SET NULL, RESTRICT), creating indexes on foreign key columns and frequently queried fields, setting up data type constraints (NOT NULL, UNIQUE, DEFAULT values), choosing appropriate data types that match data purpose and size requirements, working with ActiveRecord, Sequelize, SQLAlchemy, Prisma, TypeORM, Mongoose, or similar ORM frameworks, implementing soft deletes or audit trails, balancing database normalization with practical query performance, defining validation at both model and database levels for defense in depth, or setting up database constraints to enforce data rules at the database level. Essential for ensuring data integrity, maintaining clear relationship definitions, optimizing query performance through proper indexing, and implementing robust validation across application and database layers.
---

# Backend Models

This Skill provides Codex with specific guidance on how to adhere to coding standards as they relate to how it should handle backend models.

## When to use this skill:

- Creating new ORM model classes or entities
- Defining database table structures and columns
- Setting up model relationships (one-to-many, many-to-many, belongs-to)
- Implementing model-level validations
- Adding timestamps (created_at, updated_at) to models
- Defining foreign key constraints and cascade behaviors
- Creating indexes on model fields
- Setting up data type constraints (NOT NULL, UNIQUE)
- Working with ActiveRecord, Sequelize, SQLAlchemy, Prisma, or similar ORMs
- Working with files like `models.py`, `User.rb`, `entities/`, `models/`, `*.model.ts`

## Instructions

For details, refer to the information provided in this file:
[backend models](../../../agent-os/standards/backend/models.md)
