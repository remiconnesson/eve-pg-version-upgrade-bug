# Eve + Postgres version-upgrade repro

Minimal reproduction for parked Eve sessions becoming non-resumable after the Eve runtime is upgraded while using a persistent self-hosted PostgreSQL Workflow world.

## Setup

Requirements: Node.js 24+, Docker, and a PostgreSQL 16 instance.

```bash
npm install
export WORKFLOW_POSTGRES_URL=postgres://eve:eve@localhost:5432/eve_repro
npx @workflow/world-postgres bootstrap
npm run build
npm start
```

The channel is explicitly configured for unauthenticated local traffic. In production, configure authentication instead.

## Reproduction

1. Run this app with the version in `package.json` and create a session.
2. Send at least one follow-up message, then leave the session parked.
3. Stop the app.
4. Change `eve` and `@workflow/world-postgres` to another version, run `npm install`, bootstrap migrations, build, and start against the same database.
5. Resume the old session.

The old parked run may fail with `SESSION_NOT_RESUMABLE`; the database run records can show `CORRUPTED_EVENT_LOG` because durable step names include the exact Eve package version.

Do not use a production database. Back it up before testing.
