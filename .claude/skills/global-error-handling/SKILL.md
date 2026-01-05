---
name: Global Error Handling
description: Implement robust error handling with user-friendly messages, specific exception types, graceful degradation, and proper resource cleanup across all application layers. Use this skill when adding try-catch-finally blocks, error boundaries in React or similar frameworks, implementing validation logic that fails early with clear error messages, handling exceptions in API routes, controllers, or service layers, providing user-friendly error messages that guide users toward solutions without exposing technical details, security information, or stack traces to end users, validating input and checking preconditions early in functions to fail fast and explicitly rather than allowing invalid state to propagate, using specific exception or error types (e.g., ValidationError, NetworkError, AuthenticationError) rather than generic Error or Exception to enable targeted handling, implementing centralized error handling at appropriate boundaries (middleware, error boundaries, API layers) rather than scattering try-catch blocks throughout code, designing systems to degrade gracefully when non-critical services fail rather than breaking the entire application, implementing retry strategies with exponential backoff for transient failures in external service calls, network requests, or database operations, ensuring resources like file handles, database connections, network sockets, or memory allocations are always cleaned up in finally blocks or using with/using statements, logging errors appropriately for debugging while keeping user-facing messages simple and actionable, or implementing error monitoring and alerting to track production issues. Essential for maintaining system stability under error conditions, providing excellent user experience even when things go wrong, preventing resource leaks from unclosed connections or file handles, debugging production issues through proper error logging, and building resilient systems that handle failures gracefully without cascading failures.
---

# Global Error Handling

This Skill provides Claude Code with specific guidance on how to adhere to coding standards as they relate to how it should handle global error handling.

## When to use this skill:

- Implementing try-catch blocks or error handlers
- Creating error boundaries in React or similar frameworks
- Adding input validation with clear error messages
- Handling API errors and external service failures
- Implementing retry strategies with exponential backoff
- Setting up centralized error handling middleware
- Ensuring resource cleanup (connections, file handles) in finally blocks
- Designing graceful degradation for non-critical failures
- Providing user-friendly error messages without exposing technical details
- Using specific exception types rather than generic errors
- Working with error handling in controllers, services, or any error-prone operations

## Instructions

For details, refer to the information provided in this file:
[global error handling](../../../agent-os/standards/global/error-handling.md)
