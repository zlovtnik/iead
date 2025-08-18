# Dockerfile for Lua application

# --- Builder Stage ---
FROM alpine:latest AS builder

# Install build dependencies, including libraries required by Lua modules
RUN apk add --no-cache build-base cmake git lua5.1 lua5.1-dev luarocks5.1 postgresql-dev openssl-dev

# Set working directory
WORKDIR /app

# Copy rockspec and install dependencies
COPY *.rockspec ./
# The --tree option specifies a directory for dependencies
# The --only-deps flag ensures only dependencies are installed, not the app itself
RUN luarocks-5.1 install --tree lua_modules --only-deps church-management-1.0-1.rockspec

# Copy the rest of the application source
COPY . .

# --- Final Stage ---
FROM alpine:latest

# Install Lua
RUN apk add --no-cache lua5.1

# Install runtime dependencies in the final stage
RUN apk add --no-cache postgresql-libs

# Set working directory
WORKDIR /app

# Copy installed dependencies from builder stage
# Lua 5.1 paths are used here. Adjust if your project uses a different version.
COPY --from=builder /app/lua_modules/lib/lua/5.1 /usr/lib/lua/5.1
COPY --from=builder /app/lua_modules/share/lua/5.1 /usr/share/lua/5.1


# Copy application code from builder stage
COPY --from=builder /app .

# Expose port
EXPOSE 8080

# Set the entrypoint
CMD ["lua5.1", "app.lua"]
