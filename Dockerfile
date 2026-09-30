# ==========================================
# Stage 1: Build the React/Vite application
# ==========================================
FROM node:24-alpine AS builder

WORKDIR /app

# Install dependencies using the lock file
COPY package*.json ./
RUN npm ci

# Copy application source
COPY . .

# Create the production build
RUN npm run build


# ==========================================
# Stage 2: Production runtime
# ==========================================
FROM nginxinc/nginx-unprivileged:alpine AS runtime

# Copy only the production build artifacts
COPY --from=builder /app/dist /usr/share/nginx/html

# Replace the default server configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Application port
EXPOSE 8080

# Container health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/ || exit 1

# nginx-unprivileged already runs as a non-root user
CMD ["nginx", "-g", "daemon off;"]