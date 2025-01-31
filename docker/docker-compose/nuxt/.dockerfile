# Base image for Node
FROM node:21-slim AS base

# Builder stage
FROM base AS builder

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy all app files
COPY . .

# Set environment variables specific to Nuxt
ENV NODE_ENV=production
ARG TABLE_NAME
ARG RECAPTCHA_SECRET
ARG NUXT_PUBLIC_RECAPTCHA_SITE_KEY
ARG NUXT_PUBLIC_PLANNER_ID
ARG MAILING_LIST_ENDPOINT
ARG MAILING_LIST_PASSWORD

# Build the application
RUN npm run build

# Runner stage
FROM base AS runner

WORKDIR /app

# Set environment variables for production
ENV NODE_ENV=production

# Create a user and group for security
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nuxtjs

# Copy the built files and static assets to the runner stage
COPY --from=builder /app/.output /app/.output
# COPY --from=builder /app/static /app/static
COPY --from=builder /app/public /app/public

# Set permissions for the copied directories
RUN chown -R nuxtjs:nodejs /app

# Switch to the created user
USER nuxtjs

# Expose port 3000
EXPOSE 3000

# Set the default port
ENV PORT=3000

# Run Nuxt server
CMD ["node", ".output/server/index.mjs"]
