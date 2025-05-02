# Contributing to MeowCoin Platform

Thank you for your interest in contributing to the MeowCoin Platform! This document provides guidelines and instructions for contributing to the project.

## Development Setup

### Prerequisites

- Node.js 20.x or later
- Docker and Docker Compose
- Git
- PostgreSQL (for local development without Docker)
- Redis (for local development without Docker)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/meowcoin-platform.git
   cd meowcoin-platform
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. Start the development environment:
   ```bash
   # With Docker (recommended)
   npm run docker:up

   # Without Docker
   npm run dev
   ```

## Project Structure

The MeowCoin Platform is organized as a monorepo with the following packages:

- `packages/api`: API Gateway service
- `packages/blockchain`: Blockchain service for MeowCoin node management
- `packages/dashboard`: Web-based dashboard UI
- `packages/shared`: Shared types, utilities, and constants

## Development Workflow

### Branching Strategy

- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: Feature branches
- `bugfix/*`: Bug fix branches
- `release/*`: Release preparation branches

### Pull Request Process

1. Create a new branch from `develop` for your feature or bugfix
2. Make your changes and commit them with descriptive messages
3. Push your branch and create a pull request against `develop`
4. Ensure all tests pass and code meets quality standards
5. Request a review from maintainers
6. Address any feedback and update your PR
7. Once approved, your PR will be merged

### Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

Types include:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Changes to the build process or auxiliary tools

## Testing

We use Jest for unit and integration tests. Run tests with:

```bash
# Run all tests
npm test

# Run tests for a specific package
npm test -- --selectProjects api

# Run tests in watch mode
npm test -- --watch
```

## Code Style

We use ESLint and Prettier to maintain code quality and consistency:

```bash
# Lint all code
npm run lint

# Format all code
npm run format
```

## Documentation

Please update documentation when making changes:

- Update README.md files for significant changes
- Add JSDoc comments to functions and classes
- Update API documentation for endpoint changes

## License

By contributing to the MeowCoin Platform, you agree that your contributions will be licensed under the project's MIT License.