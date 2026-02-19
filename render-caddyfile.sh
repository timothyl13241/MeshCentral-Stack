#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "⚠️  DEPRECATION NOTICE"
echo "=================================================="
echo ""
echo -e "${YELLOW}This script is no longer needed!${NC}"
echo ""
echo "The Caddyfile now uses Caddy's native environment"
echo "variable substitution at runtime."
echo ""
echo "You can now start the stack directly without running"
echo "this script first:"
echo ""
echo -e "${GREEN}  docker-compose up -d${NC}"
echo ""
echo "The Caddyfile will automatically use environment"
echo "variables from your .env file through docker-compose.yml"
echo ""
echo "For more information, see the updated README.md"
echo "=================================================="
echo ""
exit 0
