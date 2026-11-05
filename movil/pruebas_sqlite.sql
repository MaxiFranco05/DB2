-- =============================================================================
-- Food Store - Trabajo Práctico N.° 8 (Consigna 1.c: Pruebas de la base SQLite)
-- Motor: SQLite 3.37+
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- =============================================================================

PRAGMA foreign_keys = ON;

-- Carga inicial de catálogo local en producto_cache para pruebas
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES
    (1, 'Hamburguesa Doble Queso', 850000, 15, 1, 0, '2026-11-05T10:00:00Z'),
    (2, 'Pizza Napolitana',        920000, 10, 1, 0, '2026-11-05T10:00:00Z'),
    (3, 'Gaseosa 500ml',           250000,  0, 0, 0, '2026-11-05T10:00:00Z'),
    (4, 'Empanada Cortada Cuchillo', 180000, 20, 0, 1, '2026-11-05T10:00:00Z');

-- =============================================================================
-- 1.a) Borrador completo (pedido_borrador + item_borrador + cola_sync)
--      guardado de forma atómica con BEGIN ... COMMIT
-- =============================================================================
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('550e8400-e29b-41d4-a716-446655440001', 'operador_feria_1', 'EFECTIVO', '2026-11-05T12:15:00Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 1, 2, 850000),
    ('550e8400-e29b-41d4-a716-446655440001', 2, 1, 920000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('990e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'PENDIENTE', NULL);

COMMIT;

-- =============================================================================
-- 1.b) Operación cancelada / deshecha con ROLLBACK
--      (No debe dejar ninguna fila nueva en las tres tablas)
-- =============================================================================
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('550e8400-e29b-41d4-a716-446655440099', 'operador_feria_1', 'TARJETA', '2026-11-05T12:20:00Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440099', 1, 1, 850000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('990e8400-e29b-41d4-a716-446655440099', '550e8400-e29b-41d4-a716-446655440099', 'PENDIENTE', NULL);

ROLLBACK;

-- Verificación tras COMMIT y ROLLBACK (debe existir únicamente el borrador 0001)
SELECT id_local, usuario, forma_pago, fecha FROM pedido_borrador;
SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync;

-- =============================================================================
-- 2. Caso C1: Consulta del catálogo disponible sin conectarse al servidor
--    Filtra productos disponibles (disponible = 1), no eliminados (eliminado = 0)
--    y con stock visto mayor a cero (stock_visto > 0)
-- =============================================================================
SELECT
    id,
    nombre,
    precio_centavos,
    ROUND(precio_centavos / 100.0, 2) AS precio_pesos,
    stock_visto
FROM producto_cache
WHERE disponible = 1
  AND eliminado = 0
  AND stock_visto > 0
ORDER BY nombre;

-- =============================================================================
-- 3. Caso C7: Una cantidad en 0 y un producto inexistente dan error y no dejan
--    filas nuevas (protección por CHECK (cantidad > 0) y FOREIGN KEY)
-- =============================================================================

-- C7.a) Intento de insertar cantidad = 0 (Falla por CHECK constraint failed: cantidad > 0)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440001', 2, 0, 920000);

-- C7.b) Intento de insertar un producto inexistente id = 9999 (Falla por FOREIGN KEY constraint failed)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('550e8400-e29b-41d4-a716-446655440001', 9999, 1, 500000);

-- Verificación de que el Caso C7 no dejó filas inválidas (siguen existiendo solo los 2 ítems originales)
SELECT id_local, producto_id, cantidad, precio_centavos_visto
FROM item_borrador
WHERE id_local = '550e8400-e29b-41d4-a716-446655440001';
