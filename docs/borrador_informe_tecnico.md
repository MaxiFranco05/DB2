# Borrador Informe Técnico - TPI Food Store

---

## 1. Resumen de lo implementado por Unidad

### Unidad 1: Transacciones y Concurrencia

| Característica | Implementación | Evidencia |
|---------------|----------------|-----------|
| Transacciones ACID | `BEGIN; ... COMMIT; / ROLLBACK` en `test_restricciones.sql` y `db/test_entrega_1.sql` | Scripts transaccionales con `\echo` de confirmación |
| Aislamiento `READ COMMITTED` (predeterminado) | Comportamiento verificado: lecturas ven datos comprometidos al inicio de cada consulta | `informe_concurrencia.md` - Escenario 1 (bloqueo) y 2 (lectura no repetible) |
| Nivel `REPEATABLE READ` | Evita lecturas no repetibles y lecturas fantasma | `informe_concurrencia.md` - Escenarios 2 y 3 con `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ` |
| Bloqueos a nivel de fila (`FOR UPDATE`) | Sentencia de bloqueo implícito a nivel de fila | `informe_concurrencia.md` - Escenario 1 con `SELECT ... FOR UPDATE` |
| Máquina de estados de pedido | Trigger `validar_transicion_estado_pedido()` impide transiciones a `CANCELADO`/`TERMINADO` | `test_restricciones.sql` Tests 1.1, 1.2, 1.5; `DUIA-Parte1-Semana2.md` |

### Unidad 2: Optimización e Índices

| Característica | Implementación | Evidencia |
|---------------|----------------|-----------|
| Índice `idx_producto_categoria` | `CREATE INDEX IF NOT EXISTS idx_producto_categoria ON producto(categoria_id)` | `db/indices.sql` línea 17 |
| Índice `idx_pedido_usuario` | `CREATE INDEX IF NOT EXISTS idx_pedido_usuario ON pedido(usuario_id)` | `db/indices.sql` línea 26 |
| Índice parcial `idx_producto_precio_activo` | `CREATE INDEX IF NOT EXISTS idx_producto_precio_activo ON producto(precio) WHERE activo = true` | `db/indices.sql` línea 36-37 |
| Índice compuesto `idx_pedido_pendiente_fecha` | `CREATE INDEX IF NOT EXISTS idx_pedido_pendiente_fecha ON pedido(estado, fecha)` | `db/indices.sql` línea 48 |
| Índice covering `idx_detalle_producto` | `CREATE INDEX IF NOT EXISTS idx_detalle_producto ON detalle_pedido(producto_id) INCLUDE(cantidad)` | `db/indices.sql` línea 64 |
| Índice descartado `idx_pedido_estado` | Descartado por baja selectividad ENUM (4 valores, ~25% por valor) | `informe_mediciones.md` apartado 5; `DUIA-ParteA-Semana1-Unidad3.md` |
| Costo de escritura | +0.066 ms de latencia por transacción INSERT masiva | `informe_mediciones.md` apartado 4; `DUIA-ParteA-Semana1-Unidad3.md` |
| Mejora de lectura (Consulta 1) | 37.228 ms → 1.001 ms (97.3% de mejora) | `informe_mediciones.md` apartado 1 |

### Unidad 3: Vistas, Materializadas y PL/pgSQL

| Característica | Implementación | Evidencia |
|---------------|----------------|-----------|
| Cuatro vistas obligatorias | `v_categorias_vigentes`, `v_productos_vigentes`, `v_resumen_pedidos`, `v_detalle_pedidos` | `db/views.sql` (78 líneas) |
| Vista materializada | `mv_ventas_categoria_mes` con `WITH NO DATA` y refresco concurrente | `db/materialized_views.sql` (70 líneas) |
| Función trigger `calcular_subtotal_detalle()` | Completa `precio_unitario` y `subtotal` automáticamente en INSERT a `detalle_pedido` | `db/schema.sql` líneas 103-124; `test_restricciones.sql` |
| 4 triggers de dominio | `trg_01_validar_producto_activo`, `trg_02_validar_stock`, `trg_03_calcular_subtotal`, `trg_validar_estado_pedido` | `db/restricciones.sql`; `information_schema.triggers` |
| Vistas con `WITH CHECK OPTION` | `v_categorias_vigentes` mantiene consistencia de la política de baja lógica | `db/views.sql` línea 17; `DUIA-ParteB-Semana1-Unidad3.md` |
| Validación bidireccional de vistas | `EXCEPT` entre vistas y consultas sobre tablas base: 0 filas de diferencia | `db/test_views.sql` (68 líneas) |
| Subconsultas correlacionadas | `SELECT ... (SELECT MAX(...) FROM ... WHERE ...)` en `queries.sql` | `db/queries.sql` líneas 51-60 |
| Ventanas `DENSE_RANK()` | `SELECT ... DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto` en `queries.sql` | `db/queries.sql` líneas 39-49 |

