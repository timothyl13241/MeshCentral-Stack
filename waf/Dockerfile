# Production-ready WAF: nginx + ModSecurity v3 + OWASP Core Rule Set
#
# Built on the official OWASP ModSecurity CRS nginx image (Alpine variant)
# for a minimal, auditable attack surface.  The base image installs:
#   - nginx (stable)
#   - ModSecurity v3 nginx connector
#   - OWASP CRS rules (loaded via /etc/modsecurity.d/setup.conf)
#
# Build:  docker compose build waf
# Run:    docker compose up -d
FROM owasp/modsecurity-crs:nginx-alpine

# ── Custom nginx reverse-proxy configuration ───────────────────────────────
# The OWASP CRS image uses the nginx template mechanism: *.conf.template files
# placed in /etc/nginx/templates/conf.d/ are rendered to /etc/nginx/conf.d/
# by envsubst at container startup.  nginx variables such as $host and
# $remote_addr are NOT environment variables in the container, so envsubst
# leaves them untouched — they are interpreted by nginx at runtime as normal.
COPY nginx.conf /etc/nginx/templates/conf.d/default.conf.template

# ── ModSecurity production settings ────────────────────────────────────────
# This file is loaded after the OWASP CRS defaults and overrides:
#   - SecRuleEngine mode (DetectionOnly → On to enable active blocking)
#   - Request / response body processing limits
#   - Audit log format and output path (used by CrowdSec for log analysis)
COPY modsecurity.conf /etc/modsecurity.d/modsecurity-override.conf
