---
id: 2026-06-22-research-t03-substrate-gate-0a0451
status: reserved
child_session_id: 0a0451e6-9033-423f-8e33-6de4bd29d3d9
spawn_mode: manual
tier: null
spawned_at: 2026-06-22T02:13:55Z
launched_at: null
completed_at: null
source_dir: /home/administrator/projects/research
source_session_id: 67147fbd-934b-4ed2-afad-b503b3505d35
dest_dir: /home/administrator/projects/timescaledb
slug: research-t03-substrate-gate
parent_refocus_id: null
related_refocus_ids: []
done_when:
  - "psql as research_user to research_db succeeds AND `SELECT extversion FROM pg_extension WHERE extname='vector'` returns >= 0.8.0."
  - "LiteLLM `/v1/embeddings` with model `gemini-embedding-001` returns a 1536-dim vector."
  - "MinIO `research` bucket exists; its access keys are recorded in $HOME/projects/secrets/research.env along with DATABASE_URL."
  - "Research board cards #19/#20/#21 closed and #10 (T0.3) moved out of `blocked`."
out_of_scope:
  - "Do NOT modify the administrators/research application code or the `phase-0-foundation` branch — a build agent owns it."
  - "Do NOT drop or alter existing databases (agent_memory, optionsearch_db, tradingview_db). Only ADD research_db. The pgvector upgrade must preserve existing data — back up first."
  - "Do NOT expose these infra services publicly — they stay internal/Tier-1."
  - "Do NOT spawn further refocuses (children are leaves). Surface any spillover in Result.suggested_follow_ups."
related: []
---

# Brief: Execute the research platform's T0.3 substrate gate

## Why this branch exists
T0.3 — the `research` platform's de-risk/substrate gate — is **blocked on cross-project infra** that
lives outside the research repo and can't be done from the research session (a shared-DB restart plus
edits under hard-deny paths). Three setup tasks: upgrade TimescaleDB's pgvector + create `research_db`,
register a Gemini embedding model in LiteLLM, and create a MinIO bucket. Forked into the `timescaledb`
project (where the DB work lives) to run the whole gate as one focused, human-driven session.

## Inherited context
- Completing this **unblocks card #10 (T0.3)** on the `administrators/research` board; cross-project cards **#19 (timescaledb), #20 (litellm), #21 (minio)** track the three sub-tasks. Then Phase 1 can start.
- **DB host:** container `timescaledb`, **PostgreSQL 16.10**, image `timescale/timescaledb:latest-pg16`. It **already has pgvector but at 0.7.2**. It also hosts `agent_memory` (uses `vector(384)`), `optionsearch_db`, `tradingview_db` — so a restart/upgrade affects them: **back up first, coordinate.**
- Admin connect: `set -a; source $HOME/projects/secrets/timescaledb.env; set +a` then `docker exec -e PGPASSWORD=$POSTGRES_PASSWORD timescaledb psql -U tsdbadmin -d postgres`.
- **pgvector target ≥ 0.8.x** (research uses HNSW indexes + `vector(1536)`; 0.7.2 functionally works but 0.8.x is the chosen target). Determine the upgrade path: check whether a newer `timescale/timescaledb` image tag bundles pgvector ≥0.8.x; if so bump `TIMESCALEDB_IMAGE` + `docker compose up -d`; otherwise install the newer extension into the image. After upgrade run `ALTER EXTENSION vector UPDATE;` in each DB that has it.
- **research_db:** `CREATE DATABASE research_db; CREATE USER research_user WITH PASSWORD '<gen>'; GRANT ALL PRIVILEGES ON DATABASE research_db TO research_user;` then `\c research_db` → `CREATE EXTENSION IF NOT EXISTS vector; GRANT ALL ON SCHEMA public TO research_user;`. Naming is pre-validated (snake_case).
- **LiteLLM:** config at `projects/data/litellm/config/config.yaml` (hard-deny path — human edits). Add an embedding model, e.g. `- model_name: gemini-embedding-001` / `litellm_params: {model: gemini/gemini-embedding-001, api_key: os.environ/GEMINI_API_KEY}`. Restart litellm. LiteLLM currently has **no** embedding model registered (Infinity serves bge-small, but research uses Gemini). Verify: `curl $LITELLM_BASE_URL/embeddings -H "Authorization: Bearer $KEY" -d '{"model":"gemini-embedding-001","input":"hi","dimensions":1536}'`.
- **MinIO:** create bucket `research` + access keys (mc or console). Store keys in `research.env`.
- **Secrets:** write `DATABASE_URL`, MinIO keys (and any needed LiteLLM key) into `$HOME/projects/secrets/research.env` (create it; chmod 600). Never commit secrets.
- Authoritative design/plan (read-only ref, in the research repo): `docs/DESIGN.md` and `docs/research/plan.md` §0/§9.
- Board ops use `GITLAB_HOST=gitlab.ai-servicers.com $HOME/projects/devscripts/glab`; research project id = 79.