---

## 2. Metodología de Pruebas y Resultados Obtenidos

### 2.1. Scripts de Prueba

| Archivo | Propósito | Elementos Clave |
|---------|-----------|-----------------|
| `db/test_restricciones.sql` | Pruebas de reglas de negocio (triggers) | 3 reglas (máquina estados, catálogo activo, control de stock); DO block PL/pgSQL; `EXCEPTION WHEN OTHERS` captura errores esperados |
| `db/test_views.sql` | Validación bidireccional de vistas vía `EXPECT` | 4 vistas (`v_categorias_vigentes`, `v_productos_vigentes`, `v_resumen_pedidos`, `v_detalle_pedidos`); 8 sentencias `EXPECT` (ambas direcciones) |
| `db/test_entrega_1.sql` | **Nuevo script transaccional unificado** | Las 9 unidades en un solo archivo con `ROLLBACK` final; pruebas de humo por cada objetivo |
| `informe_concurrencia.md` | Escenarios de concurrencia y aislamiento | 3 escenarios (bloqueo, lectura no repetible, lectura fantasma); verificación en motor real PostgreSQL |
| `informe_mediciones.md` | Mediciones de optimización de índices | `EXPLAIN ANALYZE` before/after con datos de prueba (50K productos, 200K pedidos) |

### 2.2. Resultados Clave

| Métrica | Resultado | Comentario |
|---------|-----------|------------|
| Mejora Consulta 1 (panel pedidos pendientes) | 37.228 ms → 1.001 ms (97.3%) | Índice compuesto `idx_pedido_pendiente_fecha` |
| Mejora Consulta 3 (precio max por categoría) | 81.069 ms → 90.087 ms (+10.9%) | Índice parcial `idx_producto_precio_activo`; planificador escoge Index Scan Backward |
| Costo escritura (1 pedido + 4 detalles) | 2.634 ms → 2.700 ms (+0.066 ms / +2.5%) | Mantenimiento de árboles B; aceptable vs ganancia de lectura |
| Lecturas no repetibles (nivel READ COMMITTED) | Se observaron cambios entre consultas | Comportamiento esperado PostgreSQL `READ COMMITTED` |
| Lecturas no repetibles (nivel REPEATABLE READ) | Mismo resultado en 2 consultas dentro de la transacción | `REPEATABLE READ` evita lecturas no repetibles y fantasmas |
| Soft delete (SET activo = FALSE) | Producto excluido de vistas `v_productos_vigentes` y índice parcial WHERE activo = true | Comportamiento consistente; vistas reflejan cambio al instante |

---

## 3. Tabla Comparativa de Optimización

| Índice / Objeto | Consulta 1: Panel Pedidos Pendientes | Consulta 2: Facturación Histórica | Consulta 3: Precio Máx por Categoría | Vista Materializada: mv_ventas_categoria_mes | Costo Escritura |
|-----------------|--------------------------------------|-----------------------------------|--------------------------------------|---------------------------------------------|-----------------|
| **ANTES** (sin índice optimizado) | Parallel Seq Scan on pedido: **37.228 ms** | Parallel Seq Scan on detalle_pedido: **310.535 ms** | Seq Scan on categoria + Subconsulta correlacionada: **81.069 ms** | Parallel Seq Scan sobre tablas múltiples: **335.380 ms** | 2.634 ms |
| **DESPUÉS** (con índices creados) | Bitmap Heap Scan → Bitmap Index Scan: **1.001 ms** (↓97.3%) | Parallel Seq Scan on detalle_pedido: **291.197 ms** (↓6.2%) | Index Scan Backward idx_producto_precio_activo: **90.087 ms** (↑10.9%) | REFRESH MATERIALIZED VIEW: **0.015 ms** (↓335.365 ms) | 2.700 ms (↑0.066 ms) |
| **Mejoras Relativas** | **97.3%** de reducción | 6.2% de reducción (agregación masiva prefiere Seq Scan) | +10.9% (costo ligeramente superior, pero evita escaneo completo) | **~100%** de reducción de latencia de lectura | +2.5% overhead aceptable |
| **Conclusión** | Índice compuesto (estado, fecha) cubre filtro + ordenación | Índice covering `idx_detalle_producto` beneficioso para filtros adicionales, pero planificador prefiere Seq Scan para agregaciones masivas | Índice parcial válido para filtros pesados sobre productos activos; validar cardinalidad | **Ganancia máxima**: vista pre-calculada con índice único (categoria_id, mes) | Overhead de mantenimiento ínfimo vs beneficio de lectura |

