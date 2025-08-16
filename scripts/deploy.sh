#!/bin/bash

# Church Management System Deployment Script
# Comprehensive deployment automation for production environments

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVIRONMENT="${1:-production}"
DOCKER_COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
BACKUP_DIR="/opt/church_management/backups"
LOG_FILE="/var/log/church_management_deploy.log"

# Deployment settings
DEFAULT_TIMEOUT=300
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_INTERVAL=30

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Church Management System Deployment  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Environment: ${ENVIRONMENT}"
echo -e "Timestamp: $(date)"
echo -e "User: $(whoami)"
echo -e "Host: $(hostname)"
echo ""

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    echo -e "${RED}❌ Deployment failed: $1${NC}"
    exit 1
}

# Warning function
warn() {
    log "WARN" "$1"
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

# Info function
info() {
    log "INFO" "$1"
    echo -e "${GREEN}ℹ️  $1${NC}"
}

# Step function
step() {
    log "STEP" "$1"
    echo -e "${PURPLE}🔄 $1${NC}"
}

# Success function
success() {
    log "SUCCESS" "$1"
    echo -e "${GREEN}✅ $1${NC}"
}

# Check if running as root
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root - this is not recommended for production deployments"
    fi
    
    # Check if user can write to project directory
    if [[ ! -w "$PROJECT_ROOT" ]]; then
        error_exit "No write permission to project directory: $PROJECT_ROOT"
    fi
}

