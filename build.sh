#!/bin/bash
# Build script for Church Management System (Production)

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION=$(grep 'version =' church-management-1.0-1.rockspec | head -1 | cut -d '"' -f2 | sed 's/-1$//')
# Set default version if not detected
if [ -z "$VERSION" ]; then
    VERSION="1.0"
fi
ENV=${ENV:-production}
BUILD_DOCKER=${BUILD_DOCKER:-true}
DOCKER_TAG=${DOCKER_TAG:-latest}
PUSH_DOCKER=${PUSH_DOCKER:-false}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-""}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --version)
      VERSION="$2"
      shift
      shift
      ;;
    --env)
      ENV="$2"
      shift
      shift
      ;;
    --no-docker)
      BUILD_DOCKER=false
      shift
      ;;
    --docker-tag)
      DOCKER_TAG="$2"
      shift
      shift
      ;;
    --push-docker)
      PUSH_DOCKER=true
      shift
      ;;
    --docker-registry)
      DOCKER_REGISTRY="$2"
      shift
      shift
      ;;
    --help)
      echo "Usage: ./build.sh [options]"
      echo "Options:"
      echo "  --version VALUE       Set version number (default: from rockspec)"
      echo "  --env VALUE           Set environment (default: production)"
      echo "  --no-docker           Skip Docker image building"
      echo "  --docker-tag VALUE    Set Docker tag (default: latest)"
      echo "  --push-docker         Push Docker image to registry"
      echo "  --docker-registry URL Set Docker registry URL"
      echo "  --help                Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $key${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}=== Church Management System Build (${ENV}) ===${NC}"
echo -e "${YELLOW}Version: ${VERSION}${NC}"
echo -e "${YELLOW}Environment: ${ENV}${NC}"

# Create necessary directories
mkdir -p bin
mkdir -p dist
mkdir -p config/${ENV}

# Check for dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v lua &> /dev/null; then
    echo -e "${RED}Error: Lua is not installed${NC}"
    exit 1
fi

if ! command -v luarocks &> /dev/null; then
    echo -e "${RED}Error: LuaRocks is not installed${NC}"
    exit 1
fi

# Create environment-specific config if it doesn't exist
if [ ! -f "config/${ENV}/config.lua" ]; then
    echo -e "${YELLOW}Creating ${ENV} config...${NC}"
    mkdir -p "config/${ENV}"
    cat > "config/${ENV}/config.lua" << EOF
-- ${ENV} configuration
return {
  db_file = "church_management.db",
  host = "0.0.0.0",  -- Listen on all interfaces in production
  port = 8080,
  log_level = "info",
  environment = "${ENV}"
}
EOF
fi

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
luarocks install --local --only-deps church-management-1.0-1.rockspec

# Create executable script
echo -e "${YELLOW}Creating executable...${NC}"
cat > bin/church-management << EOF
#!/usr/bin/env lua
package.path = package.path .. ";./?.lua"
-- Environment variable is set externally via APP_ENV
-- Standard Lua doesn't have os.setenv
dofile("app.lua")
EOF
chmod +x bin/church-management

# Create production start script
echo -e "${YELLOW}Creating production start script...${NC}"
cat > bin/start-production.sh << 'EOF'
#!/bin/sh
# Start the Church Management System in production

# Set environment variables
export APP_ENV=${APP_ENV:-production}
export PORT=${PORT:-8080}
export HOST=${HOST:-0.0.0.0}
export DB_PATH=${DB_PATH:-/data/church_management.db}

# Create data directory if it doesn't exist
mkdir -p /data

# Make the app executable
chmod +x bin/church-management

# Print environment information
echo "Starting Church Management System"
echo "Environment: $APP_ENV"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Database path: $DB_PATH"

# Run the app with environment variables passed to the process
exec env APP_ENV="$APP_ENV" PORT="$PORT" HOST="$HOST" DB_PATH="$DB_PATH" bin/church-management
EOF
chmod +x bin/start-production.sh

