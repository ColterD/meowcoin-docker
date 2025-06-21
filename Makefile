.PHONY: build up down restart logs status clean prune help

# Default target
help:
	@echo "Meowcoin Docker Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make build     - Build the Docker images"
	@echo "  make up        - Start the containers"
	@echo "  make down      - Stop the containers"
	@echo "  make restart   - Restart the containers"
	@echo "  make logs      - View container logs"
	@echo "  make status    - Check container status"
	@echo "  make clean     - Remove containers and local images"
	@echo "  make prune     - Remove all unused containers, networks, and images"
	@echo "  make help      - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make up"
	@echo "  make logs"

# Build the Docker images
build:
	@echo "Building Docker images..."
	docker-compose build

# Start the containers
up:
	@echo "Starting containers..."
	docker-compose up -d

# Stop the containers
down:
	@echo "Stopping containers..."
	docker-compose down

# Restart the containers
restart:
	@echo "Restarting containers..."
	docker-compose restart

# View container logs
logs:
	@echo "Viewing container logs..."
	docker-compose logs -f

# Check container status
status:
	@echo "Container status:"
	docker-compose ps

# Remove containers and local images
clean:
	@echo "Removing containers and local images..."
	docker-compose down --rmi local

# Remove all unused containers, networks, and images
prune:
	@echo "Pruning unused Docker resources..."
	docker system prune -a --volumes