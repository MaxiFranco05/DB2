-- ============================================================================
-- consultas_postgresql.sql
-- 
-- Asignatura: Bases de Datos II - Tecnicatura Universitaria en Programación
-- Proyecto: Food Store - Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- Repositorio: https://github.com/MaxiFranco05/DB2
-- Motor: PostgreSQL 16+
-- 
-- Especificación formal de referencia: SPEC_U7.md (Secciones 4.2 y 6.2)
-- 
-- Ejecución:
--   psql -d foodstore -f consultas_postgresql.sql
-- ============================================================================

\echo '=== Consultas PostgreSQL Equivalentes - Food Store U7 ==='
\echo ''

-- ----------------------------------------------------------------------------
-- Q-PG1: Equivalente Relacional de Q-M2 (Pedidos con estado CONFIRMADO)
-- ----------------------------------------------------------------------------
-- Propósito: Recuperar los pedidos en estado 'CONFIRMADO' dentro de la muestra
-- piloto de 5 pedidos, calculando el importe total mediante la agregación de subtotales.
-- Se proyectan id, estado, fecha y total para contrastar contra el documento BSON.

\echo '--- [Q-PG1] Pedidos con estado CONFIRMADO (Equivalente a Q-M2) ---'

SELECT
    p.id             AS pedido_id,
    p.estado,
    p.fecha,
    SUM(dp.subtotal) AS total
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id IN (756504, 756505, 756506, 756507, 756508)
  AND p.estado = 'CONFIRMADO'
GROUP BY p.id, p.estado, p.fecha
ORDER BY p.id;

\echo 'Q-PG1 ejecutada. Cardinalidad esperada: 2 filas (IDs: 756505, 756508).'
\echo ''

-- ----------------------------------------------------------------------------
-- Q-PG2: Equivalente Relacional de Q-M3 (Pedidos que contienen el Producto 243882)
-- ----------------------------------------------------------------------------
-- Propósito: Recuperar los pedidos de la muestra piloto que incluyen la línea con
-- producto_id = 243882, proyectando los datos del detalle (cantidad, precio histórico y subtotal).
-- Contrasta con la búsqueda sobre el arreglo embebido 'items' en MongoDB.

\echo '--- [Q-PG2] Pedidos que contienen el Producto 243882 (Equivalente a Q-M3) ---'

SELECT DISTINCT
    p.id                AS pedido_id,
    p.estado,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario  AS precio_unitario_historico,
    dp.subtotal
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id IN (756504, 756505, 756506, 756507, 756508)
  AND dp.producto_id = 243882
ORDER BY p.id;

\echo 'Q-PG2 ejecutada. Cardinalidad esperada: 4 filas (IDs: 756505, 756506, 756507, 756508).'
\echo ''

-- ----------------------------------------------------------------------------
-- PROTOCOLO DE VERIFICACIÓN CRUZADA POSTGRESQL vs. MONGODB:
-- ----------------------------------------------------------------------------
-- 1. Matriz de Equivalencia (Consigna 5):
--    - Q-PG1 vs Q-M2: Ambos motores deben retornar exactamente 2 pedidos (IDs 756505 y 756508).
--    - Q-PG2 vs Q-M3: Ambos motores deben retornar exactamente 4 pedidos (IDs 756505, 756506, 756507 y 756508).
-- 2. Integridad de Precios:
--    - Verificar que dp.precio_unitario en Q-PG2 coincida exactamente con
--      items.precio_unitario_historico en Q-M3 ($3628.43 para el producto 243882).
-- ----------------------------------------------------------------------------

\echo '=== FIN DE EJECUCIÓN - CONSULTAS POSTGRESQL COMPLETADAS ==='
