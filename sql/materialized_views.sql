-- =============================================================================
-- Vista Materializada - Parte C
-- Generado a partir de las especificaciones en .kiro/specs/mv_ventas_categoria_mes.md
-- =============================================================================

-- ---------------------------------------------------------
-- 1. DDL de la vista materializada mv_ventas_categoria_mes
-- ---------------------------------------------------------
-- RN-MV-01: Precalcula facturación mensual por categoría para reportes analíticos.
-- Se usa WITH NO DATA para creación en entornos CI/CD donde los datos
-- reales pueden no estar presentes al momento del despliegue DDL.
-- Se aplica ::date para convertir TIMESTAMPTZ a DATE eficiente
-- (2025-03-01 en lugar de 2025-03-01 00:00:00+00).
CREATE MATERIALIZED VIEW mv_ventas_categoria_mes AS
SELECT
    cat.id                                    AS categoria_id,
    cat.nombre                                AS nombre_categoria,
    date_trunc('month', ped.fecha)::date      AS mes,
    SUM(dp.subtotal)                          AS total_facturado,
    SUM(dp.cantidad)                          AS total_unidades
FROM detalle_pedido dp
INNER JOIN pedido   ped ON dp.pedido_id   = ped.id
INNER JOIN producto pro ON dp.producto_id = pro.id
INNER JOIN categoria cat ON pro.categoria_id = cat.id
WHERE ped.estado != 'CANCELADO'
  AND cat.activa  = TRUE
GROUP BY
    cat.id,
    cat.nombre,
    date_trunc('month', ped.fecha)::date
WITH NO DATA;

-- ---------------------------------------------------------
-- 2. Índice único obligatorio: uix_mv_ventas_categoria_mes
-- ---------------------------------------------------------
-- RN-MV-02: PostgreSQL requiere un índice único sobre la vista materializada
-- para poder ejecutar REFRESH CONCURRENTLY. Sin él, el refresco concurrente
-- falla con: "cannot refresh materialized view concurrently".
-- La clave (categoria_id, mes) es única por definición del GROUP BY: no puede
-- haber dos filas con el mismo categoria_id y el mismo mes.
-- Cardinalidad máxima: 5 categorías × 24 meses = 120 filas.
CREATE UNIQUE INDEX uix_mv_ventas_categoria_mes
    ON mv_ventas_categoria_mes (categoria_id, mes);

-- ---------------------------------------------------------
-- 3. Índice complementario: ix_mv_ventas_mes
-- ---------------------------------------------------------
-- RN-MV-03: Índice adicional para optimizar consultas que filtran por mes,
-- típicas de reportes de "ventas del último mes" o "evolución temporal".
-- Sobre (mes DESC) permite ordenamiento descendente eficiente sin duplicar
-- el índice único que ya cubre (categoria_id, mes).
CREATE INDEX ix_mv_ventas_mes
    ON mv_ventas_categoria_mes (mes DESC);

-- ---------------------------------------------------------
-- 4. Sentencias de inicialización
-- ---------------------------------------------------------

-- Primera carga (una sola vez, tras el despliegue inicial).
-- Al crear la vista con WITH NO DATA, la tabla está vacía. El REFRESH sin
-- CONCURRENTLY adquiere lock exclusivo y pobla la vista. Es un operación
-- atómica: las lecturas esperan hasta que el refresco termine.
REFRESH MATERIALIZED VIEW mv_ventas_categoria_mes;

-- Refrescos subsiguientes (rutinarios, sin bloqueo).
-- CONCURRENTLY calcula el nuevo conjunto en tabla temporal, compara con el
-- actual usando el índice único y aplica diferencias (INSERT/UPDATE/DELETE)
-- como operaciones individuales. Durante todo el proceso la vista sigue
-- legible con el dato anterior (snapshot isolation).
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes;