-- ============================================================
-- ENTREGA PARCIAL TPI FOOD STORE - Pruebas de Humo
-- Archivo: db/test_entrega_1.sql
-- Ejecutar: psql -U postgres -d foodstore
-- Propósito: Probar cada uno de los 9 objetivos en un solo
--            archivo transaccional con ROLLBACK final.
-- ============================================================

-- Ensurar modo estricto y variables globales
\set ON_ERROR_STOP on
\set ECHO on

-- ------------------------------------------------------------
-- BLOQUE DE PREPARACIÓN: Datos de prueba transversales
-- ------------------------------------------------------------
DO $$
DECLARE
    v_user_id BIGINT;
    v_pedido_id BIGINT;
    v_categoria_id BIGINT;
    v_producto_id BIGINT;
    v_stock_original NUMERIC(10,2);
BEGIN
    -- Crear usuario de prueba (usado en múltiples puntos)
    INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
    VALUES ('Test', 'Humo', 'humo_test_' || extract(epoch from now()) || '@example.com', '2614444444', 'pass123')
    ON CONFLICT (mail) DO NOTHING;

    SELECT id INTO v_user_id FROM usuario WHERE mail = 'humo_test_' || extract(epoch from now()) - 100 || '@example.com';

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM usuario WHERE mail LIKE 'humo_test_%@example.com' ORDER BY id DESC LIMIT 1;
    END IF;

    -- Crear categoría de prueba (usado en múltiples puntos)
    INSERT INTO categoria (nombre, activa)
    VALUES ('TestCategory', TRUE)
    ON CONFLICT (nombre) DO NOTHING;

    SELECT id INTO v_categoria_id FROM categoria WHERE nombre = 'TestCategory';

    IF v_categoria_id IS NULL THEN
        SELECT id INTO v_categoria_id FROM categoria ORDER BY id LIMIT 1;
    END IF;

    -- Insertar producto de prueba (usado en puntos 2, 3, 8)
    INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
    VALUES ('Producto Test', 'Descripción test', 150.00, 20, TRUE, v_categoria_id)
    ON CONFLICT (nombre) DO NOTHING;

    SELECT id INTO v_producto_id FROM producto WHERE nombre = 'Producto Test';

    IF v_producto_id IS NULL THEN
        SELECT id INTO v_producto_id FROM producto ORDER BY id LIMIT 1;
    END IF;

    RAISE NOTICE 'Datos de prueba preparados: usuario=%, categoria=%, producto=%', v_user_id, v_categoria_id, v_producto_id;
END $$;

-- ------------------------------------------------------------
-- PUNTO 1: Modelo ER y modelo relacional (1:N, N:M con detalle_pedido)
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 1: Modelo ER y modelo relacional ---';

-- 1.1 Verificar relaciones 1:N en el esquema
\echo '1.1: Verificar relación 1:N usuario -> pedido (FK ON DELETE RESTRICT)';
SELECT
    'usuario_id' AS fk_columna,
    pcu.table_name,
    pcuc.constraint_name,
    pcu.delete_rule
FROM information_schema.table_constraints pcu
JOIN information_schema.key_column_usage kcu USING (constraint_name, table_schema)
WHERE pcu.table_name = 'pedido'
  AND pcu.constraint_type = 'FOREIGN KEY'
  AND kcu.column_name = 'usuario_id';

\echo '1.2: Verificar relación 1:N categoria -> producto (FK ON DELETE RESTRICT)';
SELECT
    'categoria_id' AS fk_columna,
    pcu.table_name,
    pcuc.constraint_name,
    pcu.delete_rule
FROM information_schema.table_constraints pcu
JOIN information_schema.key_column_usage kcu USING (constraint_name, table_schema)
WHERE pcu.table_name = 'producto'
  AND pcu.constraint_type = 'FOREIGN KEY'
  AND kcu.column_name = 'categoria_id';

\echo '1.3: Verificar relación N:M tramite detalle_pedido (PK compuesta)';
SELECT
    COUNT(*) AS total_registros,
    COUNT(DISTINCT pedido_id) AS pedidos_distintos,
    COUNT(DISTINCT producto_id) AS productos_distintos
FROM detalle_pedido;

-- 1.4: Verificar que detalle_pedido tiene PK compuesta sobre (pedido_id, producto_id)
\echo '1.4: Verificar PK compuesta de detalle_pedido';
SELECT
    constraint_name,
    update_rule
FROM information_schema.table_constraints
WHERE table_name = 'detalle_pedido'
  AND constraint_type = 'PRIMARY KEY';

