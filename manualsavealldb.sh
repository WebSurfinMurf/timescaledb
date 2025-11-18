#!/bin/bash
################################################################################
# TimescaleDB Manual Checkpoint/Save All Databases
################################################################################
# Location: /home/administrator/projects/timescaledb/manualsavealldb.sh
#
# Purpose: Forces TimescaleDB (PostgreSQL-based) to flush all pending writes
# This ensures database consistency during backup operations.
#
# Called by: backup scripts before creating tar archives
################################################################################

set -e

echo "=== TimescaleDB: Forcing checkpoint to save all data to disk ==="

# Get the admin username from timescaledb container
POSTGRES_USER=$(docker exec timescaledb env | grep POSTGRES_USER | cut -d= -f2)

if [ -z "$POSTGRES_USER" ]; then
    echo "ERROR: Could not determine TimescaleDB admin user"
    exit 1
fi

echo "Using PostgreSQL user: $POSTGRES_USER"

# Run CHECKPOINT command to flush all dirty buffers to disk
echo "Running CHECKPOINT command..."
docker exec timescaledb psql -U "$POSTGRES_USER" -d postgres -c "CHECKPOINT;" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ TimescaleDB checkpoint completed successfully"
    echo "  All dirty buffers have been written to disk"
    echo "  All hypertables are in consistent state for backup"
else
    echo "✗ TimescaleDB checkpoint failed"
    exit 1
fi

echo ""
echo "=== TimescaleDB save operation complete ==="
