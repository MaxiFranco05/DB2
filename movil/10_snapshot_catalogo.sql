-- ============================================================================
-- 10_snapshot_catalogo.sql
-- 
-- Asignatura: Bases de Datos II - Tecnicatura Universitaria en Programación
-- Proyecto: Food Store - Unidad 8: Base de Datos Móvil Desconectada (SQLite)
-- Motor: PostgreSQL 16+ (Servidor Central)
-- Comisión: C3 · Prof. Sergio Neira
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- ============================================================================

-- Vista de catálogo para alimentar el snapshot de las tablets offline en la feria
-- Incluye fecha_copia para registrar la marca temporal exacta de la instantánea
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    p.id,
    p.nombre,
    ROUND(p.precio * 100)::INTEGER AS precio_centavos,
    p.stock,
    (p.activo AND p.stock > 0) AS disponible,
    (NOT p.activo) AS eliminado,
    to_char(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') AS fecha_copia
FROM producto p
ORDER BY p.id;

-- Comando para exportar el catálogo a CSV con encabezados y transferir a la tablet
\copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER
