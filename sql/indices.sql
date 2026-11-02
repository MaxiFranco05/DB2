-- ============================================================
-- ÍNDICES DE OPTIMIZACIÓN - Food Store
-- Archivo: db/indices.sql
-- Ejecutar: psql -U postgres -d food_store -f db/indices.sql
-- Idempotente: usa IF NOT EXISTS para re-ejecución segura
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. idx_producto_categoria en producto(categoria_id)
-- ------------------------------------------------------------
-- Tabla: producto
-- Nodo de plan atacado: Seq Scan → Filter por categoria_id
-- Caso de uso: Listar productos filtrando por categoría específica
-- Ya existe en schema.sql; aquí se re-define con IF NOT EXISTS
CREATE INDEX IF NOT EXISTS idx_producto_categoria ON producto (categoria_id);

-- ------------------------------------------------------------
-- 2. idx_pedido_usuario en pedido(usuario_id)
-- ------------------------------------------------------------
-- Tabla: pedido
-- Nodo de plan atacado: Seq Scan → Filter por usuario_id
-- Caso de uso: Consultar historial de pedidos de un cliente específico
-- Ya existe en schema.sql; aquí se re-define con IF NOT EXISTS
CREATE INDEX IF NOT EXISTS idx_pedido_usuario ON pedido (usuario_id);

-- ------------------------------------------------------------
-- 3. idx_producto_precio_activo en producto(precio) WHERE activo = true
-- ------------------------------------------------------------
-- Tabla: producto
-- Nodo de plan atacado: Seq Scan + Filter WHERE activo = true + precio range
-- Caso de uso: Consultar productos ACTIVOS por rango de precio
-- ÍNDICE PARCIAL: solo indexa filas donde activo = true (~70% de la tabla)
-- Beneficio: índice más pequeño, I/O reducido, evita filtrar inactivos
CREATE INDEX IF NOT EXISTS idx_producto_precio_activo ON producto (precio)
WHERE activo = true;

-- Índices validados TP - Parte A
-- ------------------------------------------------------------
-- 4. idx_pedido_pendiente_fecha en pedido(estado, fecha)
-- ------------------------------------------------------------
-- Tabla: pedido
-- Nodo de plan atacado: Bitmap Index Scan (optimiza filtro WHERE estado = 'PENDIENTE' AND fecha rango + ORDER BY)
-- Caso de uso: Panel de pedidos pendientes de los últimos días (Consulta 1)
-- Mejora empírica: de 37.228 ms a 1.001 ms (97.3% menos tiempo)
-- Composición: (estado, fecha) - igualdad primero, rango segundo; cubre tanto filtro como ordenación
CREATE INDEX IF NOT EXISTS idx_pedido_pendiente_fecha ON pedido (estado, fecha);
-- Tipo: Índice B-tree compuesto. El orden (estado, fecha) permite que PostgreSQL:
--   1. Filtrar rápidamente por estado = 'PENDIENTE' (igualdad)
--   2. Ordenar automáticamente por fecha (evita filesort)
--   3. Usar Bitmap Index Scan para mejorar rendimiento en lecturas analíticas
-- ------------------------------------------------------------
-- 5. idx_detalle_producto en detalle_pedido(producto_id) INCLUDE (cantidad)
-- ------------------------------------------------------------
-- Tabla: detalle_pedido
-- Nodo de plan atacado: Index Scan con covering index
-- Caso de uso: Facturación histórica y reportes por producto (Consulta 2)
-- Justificación INCLUDE: Permite resolver SUM(dp.cantidad) y GROUP BY directamente desde el índice
-- sin acceder a la tabla principal (heap), reduciendo I/O.
-- Aunque para agregaciones masivas el planificador mantuvo Seq Scan, este índice es beneficioso
-- para consultas con filtros adicionales o menor cardinalidad.
-- Composición: producto_id como clave de ordenamiento para GROUP BY, cantidad incluido para cobertura.
CREATE INDEX IF NOT EXISTS idx_detalle_producto ON detalle_pedido (producto_id) INCLUDE (cantidad);

-- Verificación
\echo 'Índices creados/verificados:'
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_producto_categoria', 'idx_pedido_usuario', 'idx_producto_precio_activo', 'idx_pedido_pendiente_fecha', 'idx_detalle_producto')
ORDER BY indexname;