# Contributing to Meowcoin Docker

Thank you for your interest in contributing to the Meowcoin Docker project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with the following information:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Any relevant logs or error messages
- Your environment (Docker version, OS, etc.)

### Suggesting Enhancements

We welcome suggestions for enhancements! Please create an issue with:

- A clear, descriptive title
- A detailed description of the proposed enhancement
- Any relevant examples or use cases
- If applicable, examples of how this is implemented in other projects

### Pull Requests

1. Fork the repository
2. Create a new branch with a descriptive name (e.g., `feature/add-prometheus-metrics`)
3. Make your changes
4. Run the tests to ensure everything works correctly
5. Submit a pull request with a clear description of the changes

## Development Guidelines

### Docker Best Practices

- Follow the [Docker best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- Use multi-stage builds where appropriate
- Minimize the number of layers
- Use specific versions for base images
- Keep images as small as possible

### Security

- Never run containers as root
- Use the principle of least privilege
- Implement proper credential management
- Use read-only filesystems where possible
- Verify downloads with checksums

### Testing

- Add tests for new features
- Ensure existing tests pass before submitting a PR
- Test your changes in different environments if possible

## Style Guidelines

### Shell Scripts

- Use `#!/bin/bash` for shell scripts
- Add `set -euo pipefail` to ensure scripts fail fast
- Use meaningful variable names
- Add comments for complex logic
- Use functions for reusable code

### Dockerfiles

- Use a consistent format for Dockerfiles
- Group related commands to minimize layers
- Add comments for clarity
- Use ARG for build-time variables
- Use ENV for runtime variables

### Documentation

- Keep documentation up-to-date
- Use clear, concise language
- Provide examples where helpful
- Use proper Markdown formatting

## License

By contributing to this project, you agree that your contributions will be licensed under the project's license.