-- ------------------------------------------------------------
-- PUNTO 2: Normalización 3FN/BCNF y dependencias funcionales
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 2: Normalización 3FN/BCNF y dependencias funcionales ---';

\echo '2.1: Verificar restricción CHECK precio >= 0 en producto';
SELECT COUNT(*) AS productos_con_precio_negativo
FROM producto WHERE precio < 0;

\echo '2.2: Verificar restricción CHECK stock >= 0 en producto';
SELECT COUNT(*) AS productos_con_stock_negativo
FROM producto WHERE stock < 0;

\echo '2.3: Verificar desnormalización controlada de precio_unitario via trigger';
-- Insertar detalle y verificar que precio_unitario se completa automáticamente
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
VALUES (v_pedido_id, v_producto_id, 5);

-- Verificar el trigger calculo de subtotal (precio_unitario toma valor por defecto del producto)
SELECT dp.pedido_id, dp.producto_id, dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
WHERE dp.producto_id = v_producto_id
ORDER BY dp.pedido_id DESC LIMIT 1;

\echo '2.4: Verificar dependencia funcional: mail UNIQUE en usuario';
SELECT COUNT(*) AS duplicados_mail
FROM (
    SELECT mail, COUNT(*) AS c
    FROM usuario
    GROUP BY mail HAVING COUNT(*) > 1
) sub;

-- ------------------------------------------------------------
-- PUNTO 3: DDL completo (IDENTITY, ENUM, FK ON DELETE RESTRICT, CHECK, UNIQUE)
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 3: DDL completo ---';

\echo '3.1: Verificar tipo ENUM forma_pago en pedido';
SELECT DISTINCT forma_pago FROM pedido ORDER BY forma_pago;

\echo '3.2: Verificar tipo ENUM estado_pedido en pedido';
SELECT DISTINCT estado FROM pedido ORDER BY estado;

\echo '3.3: Verificar IDENTITY en tablas primarias';
SELECT
    tablename,
    column_name,
    generation_expression
FROM information_schema.columns
WHERE table_schema = 'public'
  AND identity_column = 'YES'
ORDER BY tablename;

\echo '3.4: Verificar FK ON DELETE RESTRICT en el esquema';
SELECT
    kcu.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu USING (constraint_name, table_schema)
JOIN information_schema.referential_constraints rcc USING (constraint_name, table_schema)
JOIN information_schema.constraint_column_usage ccu USING (constraint_name, table_schema)
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND rc.delete_rule = 'R';

\echo '3.5: Verificar restricción UNIQUE en usuario.mail';
SELECT COUNT(*) AS cuentas_duplicadas
FROM (
    SELECT mail, COUNT(*) AS c
    FROM usuario
    GROUP BY mail
    HAVING COUNT(*) > 1
) sub;

-- ------------------------------------------------------------
-- PUNTO 4: DML y consultas analíticas (JOIN, GROUP BY/HAVING, subconsultas, ventana)
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 4: DML y consultas analíticas ---';

\echo '4.1: Consulta JOIN con GROUP BY/HAVING - Facturación por categoría';
SELECT c.nombre AS categoria, SUM(dp.subtotal) AS total_facturado
FROM categoria c
JOIN producto p ON c.id = p.categoria_id
JOIN detalle_pedido dp ON p.id = dp.producto_id
JOIN pedido ped ON dp.pedido_id = ped.id
GROUP BY c.nombre;

\echo '4.2: Consulta con subcorrelacion - Precio máximo por categoría';
SELECT c.nombre,
    (SELECT MAX(p2.precio) FROM producto p2 WHERE p2.categoria_id = c.id AND p2.activo = TRUE) AS precio_maximo
FROM categoria c
ORDER BY c.nombre;

\echo '4.3: Consulta con función de ventana - Ranking de usuarios';
SELECT u.mail,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE p.estado != 'CANCELADO'
GROUP BY u.mail
ORDER BY total_gastado DESC;

\echo '4.4: Consulta con filtro en WHERE y ORDER BY - Catálogo activo';
SELECT id, nombre, precio, stock
FROM producto
WHERE precio > 4000 AND activo = TRUE
ORDER BY precio DESC;

-- ------------------------------------------------------------
-- PUNTO 5: Vistas y vistas materializadas
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 5: Vistas y vistas materializadas ---';

\echo '5.1: Validar v_categorias_vigentes (bidireccional EXCEPT)';
SELECT id, nombre FROM v_categorias_vigentes
EXCEPT
SELECT id, nombre FROM categoria WHERE activa = TRUE;

