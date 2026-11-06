# TP8 - Kiro - Implementación de Bases de Datos

## Instrucciones de Despliegue (Setup)
Para inicializar el ecosistema de bases de datos desde cero, ejecutar en el siguiente orden:

1. **PostgreSQL (Capa de Verdad Central):**
   Ejecutar los scripts ubicados en la carpeta `/sql` (esquema, restricciones, triggers y roles).
2. **MongoDB (Capa Histórica Documental):**
   Ejecutar el script `consultas_mongodb.js` mediante `mongosh` para generar las proyecciones de pedidos.
3. **SQLite (Capa Móvil Offline):**
   Ejecutar el script `movil/semaforo.sql`, crear el esquema `STRICT` y cargar los datos cacheados en `producto_cache`.

---

## Historial de Trabajos Prácticos Anteriores

# FoodStore
### Proyecto de base de datos para una tienda de alimentos.
---
### Miembros:
##### - Máximo Franco
##### - Andrés Novello
##### - Octavio Fiore
---
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
