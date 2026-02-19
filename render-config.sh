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
TEMPLATE_FILE="${SCRIPT_DIR}/meshcentral-data/config.json.template"
OUTPUT_FILE="${SCRIPT_DIR}/meshcentral-data/config.json"

echo "=================================================="
echo "MeshCentral Configuration Renderer"
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

# Set default values for optional variables if not set
export CROWDSEC_LAPI_URL="${CROWDSEC_LAPI_URL:-http://crowdsec:8080}"

echo "Rendering configuration from template..."
echo "  Template: $TEMPLATE_FILE"
echo "  Output:   $OUTPUT_FILE"

# Use envsubst to substitute variables
# We need to explicitly list the variables to avoid substituting $schema
ENVSUBST_VARS='$MESHCENTRAL_HOSTNAME $MESHCENTRAL_DB_USER $MESHCENTRAL_DB_PASSWORD $MONGO_DATABASE $CROWDSEC_LAPI_URL'
envsubst "$ENVSUBST_VARS" < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

# Verify the output is valid JSON
if command -v jq &> /dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Configuration file rendered successfully!${NC}"
        echo -e "${GREEN}✓ JSON validation passed${NC}"
    else
        echo -e "${RED}Error: Generated configuration is not valid JSON${NC}"
        echo -e "${YELLOW}Please check your environment variables in .env${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Configuration file rendered successfully!${NC}"
    echo -e "${YELLOW}Note: Install 'jq' for JSON validation${NC}"
fi

echo ""
echo "=================================================="
echo "Next steps:"
echo "  1. Review the generated config: cat $OUTPUT_FILE"
echo "  2. Start the stack: docker-compose up -d"
echo "=================================================="