---

## 4. Registro de Uso de IA

### 4.1. Flujo de Trabajo

| Fase | Herramienta | Rol | Actividad Principal |
|------|-------------|-----|---------------------|
| **Diseño y Especificación** | **Kiro** | Diseñador/especificador | Definición de reglas de negocio, especificaciones SQL, diseño de esquemas, creación de specs en `.kiro/specs/` |
| **Generación y Auditoría de Código** | **OpenCode** | Generador/auditor de código | Traducción de specs a DDL SQL (`db/schema.sql`, `db/indices.sql`, `db/views.sql`, `db/materialized_views.sql`), creación de scripts de prueba (`db/test_restricciones.sql`, `db/test_views.sql`), generación de `db/test_entrega_1.sql` |
| **Validación y Verificación** | Ambos | Revisión cruzada | Ejecución de `EXPLAIN ANALYZE`, validación de `EXCEPT` bidireccional, ejecución de scripts de prueba, medición de tiempos |
| **Documentación** | Kiro + OpenCode | Co-autores | Generación de DUIA (`docs/DUIA/`), informe técnico (`docs/borrador_informe_tecnico.md`), mediciones (`informe_mediciones.md`) |

### 4.2. Decisiones de Aceptación/Descarte Documentadas en DUIAs

| Decisión | Herramienta | Justificación | Resultado |
|----------|-------------|---------------|-----------|
| **Descarte idx_pedido_estado** (índice simple sobre `pedido.estado`) | OpenCode (DUIA-ParteA-Semana1-Unidad3) | Baja selectividad ENUM (4 valores); optimizador ignora índice; degradación escrituras sin beneficio | ✅ Descartado; se confía en `idx_pedido_pendiente_fecha` compuesto |
| **Opción C: archivo dedicado db/indices.sql** | OpenCode (DUIA-Parte2-Semana3) | Separación de preocupaciones: schema = DDL base, restricciones = lógica negocio, indices = performance; versionable y re-ejecutable | ✅ Aceptado; archivo idempotente con `CREATE INDEX IF NOT EXISTS` |
| **Descarte script original de pruebas** (variables shell `\set`) | OpenCode (DUIA-Parte1-Semana2) | Sintaxis MySQL en UPDATE `LIMIT`; backticks shell no funcionan en modo script psql | ✅ Reescrito a DO block PL/pgSQL con variables reales y EXCEPTION blocks |
| **WITH CHECK OPTION en v_categorias_vigentes** | Kiro (DUIA-ParteB-Semana1-Unidad3) | Mantener consistencia de la política de baja lógica; rechazar inserciones que violen `activa = TRUE` | ✅ Aceptado; validado que rechaza inserciones inválidas |
| **Mantener visibilidad histórica completa en vistas** | Kiro (DUIA-ParteB-Semana1-Unidad3) | Decisión de negocio: preservar trazabilidad analítica; el consumidor puede filtrar usando `estado_pedido` si lo requiere | ✅ Aceptado; las 4 vistas no filtran por estado ni por baja lógica |
| **Vista materializada vs reporte en caliente** | Kiro (DUIA-ParteC-Semana1-Unidad3) | Tolerancia al atraso temporal vs costo computacional de recorrer medio millón de registros | ✅ Aceptado; `WITH NO DATA` + `REFRESH MATERIALIZED VIEW CONCURRENTLY`; latencia 0.015 ms vs 335.380 ms |

### 4.3. Herramientas y Entorno

- **Kiro**: Asistencia en redacción de especificaciones de diseño, creación de specs técnicas en `.kiro/specs/`, diseño intelectual de reglas de negocio.
- **OpenCode**: Generación de script SQL transaccional, creación y auditoría de DDL (schema, índices, vistas, materialized views), generación y ejecución de scripts de prueba PL/pgSQL.
- **Entorno de ejecución**: PostgreSQL 16+, psql cliente, herramientas de medición `EXPLAIN ANALYZE`, DBeaver para verificación visual.
- **Protocolo de seguridad**: `.env` gitignorado, backups en `db/backups/`, uso de `ROLLBACK` en scripts de prueba para evitar persistencia de datos de prueba.

---
*Este borrador será convertido a DOCX tras la revisión y aprobación de los cambios.*