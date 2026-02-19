#!/bin/sh
# CrowdSec Bouncer Setup Script for MeshCentral
# This runs as an init container to automatically configure the CrowdSec bouncer

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CROWDSEC_CONTAINER=${CROWDSEC_CONTAINER:-meshcentral-crowdsec}
BOUNCER_NAME=${CROWDSEC_BOUNCER_NAME:-meshcentral}
CROWDSEC_LAPI_URL=${CROWDSEC_LAPI_URL:-http://crowdsec:8080}
CONFIG_FILE=/meshcentral-data/config.json

echo -e "${GREEN}=== MeshCentral CrowdSec Bouncer Setup ===${NC}"

# Wait for CrowdSec to be ready (it should be due to depends_on, but double-check)
echo -e "${YELLOW}Verifying CrowdSec is ready...${NC}"
MAX_RETRIES=10
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    if docker exec "$CROWDSEC_CONTAINER" cscli version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ CrowdSec is ready${NC}"
        break
    fi
    RETRY=$((RETRY + 1))
    echo -e "${YELLOW}Waiting... ($RETRY/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY -eq $MAX_RETRIES ]; then
    echo -e "${RED}ERROR: CrowdSec is not responding${NC}"
    exit 1
fi

# Check if bouncer already exists
echo -e "${YELLOW}Checking for existing bouncer...${NC}"
if docker exec "$CROWDSEC_CONTAINER" cscli bouncers list -o json 2>/dev/null | grep -q "\"name\":\"$BOUNCER_NAME\""; then
    echo -e "${GREEN}✓ Bouncer '$BOUNCER_NAME' already exists${NC}"
    echo -e "${YELLOW}Skipping key generation (bouncer already registered)${NC}"
    echo -e "${YELLOW}If you need to regenerate the key, delete the bouncer first:${NC}"
    echo -e "  docker exec $CROWDSEC_CONTAINER cscli bouncers delete $BOUNCER_NAME"
else
    echo -e "${YELLOW}Creating new bouncer '$BOUNCER_NAME'...${NC}"
    API_KEY=$(docker exec "$CROWDSEC_CONTAINER" cscli bouncers add "$BOUNCER_NAME" -o raw 2>/dev/null)
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}ERROR: Failed to generate bouncer API key${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Bouncer created successfully${NC}"
    echo -e "${GREEN}API Key: ${API_KEY}${NC}"
    
    # Update config.json if it exists and has the crowdsec section
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}Updating config.json...${NC}"
        
        # Check if jq is available
        if command -v jq >/dev/null 2>&1; then
            # Create backup
            cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
            
            # Update the API key in the crowdsec section, preserving other settings
            # Use *= to merge instead of = to overwrite
            jq --arg url "$CROWDSEC_LAPI_URL" \
               --arg key "$API_KEY" \
               '.settings.crowdsec = (
                   .settings.crowdsec // {} | 
                   . * {
                       "url": $url,
                       "apiKey": $key,
                       "fallbackremediation": (.fallbackremediation // "bypass")
                   }
               )' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            
            if jq empty "${CONFIG_FILE}.tmp" 2>/dev/null; then
                mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}✓ Config updated successfully${NC}"
            else
                echo -e "${RED}ERROR: Generated invalid JSON, restoring backup${NC}"
                mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
            fi
        else
            echo -e "${YELLOW}⚠ jq not available - manual configuration required${NC}"
            echo ""
            echo "Add this to your $CONFIG_FILE under settings:"
            echo ""
            cat <<EOFCFG
"crowdsec": {
  "url": "$CROWDSEC_LAPI_URL",
  "apiKey": "$API_KEY",
  "fallbackremediation": "bypass"
}
EOFCFG
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠ Config file not found at $CONFIG_FILE${NC}"
        echo -e "${YELLOW}Manual configuration required${NC}"
        echo ""
        echo "Add this to your MeshCentral config.json under settings:"
        echo ""
        cat <<EOFCFG
"crowdsec": {
  "url": "$CROWDSEC_LAPI_URL",
  "apiKey": "$API_KEY",
  "fallbackremediation": "bypass"
}
EOFCFG
        echo ""
    fi
fi

echo -e "${GREEN}=== CrowdSec bouncer setup complete ===${NC}"
