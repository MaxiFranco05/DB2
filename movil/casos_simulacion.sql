-- =============================================================================
-- Food Store - Trabajo Práctico N.° 8 (Consigna 2.c: Casos de Simulación C2 a C6)
-- Motor: SQLite 3.37+
-- Comisión: C3 · Prof. Sergio Neira
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- 
-- Ejecución completa:
--   sqlite3 foodstore_movil.db < movil/schema_sqlite.sql
--   sqlite3 foodstore_movil.db < movil/casos_simulacion.sql
-- =============================================================================

PRAGMA foreign_keys = ON;

-- -----------------------------------------------------------------------------
-- PASO 1: Limpieza e inicialización de la instantánea original en la tablet
-- -----------------------------------------------------------------------------
DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;
DELETE FROM producto_cache;
DELETE FROM snapshot_servidor;

-- Carga de la instantánea inicial del catálogo (previa a cambios en el servidor)
INSERT INTO snapshot_servidor (id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia)
VALUES
    (1, 'Producto 1', 421451, 184, 't', 'f', '2026-11-05 10:00:00'),
    (2, 'Producto 2',  76689,  36, 't', 'f', '2026-11-05 10:00:00'),
    (3, 'Producto 3', 328926, 199, 't', 'f', '2026-11-05 10:00:00'),
    (4, 'Producto 4',  63036, 154, 't', 'f', '2026-11-05 10:00:00');

-- Poblar producto_cache a partir de la instantánea inicial
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT id, nombre, precio_centavos, stock, 1, 0, fecha_copia
FROM snapshot_servidor;

-- -----------------------------------------------------------------------------
-- PASO 2: Construcción de los 4 borradores offline en la tablet
-- -----------------------------------------------------------------------------
BEGIN TRANSACTION;

-- Borrador C2: sobre Producto 1 al precio visto original (421451)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c2000000-0000-4000-8000-000000000002', 'operador_feria', 'TARJETA', '2026-11-05T19:15:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c2000000-0000-4000-8000-000000000002', 1, 2, 421451);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c2-0001', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- Borrador C3: sobre Producto 2 solicitando 50 unidades (stock disponible: 36)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c3000000-0000-4000-8000-000000000003', 'operador_feria', 'EFECTIVO', '2026-11-05T19:16:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c3000000-0000-4000-8000-000000000003', 2, 50, 76689);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c3-0001', 'c3000000-0000-4000-8000-000000000003', 'PENDIENTE', NULL);

-- Borrador C4: sobre Producto 3 (que luego será dado de baja en el servidor)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c4000000-0000-4000-8000-000000000004', 'operador_feria', 'TRANSFERENCIA', '2026-11-05T19:17:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c4000000-0000-4000-8000-000000000004', 3, 1, 328926);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c4-0001', 'c4000000-0000-4000-8000-000000000004', 'PENDIENTE', NULL);

-- Borrador C5: sobre Producto 4 sin alteraciones (precio 63036 coincide, cant 3 <= 154)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c5000000-0000-4000-8000-000000000005', 'operador_feria', 'EFECTIVO', '2026-11-05T19:18:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c5000000-0000-4000-8000-000000000005', 4, 3, 63036);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);

COMMIT;

-- -----------------------------------------------------------------------------
-- PASO 3: Simulación de cambios en el servidor central (descarga de nuevo snapshot)
-- En PostgreSQL se actualizó el Producto 1 a $4500 (450000 centavos) y se dio de
-- baja lógica el Producto 3 (activo = false). Se actualiza snapshot_servidor:
-- -----------------------------------------------------------------------------
UPDATE snapshot_servidor 
SET precio_centavos = 450000, fecha_copia = '2026-11-05 18:00:00' 
WHERE id = 1;

UPDATE snapshot_servidor 
SET disponible = 'f', eliminado = 't', fecha_copia = '2026-11-05 18:00:00' 
WHERE id = 3;

