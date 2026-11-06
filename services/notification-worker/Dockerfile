# ---- stage 1: install production dependencies only ----
FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- stage 2: runtime image, no package managers, non-root ----
FROM node:25-alpine@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4
LABEL org.opencontainers.image.source="https://github.com/saidevops32/shopmini" \
      org.opencontainers.image.title="notification-worker" \
      org.opencontainers.image.licenses="MIT"
# the service only needs the node binary: remove npm, npx, corepack and yarn
RUN rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx \
           /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps --chown=1000:1000 /app/node_modules ./node_modules
COPY --chown=1000:1000 package.json ./
COPY --chown=1000:1000 src ./src
USER 1000:1000
EXPOSE 3001
# exec form: node is PID 1 and receives SIGTERM directly (see shutdown() in worker.js)
CMD ["node", "src/worker.js"]