# Create distributable package
echo -e "${YELLOW}Creating distributable package...${NC}"
DIST_DIR="dist/church-management-${VERSION}"
mkdir -p "${DIST_DIR}"
mkdir -p "${DIST_DIR}/src"
mkdir -p "${DIST_DIR}/bin"
mkdir -p "${DIST_DIR}/config/${ENV}"

# Copy files
cp -r src/* "${DIST_DIR}/src/"
cp -r config/${ENV}/* "${DIST_DIR}/config/${ENV}/"
cp app.lua "${DIST_DIR}/"
cp start.sh "${DIST_DIR}/"
cp README.md "${DIST_DIR}/"
cp bin/church-management "${DIST_DIR}/bin/"
cp bin/start-production.sh "${DIST_DIR}/bin/"
cp church-management-1.0-1.rockspec "${DIST_DIR}/"
cp Dockerfile "${DIST_DIR}/"
chmod +x "${DIST_DIR}/start.sh"
chmod +x "${DIST_DIR}/bin/church-management"
chmod +x "${DIST_DIR}/bin/start-production.sh"

# Create archive
cd dist
tar -czf "church-management-${VERSION}.tar.gz" "church-management-${VERSION}"
cd ..

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}Distributable package created at dist/church-management-${VERSION}.tar.gz${NC}"

# Build Docker image if requested
if [ "$BUILD_DOCKER" = true ]; then
    echo -e "${YELLOW}Building Docker image...${NC}"
    
    # Always create a fresh production Dockerfile
    echo -e "${YELLOW}Creating ${ENV} Dockerfile...${NC}"
    rm -f "Dockerfile.${ENV}"
    cat > "Dockerfile.${ENV}" << 'EOF'
FROM debian:bullseye-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    sqlite3 \
    libsqlite3-dev \
    build-essential \
    curl \
    bash \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application files
COPY . .

# Install Lua dependencies
RUN luarocks install luasql-sqlite3
RUN luarocks install lua-cjson
RUN luarocks install luasocket

# Create data directory
RUN mkdir -p /data

# Make scripts executable
RUN chmod +x bin/start-production.sh

# Expose port
EXPOSE 8080

# Set environment variables
ENV APP_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0
ENV DB_PATH=/data/church_management.db

# Set entry point
CMD ["bin/start-production.sh"]
EOF

    # Build the Docker image
    DOCKER_IMAGE_NAME="church-management"
    if [ -n "$DOCKER_REGISTRY" ]; then
        DOCKER_IMAGE_NAME="${DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}"
    fi
    
    # Ensure we have valid tags
    if [ -z "$DOCKER_TAG" ]; then
        DOCKER_TAG="latest"
    fi
    
    if [ -z "$VERSION" ]; then
        VERSION="1.0"
    fi
    
    echo -e "${YELLOW}Building Docker image with tags: ${DOCKER_TAG} and ${VERSION}${NC}"
    docker build -t "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}" -t "${DOCKER_IMAGE_NAME}:${VERSION}" -f "Dockerfile.${ENV}" "${DIST_DIR}"
    
    echo -e "${GREEN}Docker image built: ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} and ${DOCKER_IMAGE_NAME}:${VERSION}${NC}"
    
    # Push Docker image if requested
    if [ "$PUSH_DOCKER" = true ]; then
        echo -e "${YELLOW}Pushing Docker image to registry...${NC}"
        docker push "${DOCKER_IMAGE_NAME}:${DOCKER_TAG}"
        docker push "${DOCKER_IMAGE_NAME}:${VERSION}"
        echo -e "${GREEN}Docker image pushed to registry${NC}"
    fi
fi

echo -e "${BLUE}=== Build Process Complete ===${NC}"
echo -e "${YELLOW}Version: ${VERSION}${NC}"
echo -e "${YELLOW}Environment: ${ENV}${NC}"
echo -e "${GREEN}Distributable package: dist/church-management-${VERSION}.tar.gz${NC}"
if [ "$BUILD_DOCKER" = true ]; then
    echo -e "${GREEN}Docker image: ${DOCKER_IMAGE_NAME}:${DOCKER_TAG} and ${DOCKER_IMAGE_NAME}:${VERSION}${NC}"
fi
