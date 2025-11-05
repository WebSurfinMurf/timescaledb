# TimescaleDB Time-Series Database

## Overview
TimescaleDB time-series database built on PostgreSQL 16, providing automatic partitioning, compression, and specialized time-series functions.

## Services
- **timescaledb**: TimescaleDB database server (PostgreSQL 16 + TimescaleDB extension)

## Deployment
```bash
cd /home/administrator/projects/timescaledb
./deploy.sh
```

## Access
- **Internal**: postgresql://timescaledb:5432
- **External**: postgresql://localhost:5433

## Configuration
- **Secrets**: `$HOME/projects/secrets/timescaledb.env`
- **Networks**: timescaledb-net, postgres-net
- **Volumes**: timescaledb_data
- **Port**: 5433 (external), 5432 (internal)

## Database Configuration
- **Admin User**: tsdbadmin
- **Default Database**: timescale
- **TimescaleDB Extension**: Enabled automatically
- **Tuning**: Auto-configured based on TS_TUNE_MEMORY and TS_TUNE_NUM_CPUS

## Time-Series Features
- **Hypertables**: Automatic partitioning by time
- **Compression**: Columnar compression for older data
- **Continuous Aggregates**: Materialized views for common queries
- **Retention Policies**: Automatic data expiration
- **Time Bucketing**: Time-series specific queries

## Common Commands
```bash
# View logs
docker logs timescaledb -f

# Connect via psql
docker exec -it timescaledb psql -U tsdbadmin -d timescale

# List databases
docker exec timescaledb psql -U tsdbadmin -d postgres -c '\l'

# Show hypertables
docker exec timescaledb psql -U tsdbadmin -d timescale -c "SELECT * FROM timescaledb_information.hypertables;"

# Check container status
docker ps | grep timescaledb
```

## Creating Hypertables
```sql
-- Create regular table
CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  device_id INTEGER,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION
);

-- Convert to hypertable
SELECT create_hypertable('metrics', 'time');
```

## Compression
```sql
-- Enable compression
ALTER TABLE metrics SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id'
);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('metrics', INTERVAL '7 days');
```

## Continuous Aggregates
```sql
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', time) AS bucket,
  device_id,
  AVG(temperature) as avg_temp
FROM metrics
GROUP BY bucket, device_id;
```

## Integrations
- **Grafana**: Configured as PostgreSQL data source with TimescaleDB support
- **pgAdmin**: Accessible via postgres-net for database management
- **MCP Server**: Provides TimescaleDB-specific operations for Claude Code (Phase 3)

## Networks
- **timescaledb-net**: Database access (internal only)
- **postgres-net**: Management access (pgAdmin)

## Volumes
- **timescaledb_data**: Database files and WAL logs

## Security
- Password authentication required
- Database isolated on timescaledb-net
- Credentials stored in secrets file

## Health Checks
- PostgreSQL: `pg_isready -U tsdbadmin -d timescale`
- Container includes automatic health monitoring

## Performance Tuning
Environment variables control auto-tuning:
- TS_TUNE_MEMORY: Memory allocation
- TS_TUNE_NUM_CPUS: CPU allocation
- TS_TUNE_MAX_CONNS: Maximum connections
- TS_TUNE_MAX_BG_WORKERS: Background workers

---
*Standardized: 2025-09-30*
*Part of Phase 2: Database Layer*
