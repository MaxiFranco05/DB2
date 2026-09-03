# AGENTS.md - FoodStore

## Project Overview
PostgreSQL-backed food store application. Schema in `db/schema.sql`. Source code in `src/` (language/framework TBD).

## Commands

### Database
```bash
# Apply schema
psql -d foodstore -f db/schema.sql

# Backup
pg_dump -d foodstore > db/backups/backup_$(date +%Y%m%d).dump

# Restore
pg_restore -d foodstore db/backups/backup_YYYYMMDD.dump
```

### Environment
```bash
cp .env.example .env  # then edit with real values
```

## Structure
- `src/` — application code (to be implemented)
- `db/schema.sql` — canonical schema (source of truth)
- `db/backups/` — pg_dump outputs (gitignored)
- `docs/` — diagrams, notes
- `.kiro/specs/`, `.kiro/steering/` — Kiro artifacts

## Conventions
- Schema changes: edit `db/schema.sql`, then re-apply or create migration
- Never commit real credentials (`.env` is gitignored)
- Backups go to `db/backups/` (gitignored)

## Key Files to Know
- `db/schema.sql` — full schema with triggers, indexes, seed data
- `.env.example` — required env vars template
- `.gitignore` — excludes .env, backups, node_modules, IDE files