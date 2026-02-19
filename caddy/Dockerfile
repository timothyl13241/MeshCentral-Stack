# Build Caddy with Cloudflare DNS module using Go >= 1.23
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git ca-certificates && \
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

WORKDIR /build
RUN xcaddy build --with github.com/caddy-dns/cloudflare

# Runtime image
FROM caddy:2-alpine
COPY --from=builder /build/caddy /usr/bin/caddy
