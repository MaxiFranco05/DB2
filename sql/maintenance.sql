-- ============================================================================
-- PROYECTO: Food Store | Bases de Datos II
-- ARCHIVO: sql/maintenance.sql
-- DESCRIPCIÓN: Procedimiento de revisión y mantenimiento seguro justificado.
-- EJECUCIÓN: psql -U postgres -d foodstore -f sql/maintenance.sql
-- ============================================================================
-- 
-- JUSTIFICACIÓN TÉCNICA Y CRITERIO DE SEGURIDAD (UNIDAD 6):
-- 
-- 1. PROHIBICIÓN DE 'VACUUM FULL':
--    El comando VACUUM FULL reescribe físicamente la tabla y sus índices en disco
--    para devolver espacio al sistema operativo. Para lograr esto, adquiere un
--    bloqueo exclusivo de acceso (AccessExclusiveLock), el nivel más restrictivo
--    en PostgreSQL. Este bloqueo impide no solo cualquier escritura (INSERT, 
--    UPDATE, DELETE), sino también cualquier LECTURA (SELECT) concurrente.
--    En una base de datos operativa transaccional como Food Store, ejecutar 
--    VACUUM FULL provocaría indisponibilidad total del servicio (downtime).
--    Por este motivo, VACUUM FULL queda estrictamente descartado como rutina periódica.
-- 
-- 2. ACCIÓN DE MANTENIMIENTO SEGURA SELECCIONADA:
--    Se adopta 'VACUUM ANALYZE' estándar concurrente sobre las tablas operativas:
--    - Adquiere únicamente un bloqueo 'ShareUpdateExclusiveLock', permitiendo que
--      las aplicaciones continúen leyendo y escribiendo concurrentemente.
--    - Marca las tuplas muertas como espacio libre reutilizable (FSM - Free Space Map)
--      evitando que los archivos crezcan desmedidamente.
--    - Actualiza las estadísticas del catálogo 'pg_statistic' (ANALYZE), permitiendo
--      al optimizador de costos (CBO) elegir los mejores planes de ejecución.
-- ============================================================================

\echo '========================================================================'
\echo ' PASO 1: OBSERVACIÓN PREVIA DEL ESTADO DE LAS TABLAS'
\echo '========================================================================'
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    CASE 
        WHEN (n_live_tup + n_dead_tup) > 0 
        THEN ROUND(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2) 
        ELSE 0 
    END AS pct_bloat_estimado,
    COALESCE(to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Sin registro') AS ultimo_vacuum,
    COALESCE(to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS'), 'Sin registro') AS ultimo_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '========================================================================'
\echo ' PASO 2: EJECUCIÓN DE MANTENIMIENTO SEGURO (VACUUM ANALYZE NO BLOQUEANTE)'
\echo '========================================================================'

-- Actualización de estadísticas y purga concurrente de tuplas muertas
-- en las tablas transaccionales de mayor volumen:
\echo '-> Mantenimiento en tabla: detalle_pedido...'
VACUUM ANALYZE detalle_pedido;

\echo '-> Mantenimiento en tabla: pedido...'
VACUUM ANALYZE pedido;

\echo '-> Mantenimiento en tabla: producto...'
VACUUM ANALYZE producto;

\echo '-> Mantenimiento en tabla: usuario...'
VACUUM ANALYZE usuario;

\echo '-> Mantenimiento en tabla: categoria...'
VACUUM ANALYZE categoria;

\echo '========================================================================'
\echo ' PASO 3: VERIFICACIÓN POST-MANTENIMIENTO'
\echo '========================================================================'
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS') AS fecha_vacuum_actualizada,
    to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS') AS fecha_analyze_actualizada
FROM pg_stat_user_tables
ORDER BY relname;

\echo '========================================================================'
\echo ' MANTENIMIENTO PREVENTIVO FINALIZADO CON ÉXITO'
\echo '========================================================================'
