# ---- stage 1: install production dependencies only ----
FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- stage 2: small runtime image, no build tools, non-root ----
FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914
LABEL org.opencontainers.image.source="https://github.com/saidevops32/shopmini" \
      org.opencontainers.image.title="auth-service" \
      org.opencontainers.image.licenses="MIT"
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps --chown=1000:1000 /app/node_modules ./node_modules
COPY --chown=1000:1000 package.json ./
COPY --chown=1000:1000 src ./src
USER 1000:1000
EXPOSE 3000
# exec form: node is PID 1 and receives SIGTERM directly (see shutdown() in server.js)
CMD ["node", "src/server.js"]
