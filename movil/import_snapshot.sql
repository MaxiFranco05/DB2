-- =============================================================================
-- import_snapshot.sql
-- 
-- Asignatura: Bases de Datos II - Tecnicatura Universitaria en Programación
-- Proyecto: Food Store - Unidad 8 (Importación de Snapshot y Poblado de Catálogo)
-- Motor: SQLite 3.37+
-- =============================================================================

-- Este script traslada los registros de la tabla staging 'snapshot_servidor'
-- (previamente importada desde servidor_snapshot.csv) hacia 'producto_cache',
-- convirtiendo los booleanos de PostgreSQL ('t'/'f') a enteros SQLite (1/0).

INSERT OR REPLACE INTO producto_cache (
    id,
    nombre,
    precio_centavos,
    stock_visto,
    disponible,
    eliminado,
    fecha_copia
)
SELECT 
    id,
    nombre,
    precio_centavos,
    stock,
    CASE WHEN disponible IN ('t', 'true', '1') THEN 1 ELSE 0 END,
    CASE WHEN eliminado IN ('t', 'true', '1') THEN 1 ELSE 0 END,
    fecha_copia
FROM snapshot_servidor;
