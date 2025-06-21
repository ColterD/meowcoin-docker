# Meowcoin Docker Tests

This directory contains test scripts for verifying the Meowcoin Docker setup.

## Available Tests

### Build Test

The `test-build.sh` script verifies that the Docker images can be built correctly and that all necessary components are properly configured.

To run the build test:

```bash
sudo ./test/test-build.sh
```

Note: The test requires Docker to be installed and running, and may need sudo privileges.

This test:
1. Creates a temporary directory
2. Copies the project files
3. Builds the Docker images
4. Verifies that the images were created successfully
5. Checks that the entrypoint.sh contains healthcheck functionality
6. Verifies that the Dockerfile contains the HEALTHCHECK directive
7. Confirms that docker-compose.yml has the proper healthcheck configuration

## Adding New Tests

When adding new tests, please follow these guidelines:

1. Create a new script with a descriptive name (e.g., `test-network.sh`)
2. Add proper error handling and cleanup
3. Make the script executable (`chmod +x test-new-test.sh`)
4. Update this README with information about the new test