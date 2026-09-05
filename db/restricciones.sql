BEGIN;

-- ============================================================
-- REGLAS DE NEGOCIO: TRIGGERS DE VALIDACIÓN
-- Archivo: db/restricciones.sql
-- Aplicar después de db/schema.sql
-- ============================================================

-- -----------------------------------------------------------------
-- 0. Renombrar trigger existente para control de orden de ejecución
--    PostgreSQL dispara triggers BEFORE INSERT en orden alfabético.
--    Renombramos a trg_03_... para que corra DESPUÉS de las validaciones.
-- -----------------------------------------------------------------
ALTER TRIGGER trg_subtotal ON detalle_pedido RENAME TO trg_03_calcular_subtotal;

-- ============================================================
-- REGLA 1: MÁQUINA DE ESTADOS (pedido.estado)
-- Impide actualizar estado si el valor actual (OLD) es 'CANCELADO' o 'TERMINADO'
-- ============================================================
CREATE OR REPLACE FUNCTION validar_transicion_estado_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado IN ('CANCELADO', 'TERMINADO') THEN
        RAISE EXCEPTION 'No se puede modificar el estado del pedido %: ya está %', OLD.id, OLD.estado;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_estado_pedido
BEFORE UPDATE OF estado ON pedido
FOR EACH ROW
EXECUTE FUNCTION validar_transicion_estado_pedido();

-- ============================================================
-- REGLA 2: CATÁLOGO ACTIVO (detalle_pedido → producto.activo)
-- Impide INSERT si el producto referenciado tiene activo = FALSE
-- Respeta R7 (borrado lógico)
-- ============================================================
CREATE OR REPLACE FUNCTION validar_producto_activo()
RETURNS TRIGGER AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo INTO v_activo
    FROM producto
    WHERE id = NEW.producto_id;

    IF NOT v_activo THEN
        RAISE EXCEPTION 'No se puede agregar el producto % al pedido: el producto está inactivo', NEW.producto_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_01_validar_producto_activo
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION validar_producto_activo();

-- ============================================================
-- REGLA 3: CONTROL DE STOCK (detalle_pedido.cantidad ≤ producto.stock)
-- Verifica que la cantidad a insertar no supere el stock actual
-- Complementa R5 (stock >= 0)
-- ============================================================
CREATE OR REPLACE FUNCTION validar_stock_producto()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock INTO v_stock
    FROM producto
    WHERE id = NEW.producto_id;

    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente para producto %: solicitado %, disponible %',
            NEW.producto_id, NEW.cantidad, v_stock;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_02_validar_stock
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION validar_stock_producto();

COMMIT;