# TimescaleDB Deployment

> **For overall environment context, see: `/home/administrator/projects/AINotes/SYSTEM-OVERVIEW.md`**  
> **Network details: `/home/administrator/projects/AINotes/network.md`**  
> **Security configuration: `/home/administrator/projects/AINotes/security.md`**

## Overview
TimescaleDB is a time-series database built on PostgreSQL, providing automatic partitioning, compression, and specialized time-series functions while maintaining full SQL compatibility. Running as a separate instance from the main PostgreSQL server on port 5433.

## Current State (2025-09-05)
- **Status**: ✅ Fully operational (2+ days uptime, healthy)
- **Version**: TimescaleDB 2.22.0 on PostgreSQL 16.10
- **Port**: 5433 (external), 5432 (internal Docker)
- **Database**: 1 hypertable (sensor_data), 1 chunk, ~9.4MB size
- **MCP Server**: Running (stdio-based for Claude Code)
- **Integrations**: Grafana ✅, pgAdmin ✅, MCP ✅

## Architecture
```
TimescaleDB Container (Port 5433)
         ↓
    PostgreSQL 16.10 + TimescaleDB Extension 2.22.0
         ↓
    Networks: observability-net, postgres-net, traefik-net
         ↓
    Integrations:
    ├── Grafana (visualization) - Data source configured
    ├── pgAdmin (management) - Server registered
    ├── MCP Server (Claude Code) - 10 tools available
    └── Loki/Promtail (logging) - Container logs collected
```

## Deployment Strategy

### Phase 1: Core Deployment ✅
- Deploy TimescaleDB as separate container (not reusing existing PostgreSQL)
  - Reason: TimescaleDB requires specific PostgreSQL configurations and extensions
  - Better isolation for time-series workloads
  - Avoid impacting existing PostgreSQL services
- Configure automatic tuning based on container resources
- Set up proper data persistence
- Configure logging to Loki

### Phase 2: Integration ✅ 
- [x] Configure as Grafana data source (completed 2025-09-03)
- [x] Add to pgAdmin for management (completed 2025-09-03)
- [ ] Set up automated backups (future enhancement)

### Phase 3: MCP Server ✅
- [x] Create MCP server for TimescaleDB operations (completed 2025-09-03)
- [x] Enable time-series specific queries
- [x] Provide hypertable management
- [x] Available tools: tsdb_query, tsdb_execute, tsdb_create_hypertable, etc.

## Key Features Configured

### 1. Time-Series Optimization
- Automatic hypertable creation
- Compression policies
- Retention policies
- Continuous aggregates

### 2. Performance Tuning
- Memory optimization via TS_TUNE_MEMORY
- CPU allocation via TS_TUNE_NUM_CPUS
- Background worker configuration
- Connection pooling

### 3. Data Management
- Persistent volume for data
- Automated backups
- Point-in-time recovery capability

## Access Configuration

### Database Connection
- **Host**: `timescaledb` (internal Docker) / `linuxserver.lan` (external)
- **Port**: 5432 (internal Docker) / 5433 (external host)
- **Database**: `timescale`
- **Username**: `tsdbadmin`
- **Password**: Stored in `$HOME/projects/secrets/timescaledb.env`
- **Authentication**: MD5 (changed from SCRAM-SHA-256 for better client compatibility)

### Why No Keycloak SSO?
- TimescaleDB is a database server, not a web application
- Authentication happens at database protocol level (PostgreSQL protocol)
- Keycloak OAuth2 is for web-based authentication
- Database clients (pgAdmin, Grafana, applications) use database credentials

## Network Configuration
- **observability-net**: Primary network for Grafana/monitoring integration
- **postgres-net**: Enables pgAdmin management access
- **traefik-net**: Available for future web UI tools (not currently used)
- **Port Mapping**: 5433:5432 (avoids conflict with main PostgreSQL on 5432)
- **Internal Hostname**: `timescaledb` (Docker DNS)

## Logging Configuration
- Container logs sent to Loki via Docker logging driver
- Query logs and slow query logs enabled
- Performance metrics exposed for monitoring

## Deployment Scripts

