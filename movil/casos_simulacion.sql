-- =============================================================================
-- Food Store - Trabajo Práctico N.° 8 (Consigna 2.c: Casos de simulación C2 a C6)
-- Motor: SQLite 3.37+ (con instantánea exportada desde PostgreSQL de pruebas)
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- =============================================================================

PRAGMA foreign_keys = ON;

-- Limpieza previa de borradores de prueba para corrida limpia de los casos C2 a C6
DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;

-- =============================================================================
-- 1. Armado de los 4 borradores en la tablet (con los datos iniciales de producto_cache)
--    - Producto 1: precio_centavos = 421451, stock_visto = 184, disponible = 1, eliminado = 0
--    - Producto 2: precio_centavos =  76689, stock_visto =  36, disponible = 1, eliminado = 0
--    - Producto 3: precio_centavos = 328926, stock_visto = 199, disponible = 1, eliminado = 0
--    - Producto 4: precio_centavos =  63036, stock_visto = 154, disponible = 1, eliminado = 0
-- =============================================================================
BEGIN;

-- Caso C2: Borrador sobre Producto 1 al precio original (421451 centavos)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c2000000-0000-4000-8000-000000000002', 'operador_feria', 'TARJETA', '2026-11-05T19:15:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c2000000-0000-4000-8000-000000000002', 1, 2, 421451);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c2-0001', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- Caso C3: Borrador sobre Producto 2 pidiendo 50 unidades (más de las 36 que quedan en stock)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c3000000-0000-4000-8000-000000000003', 'operador_feria', 'EFECTIVO', '2026-11-05T19:16:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c3000000-0000-4000-8000-000000000003', 2, 50, 76689);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c3-0001', 'c3000000-0000-4000-8000-000000000003', 'PENDIENTE', NULL);

-- Caso C4: Borrador sobre Producto 3 (que luego será dado de baja lógica en el servidor)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c4000000-0000-4000-8000-000000000004', 'operador_feria', 'TRANSFERENCIA', '2026-11-05T19:17:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c4000000-0000-4000-8000-000000000004', 3, 1, 328926);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c4-0001', 'c4000000-0000-4000-8000-000000000004', 'PENDIENTE', NULL);

-- Caso C5: Borrador sobre Producto 4 sin cambios (precio 63036 coincide, cantidad 3 <= stock 154, activo)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c5000000-0000-4000-8000-000000000005', 'operador_feria', 'EFECTIVO', '2026-11-05T19:18:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c5000000-0000-4000-8000-000000000005', 4, 3, 63036);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);

COMMIT;

-- =============================================================================
-- 2. En la copia del servidor (PostgreSQL) se subió el precio del Producto 1 a
--    4500.00 (450000 centavos) y se dio de baja lógica al Producto 3 (activo = false),
--    exportándose la nueva instantánea a snapshot_servidor.
--    A continuación se ejecuta el semáforo (movil/semaforo.sql) por primera vez:
--    - req-uuid-c2-0001 -> CONFLICTO
--    - req-uuid-c3-0001 -> RECHAZADO (stock insuficiente)
--    - req-uuid-c4-0001 -> RECHAZADO (baja lógica)
--    - req-uuid-c5-0001 -> SIMULADO_APROBADO
-- =============================================================================

-- =============================================================================
-- 3. Resolución de C2 (el cliente acepta el nuevo precio 450000):
--    Se actualiza precio_centavos_visto en item_borrador y se encola una
--    solicitud nueva (req-uuid-c2-0002), que al correr el semáforo da SIMULADO_APROBADO.
-- =============================================================================
-- UPDATE item_borrador SET precio_centavos_visto = 450000
-- WHERE id_local = 'c2000000-0000-4000-8000-000000000002' AND producto_id = 1;
-- INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
-- VALUES ('req-uuid-c2-0002', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- =============================================================================
-- 4. Caso C4 (Recarga del catálogo desde snapshot_servidor):
--    Al recargar producto_cache con la nueva instantánea, la fila del Producto 3
--    queda almacenada en producto_cache con eliminado = 1 y disponible = 0 (lápida),
--    por lo que ya no aparece en la consulta del catálogo disponible (C1).
-- =============================================================================

-- =============================================================================
-- 5. Caso C6 (Idempotencia: reenviar el mismo UUID y reejecutar el semáforo):
--    Intento de insertar nuevamente 'req-uuid-c5-0001' falla por UNIQUE/PRIMARY KEY,
--    y volver a correr semaforo.sql no reevalúa solicitudes que ya no están PENDIENTE.
-- =============================================================================
-- INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
-- VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);
