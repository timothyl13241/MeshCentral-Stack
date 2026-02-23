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

# Check if python for percent-encoding is available
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}Error: python3 is required for percent-encoding${NC}"
    echo -e "${YELLOW}Please install python3 package:${NC}"
    echo "  Ubuntu/Debian: sudo apt-get install python3"
    echo "  RHEL/CentOS:   sudo yum install python3"
    exit 1
fi

echo "Loading environment variables from: $ENV_FILE"
# Export all variables from .env file
set -a
source "$ENV_FILE"
set +a

# --- Percent-encode function using python3 ---
percent_encode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

# Encode Mongo credentials
export MESHCENTRAL_DB_USER_ENC=$(percent_encode "$MESHCENTRAL_DB_USER")
export MESHCENTRAL_DB_PASSWORD_ENC=$(percent_encode "$MESHCENTRAL_DB_PASSWORD")

# Set default values for optional variables if not set
export CROWDSEC_LAPI_URL="${CROWDSEC_LAPI_URL:-http://crowdsec:8080}"

echo "Rendering configuration from template..."
echo "  Template: $TEMPLATE_FILE"
echo "  Output:   $OUTPUT_FILE"

# Use envsubst to substitute variables
# Be sure to use the _ENC variables in your template for mongo
ENVSUBST_VARS='$MESHCENTRAL_HOSTNAME $MESHCENTRAL_DB_USER_ENC $MESHCENTRAL_DB_PASSWORD_ENC $MONGO_DATABASE $CROWDSEC_LAPI_URL'
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

# ------------------------------------------------------------------
# Traefik dynamic middleware config
# ------------------------------------------------------------------
TRAEFIK_EXAMPLE="${SCRIPT_DIR}/traefik/dynamic/middlewares.yml.example"
TRAEFIK_OUTPUT="${SCRIPT_DIR}/traefik/dynamic/middlewares.yml"

if [ -f "$TRAEFIK_EXAMPLE" ]; then
    # Substitute TRAEFIK_CROWDSEC_BOUNCER_KEY (may be empty on first setup)
    export TRAEFIK_CROWDSEC_BOUNCER_KEY="${TRAEFIK_CROWDSEC_BOUNCER_KEY:-}"

    if [ -f "$TRAEFIK_OUTPUT" ] && [ -z "${TRAEFIK_CROWDSEC_BOUNCER_KEY}" ]; then
        # Avoid overwriting a key that may have been injected by the crowdsec-init container
        echo -e "${GREEN}✓ Traefik middleware config already exists (skipping re-render)${NC}"
        echo -e "${YELLOW}  Set TRAEFIK_CROWDSEC_BOUNCER_KEY in .env and re-run to regenerate.${NC}"
    else
        envsubst '$TRAEFIK_CROWDSEC_BOUNCER_KEY' < "$TRAEFIK_EXAMPLE" > "$TRAEFIK_OUTPUT"
        echo -e "${GREEN}✓ Traefik middleware config rendered: $TRAEFIK_OUTPUT${NC}"
        if [ -z "${TRAEFIK_CROWDSEC_BOUNCER_KEY}" ]; then
            echo -e "${YELLOW}  TRAEFIK_CROWDSEC_BOUNCER_KEY is empty – run the crowdsec-init profile to populate it.${NC}"
        fi
    fi
fi

echo ""
echo "=================================================="
echo "Next steps:"
echo "  1. Review the generated config: cat $OUTPUT_FILE"
echo "  2. Start the stack: docker-compose up -d"
echo "=================================================="
