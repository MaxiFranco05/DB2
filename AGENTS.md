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

**Formato obligatorio absolutamente:**
Respondiendo SIEMPRE con una tabla Markdown vertical de dos columnas y encabezado `| Campo | Completar | | :--- | :--- |`. Sin excepciones, sin texto libre fuera de la tabla.

**Estructura de la tabla (6 campos obligatorios en negrilla, orden obligatorio):**

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | [nombre de la herramienta usada] |
| **Spec o prompt utilizado** | [ruta o descripción del spec/prompt] |
| **Qué generó** | [descripción concisa de lo generado] |
| **Qué se aceptó** | [100% de lógica o porcentaje aceptado] |
| **Qué se modificó o descartó, y por qué** | [razón técnica de qué se cambió o descartó] |
| **Verificación realizada** | [prueba técnica detallada: EXCEPT bidireccional, ✅ de aprobación, ms medidos, etc.] |

**Reglas críticas:**
1. **NEVER** usar `SELECT *`, texto introductorio, saludos, ni conclusiones fuera de la tabla
2. **SIEMPRE** incluir los 6 campos en negrilla en la columna izquierda, en el orden especificado
3. **SIEMPRE** terminar la fila de "Verificación realizada" con ✅ tildes de aprobación y mención a EXCEPT bidireccional cuando aplique
4. Si hay múltiples tareas o specs, generar una tabla independiente por cada una (nunca combinadas en una sola tabla)
5. La tabla debe comenzar SIEMPRE con `| **Campo** | **Completar** | | :--- | :--- |` en la primera línea después del heading opcional
6. La ubicación exclusiva es `/docs/DUIA/` siguiendo la nomenclatura `DUIA-ParteX-SemanaY.md`

**Ejemplo de estructura válida:**

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Spec o prompt utilizado** | .kiro/specs/indice_detalle_producto.txt |
| **Qué generó** | Script transaccional CREATE INDEX |
| **Qué se aceptó** | 100% de la lógica generada |
| **Qué se modificó/descartó** | Se descartó índice por baja selectividad ENUM |
| **Verificación realizada** | ✅ EXPLAIN ANALYZE: de 37ms a 1ms. ✅ EXCEPT: 0 filas. |

**Consecuencias de incumplimiento:**
- El agente deberá reescribir completamente el DUIA cumpliendo el formato
- No se considerará el deliverable válido para cierre de cambio
- Se deberá re-ejecutar la tarea desde el paso de especificación