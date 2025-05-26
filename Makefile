.PHONY: setup deps compile test run clean docker-build docker-run docker-stop

# Default task
all: deps compile test

# Setup development environment
setup:
	./setup.sh

# Get dependencies
deps:
	mix deps.get

# Compile the project
compile:
	mix compile

# Run tests
test:
	mix test

# Run the application
run:
	mix run --no-halt

# Clean build artifacts
clean:
	mix clean

# Format code
format:
	mix format

# Run static code analysis
lint:
	mix credo

# Generate documentation
docs:
	mix docs

# Docker tasks
docker-build:
	docker-compose build

docker-run:
	docker-compose up

docker-stop:
	docker-compose down

# Help
help:
	@echo "Available targets:"
	@echo "  setup        - Run setup script to install dependencies"
	@echo "  deps         - Get project dependencies"
	@echo "  compile      - Compile the project"
	@echo "  test         - Run tests"
	@echo "  run          - Run the application"
	@echo "  clean        - Clean build artifacts"
	@echo "  format       - Format code"
	@echo "  lint         - Run static code analysis"
	@echo "  docs         - Generate documentation"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run with Docker Compose"
	@echo "  docker-stop  - Stop Docker containers"