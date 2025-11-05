#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== TimescaleDB Health Check ===${NC}"
echo ""

# Load environment
if [ -f $HOME/projects/secrets/timescaledb.env ]; then
    export $(grep -v '^#' $HOME/projects/secrets/timescaledb.env | xargs)
fi

# Check container status
echo -e "${YELLOW}Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|timescaledb" || echo "Container not running"
echo ""

# Check internal connectivity
echo -e "${YELLOW}Internal Database Check:${NC}"
if docker exec timescaledb pg_isready -U tsdbadmin -d timescale &>/dev/null; then
    echo -e "${GREEN}✓ Database is ready${NC}"
    
    # Get version info
    echo -e "${YELLOW}Database Version:${NC}"
    docker exec timescaledb psql -U tsdbadmin -d timescale -t -c "SELECT version();" | head -1
    
    echo -e "${YELLOW}TimescaleDB Version:${NC}"
    docker exec timescaledb psql -U tsdbadmin -d timescale -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
    
    # Check hypertables
    echo -e "${YELLOW}Hypertables:${NC}"
    docker exec timescaledb psql -U tsdbadmin -d timescale -c "\dt+ sensor_data"
    
    # Check database size
    echo -e "${YELLOW}Database Size:${NC}"
    docker exec timescaledb psql -U tsdbadmin -d timescale -t -c "SELECT pg_size_pretty(pg_database_size('timescale'));"
    
else
    echo -e "${RED}✗ Database is not ready${NC}"
fi

echo ""
echo -e "${YELLOW}Network Connectivity:${NC}"
docker network inspect observability-net --format '{{range .Containers}}{{if eq .Name "timescaledb"}}✓ Connected to observability-net{{end}}{{end}}'
docker network inspect traefik-proxy --format '{{range .Containers}}{{if eq .Name "timescaledb"}}✓ Connected to traefik-proxy{{end}}{{end}}'

echo ""
echo -e "${BLUE}Connection Information:${NC}"
echo "Internal: psql -h timescaledb -p 5432 -U tsdbadmin -d timescale"
echo "External: psql -h linuxserver.lan -p 5433 -U tsdbadmin -d timescale"
echo ""
echo -e "${YELLOW}Note:${NC} Use password from $HOME/projects/secrets/timescaledb.env"