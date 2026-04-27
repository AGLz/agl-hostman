---
name: Testing Test Writing
description: Write strategic, behavior-focused tests that cover core user workflows and critical paths without over-testing implementation details, edge cases, or non-critical utilities during feature development. Use this skill when writing unit tests in files like *.test.js, *.spec.ts, *_test.py, *_spec.rb, integration tests that verify multiple components work together correctly, or end-to-end tests for critical user workflows, focusing on writing minimal tests during development by completing feature implementation first before adding strategic tests only at logical completion points, testing exclusively core user flows and primary workflows that are business-critical while skipping tests for non-critical utilities and secondary workflows unless specifically instructed, deferring edge case testing, error state validation, and exhaustive validation logic testing unless they are business-critical (these can be addressed in dedicated testing phases), writing tests that focus on behavior (what the code does) rather than implementation details (how it does it) to reduce test brittleness during refactoring, using clear, descriptive test names that explain what's being tested and the expected outcome (e.g., "should return user profile when authenticated" rather than "test1"), mocking external dependencies like databases, APIs, file systems, and third-party services to isolate units and prevent tests from depending on external state, keeping unit tests fast with execution times in milliseconds so developers run them frequently during development without friction, avoiding testing private methods or internal implementation details that may change during refactoring, organizing tests with clear arrange-act-assert (AAA) or given-when-then patterns, using testing frameworks like Jest, Vitest, RSpec, pytest, JUnit, or xUnit family appropriately, or setting up test fixtures, factories, or test data builders for consistent test setup. Essential for maintaining confidence in code changes without slowing down development velocity, catching regressions in critical user flows while avoiding test maintenance burden, enabling safe refactoring through behavior-focused tests that don't break when implementation changes, and keeping test suites fast enough that developers actually run them during development rather than treating them as a CI-only concern.
---

# Testing Test Writing

This Skill provides Claude Code with specific guidance on how to adhere to coding standards as they relate to how it should handle testing test writing.

## When to use this skill:

- Writing tests at logical feature completion points (not during development)
- Creating tests for core user flows and critical paths
- Testing business-critical functionality and primary workflows
- Implementing behavior-focused tests (not implementation details)
- Writing clear, descriptive test names that explain intent
- Mocking external dependencies (databases, APIs, file systems)
- Ensuring fast test execution (milliseconds for unit tests)
- Deferring edge case and error state testing until necessary
- Avoiding over-testing of non-critical utilities or secondary flows
- Working with test files like `*.test.js`, `*.spec.ts`, `test/`, `__tests__/`

## Instructions

For details, refer to the information provided in this file:
[testing test writing](../../../agent-os/standards/testing/test-writing.md)
