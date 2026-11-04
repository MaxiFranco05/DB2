-- =============================================================================
-- Food Store - Unidad 5 (Parte B: Activación y prueba de la auditoría)
-- Integrantes: Máximo, Andrés y Octavio
-- Descripción: Secuencia de operaciones de prueba para verificar el registro
--              en el log nativo del servidor (log_statement = 'mod',
--              log_connections = 'on', log_disconnections = 'on') y en la
--              tabla de auditoría por triggers.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Configuración aplicada en el servidor (ejecutada por superusuario):
--    ALTER SYSTEM SET log_connections = 'on';
--    ALTER SYSTEM SET log_disconnections = 'on';
--    ALTER SYSTEM SET log_statement = 'mod';
--    ALTER SYSTEM SET log_line_prefix = '%t [%p] %u@%d %h ';
--    SELECT pg_reload_conf();
-- -----------------------------------------------------------------------------

BEGIN;

-- -----------------------------------------------------------------------------
-- 2. Operación de LECTURA (SELECT)
--    Nota técnica: Al estar configurado log_statement = 'mod', esta lectura
--    se ejecuta normalmente pero NO se vuelca al archivo de log del servidor.
-- -----------------------------------------------------------------------------
SELECT id, nombre, precio, stock
FROM producto
WHERE id = 1;

-- -----------------------------------------------------------------------------
-- 3. Operación de INSERCIÓN (INSERT)
--    Se inserta un nuevo pedido de prueba y su línea de detalle.
--    Queda registrado tanto en el log del servidor como en la tabla auditoria.
-- -----------------------------------------------------------------------------
INSERT INTO pedido (fecha, estado, forma_pago, usuario_id)
VALUES (CURRENT_TIMESTAMP, 'PENDIENTE', 'TARJETA', 1);

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
VALUES (currval(pg_get_serial_sequence('pedido', 'id')), 1, 2);

-- -----------------------------------------------------------------------------
-- 4. Operación de ACTUALIZACIÓN (UPDATE)
--    Se descuenta el stock del producto y se confirma el estado del pedido.
-- -----------------------------------------------------------------------------
UPDATE producto
SET stock = stock - 2
WHERE id = 1;

UPDATE pedido
SET estado = 'CONFIRMADO'
WHERE id = currval(pg_get_serial_sequence('pedido', 'id'));

-- -----------------------------------------------------------------------------
-- 5. Intento de inicio de sesión fallido (nivel aplicación vía fn_autenticar)
--    Además de probarse un fallo de conexión a nivel motor (FATAL: password
--    authentication failed for user "app_web"), se prueba el fallo en la
--    función de autenticación que emite un WARNING en el log.
-- -----------------------------------------------------------------------------
SELECT fn_autenticar('usuario1@test.com', 'PasswordIncorrecta_PruebaB');

COMMIT;
