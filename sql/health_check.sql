-- ============================================================================
-- PROYECTO: Food Store | Bases de Datos II
-- ARCHIVO: sql/health_check.sql
-- DESCRIPCIÓN: Script de diagnóstico no invasivo de salud operativa de la BD.
-- EJECUCIÓN: psql -U postgres -d foodstore -f sql/health_check.sql
-- ============================================================================

\echo '========================================================================'
\echo ' CONTROL 1: TAMAÑO FÍSICO DE LA BASE DE DATOS'
\echo '========================================================================'
SELECT 
    datname AS base_de_datos,
    pg_size_pretty(pg_database_size(datname)) AS tamano_total
FROM pg_database
WHERE datname = 'foodstore';

\echo '========================================================================'
\echo ' CONTROL 2: ACTIVIDAD TRANSACCIONAL Y CONEXIONES'
\echo '========================================================================'
SELECT 
    datname AS base_de_datos,
    numbackends AS conexiones_activas,
    xact_commit AS transacciones_confirmadas,
    xact_rollback AS transacciones_abortadas,
    CASE 
        WHEN (xact_commit + xact_rollback) > 0 
        THEN ROUND(100.0 * xact_rollback / (xact_commit + xact_rollback), 2)
        ELSE 0 
    END AS porcentaje_rollback,
    conflicts AS conflictos,
    deadlocks AS interbloqueos
FROM pg_stat_database
WHERE datname = 'foodstore';

\echo '========================================================================'
\echo ' CONTROL 3: SALUD DE TABLAS, TUPLAS MUERTAS Y AUTOVACUUM'
\echo '========================================================================'
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    CASE 
        WHEN (n_live_tup + n_dead_tup) > 0 
        THEN ROUND(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
        ELSE 0 
    END AS pct_tuplas_muertas,
    COALESCE(to_char(last_vacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_vacuum_manual,
    COALESCE(to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_autovacuum,
    COALESCE(to_char(last_analyze, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_analyze_manual,
    COALESCE(to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI:SS'), 'Nunca') AS ultimo_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '========================================================================'
\echo ' CONTROL 4: CONSULTAS ACTIVAS NO OCIOSAS Y TIEMPO DE EJECUCIÓN'
\echo '========================================================================'
SELECT 
    pid,
    usename AS usuario,
    client_addr AS ip_origen,
    state AS estado,
    now() - query_start AS duracion,
    SUBSTRING(query FROM 1 FOR 80) AS consulta_truncada
FROM pg_stat_activity
WHERE datname = 'foodstore' 
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY duracion DESC;
