-- =============================================================================
-- Vistas obligatorias - Parte B
-- Generado a partir de las especificaciones en .kiro/specs/
-- =============================================================================

-- ---------------------------------------------------------
-- 1. v_categorias_vigentes
--     RN-CAT-01: Filtro de baja lógica WHERE activa = TRUE
--     RN-CAT-02: WITH CHECK OPTION para mantener consistencia de la politica de baja
-- ---------------------------------------------------------
CREATE OR REPLACE VIEW v_categorias_vigentes AS
SELECT
    id,
    nombre
FROM categoria
WHERE activa = TRUE
WITH CHECK OPTION;

-- ---------------------------------------------------------
-- 2. v_productos_vigentes
--     RN-PROD-01: Filtro producto activo = TRUE
--     RN-PROD-02: Tambien categoria activa = TRUE (decision de negocio: productos
--                 de categoria inactiva no deben aparecer aunque producto.active)
--     Excluye columnas de control interno (producto.activo, categoria.activa)
-- ---------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT
    p.id               AS producto_id,
    p.nombre           AS nombre_producto,
    p.descripcion,
    p.precio,
    p.stock,
    p.categoria_id,
    c.nombre           AS nombre_categoria
FROM producto p
INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE
  AND c.activa = TRUE;

-- ---------------------------------------------------------
-- 3. v_resumen_pedidos
--     RN-PED-01: Sin filtro de baja lógica sobre pedidos (todos los estados son visibles)
--     RN-PED-02: Historial de usuarios dada de baja debe seguir siendo consultable
--     Excluye explicitamente usuario.contrasena por seguridad
-- ---------------------------------------------------------
CREATE OR REPLACE VIEW v_resumen_pedidos AS
SELECT
    p.id            AS pedido_id,
    p.fecha,
    p.estado,
    p.forma_pago,
    p.usuario_id,
    u.nombre        AS nombre_usuario,
    u.apellido      AS apellido_usuario,
    u.mail          AS mail_usuario
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id;

-- ---------------------------------------------------------
-- 4. v_detalle_pedidos
--     RN-DET-01: Sin filtro de baja lógica sobre productos en detalles historicos
--     RN-DET-02: No filtrar por estado del pedido; expondra linea de todos los pedidos
--                 para preservar trazabilidad analitica; el consumidor puede filtrar
--                 usando estado_pedido si lo requiere
--     Usa precio_unitario historico congelado de detalle_pedido
-- ---------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedidos AS
SELECT
    dp.pedido_id,
    dp.producto_id,
    pr.nombre         AS nombre_producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal,
    p.estado          AS estado_pedido
FROM detalle_pedido dp
INNER JOIN pedido   p  ON dp.pedido_id   = p.id
INNER JOIN producto pr ON dp.producto_id = pr.id;