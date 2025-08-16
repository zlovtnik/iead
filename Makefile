.PHONY: install test clean build run docker-build docker-run

# Default target
all: install

# Install dependencies
install:
	luarocks install --local --only-deps church-management-1.0-1.rockspec

# Run the application
run:
	./scripts/start.sh

# Build the application package
build:
	mkdir -p bin
	cp app.lua bin/church-management
	chmod +x bin/church-management
	luarocks make church-management-1.0-1.rockspec

# Test the application with both runtimes
test:
	@echo "Testing with Lua 5.4..."
	lua scripts/test_both_runtimes.lua
	@echo ""
	@echo "Testing with LuaJIT..."
	@export LUA_PATH="/Users/rcs/.luarocks/share/lua/5.1/?.lua;./src/?.lua;./?.lua;;" && luajit scripts/test_both_runtimes.lua
	@echo ""
	@echo "Running comprehensive tests..."
	lua scripts/run_comprehensive_tests.lua

# Test functional programming features
test-functional:
	@echo "Testing functional programming with current runtime..."
	lua scripts/functional_programming_demo.lua

# Validate installation
validate:
	@echo "Validating installation..."
	lua scripts/validate_functional_setup.lua

# Create a distributable package
pack:
	luarocks pack church-management 1.0-1

# Clean build artifacts
clean:
	rm -rf bin
	rm -f *.rock

# Build Docker image
docker-build:
	docker build -t church-management:1.0 .

# Run Docker container
docker-run:
	docker run -p 8080:8080 church-management:1.0

# Create database schema
init-db:
	lua -e "require('src.db.schema').init()"

# Help target
help:
	@echo "Available targets:"
	@echo "  make install       - Install dependencies"
	@echo "  make test          - Run tests with both Lua 5.4 and LuaJIT"
	@echo "  make test-functional - Test functional programming features"
	@echo "  make validate      - Validate installation"
	@echo "  make run           - Run the application"
	@echo "  make build         - Build the application package"
	@echo "  make pack          - Create a distributable package"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make docker-build  - Build Docker image"
	@echo "  make docker-run    - Run Docker container"
	@echo "  make init-db       - Initialize database schema"
