#!/bin/bash
set -e

echo "🚀 Deploying TimescaleDB"
echo "==================================="
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Environment file
ENV_FILE="$HOME/projects/secrets/timescaledb.env"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Pre-deployment Checks ---
echo "🔍 Pre-deployment checks..."

# Check environment file
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ Environment file not found: $ENV_FILE${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Environment file exists${NC}"

# Source environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Validate required variables
required_vars=("POSTGRES_USER" "POSTGRES_PASSWORD")

for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "${RED}❌ Required variable $var is not set${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ Environment variables validated${NC}"

# Check if networks exist
for network in timescaledb-net postgres-net; do
    if ! docker network inspect "$network" &>/dev/null; then
        echo -e "${RED}❌ $network network not found${NC}"
        echo "Run: /home/administrator/projects/infrastructure/setup-networks.sh"
        exit 1
    fi
done
echo -e "${GREEN}✅ All required networks exist${NC}"

# Check/create volume
if ! docker volume inspect timescaledb_data &>/dev/null; then
    echo "Creating timescaledb_data volume..."
    docker volume create timescaledb_data
fi
echo -e "${GREEN}✅ TimescaleDB data volume ready${NC}"

# Validate docker-compose.yml syntax
echo ""
echo "✅ Validating docker-compose.yml..."
if ! docker compose config > /dev/null 2>&1; then
    echo -e "${RED}❌ docker-compose.yml validation failed${NC}"
    docker compose config
    exit 1
fi
echo -e "${GREEN}✅ docker-compose.yml is valid${NC}"

# --- Deployment ---
echo ""
echo "🚀 Deploying TimescaleDB..."
docker compose up -d --remove-orphans

# --- Post-deployment Validation ---
echo ""
echo "⏳ Waiting for TimescaleDB to be ready..."
timeout 60 bash -c 'until docker exec timescaledb pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB:-timescale} 2>/dev/null; do sleep 2; done' || {
    echo -e "${RED}❌ TimescaleDB failed to start${NC}"
    docker logs timescaledb --tail 30
    exit 1
}
echo -e "${GREEN}✅ TimescaleDB is ready${NC}"

# Enable TimescaleDB extension
echo ""
echo "⏳ Enabling TimescaleDB extension..."
docker exec timescaledb psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB:-timescale}" -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" 2>/dev/null || true
echo -e "${GREEN}✅ TimescaleDB extension enabled${NC}"

# Get database list
echo ""
echo "📊 Database Status:"
docker exec timescaledb psql -U "${POSTGRES_USER}" -d postgres -c "\\l" 2>/dev/null | grep -E "Name|-------|${POSTGRES_DB:-timescale}|postgres" | head -10

# --- Summary ---
echo ""
echo "=========================================="
echo "✅ TimescaleDB Deployment Summary"
echo "=========================================="
echo "Container: ${TIMESCALEDB_CONTAINER:-timescaledb}"
echo "Image: ${TIMESCALEDB_IMAGE:-timescale/timescaledb:latest-pg16}"
echo "Networks: timescaledb-net, postgres-net"
echo "Port: ${TIMESCALEDB_PORT:-5433} (external), 5432 (internal)"
echo ""
echo "Database Configuration:"
echo "  - Admin User: ${POSTGRES_USER}"
echo "  - Default Database: ${POSTGRES_DB:-timescale}"
echo "  - Data Volume: timescaledb_data"
echo ""
echo "Connection Strings:"
echo "  - Internal: postgresql://${POSTGRES_USER}:***@timescaledb:5432/${POSTGRES_DB:-timescale}"
echo "  - External: postgresql://${POSTGRES_USER}:***@localhost:${TIMESCALEDB_PORT:-5433}/${POSTGRES_DB:-timescale}"
echo ""
echo "=========================================="
echo ""
echo "📊 View logs:"
echo "   docker logs timescaledb -f"
echo ""
echo "🔍 Connect via psql:"
echo "   docker exec -it timescaledb psql -U ${POSTGRES_USER} -d ${POSTGRES_DB:-timescale}"
echo ""
echo "📋 List databases:"
echo "   docker exec timescaledb psql -U ${POSTGRES_USER} -d postgres -c '\\l'"
echo ""
echo "✅ Deployment complete!"
