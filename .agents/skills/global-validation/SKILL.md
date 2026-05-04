---
name: Global Validation
description: Implement comprehensive input validation with server-side enforcement, client-side UX feedback, and security-focused sanitization using allowlists over blocklists to prevent injection attacks and ensure data integrity. Use this skill when validating user input from forms, query parameters, request bodies, or any external data sources, implementing server-side validation that never trusts client-side validation alone for security or data integrity purposes, adding client-side validation in forms, React components, or frontend code to provide immediate user feedback and improve UX while understanding it's not a security measure, validating input as early as possible in the request lifecycle and rejecting invalid data before processing or database operations, providing clear, field-specific error messages that help users correct their input (e.g., "Password must be at least 8 characters" rather than "Invalid input"), defining allowlists of what is allowed (e.g., allowed characters, formats, values) rather than trying to block everything that's not allowed (blocklists), checking data types, formats (email, URL, date), ranges (min/max values), lengths, and required fields systematically across all inputs, sanitizing user input to prevent injection attacks including SQL injection, XSS (cross-site scripting), command injection, or path traversal vulnerabilities, validating business rules such as sufficient account balance, valid date ranges, unique constraints, or referential integrity at the appropriate application layer, applying validation consistently across all entry points including web forms, REST API endpoints, GraphQL resolvers, WebSocket messages, and background jobs, using validation libraries or frameworks (Yup, Zod, Joi, marshmallow, Rails validations, Django forms) for consistent validation logic, or implementing custom validators for complex business rules that framework validations can't handle. Essential for preventing security vulnerabilities that could compromise the application or user data, ensuring data integrity throughout the system, providing excellent user experience through helpful validation feedback, protecting against malicious input or injection attacks, and maintaining database consistency by rejecting invalid data at application boundaries.
---

# Global Validation

This Skill provides Codex with specific guidance on how to adhere to coding standards as they relate to how it should handle global validation.

## When to use this skill:

- Implementing form validation (client-side and server-side)
- Validating API request payloads and parameters
- Adding input sanitization to prevent injection attacks
- Implementing type and format validation (emails, dates, numbers)
- Writing business rule validation (sufficient balance, valid ranges)
- Providing specific, actionable error messages for invalid input
- Using allowlists instead of blocklists for input validation
- Ensuring consistent validation across all entry points
- Validating data before processing or storing
- Working with form handlers, API controllers, or data processing logic

## Instructions

For details, refer to the information provided in this file:
[global validation](../../../agent-os/standards/global/validation.md)