### Initial Deployment
```bash
cd /home/administrator/projects/timescaledb
./deploy.sh
```

### Health Check
```bash
./check-health.sh
```

### Backup
```bash
./backup.sh
```

## Common Operations

### Connect to Database
```bash
# External connection
PGPASSWORD='TimescaleSecure2025' psql -h localhost -p 5433 -U tsdbadmin -d timescale

# Via Docker exec
docker exec -it timescaledb psql -U tsdbadmin -d timescale
```

### Create Hypertable
```sql
CREATE TABLE metrics (
  time TIMESTAMPTZ NOT NULL,
  device_id INTEGER,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION
);

SELECT create_hypertable('metrics', 'time');
```

### Enable Compression
```sql
ALTER TABLE metrics SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'device_id'
);

SELECT add_compression_policy('metrics', INTERVAL '7 days');
```

### Create Continuous Aggregate
```sql
CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT 
  time_bucket('1 hour', time) AS bucket,
  device_id,
  AVG(temperature) as avg_temp,
  AVG(humidity) as avg_humidity
FROM metrics
GROUP BY bucket, device_id;
```

## Monitoring Queries

### Database Size
```sql
SELECT hypertable_size('metrics');
```

### Compression Stats
```sql
SELECT * FROM timescaledb_information.compression_stats;
```

### Chunk Information
```sql
SELECT * FROM timescaledb_information.chunks 
WHERE hypertable_name = 'metrics';
```

## pgAdmin Configuration (Completed 2025-09-03)

### Connection Settings in pgAdmin
1. **Register New Server** → Right-click "Servers" → Register → Server
2. **General Tab**:
   - Name: `TimescaleDB`
   - Server group: `Servers`
3. **Connection Tab**:
   - Host: `timescaledb` (Docker hostname)
   - Port: `5432` (internal port)
   - Maintenance database: `timescale`
   - Username: `tsdbadmin`
   - Password: `TimescaleSecure2025`
   - Save password: ✓
4. **SSL Tab**: Set to `Prefer` or `Disable`
5. Leave Kerberos, Role, and Service fields empty

### Authentication Fix Applied
- Changed from SCRAM-SHA-256 to MD5 in pg_hba.conf
- This resolved pgAdmin connection issues
- MD5 provides better compatibility with various PostgreSQL clients

## Troubleshooting

### Container Won't Start
```bash
docker logs timescaledb --tail 50
```

### Connection Issues
```bash
docker exec timescaledb pg_isready
```

### Performance Issues
```bash
docker exec timescaledb psql -U tsdbadmin -d timescale -c "SHOW shared_buffers;"
docker exec timescaledb psql -U tsdbadmin -d timescale -c "SHOW work_mem;"
```

## Integration Status
- [x] Grafana data source configuration - Completed 2025-09-03
- [x] pgAdmin server registration - Connected successfully
- [x] MCP server deployment - Running stdio-based (not containerized)
- [x] Loki/Promtail logging - Container logs collected
- [ ] Sample dashboards creation (optional future enhancement)
- [ ] Automated backup configuration
- [ ] Retention policy setup
- [ ] Compression policy for older data

## Security Notes
- Database credentials stored in environment file
- Network isolation via Docker networks
- SSL/TLS for external connections (future)
- Regular security updates via container rebuilds

## Grafana Configuration (Completed 2025-09-03)

### Data Source Settings
1. **Type**: PostgreSQL
2. **Connection**:
   - Host: `timescaledb:5432`
   - Database: `timescale`
   - User: `tsdbadmin`
   - Password: `TimescaleSecure2025`
   - SSL Mode: `disable`
3. **PostgreSQL details**:
   - TimescaleDB: Toggle ON ✅
   - Min time interval: `1m`

### Sample Queries for Grafana
```sql
-- Time-bucketed aggregation
SELECT
  time_bucket('5 minutes', time) AS time,
  sensor_id::text AS metric,
  AVG(temperature) AS value
FROM sensor_data
WHERE $__timeFilter(time)
GROUP BY 1, 2
ORDER BY 1
```

## MCP Server (Fixed 2025-09-03)

