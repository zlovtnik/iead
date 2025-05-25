# Church Management System

A web-based church management system built with pure Lua and SQLite. This application provides a RESTful API for managing church members with a clean, modular architecture.

## Features

- Member management (add, view, edit, delete)
- Event management
- Attendance tracking
- Donation management
- Volunteer scheduling
- Reporting
- Tithe management (10% salary contributions)

## Prerequisites

- [Lua](https://www.lua.org/download.html) (5.1 or higher)
- [LuaRocks](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-macOS)
- [Docker](https://www.docker.com/get-started) (optional, for containerized deployment)

## Installation

### Local Development

1. Install Lua and LuaRocks
2. Clone this repository
3. Install dependencies:
```
luarocks install luasql-sqlite3
luarocks install lua-cjson
luarocks install luasocket
```
4. Make the start script executable:
```
chmod +x start.sh
```
5. Start the server:
```
./start.sh
```

### Production Deployment

#### Option 1: Using the Build Script

1. Run the build script to create a production-ready package:
```
./build.sh
```

This will create a distributable package at `dist/church-management-<version>.tar.gz` and build a Docker image.

2. The build script supports various options:
```
./build.sh --help
```

Common options:
- `--version VALUE`: Set version number
- `--env VALUE`: Set environment (default: production)
- `--no-docker`: Skip Docker image building
- `--docker-tag VALUE`: Set Docker tag
- `--push-docker`: Push Docker image to registry
- `--docker-registry URL`: Set Docker registry URL

#### Option 2: Using Docker Compose

1. Deploy using Docker Compose:
```
docker-compose -f docker-compose.production.yml up -d
```

This will start the application in a Docker container with persistent storage.

## API Endpoints

- `GET /health` - Health check

### Members
- `GET /members` - List all members
- `POST /members` - Create a new member
- `GET /members/{id}` - Get a member by ID
- `PUT /members/{id}` - Update a member
- `DELETE /members/{id}` - Delete a member

### Tithes
- `GET /tithes` - List all tithes
- `POST /tithes` - Create a new tithe
- `GET /tithes/{id}` - Get a tithe by ID
- `PUT /tithes/{id}` - Update a tithe
- `DELETE /tithes/{id}` - Delete a tithe
- `POST /tithes/{id}/pay` - Mark a tithe as paid
- `GET /members/{id}/tithes` - Get all tithes for a member
- `GET /members/{id}/tithe-calculation` - Calculate tithe amount for a member
- `POST /tithes/generate-monthly` - Generate monthly tithes for all members

## Example Usage

```bash
# Health check
curl http://localhost:8080/health

# Create a member with salary
curl -X POST http://localhost:8080/members \
  -d "name=John Doe" \
  -d "email=john@example.com" \
  -d "phone=1234567890" \
  -d "salary=5000"

# List all members
curl http://localhost:8080/members

# Calculate tithe for a member (10% of salary)
curl http://localhost:8080/members/1/tithe-calculation

# Generate monthly tithes for all members
curl -X POST http://localhost:8080/tithes/generate-monthly \
  -d "month=5" \
  -d "year=2025"

# Mark a tithe as paid
curl -X POST http://localhost:8080/tithes/1/pay \
  -d "payment_method=Cash" \
  -d "notes=Paid on Sunday service"
```

## CI/CD Pipeline

This project uses GitHub Actions for continuous integration and deployment. The pipeline includes:

### Workflows

- **Lint**: Static code analysis using `luacheck`
- **Test**: Run all tests in the application
- **Security Scan**: Vulnerability scanning using Trivy
- **Build**: Build the application package
- **Docker**: Build and push Docker images to GitHub Container Registry
- **Deploy**: Automated deployment to staging and production environments

### Environments

- **Staging**: Deployed automatically when changes are pushed to the `develop` branch
- **Production**: Deployed automatically when:
  - Changes are pushed to the `main` branch
  - A new version tag (e.g., `v1.0.0`) is created

### Release Process

1. Create and push a new tag following semantic versioning:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. The CI/CD pipeline will automatically:
   - Build and test the application
   - Create a Docker image with the version tag
   - Deploy to production
   - Create a GitHub Release with changelog and artifacts

### Required Secrets

For the CI/CD pipeline to work, you need to set up the following secrets in your GitHub repository:

- `DEPLOY_USERNAME`: SSH username for deployment
- `DEPLOY_KEY`: SSH private key for deployment
- `DEPLOY_PORT`: SSH port for deployment (usually 22)
- `STAGING_HOST`: Hostname/IP for staging server
- `PRODUCTION_HOST`: Hostname/IP for production server

## License

MIT
