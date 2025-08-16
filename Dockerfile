# Multi-stage Docker build for Church Management System
# Stage 1: Build frontend
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend
COPY public/package*.json ./
RUN npm ci --only=production

COPY public/ ./
RUN npm run build

# Stage 2: Build backend
FROM debian:bullseye-slim AS backend-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    sqlite3 \
    libsqlite3-dev \
    build-essential \
    curl \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Lua dependencies
RUN luarocks install luasql-sqlite3
RUN luarocks install lua-cjson
RUN luarocks install luasocket
RUN luarocks install redis-lua || echo "WARNING: redis-lua installation failed"
RUN luarocks install luacheck
RUN luarocks install busted

# Stage 3: Production runtime
FROM openresty/openresty:1.21.4.1-0-bullseye AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    lua5.4 \
    sqlite3 \
    libsqlite3-dev \
    curl \
    bash \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy Lua rocks from builder
COPY --from=backend-builder /usr/local/lib/lua/5.1/luasql /usr/local/lib/lua/5.1/luasql
COPY --from=backend-builder /usr/local/lib/lua/5.1/cjson.so /usr/local/lib/lua/5.1/cjson.so
COPY --from=backend-builder /usr/local/lib/lua/5.1/socket /usr/local/lib/lua/5.1/socket
COPY --from=backend-builder /usr/local/lib/lua/5.1/bcrypt.so /usr/local/lib/lua/5.1/bcrypt.so
COPY --from=backend-builder /usr/local/share/lua/5.1/luasql /usr/local/share/lua/5.1/luasql
COPY --from=backend-builder /usr/local/share/lua/5.1/cjson /usr/local/share/lua/5.1/cjson
COPY --from=backend-builder /usr/local/share/lua/5.1/socket /usr/local/share/lua/5.1/socket
COPY --from=backend-builder /usr/local/share/lua/5.1/bcrypt /usr/local/share/lua/5.1/bcrypt
COPY --from=backend-builder /usr/local/bin/church-management /usr/local/bin/church-management

# Create app user for security


WORKDIR /app

# Copy application files
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY config/ ./config/
COPY *.lua ./
COPY *.sh ./
COPY church_management.db ./

# Copy built frontend
COPY --from=frontend-builder /app/frontend/dist ./public/dist/
COPY --from=frontend-builder /app/frontend/static ./public/static/

# Make scripts executable
RUN chmod +x scripts/*.sh
RUN chmod +x *.sh
RUN chmod +x /app/bin/healthcheck.sh

# Create necessary directories
RUN mkdir -p /app/logs /app/tmp /app/uploads
RUN chown -R appuser:appuser /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set entry point
ENTRYPOINT ["./scripts/start.sh"]
CMD ["production"]
