# Eve + Postgres version-upgrade repro

Minimal reproduction for parked Eve sessions becoming non-resumable after the Eve runtime is upgraded while using a persistent self-hosted PostgreSQL Workflow world.

## Requirements

- Node.js 24+
- Docker
- `curl`
- An Eve-compatible AI API key (`AI_GATEWAY_API_KEY` or `ANTHROPIC_API_KEY`)
- PostgreSQL 16, available through the Docker container expected by the script

Start the local PostgreSQL container if needed:

```bash
docker run --name eve-repro-pg \
  -e POSTGRES_USER=eve \
  -e POSTGRES_PASSWORD=eve \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  -d postgres:16
```

## Run the repro

The script installs Eve `0.47.2`, creates an isolated database, creates and parks a session, upgrades to Eve `0.47.3`, then resumes the session and checks the durable run status.

```bash
export AI_GATEWAY_API_KEY=your-key
./repro.sh
```

Expected result:

```text
Durable run status: failed|CORRUPTED_EVENT_LOG
PASS: parked session became non-resumable after the Eve version upgrade.
```

The script cleans up its temporary database when it exits. It leaves logs in a temporary directory, printed at the end. Override the versions or port when needed:

```bash
OLD_EVE=0.47.1 NEW_EVE=0.47.3 PORT=4225 ./repro.sh
```

Do not use a production database. The channel accepts unauthenticated local traffic for this repro only; configure authentication in production.