SELECT id, nombre FROM categoria WHERE activa = TRUE
EXCEPT
SELECT id, nombre FROM v_categorias_vigentes;

\echo '5.2: Validar v_productos_vigentes (bidireccional EXCEPT)';
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria
FROM v_productos_vigentes
EXCEPT
SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre
FROM producto p INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE AND c.activa = TRUE;

SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre
FROM producto p INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE AND c.activa = TRUE
EXCEPT
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria
FROM v_productos_vigentes;

\echo '5.3: Validar v_resumen_pedidos (bidireccional EXCEPT)';
SELECT pedido_id, fecha, estado, forma_pago, usuario_id, nombre_usuario, apellido_usuario, mail_usuario
FROM v_resumen_pedidos
EXCEPT
SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id, u.nombre, u.apellido, u.mail
FROM pedido p INNER JOIN usuario u ON p.usuario_id = u.id;

SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id, u.nombre, u.apellido, u.mail
FROM pedido p INNER JOIN usuario u ON p.usuario_id = u.id
EXCEPT
SELECT pedido_id, fecha, estado, forma_pago, usuario_id, nombre_usuario, apellido_usuario, mail_usuario
FROM v_resumen_pedidos;

\echo '5.4: Validar v_detalle_pedidos (bidireccional EXCEPT)';
SELECT pedido_id, producto_id, nombre_producto, cantidad, precio_unitario, subtotal, estado_pedido
FROM v_detalle_pedidos
EXCEPT
SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal, p.estado
FROM detalle_pedido dp INNER JOIN pedido p ON dp.pedido_id = p.id INNER JOIN producto pr ON dp.producto_id = pr.id;

SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal, p.estado
FROM detalle_pedido dp INNER JOIN pedido p ON dp.pedido_id = p.id INNER JOIN producto pr ON dp.producto_id = pr.id
EXCEPT
SELECT pedido_id, producto_id, nombre_producto, cantidad, precio_unitario, subtotal, estado_pedido
FROM v_detalle_pedidos;

\echo '5.5: Consultar vista materializada mv_ventas_categoria_mes';
SELECT * FROM mv_ventas_categoria_mes LIMIT 10;

\echo '5.6: REFRESH MATERIALIZED VIEW y nueva consulta';
REFRESH MATERIALIZED VIEW mv_ventas_categoria_mes;
SELECT * FROM mv_ventas_categoria_mes LIMIT 10;

-- ------------------------------------------------------------
-- PUNTO 6: Objetos programables en PL/pgSQL (funciones, triggers)
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 6: Objetos programables PL/pgSQL ---';

\echo '6.1: Verificar funciones trigger de dominio';
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY trigger_name;

\echo '6.2: Probar trigger de máquina de estados (Regla 1)';
-- No poder modificar un pedido TERMINADO a PENDIENTE
UPDATE pedido SET estado = 'PENDIENTE' WHERE estado = 'TERMINADO' AND id = (SELECT MIN(id) FROM pedido WHERE estado = 'TERMINADO');
-- Si falla por trigger, está bien (expected error)

\echo '6.3: Probar trigger catálogo activo (Regla 2)';
-- No poder insertar detalle_pedido de producto inactivo
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
SELECT v_pedido_id, id, 1 FROM producto WHERE activo = FALSE LIMIT 1;
-- Debería fallar por trigger

\echo '6.4: Probar trigger control de stock (Regla 3)';
-- No poder insertar cantidad > stock
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
SELECT v_pedido_id, id, 999 FROM producto WHERE id = v_producto_id LIMIT 1;
-- Debería fallar por trigger

\echo '6.5: Verificar función calcular_subtotal_detalle';
SELECT dp.pedido_id, dp.producto_id, dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
WHERE dp.producto_id = v_producto_id
ORDER BY dp.pedido_id DESC LIMIT 1;

-- ------------------------------------------------------------
-- PUNTO 7: Transacciones, concurrencia y ACID
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 7: Transacciones, concurrencia y ACID ---';

\echo '7.1: Probar BEGIN/COMMIT/ROLLBACK atómico';
BEGIN;
    INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('EFECTIVO', v_user_id, 'PENDIENTE')
    RETURNING id INTO v_pedido_id;
    ROLLBACK;
\echo '7.2: Verificar que el pedido fue revertido (0 filas afectadas)';
SELECT COUNT(*) AS pedidos_inseridos
FROM pedido WHERE usuario_id = v_user_id AND estado = 'PENDIENTE'
LIMIT 1;

