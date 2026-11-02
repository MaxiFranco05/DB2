-- ============================================================
-- SCRIPTS DE PRUEBA PARA RESTRICCIONES DE NEGOCIO
-- Archivo: db/test_restricciones.sql
-- Ejecutar: psql -U postgres -d food_store_test -f db/test_restricciones.sql
-- Usa DO block PL/pgSQL para evitar problemas de variables en script
-- ============================================================

\set ON_ERROR_STOP off
\echo '=== INICIO PRUEBAS RESTRICCIONES ==='

DO $$
DECLARE
    v_test_user_id        BIGINT;
    v_pedido_pendiente_id BIGINT;
    v_pedido_terminado_id BIGINT;
    v_pedido_cancelado_id BIGINT;
    v_prod_activo_id      BIGINT;
    v_prod_inactivo_id    BIGINT;
    v_prod_stock_bajo_id  BIGINT;
    v_prod_stock_cero_id  BIGINT;
    v_pedido_nuevo_id     BIGINT;
    v_error_text          TEXT;
BEGIN
    -- ------------------------------------------------------------
    -- SETUP: Crear datos de prueba
    -- ------------------------------------------------------------
    RAISE NOTICE '--- SETUP: Creando datos de prueba ---';

    INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
    VALUES ('Test', 'User', 'test_' || extract(epoch from now()) || '@example.com', '11111111', 'pass')
    ON CONFLICT (mail) DO NOTHING
    RETURNING id INTO v_test_user_id;

    IF v_test_user_id IS NULL THEN
        SELECT id INTO v_test_user_id FROM usuario WHERE mail LIKE 'test_%@example.com' ORDER BY id DESC LIMIT 1;
    END IF;

    RAISE NOTICE 'Usuario ID: %', v_test_user_id;

    INSERT INTO pedido (forma_pago, usuario_id, estado)
    VALUES ('EFECTIVO', v_test_user_id, 'PENDIENTE')
    RETURNING id INTO v_pedido_pendiente_id;

    INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
    VALUES ('Prod Test Activo', 'Desc', 100.00, 10, TRUE, 1)
    RETURNING id INTO v_prod_activo_id;

    INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
    VALUES ('Prod Test Inactivo', 'Desc', 200.00, 5, FALSE, 1)
    RETURNING id INTO v_prod_inactivo_id;

    INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
    VALUES ('Prod Test Stock Bajo', 'Desc', 50.00, 3, TRUE, 1)
    RETURNING id INTO v_prod_stock_bajo_id;

    INSERT INTO pedido (forma_pago, usuario_id, estado)
    VALUES ('TARJETA', v_test_user_id, 'TERMINADO')
    RETURNING id INTO v_pedido_terminado_id;

    INSERT INTO pedido (forma_pago, usuario_id, estado)
    VALUES ('TRANSFERENCIA', v_test_user_id, 'CANCELADO')
    RETURNING id INTO v_pedido_cancelado_id;

    RAISE NOTICE 'Setup completado.';


    -- ------------------------------------------------------------
    -- TEST REGLA 1: Máquina de estados (pedido.estado)
    -- ------------------------------------------------------------
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST REGLA 1: Máquina de estados ===';

    -- Test 1.1: TERMINADO -> PENDIENTE (DEBE FALLAR)
    RAISE NOTICE 'Test 1.1: UPDATE TERMINADO -> PENDIENTE (esperado: ERROR)';
    BEGIN
        UPDATE pedido SET estado = 'PENDIENTE' WHERE id = v_pedido_terminado_id;
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;

    -- Test 1.2: CANCELADO -> CONFIRMADO (DEBE FALLAR)
    RAISE NOTICE 'Test 1.2: UPDATE CANCELADO -> CONFIRMADO (esperado: ERROR)';
    BEGIN
        UPDATE pedido SET estado = 'CONFIRMADO' WHERE id = v_pedido_cancelado_id;
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;

    -- Test 1.3: PENDIENTE -> CONFIRMADO (DEBE FUNCIONAR)
    RAISE NOTICE 'Test 1.3: UPDATE PENDIENTE -> CONFIRMADO (esperado: OK)';
    BEGIN
        UPDATE pedido SET estado = 'CONFIRMADO' WHERE id = v_pedido_pendiente_id;
        RAISE NOTICE '  RESULTADO: OK (esperado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (inesperado) - %', SQLERRM;
    END;

    -- Test 1.4: CONFIRMADO -> TERMINADO (DEBE FUNCIONAR)
    RAISE NOTICE 'Test 1.4: UPDATE CONFIRMADO -> TERMINADO (esperado: OK)';
    BEGIN
        UPDATE pedido SET estado = 'TERMINADO' WHERE id = v_pedido_pendiente_id;
        RAISE NOTICE '  RESULTADO: OK (esperado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (inesperado) - %', SQLERRM;
    END;

    -- Test 1.5: TERMINADO (recién puesto) -> CANCELADO (DEBE FALLAR)
    RAISE NOTICE 'Test 1.5: UPDATE TERMINADO -> CANCELADO (esperado: ERROR)';
    BEGIN
        UPDATE pedido SET estado = 'CANCELADO' WHERE id = v_pedido_pendiente_id;
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;


    -- ------------------------------------------------------------
    -- TEST REGLA 2: Catálogo activo (producto.activo = FALSE)
    -- ------------------------------------------------------------
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST REGLA 2: Catálogo activo ===';

    -- Test 2.1: Insertar con producto ACTIVO (DEBE FUNCIONAR)
    RAISE NOTICE 'Test 2.1: INSERT producto ACTIVO (esperado: OK)';
    BEGIN
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_pendiente_id, v_prod_activo_id, 2);
        RAISE NOTICE '  RESULTADO: OK (esperado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (inesperado) - %', SQLERRM;
    END;

    -- Test 2.2: Insertar con producto INACTIVO (DEBE FALLAR)
    RAISE NOTICE 'Test 2.2: INSERT producto INACTIVO (esperado: ERROR)';
    BEGIN
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_pendiente_id, v_prod_inactivo_id, 1);
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;

    -- Test 2.3: Cambiar a INACTIVO y luego insertar (DEBE FALLAR)
    RAISE NOTICE 'Test 2.3: Cambiar a INACTIVO y luego INSERT (esperado: ERROR)';
    BEGIN
        UPDATE producto SET activo = FALSE WHERE id = v_prod_activo_id;
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_pendiente_id, v_prod_activo_id, 1);
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;


    -- ------------------------------------------------------------
    -- TEST REGLA 3: Control de stock (cantidad > stock)
    -- ------------------------------------------------------------
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST REGLA 3: Control de stock ===';

    -- Test 3.1: Insertar cantidad = stock (3) (DEBE FUNCIONAR)
    RAISE NOTICE 'Test 3.1: INSERT cantidad = stock (3) (esperado: OK)';
    BEGIN
        INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('EFECTIVO', v_test_user_id, 'PENDIENTE')
        RETURNING id INTO v_pedido_nuevo_id;
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_nuevo_id, v_prod_stock_bajo_id, 3);
        RAISE NOTICE '  RESULTADO: OK (esperado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (inesperado) - %', SQLERRM;
    END;

    -- Test 3.2: Insertar cantidad < stock (1) (DEBE FUNCIONAR)
    RAISE NOTICE 'Test 3.2: INSERT cantidad < stock (1) (esperado: OK)';
    BEGIN
        INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('EFECTIVO', v_test_user_id, 'PENDIENTE')
        RETURNING id INTO v_pedido_nuevo_id;
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_nuevo_id, v_prod_stock_bajo_id, 1);
        RAISE NOTICE '  RESULTADO: OK (esperado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (inesperado) - %', SQLERRM;
    END;

    -- Test 3.3: Insertar cantidad > stock (5 > 3) (DEBE FALLAR)
    RAISE NOTICE 'Test 3.3: INSERT cantidad > stock (5 > 3) (esperado: ERROR)';
    BEGIN
        INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('EFECTIVO', v_test_user_id, 'PENDIENTE')
        RETURNING id INTO v_pedido_nuevo_id;
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_nuevo_id, v_prod_stock_bajo_id, 5);
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;

    -- Test 3.4: Stock 0 -> INSERT 1 (DEBE FALLAR)
    RAISE NOTICE 'Test 3.4: Producto stock 0, INSERT 1 (esperado: ERROR)';
    BEGIN
        INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
        VALUES ('Prod Test Stock Cero', 'Desc', 10.00, 0, TRUE, 1)
        RETURNING id INTO v_prod_stock_cero_id;
        INSERT INTO pedido (forma_pago, usuario_id, estado) VALUES ('EFECTIVO', v_test_user_id, 'PENDIENTE')
        RETURNING id INTO v_pedido_nuevo_id;
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_nuevo_id, v_prod_stock_cero_id, 1);
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  RESULTADO: ERROR (esperado) - %', SQLERRM;
    END;


    -- ------------------------------------------------------------
    -- TEST ORDEN TRIGGERS: Validaciones antes que subtotal
    -- ------------------------------------------------------------
    RAISE NOTICE '';
    RAISE NOTICE '=== TEST ORDEN TRIGGERS ===';

    SELECT id INTO v_pedido_nuevo_id
    FROM pedido WHERE usuario_id = v_test_user_id AND estado = 'PENDIENTE'
    ORDER BY id DESC LIMIT 1;

    RAISE NOTICE 'Test orden: INSERT cantidad > stock (debe fallar por stock, no subtotal)';
    BEGIN
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_nuevo_id, v_prod_activo_id, 999999);
        RAISE NOTICE '  RESULTADO: OK (inesperado - debería haber fallado por stock)';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Stock insuficiente%' THEN
            RAISE NOTICE '  RESULTADO: ERROR por STOCK (esperado, orden correcto) - %', SQLERRM;
        ELSE
            RAISE NOTICE '  RESULTADO: ERROR por OTRO - %', SQLERRM;
        END IF;
    END;

END $$;


-- ------------------------------------------------------------
-- VERIFICACIÓN FINAL: Triggers creados y orden
-- ------------------------------------------------------------
\echo ''
\echo '=== VERIFICACIÓN TRIGGERS (orden de ejecución) ==='

SELECT trigger_name, event_manipulation, event_object_table, action_order
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, action_order;


-- ------------------------------------------------------------
-- RESUMEN
-- ------------------------------------------------------------
\echo ''
\echo '=== PRUEBAS COMPLETADAS ==='
\echo 'Ejecuta ROLLBACK; para descartar cambios (por defecto).'
\echo ''
\echo 'RESUMEN ESPERADO:'
\echo '  REGLA 1: Tests 1.1, 1.2, 1.5 = ERROR; Tests 1.3, 1.4 = OK'
\echo '  REGLA 2: Test 2.1 = OK; Tests 2.2, 2.3 = ERROR'
\echo '  REGLA 3: Tests 3.1, 3.2 = OK; Tests 3.3, 3.4 = ERROR'
\echo '  ORDEN: Error por "Stock insuficiente" (Regla 3), no por subtotal'