-- -----------------------------------------------------------------------------
-- PASO 4: Primera corrida del semáforo sobre solicitudes PENDIENTE
-- -----------------------------------------------------------------------------
WITH evaluacion AS (
    SELECT
        cs.solicitud_uuid,
        CASE
            WHEN SUM(
                CASE
                    WHEN s.id IS NULL
                      OR s.disponible IN ('f', 'false', '0', 0)
                      OR s.eliminado  IN ('t', 'true',  '1', 1)
                      OR i.cantidad > CAST(s.stock AS INTEGER)
                    THEN 1 ELSE 0
                END
            ) > 0 THEN 'RECHAZADO'
            WHEN SUM(
                CASE
                    WHEN i.precio_centavos_visto <> CAST(s.precio_centavos AS INTEGER)
                    THEN 1 ELSE 0
                END
            ) > 0 THEN 'CONFLICTO'
            ELSE 'SIMULADO_APROBADO'
        END AS nuevo_estado,
        CASE
            WHEN SUM(CASE WHEN s.id IS NULL THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto inexistente en el servidor'
            WHEN SUM(CASE WHEN s.eliminado IN ('t', 'true', '1', 1) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto dado de baja lógica (eliminado)'
            WHEN SUM(CASE WHEN s.disponible IN ('f', 'false', '0', 0) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto no disponible en catálogo'
            WHEN SUM(CASE WHEN i.cantidad > CAST(s.stock AS INTEGER) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Stock insuficiente en el servidor para la cantidad solicitada'
            WHEN SUM(CASE WHEN i.precio_centavos_visto <> CAST(s.precio_centavos AS INTEGER) THEN 1 ELSE 0 END) > 0
                THEN 'CONFLICTO: El precio actual en el servidor difiere del precio visto en el borrador'
            ELSE 'OK: Precio, disponibilidad y stock verificados en la instantánea'
        END AS nuevo_motivo
    FROM cola_sync cs
    JOIN item_borrador i ON i.id_local = cs.id_local
    LEFT JOIN snapshot_servidor s ON CAST(s.id AS INTEGER) = i.producto_id
    WHERE cs.estado = 'PENDIENTE'
    GROUP BY cs.solicitud_uuid
)
UPDATE cola_sync
SET
    estado = (SELECT e.nuevo_estado FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid),
    motivo = (SELECT e.nuevo_motivo FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid)
WHERE estado = 'PENDIENTE'
  AND EXISTS (SELECT 1 FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid);

-- -----------------------------------------------------------------------------
-- PASO 5: Resolución de Caso C2 (Cliente acepta nuevo precio: 450000 centavos)
-- Se actualiza precio_centavos_visto en el borrador y se encola nueva solicitud
-- -----------------------------------------------------------------------------
UPDATE item_borrador 
SET precio_centavos_visto = 450000
WHERE id_local = 'c2000000-0000-4000-8000-000000000002' AND producto_id = 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c2-0002', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- -----------------------------------------------------------------------------
-- PASO 6: Recarga del catálogo local en producto_cache (Preservación de lápida C4)
-- El Producto 3 se actualiza con disponible = 0 y eliminado = 1 (lápida).
-- No se hace DELETE para mantener la FK de borradores previos.
-- -----------------------------------------------------------------------------
INSERT OR REPLACE INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT 
    id, 
    nombre, 
    precio_centavos, 
    stock, 
    CASE WHEN disponible IN ('t', 'true', '1') THEN 1 ELSE 0 END,
    CASE WHEN eliminado IN ('t', 'true', '1') THEN 1 ELSE 0 END,
    fecha_copia
FROM snapshot_servidor;

-- -----------------------------------------------------------------------------
-- PASO 7: Segunda corrida del semáforo para resolver req-uuid-c2-0002
-- -----------------------------------------------------------------------------
WITH evaluacion AS (
    SELECT
        cs.solicitud_uuid,
        CASE
            WHEN SUM(
                CASE
                    WHEN s.id IS NULL
                      OR s.disponible IN ('f', 'false', '0', 0)
                      OR s.eliminado  IN ('t', 'true',  '1', 1)
                      OR i.cantidad > CAST(s.stock AS INTEGER)
                    THEN 1 ELSE 0
                END
            ) > 0 THEN 'RECHAZADO'
            WHEN SUM(
                CASE
                    WHEN i.precio_centavos_visto <> CAST(s.precio_centavos AS INTEGER)
                    THEN 1 ELSE 0
                END
            ) > 0 THEN 'CONFLICTO'
            ELSE 'SIMULADO_APROBADO'
        END AS nuevo_estado,
        CASE
            WHEN SUM(CASE WHEN s.id IS NULL THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto inexistente en el servidor'
            WHEN SUM(CASE WHEN s.eliminado IN ('t', 'true', '1', 1) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto dado de baja lógica (eliminado)'
            WHEN SUM(CASE WHEN s.disponible IN ('f', 'false', '0', 0) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Producto no disponible en catálogo'
            WHEN SUM(CASE WHEN i.cantidad > CAST(s.stock AS INTEGER) THEN 1 ELSE 0 END) > 0
                THEN 'RECHAZADO: Stock insuficiente en el servidor para la cantidad solicitada'
            WHEN SUM(CASE WHEN i.precio_centavos_visto <> CAST(s.precio_centavos AS INTEGER) THEN 1 ELSE 0 END) > 0
                THEN 'CONFLICTO: El precio actual en el servidor difiere del precio visto en el borrador'
            ELSE 'OK: Precio, disponibilidad y stock verificados en la instantánea'
        END AS nuevo_motivo
    FROM cola_sync cs
    JOIN item_borrador i ON i.id_local = cs.id_local
    LEFT JOIN snapshot_servidor s ON CAST(s.id AS INTEGER) = i.producto_id
    WHERE cs.estado = 'PENDIENTE'
    GROUP BY cs.solicitud_uuid
)
UPDATE cola_sync
SET
    estado = (SELECT e.nuevo_estado FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid),
    motivo = (SELECT e.nuevo_motivo FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid)
WHERE estado = 'PENDIENTE'
  AND EXISTS (SELECT 1 FROM evaluacion e WHERE e.solicitud_uuid = cola_sync.solicitud_uuid);

-- -----------------------------------------------------------------------------
-- PASO 8: Caso C6 — Demostración de Idempotencia y Protección ante Reintentos
-- Intentar reinsertar una solicitud ya existente ('req-uuid-c5-0001') es ignorado
-- o rechazado por PRIMARY KEY, garantizando que el semáforo no reevalúe registros cerrados.
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);

-- -----------------------------------------------------------------------------
-- CONSULTAS FINALES DE VERIFICACIÓN EN SQLITE
-- -----------------------------------------------------------------------------
-- 1. Estado final de todas las solicitudes en cola_sync:
SELECT solicitud_uuid, estado, motivo 
FROM cola_sync 
ORDER BY solicitud_uuid;

-- 2. Verificación de la lápida en producto_cache (Producto 3 eliminado pero presente):
SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado 
FROM producto_cache 
WHERE id = 3;

-- 3. Catálogo activo visible para nuevas ventas (el Producto 3 no aparece):
SELECT id, nombre, precio_centavos, stock_visto 
FROM producto_cache 
WHERE disponible = 1 AND eliminado = 0 
ORDER BY id;
