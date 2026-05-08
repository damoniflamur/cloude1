# ============================================================================
# STAGE 1: BUILDER - Compile and prepare dependencies
# ============================================================================
FROM node:20-alpine AS builder

# Set working directory for build stage
WORKDIR /app

# Copy package files (package.json and package-lock.json)
# These are copied first to leverage Docker layer caching
COPY package*.json ./

# Install production dependencies only using npm ci for deterministic builds
# --only=production ensures dev dependencies are excluded
RUN npm ci --only=production

# ============================================================================
# STAGE 2: RUNTIME - Final lightweight production image
# ============================================================================
FROM node:20-alpine

# Set metadata labels for image identification and tracking
LABEL maintainer="your-email@example.com" \
      description="Production Node.js application" \
      version="1.0.0"

# Set working directory for runtime
WORKDIR /app

# Copy only the necessary built artifacts from builder stage
# This reduces final image size by excluding build tools and node_modules from source
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY . .

# Create a non-root user group named 'appgroup' for security
# Using -S flag creates a system group without login shell
RUN addgroup -S appgroup

# Create a non-root user named 'appuser' assigned to 'appgroup'
# -S flag creates a system user without login shell for security best practices
RUN adduser -S appuser -G appgroup

# Set ownership of application files to the non-root user
# This ensures the app runs with minimal required permissions
RUN chown -R appuser:appgroup /app

# Switch to non-root user for all subsequent commands and runtime
# Running as root in containers is a security risk; this prevents privilege escalation
USER appuser

# Expose port 3000 (EXPOSE is informational; actual port binding done with -p in docker run)
EXPOSE 3000

# Configure health check to monitor application availability
# --interval=30s: Check every 30 seconds
# --timeout=5s: Kill check command if it exceeds 5 seconds
# --start-period=10s: Grace period before first health check (app startup time)
# --retries=3: Mark container unhealthy after 3 failed checks
# Uses wget to probe the /health endpoint (replace with your actual health check)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Set environment to production to enable Node.js optimizations
ENV NODE_ENV=production

# Default command to start the application
# Using exec form ensures proper signal handling for graceful shutdown
CMD ["node", "server.js"]
