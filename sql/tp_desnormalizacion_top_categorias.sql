-- =====================================================================
-- Trabajo Práctico Unidad 4 - Parte 2: Desnormalización Controlada
-- Proyecto: Food Store
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 0. Limpieza previa (Idempotencia)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_actualizar_ventas_categoria ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_sincronizar_ventas ON detalle_pedido;
DROP FUNCTION IF EXISTS fn_sincronizar_ventas_diarias();
DROP TABLE IF EXISTS ventas_diarias_categoria;

-- ---------------------------------------------------------------------
-- 1. Creación de la Estructura Desnormalizada (Punto 1.3c / 5.2c)
-- ---------------------------------------------------------------------
CREATE TABLE ventas_diarias_categoria (
    fecha         DATE          NOT NULL,
    categoria_id  BIGINT        NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    total_vendido NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (fecha, categoria_id)
);

-- Índice cubriente del filtro por fecha y ordenamiento descendente por monto
CREATE INDEX idx_ventas_diarias_fecha_monto 
ON ventas_diarias_categoria (fecha, total_vendido DESC);


-- ---------------------------------------------------------------------
-- 2. Mecanismo de Sincronización Automática (Punto 1.3c / 5.2c)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sincronizar_ventas_diarias()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha_old DATE;
    v_cat_old   BIGINT;
    v_fecha_new DATE;
    v_cat_new   BIGINT;
BEGIN
    -- Si es una eliminación o actualización, descontamos el valor anterior
    IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') THEN
        SELECT p.fecha::date INTO v_fecha_old 
        FROM pedido p WHERE p.id = OLD.pedido_id;
        
        SELECT pr.categoria_id INTO v_cat_old 
        FROM producto pr WHERE pr.id = OLD.producto_id;
        
        IF v_fecha_old IS NOT NULL AND v_cat_old IS NOT NULL THEN
            UPDATE ventas_diarias_categoria
            SET total_vendido = GREATEST(0.00, total_vendido - COALESCE(OLD.subtotal, 0.00))
            WHERE fecha = v_fecha_old AND categoria_id = v_cat_old;
        END IF;
    END IF;

    -- Si es una inserción o actualización, sumamos el nuevo valor
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT p.fecha::date INTO v_fecha_new 
        FROM pedido p WHERE p.id = NEW.pedido_id;
        
        SELECT pr.categoria_id INTO v_cat_new 
        FROM producto pr WHERE pr.id = NEW.producto_id;
        
        IF v_fecha_new IS NOT NULL AND v_cat_new IS NOT NULL THEN
            INSERT INTO ventas_diarias_categoria (fecha, categoria_id, total_vendido)
            VALUES (v_fecha_new, v_cat_new, COALESCE(NEW.subtotal, 0.00))
            ON CONFLICT (fecha, categoria_id) 
            DO UPDATE SET total_vendido = ventas_diarias_categoria.total_vendido + COALESCE(EXCLUDED.total_vendido, 0.00);
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Creación del Trigger sobre la tabla detalle_pedido
CREATE TRIGGER trg_actualizar_ventas_categoria
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_sincronizar_ventas_diarias();


-- ---------------------------------------------------------------------
-- 3. Carga Inicial de Datos Históricos (Población desde la fuente de verdad)
-- ---------------------------------------------------------------------
INSERT INTO ventas_diarias_categoria (fecha, categoria_id, total_vendido)
SELECT p.fecha::date, pr.categoria_id, SUM(dp.subtotal)
FROM detalle_pedido dp
JOIN pedido p ON p.id = dp.pedido_id
JOIN producto pr ON pr.id = dp.producto_id
GROUP BY p.fecha::date, pr.categoria_id;


-- ---------------------------------------------------------------------
-- 4. Consulta del Reporte Optimizado (Punto 1.3d / 5.2d)
-- ---------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       v.total_vendido
FROM ventas_diarias_categoria v
JOIN categoria c ON c.id = v.categoria_id
WHERE v.fecha = CURRENT_DATE
ORDER BY v.total_vendido DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- 5. Script de Auditoría de Consistencia (Punto 1.3e / 5.2e)
-- Compara el resumen precalculado contra la agregación de la fuente de verdad.
-- Debe retornar 0 filas si todo está perfectamente sincronizado.
-- ---------------------------------------------------------------------
SELECT 
    COALESCE(s.fecha, r.fecha) AS fecha,
    COALESCE(s.categoria_id, r.categoria_id) AS categoria_id,
    COALESCE(s.total_vendido, 0.00) AS monto_resumen,
    COALESCE(r.total_real, 0.00) AS monto_real,
    ABS(COALESCE(s.total_vendido, 0.00) - COALESCE(r.total_real, 0.00)) AS diferencia
FROM ventas_diarias_categoria s
FULL OUTER JOIN (
    SELECT p.fecha::date AS fecha, pr.categoria_id, SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN pedido p ON p.id = dp.pedido_id
    JOIN producto pr ON pr.id = dp.producto_id
    GROUP BY p.fecha::date, pr.categoria_id
) r ON s.fecha = r.fecha AND s.categoria_id = r.categoria_id
WHERE ABS(COALESCE(s.total_vendido, 0.00) - COALESCE(r.total_real, 0.00)) > 0.01;

COMMIT;
