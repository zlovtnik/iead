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
RUN luarocks install redis-lua || echo "Redis client installation failed - using memory fallback"

# Make scripts executable
RUN chmod +x start.sh

# Expose port
EXPOSE 8080

# Set entry point
CMD ["./start.sh"]
