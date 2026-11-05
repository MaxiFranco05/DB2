-- =============================================================================
-- Food Store - Trabajo Práctico N.° 8 (Consigna 2.b: El semáforo)
-- Motor: SQLite 3.37+
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- Descripción: Evalúa únicamente las solicitudes en estado 'PENDIENTE' dentro
--              de cola_sync comparando cada ítem de item_borrador contra la
--              instantánea actual en snapshot_servidor:
--              - Rojo (RECHAZADO): algún producto no existe, no está disponible,
--                fue dado de baja (eliminado) o no alcanza el stock.
--              - Amarillo (CONFLICTO): no hay rojo, pero cambió algún precio.
--              - Verde (SIMULADO_APROBADO): todo coincide.
-- =============================================================================

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
