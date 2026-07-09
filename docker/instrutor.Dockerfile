FROM node:22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache imagemagick
COPY instrutor/package*.json ./
RUN npm ci
COPY instrutor/ .
RUN mkdir -p public/icons && \
    convert public/favicon.ico -resize 192x192 public/icons/icon-192.png && \
    convert public/favicon.ico -resize 512x512 public/icons/icon-512.png
ARG NEXT_PUBLIC_BASE_PATH=/instrutor
ARG NEXT_PUBLIC_API_URL=
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_PUBLIC_BASE_PATH=$NEXT_PUBLIC_BASE_PATH
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nextjs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nextjs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
