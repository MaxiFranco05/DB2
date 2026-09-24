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

COMMIT;

-- Verificación
\echo 'Índices creados/verificados:'
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('idx_producto_categoria', 'idx_pedido_usuario', 'idx_producto_precio_activo')
ORDER BY indexname;