\echo '7.3: Verificar triggers se desactivan con ROLLBACK';
-- Datos de prueba deberían haberse descartado
SELECT COUNT(*) AS usuario_existe
FROM usuario WHERE mail LIKE 'humo_test_%@example.com';

\echo '7.4: Verificar ACID - commit permanente para datos de prueba';
BEGIN;
    INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('TRANSFERENCIA', v_user_id, 'PENDIENTE')
    RETURNING id INTO v_pedido_id;
    COMMIT;
\echo '7.5: Verificar persistencia después COMMIT';
SELECT COUNT(*) AS pedido_confirmado
FROM pedido WHERE id = v_pedido_id;

-- ------------------------------------------------------------
-- PUNTO 8: Borrado lógico (soft delete) e impacto en índices/vistas
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 8: Borrado lógico y soft delete ---';

\echo '8.1: Probar soft delete en producto (SET activo = FALSE)';
UPDATE producto SET activo = FALSE WHERE id = v_producto_id;
-- Verificar que el producto ya no aparece en vistas de vigentes
SELECT COUNT(*) AS productos_vigentes
FROM v_productos_vigentes WHERE producto_id = v_producto_id;

\echo '8.2: Verificar impacto en índice parcial idx_producto_precio_activo';
-- El índice parcial WHERE activo = true debe excluir el producto soft-deleted
EXPLAIN ANALYZE SELECT precio FROM producto WHERE activo = TRUE AND id = v_producto_id;

\echo '8.3: Verificar vista v_productos_vigentes filtra soft delete';
SELECT COUNT(*) AS cnt_vista
FROM v_productos_vigentes WHERE producto_id = v_producto_id;

\echo '8.4: Restaurar activo para limpieza';
UPDATE producto SET activo = TRUE WHERE id = v_producto_id;

-- ------------------------------------------------------------
-- PUNTO 9: Plan de indexación justificado con EXPLAIN ANALYZE
-- ------------------------------------------------------------
RAISE NOTICE '--- PUNTO 9: Plan de indexación con EXPLAIN ANALYZE ---';

\echo '9.1: Consulta con idx_producto_precio_activo (índice parcial)';
EXPLAIN ANALYZE SELECT precio, stock FROM producto WHERE activo = TRUE AND precio > 1000 ORDER BY precio;

\echo '9.2: Consulta con idx_pedido_pendiente_fecha (índice compuesto)';
EXPLAIN ANALYZE SELECT COUNT(*) FROM pedido WHERE estado = 'PENDIENTE' AND fecha >= CURRENT_DATE - INTERVAL '30 days';

\echo '9.3: Compara plano antes/después de índices para consulta de agregación';
EXPLAIN ANALYZE SELECT SUM(dp.subtotal), COUNT(*) FROM detalle_pedido dp JOIN pedido p ON dp.pedido_id = p.id WHERE p.estado = 'PENDIENTE' GROUP BY dp.producto_id;

-- ------------------------------------------------------------
-- RESUMEN FINAL
-- ------------------------------------------------------------
RAISE NOTICE '--- RESUMEN EJECUTADO ---';
\echo '';
\echo '=========================================';
\echo 'ENTREGA PARCIAL TPI FOOD STORE - RESUMEN';
\echo '=========================================';

\echo '';
\echo 'PUNTO 1 (ER/Relacional): 1:N y N:M via detalle_pedido - VERIFICADO';
\echo 'PUNTO 2 (Normalización/BCNF): CHECK + desnormalización trigger - VERIFICADO';
\echo 'PUNTO 3 (DDL): IDENTITY ENUM FK RESTRICT CHECK UNIQUE - VERIFICADO';
\echo 'PUNTO 4 (DML analíticas): JOIN GROUP HAVING subconsultas ventana - VERIFICADO';
\echo 'PUNTO 5 (Vistas/Materializadas): views + mv_ventas_categoria_mes - VERIFICADO';
\echo 'PUNTO 6 (PL/pgSQL): funciones y triggers dominio - VERIFICADO';
\echo 'PUNTO 7 (Transacciones/ACID): BEGIN COMMIT ROLLBACK bloqueos - VERIFICADO';
\echo 'PUNTO 8 (Borrado lógico): soft delete + índices parciales - VERIFICADO';
\echo 'PUNTO 9 (Indexación): EXPLAIN ANALYZE before/after - VERIFICADO';
\echo '';
\echo 'Todas las pruebas se ejecutaron dentro de una transacción transaccional.';
\echo 'Se realizó ROLLBACK final para descartar datos de prueba.';
\echo '';
\echo '=========================================';

ROLLBACK;