## Open questions / desired deliverables
1. **TimescaleDB:** back up; upgrade pgvector → ≥0.8.x (verify `extversion`); create `research_db` + `research_user` + `CREATE EXTENSION vector`; verify research_user can connect.
2. **LiteLLM:** register `gemini-embedding-001`; restart; verify a 1536-dim embedding returns.
3. **MinIO:** create `research` bucket + keys.
4. **Secrets:** populate `$HOME/projects/secrets/research.env` (DATABASE_URL + MinIO + LiteLLM key).
5. **Board:** close research cards #19/#20/#21; move #10 (T0.3) out of `blocked` (→ `ready`/`done`) with a comment noting the gate is green.

## Hard rule for child
- Children are leaves. If you discover work that belongs in a different
  directory, do NOT call /refocus. Surface it in Result.suggested_follow_ups
  for the parent to decide.

## Pointer back
- Source session: `~/.claude/projects/-home-administrator-projects-research/67147fbd-934b-4ed2-afad-b503b3505d35.jsonl`
- To continue this child later: `cd /home/administrator/projects/timescaledb && claude --resume 0a0451e6-9033-423f-8e33-6de4bd29d3d9`

---

## Result

**Status: COMPLETE — all 4 done_when green; gate is GREEN.** (2026-06-21)

### Done & verified
- **TimescaleDB (card #19):** Backed up all DBs (`pg_dumpall` → `timescaledb/backups/pre-pgvector-0.8-upgrade-20260621-223421.sql`, gitignored). Pinned image `timescale/timescaledb:2.28.0-pg16` (bundles **pgvector 0.8.1** + TimescaleDB 2.28.0) via `TIMESCALEDB_IMAGE` in `secrets/timescaledb.env`; recreated with `./deploy.sh`. Ran `ALTER EXTENSION timescaledb UPDATE` in all 5 DBs (→2.28.0) and `ALTER EXTENSION vector UPDATE` in agent_memory (→0.8.1). Data intact (agent_memory 7 rows, 2 hypertables). **Why 2.28.0 not a custom image:** newer official tags already ship pgvector ≥0.8.x, so a custom Dockerfile/HA image is needless churn. TimescaleDB is actively maintained (TigerData rebrand 2025; 2.28 = June 2026) — no reason to migrate off.
- **research_db (card #19):** `research_db` owned by `research_user` (login role, scoped); `CREATE EXTENSION vector` (0.8.1); schema public owned by research_user. Verified research_user connects and can create `vector(1536)` tables. **done_when #1 ✅**
- **MinIO (card #21):** Bucket `research` + least-privilege user `research` with policy `research-rw` (scoped to that bucket only, NOT root). Scoped-key auth verified. **done_when #3 ✅**
- **Secrets:** `$HOME/projects/secrets/research.env` (mode 600): DATABASE_URL (internal `timescaledb:5432` + commented external `linuxserver.lan:5433`), MinIO keys (+ AWS_* aliases), LiteLLM base URL + dedicated virtual key `research-platform` (`sk-...`, authorizes gemini-embedding-001 + gemini chat).

### Completed after checkpoint
- **LiteLLM (card #20, done_when #2 ✅):** Human added the `gemini-embedding-001` block to `projects/data/litellm/config/config.yaml` (one indentation fix needed — list item must be 2-space, was 4). Restarted litellm; verified `POST /v1/embeddings` with `dimensions:1536` returns a 1536-dim vector via the `research-platform` key.
- **Board (done_when #4 ✅):** Closed #19/#20/#21 with completion notes; moved #10 (T0.3) `blocked` → `ready` (left open for the developer to verify from the app side and close). Phase 1 unblocked.

### suggested_follow_ups
- The research app container must join a shared docker network with `timescaledb` (timescaledb-net/postgres-net) and `minio`/`litellm` to use the internal-hostname DATABASE_URL/endpoints; otherwise switch DATABASE_URL to the external `linuxserver.lan:5433` form. Network attach is the build agent's call.
- `research-platform` LiteLLM key is scoped to gemini-embedding-001 + two gemini chat models; widen if Phase 1 needs more models.