# Validate environment
validate_environment() {
    step "Validating deployment environment"
    
    # Check if environment is valid
    case "$ENVIRONMENT" in
        development|staging|production)
            info "Environment '$ENVIRONMENT' is valid"
            ;;
        *)
            error_exit "Invalid environment: $ENVIRONMENT. Use: development, staging, or production"
            ;;
    esac
    
    # Check if Docker Compose file exists
    if [[ ! -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" ]]; then
        error_exit "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
    fi
    
    # Check if environment file exists
    local env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    if [[ ! -f "$env_file" ]]; then
        warn "Environment file not found: $env_file"
        if [[ -f "$PROJECT_ROOT/.env.${ENVIRONMENT}.template" ]]; then
            info "Template found. Please copy and configure: cp .env.${ENVIRONMENT}.template .env.$ENVIRONMENT"
        fi
        error_exit "Environment configuration missing"
    fi
    
    # Validate required environment variables
    # Validate file permissions (not world/group writable)
    if [[ $(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%Lp" "$env_file" 2>/dev/null) =~ [2367]$ ]]; then
        error_exit "Environment file $env_file has unsafe permissions"
    fi

    # Parse and export only safe KEY=VALUE pairs
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        # Only allow KEY=VALUE pairs, reject lines with metacharacters
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Reject values with shell metacharacters or command substitution
            if [[ "$value" =~ [\`\$\(\)\{\}\;\&\|\>] ]]; then
                warn "Skipping unsafe env line: $line"
                continue
            fi
            # Remove surrounding quotes if present
            value="${value%\"}"
            value="${value#\"}"
            export "$key"="$value"
        else
            warn "Skipping malformed env line: $line"
        fi
    done < "$env_file"
    
    local required_vars=("SESSION_SECRET" "JWT_SECRET")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error_exit "Required environment variable not set: $var"
        fi
    done
    
    success "Environment validation passed"
}

# Check system requirements
check_system_requirements() {
    step "Checking system requirements"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed"
    fi
    
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    info "Docker version: $docker_version"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error_exit "Docker Compose is not installed"
    fi
    
    local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    info "Docker Compose version: $compose_version"
    
    # Check available disk space
    local available_space=$(df -BG "$PROJECT_ROOT" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $available_space -lt 5 ]]; then
        error_exit "Insufficient disk space. Available: ${available_space}GB, Required: 5GB"
    fi
    info "Available disk space: ${available_space}GB"
    
    # Check available memory
    local available_memory=$(free -g | awk '/^Mem:/{print $7}')
    if [[ $available_memory -lt 1 ]]; then
        warn "Low available memory: ${available_memory}GB"
    fi
    info "Available memory: ${available_memory}GB"
    
    success "System requirements check passed"
}

# Create backup
create_backup() {
    if [[ "$ENVIRONMENT" != "production" ]]; then
        info "Skipping backup for non-production environment"
        return 0
    fi
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENVIRONMENT="${1:-production}"
DOCKER_COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"
BACKUP_DIR="/opt/church_management/backups"
LOG_FILE="/var/log/church_management_deploy.log"
rollback_allowed=false
    step "Creating system backup"
    
    local backup_name="backup-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Backup database if running
    # Backup database if running
    if docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" ps app | grep -q "Up"; then
        info "Backing up database"
        # Ensure backup directory exists in container
        docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" exec -T app \
            mkdir -p "/app/backups/$backup_name" || warn "Failed to create backup directory in container"

        # Backup database
        docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" exec -T app \
            sqlite3 /app/data/church_management.db ".backup /app/backups/$backup_name/database.db" || \
            warn "Database backup failed - continuing deployment"
    fi
    
    # Backup uploads directory
    if [[ -d "$PROJECT_ROOT/uploads" ]]; then
        info "Backing up uploads"
        cp -r "$PROJECT_ROOT/uploads" "$backup_path/" || warn "Uploads backup failed"
    fi
    
    # Backup configuration
    info "Backing up configuration"
    cp "$PROJECT_ROOT/.env.$ENVIRONMENT" "$backup_path/env" || warn "Config backup failed"
    cp "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" "$backup_path/" || warn "Compose file backup failed"
    
    # Create backup metadata
    cat > "$backup_path/metadata.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "environment": "$ENVIRONMENT",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_branch": "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')",
    "backup_type": "pre-deployment",
    "created_by": "$(whoami)@$(hostname)"
}
EOF
    
    # Compress backup
    info "Compressing backup"
    tar -czf "$BACKUP_DIR/${backup_name}.tar.gz" -C "$BACKUP_DIR" "$backup_name"
    rm -rf "$backup_path"
    
    success "Backup created: ${backup_name}.tar.gz"
    export BACKUP_NAME="$backup_name"
}

# Pull latest code
update_code() {
    step "Updating application code"
    
    cd "$PROJECT_ROOT"
    
    # Check if git repository
    if [[ ! -d ".git" ]]; then
        warn "Not a git repository - skipping code update"
        return 0
    fi
    
    # Save current commit
    local current_commit=$(git rev-parse HEAD)
    info "Current commit: $current_commit"
    
    # Pull latest changes
    local target_branch
    case "$ENVIRONMENT" in
        production)
            target_branch="main"
            ;;
        staging)
            target_branch="develop"
    info "Pulling latest changes from $target_branch"
-    git fetch origin
-    git checkout "$target_branch"
    git fetch origin || error_exit "Failed to fetch from remote repository"
    git checkout "$target_branch" || error_exit "Failed to checkout $target_branch"

    # Check for local changes that might conflict
    if ! git diff --quiet HEAD; then
        warn "Local changes detected, stashing them"
        git stash push -m "Auto-stash before deployment $(date)"
    fi

    git pull origin "$target_branch" || error_exit "Failed to pull latest changes"
    esac
    
    info "Pulling latest changes from $target_branch"
    git fetch origin
    git checkout "$target_branch"
    git pull origin "$target_branch"
    
    local new_commit=$(git rev-parse HEAD)
    info "New commit: $new_commit"
    
    if [[ "$current_commit" == "$new_commit" ]]; then
        info "No code changes detected"
    else
        info "Code updated successfully"
        # Show changes
        echo "Recent changes:"
        git log --oneline "$current_commit..$new_commit" | head -5
    fi
    
    success "Code update completed"
}

# Build and pull Docker images
update_images() {
    step "Updating Docker images"
    
    cd "$PROJECT_ROOT"
    
    # Pull latest images
    info "Pulling latest Docker images"
    docker-compose -f "$DOCKER_COMPOSE_FILE" pull
    
    # Build custom images if needed
    if grep -q "build:" "$DOCKER_COMPOSE_FILE"; then
        info "Building custom images"
        docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache
    fi
    
    # Clean up old images
    info "Cleaning up old images"
    docker image prune -f
    
    success "Docker images updated"
}

# Run database migrations
run_migrations() {
    step "Running database migrations"
    
    cd "$PROJECT_ROOT"
    
    # Check if migration script exists
    if [[ ! -f "scripts/migrate.lua" ]]; then
        warn "Migration script not found - skipping migrations"
        return 0
    fi
    
    # Run migrations in a temporary container
    info "Running database migrations"
    docker-compose -f "$DOCKER_COMPOSE_FILE" run --rm app lua scripts/migrate.lua migrate
    
    # Start services
    info "Starting services"
    if [[ "$ENVIRONMENT" == "production" ]]; then
        # Production: rolling update to minimize downtime
        info "Performing rolling update for production"
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d --scale app=2 --no-recreate || {
    success "Application deployment initiated"
}
    else
        # Development/Staging: simple deployment
        docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    fi
    
    success "Application deployment initiated"
}

# Health check
health_check() {
    step "Performing health checks"
    
    local retries=0
    local max_retries=$HEALTH_CHECK_RETRIES
    local interval=$HEALTH_CHECK_INTERVAL
    
    while [[ $retries -lt $max_retries ]]; do
        info "Health check attempt $((retries + 1))/$max_retries"
        
        # Wait for services to start
        sleep "$interval"
        
        # Check if containers are running
        # Check if required services are running
        local required_services=("$APP_SERVICE")
        local running_services
        running_services=$(docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" ps --services --filter "status=running")
        local all_running=true
        for svc in "${required_services[@]}"; do
            if ! echo "$running_services" | grep -q "^$svc$"; then
                warn "Required service '$svc' is not running"
                all_running=false
            fi
# Deployment settings
DEFAULT_TIMEOUT=300
HEALTH_CHECK_RETRIES=10
HEALTH_CHECK_INTERVAL=30
APP_SERVICE="app"
        if [[ "$all_running" != true ]]; then
            retries=$((retries + 1))
            continue
        fi
        
        # Check application health endpoint
        local health_url="http://localhost:8080/api/health"
        if curl -f -s "$health_url" >/dev/null 2>&1; then
            success "Health check passed"
            
            # Run comprehensive health check
            if [[ -f "$PROJECT_ROOT/scripts/health_check.lua" ]]; then
                info "Running comprehensive health check"
                docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" exec -T app \
                    lua scripts/health_check.lua status
            fi
            
            return 0
        else
            warn "Health check failed - application not responding"
        fi
        
        retries=$((retries + 1))
    done
    
    error_exit "Health checks failed after $max_retries attempts"
}

# Post-deployment tasks
post_deployment() {
    step "Running post-deployment tasks"
    
    # Clear application caches
    info "Clearing application caches"
    docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" exec -T app \
        find /tmp -name "*.cache" -delete 2>/dev/null || true
    
    # Optimize database
    if [[ "$ENVIRONMENT" == "production" ]]; then
        info "Optimizing database"
        docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" exec -T app \
            sqlite3 /app/data/church_management.db "VACUUM; ANALYZE;" || warn "Database optimization failed"
    fi
    
    # Update metrics
    info "Updating deployment metrics"
    local metrics_file="/var/log/church_management_metrics.log"
    echo "$(date -Iseconds),deployment,success,$ENVIRONMENT,$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" >> "$metrics_file"
    
    success "Post-deployment tasks completed"
    rollback_allowed=false
}

# Rollback function
rollback() {
    if [[ -z "${BACKUP_NAME:-}" ]]; then
        error_exit "No backup available for rollback"
    fi
    
    step "Rolling back deployment"
    
    # Stop current services
    docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" down
    
    # Restore from backup
    info "Restoring from backup: $BACKUP_NAME"
    cd "$BACKUP_DIR"
    tar -xzf "${BACKUP_NAME}.tar.gz"
    
    # Restore database
    # Restore database
    if [[ -f "$BACKUP_NAME/database.db" ]]; then
        # Restore database to the correct location inside container volume
        docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" run --rm app \
            cp "/app/backups/$BACKUP_NAME/database.db" "/app/data/church_management.db" || \
            warn "Failed to restore database"
    fi
    
    # Restore uploads
    if [[ -d "$BACKUP_NAME/uploads" ]]; then
        rm -rf "$PROJECT_ROOT/uploads"
        cp -r "$BACKUP_NAME/uploads" "$PROJECT_ROOT/"
    fi
    
    # Restore configuration
    if [[ -f "$BACKUP_NAME/env" ]]; then
        cp "$BACKUP_NAME/env" "$PROJECT_ROOT/.env.$ENVIRONMENT"
    fi
    
    # Start services with previous configuration
    docker-compose -f "$PROJECT_ROOT/$DOCKER_COMPOSE_FILE" up -d
    
    success "Rollback completed"
}

# Cleanup old backups
cleanup_backups() {
    if [[ "$ENVIRONMENT" != "production" ]]; then
        return 0
    fi
    
    step "Cleaning up old backups"
    
    # Keep last 10 backups
    cd "$BACKUP_DIR"
    ls -t backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f
    
    success "Backup cleanup completed"
}

# Error handler for trap
on_error() {
    local line="$1"
    local exit_code="$2"
    warn "Error at line $line (exit code $exit_code)"
    if [[ "$rollback_allowed" == true ]]; then
        rollback
    else
        warn "Rollback not permitted at this stage. Performing safe cleanup."
        # Add any safe cleanup or logging here
    fi
}

# Main deployment flow
main() {
    # Trap errors for conditional rollback
    trap 'on_error $LINENO $?' ERR
    
    check_permissions
    validate_environment
    check_system_requirements
    create_backup
    update_code
    update_images
    run_migrations
    update_code
    update_images
    run_migrations
    health_check
    health_check
    post_deployment
    cleanup_backups
    
    echo ""
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL! 🎉${NC}"
    echo -e "Environment: $ENVIRONMENT"
    echo -e "Timestamp: $(date)"
    echo -e "Application URL: ${APPLICATION_URL:-http://localhost:8080}"
    echo ""
    
    # Show deployment summary
    info "Deployment Summary:"
    echo "  - Environment: $ENVIRONMENT"
    echo "  - Git Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
    echo "  - Docker Images Updated: ✅"
    echo "  - Database Migrated: ✅"
    echo "  - Health Checks: ✅"
    echo "  - Backup Created: ${BACKUP_NAME:-N/A}"
}

# Handle command line arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    rollback)
        if [[ -z "${2:-}" ]]; then
            error_exit "Backup name required for rollback"
        fi
        BACKUP_NAME="$2"
        rollback
        ;;
    health)
        health_check
        ;;
    backup)
        create_backup
        ;;
    *)
        echo "Usage: $0 [deploy|rollback <backup_name>|health|backup] [environment]"
        echo ""
        echo "Commands:"
        echo "  deploy              - Full deployment (default)"
        echo "  rollback <backup>   - Rollback to specified backup"
        echo "  health              - Run health checks only"
        echo "  backup              - Create backup only"
        echo ""
        echo "Environments: development, staging, production"
        exit 1
        ;;
esac
