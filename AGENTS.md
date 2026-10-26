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

### REGLA DE FORMATO ESTRICTO: DUIA (Declaración de Uso de IA)
Cuando el usuario solicite generar la "Declaración de Uso de IA" (DUIA), estás OBLIGADO a responder utilizando ÚNICAMENTE una tabla Markdown vertical de dos columnas (`| Campo | Completar |`). Si hay múltiples tareas, debes generar una tabla independiente por cada una.
Los campos obligatorios en la primera columna (en negrita) son:
1. **Herramienta**
2. **Spec o prompt utilizado**
3. **Qué generó**
4. **Qué se aceptó**
5. **Qué se modificó o descartó, y por qué**
6. **Verificación realizada** (Debe incluir el detalle de la prueba técnica, uso de EXCEPT, y tildes ✅ de aprobación).
Está terminantemente prohibido generar texto fuera de las tablas.
La DUIA se crea y edita exclusivamente en /docs/DUIA siguiendo el formato de nombre de los archivos. 