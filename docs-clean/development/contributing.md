# Contributing to AGL Hostman

We welcome contributions to AGL Hostman! This guide will help you get started with contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Environment Setup](#development-environment-setup)
4. [Branching Strategy](#branching-strategy)
5. [Commit Guidelines](#commit-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Coding Standards](#coding-standards)
8. [Testing](#testing)
9. [Documentation](#documentation)
10. [Reporting Issues](#reporting-issues)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). This code outlines the rules for participating in the community and maintaining a positive environment.

## Getting Started

### 1. Fork the Repository

Fork the [AGL Hostman repository](https://github.com/aglhostman/agl-hostman) on GitHub.

### 2. Clone Your Fork

```bash
git clone https://github.com/your-username/agl-hostman.git
cd agl-hostman
git remote add upstream https://github.com/aglhostman/agl-hostman.git
```

### 3. Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install Python dependencies for documentation
pip install -r docs/requirements.txt
```

## Development Environment Setup

### 1. Environment Variables

Create a `.env` file in the root directory:

```bash
# .env
NODE_ENV=development
API_URL=http://localhost:8080
DATABASE_URL=postgresql://localhost:5432/agl_hostman
REDIS_URL=redis://localhost:6379
```

### 2. Database Setup

```bash
# Create database
createdb agl_hostman_dev

# Run migrations
npm run migrate

# Seed database
npm run seed
```

### 3. Development Server

```bash
# Start development server
npm run dev

# Start documentation server
npm run docs:serve
```

### 4. Code Quality Tools

Install pre-commit hooks:

```bash
# Install pre-commit
npm install --save-dev pre-commit

# Configure pre-commit
cat > .pre-commit-config.yaml << EOF
repos:
  - repo: local
    hooks:
      - id: eslint
        name: Run ESLint
        entry: npm run lint
        language: system
        pass_filenames: false
      - id: prettier
        name: Run Prettier
        entry: npx prettier --write
        language: system
        files: \.(js|jsx|ts|tsx|json|md|yml|yaml)$
      - id: test
        name: Run tests
        entry: npm run test
        language: system
        pass_filenames: false
EOF

git config core.hooksPath .git/hooks
```

## Branching Strategy

We use GitFlow for branching:

```
main
├── develop
├── feature/*
├── hotfix/*
└── release/*
```

### Branch Types

- **`main`**: Production-ready code
- **`develop`**: Integration branch for new features
- **`feature/*`**: New feature branches
- **`release/*`**: Release preparation branches
- **`hotfix/*`**: Critical bug fixes

### Creating a Feature Branch

```bash
# Create feature branch
git checkout -b feature/user-management develop

# Push to remote
git push origin feature/user-management
```

## Commit Guidelines

### Commit Message Format

```
type(scope): description

[optional body]

[optional footer]
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation change
- **style**: Code style change
- **refactor**: Code refactoring
- **perf**: Performance improvement
- **test**: Test addition or modification
- **chore**: Build or tooling changes

### Examples

```
feat(storage): add NFS mount management

Add support for creating and managing NFS mounts with automatic
discovery and configuration. Includes validation for mount points
and remote servers.

Fixes #123

feat(auth): implement OAuth2 support

Add OAuth2 authentication with GitHub and Google providers.
Includes token refresh and session management.

Closes #456

docs(api): update API documentation

Add new endpoints for backup management and update existing
API documentation with examples and response formats.
```

### Commit Best Practices

1. **Keep commits focused**: Each commit should do one thing
2. **Write clear messages**: Use descriptive subjects
3. **Use present tense**: "Add feature" not "Added feature"
4. **Include references**: Reference related issues with `#123`
5. **Break large changes**: Split large feature implementations into smaller commits

## Pull Request Process

### 1. Create Pull Request

After pushing your feature branch:

1. Open the repository on GitHub
2. Click "New Pull Request"
3. Select your branch and `develop` as the target
4. Fill out the PR template

### 2. Pull Request Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation change

## How to Test
Steps to test the changes

## Checklist
- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have run tests locally and they pass
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any changes that affect user-facing functionality are documented in the PR
- [ ] I have updated the documentation accordingly

## Related Issues
Fixes #123
Related to #456
```

### 3. Review Process

1. **Automated Checks**: CI/CD pipeline runs automatically
2. **Code Review**: At least one maintainer must approve
3. **Testing**: All tests must pass
4. **Merge**: Maintainer merges to `develop`

### 4. After Merge

After your PR is merged:

```bash
# Fetch latest changes
git fetch upstream

# Update local develop
git checkout develop
git pull upstream develop

# Clean up feature branch
git branch -d feature/user-management
git push origin --delete feature/user-management
```

## Coding Standards

### JavaScript/TypeScript

We use ESLint and Prettier for code formatting:

```bash
# Check code style
npm run lint

# Fix code style
npm run lint:fix

# Format code
npm run format
```

#### Key Rules
- Use TypeScript for all new code
- Use meaningful variable and function names
- Follow the existing code style
- Write JSDoc comments for public APIs
- Use async/await for async operations

### Python

For documentation scripts and tools:

```bash
# Format Python code
black docs/
```

### Go

For infrastructure tools:

```bash
# Format Go code
gofmt -w infrastructure/
```

## Testing

### Test Categories

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions
3. **E2E Tests**: Test complete user workflows
4. **Performance Tests**: Test under load

### Running Tests

```bash
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests
npm run test:integration

# Run E2E tests
npm run test:e2e

# Run tests with coverage
npm run test:coverage
```

### Test Structure

```
tests/
├── unit/
│   ├── storage/
│   │   ├── nfs.test.js
│   │   └── iscsi.test.js
│   ├── api/
│   │   ├── authentication.test.js
│   │   └── endpoints.test.js
│   └── utils/
│       └── helpers.test.js
├── integration/
│   ├── api.test.js
│   ├── storage.test.js
│   └── backup.test.js
└── e2e/
    ├── login.spec.js
    ├── backup.spec.js
    └── recovery.spec.js
```

### Writing Tests

#### Unit Test Example

```javascript
// tests/unit/storage/nfs.test.js
const NFSManager = require('../../../src/storage/nfs');

describe('NFS Manager', () => {
  let nfsManager;

  beforeEach(() => {
    nfsManager = new NFSManager({
      server: 'aglsrv1.local',
      mountPoint: '/mnt/test'
    });
  });

  describe('mount', () => {
    it('should create NFS mount', async () => {
      const result = await nfsManager.mount();
      expect(result).to.be.true;
    });

    it('should handle mount errors', async () => {
      nfsManager.server = 'invalid-server';
      const result = await nfsManager.mount();
      expect(result).to.be.false;
    });
  });
});
```

#### Integration Test Example

```javascript
// tests/integration/api.test.js
const request = require('supertest');
const app = require('../../../src/app');

describe('API Integration', () => {
  describe('GET /api/v1/status', () => {
    it('should return system status', async () => {
      const response = await request(app)
        .get('/api/v1/status')
        .expect(200);

      expect(response.body).to.have.property('success', true);
      expect(response.body).to.have.property('data');
      expect(response.body.data).to.have.property('status');
    });
  });
});
```

## Documentation

### Documentation Types

1. **Code Documentation**: JSDoc for code
2. **API Documentation**: Swagger/OpenAPI
3. **User Documentation**: Getting started guides
4. **Developer Documentation**: Contributing guides

### Writing Documentation

#### Code Documentation

```javascript
/**
 * NFS Manager for handling NFS mounts
 * @class NFSManager
 * @param {Object} config - Configuration options
 * @param {string} config.server - NFS server hostname
 * @param {string} config.mountPoint - Mount point path
 */
class NFSManager {
  /**
   * Create an NFS mount
   * @returns {Promise<boolean>} True if successful
   */
  async mount() {
    // Implementation
  }

  /**
   * Unmount NFS mount
   * @returns {Promise<boolean>} True if successful
   */
  async unmount() {
    // Implementation
  }
}
```

#### Markdown Documentation

Use the existing documentation structure in `docs/`:

```markdown
# API Endpoint

## Description
Brief description of the endpoint

## Method
HTTP method (GET, POST, PUT, DELETE)

## URL
`/api/v1/endpoint`

## Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | string | Yes | Resource ID |

## Response
```json
{
  "success": true,
  "data": {
    "id": "123",
    "name": "Example"
  }
}
```

## Example
```bash
curl -X GET "https://api.aglhostman.local/api/v1/endpoint/123"
```
```

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Environment**: OS, Node.js version, etc.
2. **Steps to Reproduce**: Clear steps to reproduce the issue
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Error Messages**: Any error messages or stack traces
6. **Relevant Code**: Code snippets that cause the issue

### Issue Template

```markdown
## Bug Description
Brief description of the bug

## Environment
- OS: [e.g., Ubuntu 20.04]
- Node.js: [e.g., 18.0.0]
- AGL Hostman: [e.g., 1.0.0]

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Error Messages
```
Error message here
```

## Additional Context
Any additional information that might help
```

### Feature Requests

For feature requests, please include:

1. **Problem**: What problem does the feature solve?
2. **Proposed Solution**: How would you like the feature to work?
3. **Alternatives**: Any alternative solutions you've considered
4. **Use Cases**: Real-world use cases for the feature

## Development Workflow

### 1. Development Process

1. Check existing issues and PRs
2. Create a feature branch from `develop`
3. Implement changes with tests
4. Run test suite
5. Update documentation
6. Create pull request
7. Address feedback
8. Merge after approval

### 2. Code Review

Code review checklist:
- [ ] Code follows project standards
- [ ] Tests are comprehensive
- [ ] Documentation is updated
- [ ] No breaking changes (unless intended)
- [ ] Performance considerations
- [ ] Security implications
- [ ] Error handling

### 3. Release Process

1. Prepare release branch
2. Update version numbers
3. Update CHANGELOG.md
4. Run full test suite
5. Create release tag
6. Update documentation
7. Deploy to production

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: General discussion and Q&A
- **Email**: Private questions and sensitive issues

### Getting Help

1. Check existing issues and documentation
2. Search the codebase
3. Create a detailed issue report
4. Be patient and responsive to questions

## Recognition

Contributors will be recognized in:
- Contributors list in README
- Commit history
- Release notes for significant contributions

Thank you for contributing to AGL Hostman!

---

*Next: [Code Standards](code-standards.md)*

*Previous: [Development Environment](environment.md)*