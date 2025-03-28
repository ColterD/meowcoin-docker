# Contributing to Meowcoin Docker

We welcome contributions to the Meowcoin Docker project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming community.

## Ways to Contribute

- Reporting bugs
- Suggesting enhancements
- Improving documentation
- Submitting code changes
- Writing tests

## Development Process

1. **Fork the repository**
2. **Clone your fork**:
   ```bash
   git clone https://github.com/YOUR-USERNAME/meowcoin-docker.git
   cd meowcoin-docker
   ```

3. **Create a branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Make your changes**

5. **Test your changes**:
   ```bash
   docker-compose build
   docker-compose up -d
   # Run appropriate tests
   ```

6. **Commit your changes**:
   ```bash
   git commit -m "Add feature: brief description"
   ```

7. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

8. **Submit a pull request**

## Pull Request Guidelines

- Fill in the required template
- Include appropriate tests
- Follow the code style
- Update documentation for significant changes
- Pass all CI checks

## Coding Standards

- Use shellcheck for shell scripts
- Follow Docker best practices
- Use meaningful variable names
- Include comments for complex logic
- Update documentation when needed

## Testing

Before submitting, test your changes:

- Build the image locally
- Verify functionality with docker-compose
- Check logs for errors
- Test on multiple architectures if possible

## Documentation

When updating documentation:

- Use clear, concise language
- Provide examples where helpful
- Update all relevant files
- Check for spelling and grammar

## Questions?

If you have questions about contributing, please open an issue or discussion on GitHub.

Thank you for your contributions!