#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# File paths
ENV_FILE="${SCRIPT_DIR}/.env"
TEMPLATE_FILE="${SCRIPT_DIR}/caddy/Caddyfile.template"
OUTPUT_FILE="${SCRIPT_DIR}/caddy/Caddyfile"

echo "=================================================="
echo "Caddyfile Renderer"
echo "=================================================="
echo ""

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo -e "${YELLOW}Please copy .env.example to .env and configure it first:${NC}"
    echo "  cp .env.example .env"
    echo "  nano .env"
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Template file not found at $TEMPLATE_FILE${NC}"
    exit 1
fi

# Check if envsubst is available
if ! command -v envsubst &> /dev/null; then
    echo -e "${RED}Error: envsubst command not found${NC}"
    echo -e "${YELLOW}Please install gettext package:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install gettext-base"
    echo "  RHEL/CentOS:   sudo yum install gettext"
    echo "  macOS:         brew install gettext"
    exit 1
fi

echo "Loading environment variables from: $ENV_FILE"
# Export all variables from .env file
set -a
source "$ENV_FILE"
set +a

echo "Rendering Caddyfile from template..."
echo "  Template: $TEMPLATE_FILE"
echo "  Output:   $OUTPUT_FILE"

# Use envsubst to substitute only MESHCENTRAL_HOSTNAME variable
# This ensures that other {env.VARNAME} references remain unchanged
ENVSUBST_VARS='$MESHCENTRAL_HOSTNAME'
envsubst "$ENVSUBST_VARS" < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Caddyfile rendered successfully!${NC}"

echo ""
echo "=================================================="
echo "Next steps:"
echo "  1. Review the generated Caddyfile: cat $OUTPUT_FILE"
echo "  2. Start the stack: docker-compose up -d"
echo "=================================================="
