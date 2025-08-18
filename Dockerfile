# Dockerfile for Lua application

# --- Builder Stage ---
FROM alpine:latest AS builder

# Install build dependencies, including libraries required by Lua modules
RUN apk add --no-cache build-base cmake git lua5.1 lua5.1-dev luarocks5.1 postgresql-dev openssl-dev

# Set working directory
WORKDIR /app

# Copy rockspec and install dependencies
COPY *.rockspec ./
# Install dependencies with explicit PostgreSQL directory for Alpine Linux
RUN luarocks-5.1 install --tree lua_modules --only-deps church-management-1.0-1.rockspec PGSQL_DIR=/usr PGSQL_INCDIR=/usr/include/postgresql

# Copy the rest of the application source
COPY . .

# --- Final Stage ---
FROM alpine:latest

# Install Lua and runtime dependencies
RUN apk add --no-cache lua5.1 postgresql-libs

# Set working directory
WORKDIR /app

# Copy installed dependencies from builder stage
COPY --from=builder /app/lua_modules/lib/lua/5.1 /usr/lib/lua/5.1
COPY --from=builder /app/lua_modules/share/lua/5.1 /usr/share/lua/5.1

# Copy application code from builder stage
COPY --from=builder /app .

# Expose port
EXPOSE 8080

# Set the entrypoint
CMD ["lua5.1", "app.lua"]