### Deployment
- **Type**: Stdio-based MCP server (not standalone container)
- **Command**: `/home/administrator/projects/mcp-timescaledb/mcp-wrapper.sh`
- **Network**: Uses host network for database access
- **Status**: ✅ Configured and ready

### Configuration Fix Applied
- Changed from standalone Docker container to stdio-based MCP server
- Created wrapper script to handle Docker execution with proper stdio
- Added to Claude's mcp_servers.json configuration
- Server connects on-demand when Claude needs it

### Available MCP Tools
- `tsdb_query` - Execute SELECT queries
- `tsdb_execute` - Execute INSERT/UPDATE/DELETE
- `tsdb_create_hypertable` - Convert tables to hypertables
- `tsdb_show_hypertables` - List all hypertables
- `tsdb_show_chunks` - Show chunks for hypertables
- `tsdb_compression_stats` - View compression statistics
- `tsdb_add_compression` - Add compression policies
- `tsdb_continuous_aggregate` - Create continuous aggregates
- `tsdb_time_bucket_query` - Time-bucket aggregations
- `tsdb_database_stats` - Database statistics

### MCP Server Files
- `/home/administrator/projects/mcp-timescaledb/server.py` - Main MCP server implementation
- `/home/administrator/projects/mcp-timescaledb/mcp-wrapper.sh` - Docker wrapper for stdio handling
- `/home/administrator/projects/mcp-timescaledb/Dockerfile` - Docker image definition
- `/home/administrator/projects/mcp-timescaledb/requirements.txt` - Python dependencies
- `/home/administrator/.config/claude/mcp_servers.json` - MCP configuration entry

## Recent Changes & Updates

### Session: 2025-09-05
- **Documentation Update**: Comprehensive state verification
  - Confirmed healthy status with 2+ days uptime
  - Verified all network connections (3 networks)
  - Database stats: 1 hypertable, 1 chunk, ~9.4MB
  - MCP server operational with 10 tools available
  - All integrations functioning (Grafana, pgAdmin, MCP)

### Session: 2025-09-03
- **MCP Server Fix**: Changed from containerized to stdio-based
  - Created wrapper script for Docker stdio handling
  - Fixed "tsdb_show_hypertables" tool (tablespace column issue)
  - Successfully integrated with Claude Code
- **pgAdmin Integration**: Completed with MD5 auth
- **Grafana Integration**: Data source configured

### Session: 2025-09-02
- **Initial Deployment**: TimescaleDB container created
  - Separate from main PostgreSQL (port 5433)
  - Configured with auto-tuning
  - Basic hypertable created (sensor_data)

## Performance & Resource Usage
- **Memory**: Configured with TS_TUNE_MEMORY (auto-tuning)
- **CPU**: Uses TS_TUNE_NUM_CPUS for optimization
- **Storage**: Docker volume for persistence
- **Current Size**: ~9.4MB (minimal test data)
- **Health Check**: Built-in PostgreSQL health checks

## Backup & Recovery
- **Strategy**: Not yet implemented (manual backup available)
- **Script**: `/home/administrator/projects/timescaledb/backup.sh`
- **Recommendation**: Daily automated backups with 30-day retention
- **Recovery**: Point-in-time recovery capable (needs configuration)

## Future Enhancements
1. **Automated Policies**:
   - Compression for data older than 7 days
   - Retention policy for data older than 90 days
   - Continuous aggregates for common queries

2. **Monitoring Dashboards**:
   - Database performance metrics
   - Chunk statistics visualization
   - Compression effectiveness tracking

3. **Production Hardening**:
   - SSL/TLS for external connections
   - Connection pooling with PgBouncer
   - Read replicas for query scaling

## Related Services
- **Main PostgreSQL**: Port 5432 (separate instance)
- **Grafana**: Visualization at https://grafana.ai-servicers.com
- **pgAdmin**: Management at https://pgadmin.ai-servicers.com
- **Loki**: Log aggregation for troubleshooting

---
*Created: 2025-09-02*
*Last Updated: 2025-09-05 by Claude*
*Purpose: Time-series database for metrics and monitoring data*
*Status: ✅ Fully deployed with pgAdmin, Grafana, and MCP integrations*
*Next Review: When implementing automated backup/retention policies*