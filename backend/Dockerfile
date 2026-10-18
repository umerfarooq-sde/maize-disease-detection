# syntax=docker/dockerfile:1.7
FROM node:24.22.0-bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm ci
COPY backend/ ./
RUN DATABASE_URL=postgresql://localhost/build npm run db:generate && npm run build

FROM build AS migration
USER node
ENTRYPOINT ["node_modules/.bin/prisma"]
CMD ["migrate", "deploy"]

FROM build AS production-dependencies
RUN npm prune --omit=dev

FROM node:24.22.0-bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates openssl && rm -rf /var/lib/apt/lists/*
ENV NODE_ENV=production HOST=0.0.0.0 PORT=3000
WORKDIR /app/backend
COPY --from=production-dependencies --chown=node:node /app/backend/node_modules ./node_modules
COPY --from=build --chown=node:node /app/backend/dist ./dist
COPY --from=build --chown=node:node /app/backend/package.json ./package.json
RUN mkdir /logs && chown node:node /logs
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=20s --start-period=30s --retries=3 CMD ["node", "dist/cli/readiness.js"]
CMD ["node", "dist/server.js"]
