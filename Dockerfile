
FROM node:22-alpine AS dependencies

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev && npm cache clean --force


FROM node:22-alpine AS production

# Wave 1: digest pinning is deferred until a Docker host can resolve + verify digests
# (registry API unreachable from here); see docs/security/wave1-baseline.md for commands.

ARG GIT_SHA=unknown

LABEL org.opencontainers.image.title="chess-backend" \
      org.opencontainers.image.description="Chess backend: Express + Socket.io (single replica, ADR-002)" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/MomenLotfy/Chess-Backend"

# Production configuration
ENV NODE_ENV=production
ENV PORT=8080

# Create non-root application user
RUN addgroup -S -g 1001 appgroup && \
    adduser -S -D -H -u 1001 -G appgroup appuser

WORKDIR /app

# Install production dependencies
COPY --from=dependencies --chown=1001:1001 /app/node_modules ./node_modules

COPY --chown=1001:1001 package.json package-lock.json ./

# Copy backend source code
COPY --chown=1001:1001 src ./src

# Prepare uploads directory
RUN mkdir -p /app/uploads/avatars && \
    chown -R 1001:1001 /app/uploads && \
    chmod 0750 /app/uploads /app/uploads/avatars

# Run as non-root user
USER 1001:1001

# Application port exposed to Ghaymah Cloud
EXPOSE 8080

# Backend health check
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=5 \
    CMD wget -qO- http://127.0.0.1:8080/liveness >/dev/null || exit 1

# Start application
CMD ["node", "src/server.js"]
