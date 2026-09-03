# FoodStore

Proyecto de base de datos para una tienda de alimentos.

## Estructura

```
FoodStore/
├── src/                     # Código fuente
├── db/
│   ├── schema.sql           # Esquema de base de datos
│   └── backups/             # Backups de pg_dump
├── docs/                    # Documentación y diagramas
├── .env.example             # Variables de entorno (sin valores reales)
└── .kiro/                   # Configuración de Kiro
```

## Setup

```bash
# Copiar variables de entorno
cp .env.example .env
# Editar .env con tus valores
```

## Base de datos

```bash
# Aplicar esquema
psql -d foodstore -f db/schema.sql

# Backup
pg_dump -d foodstore > db/backups/backup_$(date +%Y%m%d).dump

# Restore
pg_restore -d foodstore db/backups/backup_20260101.dump
```