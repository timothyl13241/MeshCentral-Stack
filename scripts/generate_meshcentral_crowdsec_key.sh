#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CROWDSEC_CONTAINER=${CROWDSEC_CONTAINER:-meshcentral-crowdsec}
CROWDSEC_LAPI_URL=${CROWDSEC_LAPI_URL:-http://crowdsec:8080}
BOUNCER_NAME=${CROWDSEC_BOUNCER_NAME:-meshcentral}
CONFIG_FILE=${MESHCENTRAL_CONFIG_FILE:-/opt/meshcentral/meshcentral-data/config.json}
MAX_RETRIES=${CROWDSEC_MAX_RETRIES:-30}
RETRY_DELAY=${CROWDSEC_RETRY_DELAY:-2}

echo -e "${GREEN}=== MeshCentral CrowdSec Integration Setup ===${NC}"

wait_for_crowdsec() {
    echo -e "${YELLOW}Waiting for CrowdSec LAPI to become available...${NC}"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if docker exec "$CROWDSEC_CONTAINER" cscli version >/dev/null 2>&1; then
            echo -e "${GREEN}CrowdSec LAPI is ready!${NC}"
            return 0
        fi
        
        retries=$((retries + 1))
        echo -e "${YELLOW}Attempt $retries/$MAX_RETRIES: Waiting for CrowdSec...${NC}"
        sleep $RETRY_DELAY
    done
    
    echo -e "${RED}ERROR: CrowdSec LAPI did not become available${NC}"
    return 1
}

check_bouncer_exists() {
    if docker exec "$CROWDSEC_CONTAINER" cscli bouncers list -o json 2>/dev/null | grep -q "\"name\":\"$BOUNCER_NAME\""; then
        echo -e "${GREEN}Bouncer '$BOUNCER_NAME' already exists${NC}"
        return 0
    else
        return 1
    fi
}

generate_or_get_bouncer_key() {
    local api_key=""
    
    if check_bouncer_exists; then
        echo -e "${YELLOW}Reusing existing bouncer${NC}"
        return 0
    else
        echo -e "${YELLOW}Generating new bouncer API key...${NC}"
        api_key=$(docker exec "$CROWDSEC_CONTAINER" cscli bouncers add "$BOUNCER_NAME" -o raw 2>/dev/null || echo "")
        
        if [ -z "$api_key" ]; then
            echo -e "${RED}ERROR: Failed to generate bouncer API key${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Successfully generated bouncer API key${NC}"
        echo "$api_key"
        return 0
    fi
}

update_config() {
    local api_key=$1
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}ERROR: Config file not found at $CONFIG_FILE${NC}"
        return 1
    fi
    
    if grep -q '"crowdsec"' "$CONFIG_FILE"; then
        echo -e "${YELLOW}CrowdSec configuration already exists${NC}"
        
        if grep -q '"apiKey".*"[a-zA-Z0-9]\{30,\}"' "$CONFIG_FILE"; then
            echo -e "${GREEN}Valid API key already configured${NC}"
            return 0
        fi
    fi
    
    if [ -n "$api_key" ]; then
        echo -e "${YELLOW}Updating config.json with CrowdSec settings...${NC}"
        
        if command -v jq >/dev/null 2>&1; then
            cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
            
            jq --arg url "$CROWDSEC_LAPI_URL" \
               --arg key "$api_key" \
               '.settings.crowdsec = {
                   "url": $url,
                   "apiKey": $key,
                   "fallbackremediation": "bypass"
               }' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
            
            if jq empty "${CONFIG_FILE}.tmp" 2>/dev/null; then
                mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                echo -e "${GREEN}Successfully updated config.json${NC}"
            else
                echo -e "${RED}ERROR: Invalid JSON, restoring backup${NC}"
                mv "${CONFIG_FILE}.backup" "$CONFIG_FILE"
                return 1
            fi
        else
            echo -e "${YELLOW}jq not available, API key must be configured manually${NC}"
            echo "Add this to your config.json settings:"
            cat <<EOFCFG
"crowdsec": {
  "url": "$CROWDSEC_LAPI_URL",
  "apiKey": "$api_key",
  "fallbackremediation": "bypass"
}
EOFCFG
        fi
    else
        echo -e "${YELLOW}No new API key to configure${NC}"
    fi
    
    return 0
}

main() {
    echo -e "${YELLOW}Starting CrowdSec integration setup...${NC}"
    
    if ! wait_for_crowdsec; then
        echo -e "${RED}Failed to connect to CrowdSec${NC}"
        exit 1
    fi
    
    api_key=$(generate_or_get_bouncer_key)
    
    if [ -n "$api_key" ]; then
        update_config "$api_key"
    else
        echo -e "${GREEN}Bouncer exists, checking config...${NC}"
        if ! grep -q '"crowdsec"' "$CONFIG_FILE"; then
            echo -e "${RED}ERROR: Bouncer exists but config has no CrowdSec section${NC}"
            exit 1
        else
            echo -e "${GREEN}CrowdSec configuration found${NC}"
        fi
    fi
    
    echo -e "${GREEN}=== CrowdSec integration setup complete ===${NC}"
}

main

echo -e "${GREEN}Starting MeshCentral...${NC}"
exec node node_modules/meshcentral "$@"
