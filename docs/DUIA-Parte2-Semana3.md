# DUIA - Parte 2: Creación de Índices de Optimización (Semana 3)

## Resumen Ejecutivo
Este documento registra la creación del script `db/indices.sql` que consolida los 3 índices necesarios para optimizar escaneos secuenciales en la base de datos Food Store. Dos índices ya existían en `db/schema.sql`; el tercero (parcial) es nuevo.

---

## Archivo Generado
- **Ubicación**: `db/indices.sql`
- **Tipo**: Script SQL transaccional PostgreSQL idempotente
- **Ejecución**: `psql -U postgres -d food_store -f db/indices.sql`

---

## Decisión de Arquitectura: ¿Por qué `db/indices.sql` Separado?

### Análisis del Estado Actual
- `db/schema.sql` (líneas 53-57): Ya contiene `idx_producto_categoria` y `idx_pedido_usuario`
- `db/restricciones.sql`: Contiene **triggers de negocio** (validaciones), no optimizaciones
- Nuevo índice requerido: `idx_producto_precio_activo` (parcial, `WHERE activo = true`)

### Opciones Evaluadas

| Opción | Descripción | Veredicto |
|--------|-------------|-----------|
| **A. Agregar a `schema.sql`** | Modificar archivo base | ❌ Rompe idempotencia de schema; schema = estructura mínima |
| **B. Agregar a `restricciones.sql`** | Mezclar triggers + índices | ❌ Confunde restricciones lógicas vs optimización física |
| **C. Crear `db/indices.sql`** | Archivo dedicado a performance | ✅ **Elegida**: Separación de preocupaciones, versionable, re-ejecutable |

### Justificación Final
- **Principio Single Responsibility**: `schema` = DDL base, `restricciones` = lógica negocio, `indices` = performance
- **Idempotencia**: `CREATE INDEX IF NOT EXISTS` permite re-ejecutar sin errores
- **Mantenibilidad**: Un solo lugar para "todo lo de índices", fácil auditoría
- **Cumplimiento Steering Rules**: No rompe 3NF, son optimizaciones puras

---

## Índices Creados en `db/indices.sql`

```sql
BEGIN;

-- 1. idx_producto_categoria (ya en schema.sql)
CREATE INDEX IF NOT EXISTS idx_producto_categoria ON producto (categoria_id);

-- 2. idx_pedido_usuario (ya en schema.sql)
CREATE INDEX IF NOT EXISTS idx_pedido_usuario ON pedido (usuario_id);

-- 3. idx_producto_precio_activo (NUEVO - índice parcial)
CREATE INDEX IF NOT EXISTS idx_producto_precio_activo ON producto (precio)
WHERE activo = true;

COMMIT;
```

---

## Documentación para DUIA: Nodo de Plan Atacado por Cada Índice

| Índice | Tabla | Nodo de Plan Atacado | Query Típica Optimizada |
|--------|-------|---------------------|------------------------|
| `idx_producto_categoria` | `producto` | **Seq Scan** → Filter por `categoria_id` | `SELECT * FROM producto WHERE categoria_id = 3;` |
| `idx_pedido_usuario` | `pedido` | **Seq Scan** → Filter por `usuario_id` | `SELECT * FROM pedido WHERE usuario_id = 123;` |
| `idx_producto_precio_activo` | `producto` | **Seq Scan** + **Filter** `WHERE activo = true AND precio BETWEEN ...` | `SELECT * FROM producto WHERE activo = true AND precio BETWEEN 1000 AND 2000;` |

### Detalle Técnico: Índice Parcial (`idx_producto_precio_activo`)

**Por qué parcial (`WHERE activo = true`):**
- La tabla `producto` tiene columna `activo BOOLEAN DEFAULT TRUE` (baja lógica)
- Consultas de catálogo **siempre** filtran `activo = true`
- Un índice total sobre `(precio)` indexaría también productos inactivos (desperdicio)
- Índice parcial:
  - **Tamaño**: ~70% del índice total (solo filas activas)
  - **I/O**: Menos páginas leídas
  - **Planner**: PostgreSQL lo elige automáticamente cuando query tiene `activo = true`

**Plan de ejecución ANTES (sin índice parcial):**
```
Seq Scan on producto
  Filter: (activo = true AND precio BETWEEN 1000 AND 2000)
  Rows Removed by Filter: 15000 (inactivos + fuera de rango)
```

**Plan de ejecución DESPUÉS (con índice parcial):**
```
Index Scan using idx_producto_precio_activo on producto
  Index Cond: (precio BETWEEN 1000 AND 2000)
  -- No necesita Filter extra: el índice YA solo tiene activo=true
```

---

## Verificación de Ejecución

```sql
-- Ejecutar script
psql -U postgres -d food_store -f db/indices.sql

-- Verificar índices creados
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_producto_categoria', 'idx_pedido_usuario', 'idx_producto_precio_activo')
ORDER BY indexname;

-- Verificar uso en queries (EXPLAIN ANALYZE)
EXPLAIN ANALYZE SELECT * FROM producto WHERE categoria_id = 1;
EXPLAIN ANALYZE SELECT * FROM pedido WHERE usuario_id = 123;
EXPLAIN ANALYZE SELECT * FROM producto WHERE activo = true AND precio BETWEEN 1000 AND 2000;
```

### Resultado Esperado `EXPLAIN`

| Query | Plan Esperado |
|-------|---------------|
| `categoria_id = 1` | **Index Scan** using `idx_producto_categoria` |
| `usuario_id = 123` | **Index Scan** using `idx_pedido_usuario` |
| `activo=true AND precio BETWEEN...` | **Index Scan** using `idx_producto_precio_activo` |

---

## Impacto en Rendimiento (Con 50K productos, 200K pedidos)

| Métrica | Antes (Seq Scan) | Después (Index Scan) | Mejora |
|---------|------------------|---------------------|--------|
| Productos por categoría | ~50K rows scanned | ~1-5K rows (selectividad) | **10-50x** |
| Pedidos por usuario | ~200K rows scanned | ~1-50 rows | **4K-200Kx** |
| Productos activos por precio | ~35K rows scanned | ~1-5K rows (solo activos) | **7-35x** |

---

## Próximos Pasos
- Monitorear uso real con `pg_stat_user_indexes`
- Evaluar índices compuestos si hay queries multi-columna frecuentes
- Documentar en DUIA siguiente fase (Semana 4+)