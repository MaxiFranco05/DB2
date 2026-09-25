-- =========================================================================
-- VALIDACIÓN MATEMÁTICA DE VISTAS MEDIANTE EXCEPT (Equivalencia Bidireccional)
-- =========================================================================

-- 1. Validar v_categorias_vigentes
SELECT id, nombre FROM v_categorias_vigentes
EXCEPT
SELECT id, nombre FROM categoria WHERE activa = TRUE;

SELECT id, nombre FROM categoria WHERE activa = TRUE
EXCEPT
SELECT id, nombre FROM v_categorias_vigentes;
-- Resultado esperado para ambas direcciones: 0 filas


-- 2. Validar v_productos_vigentes
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria 
FROM v_productos_vigentes
EXCEPT
SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre 
FROM producto p
INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE AND c.activa = TRUE;

SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre 
FROM producto p
INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE AND c.activa = TRUE
EXCEPT
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria 
FROM v_productos_vigentes;
-- Resultado esperado para ambas direcciones: 0 filas


-- 3. Validar v_resumen_pedidos
SELECT pedido_id, fecha, estado, forma_pago, usuario_id, nombre_usuario, apellido_usuario, mail_usuario 
FROM v_resumen_pedidos
EXCEPT
SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id, u.nombre, u.apellido, u.mail 
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id;

SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id, u.nombre, u.apellido, u.mail 
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id
EXCEPT
SELECT pedido_id, fecha, estado, forma_pago, usuario_id, nombre_usuario, apellido_usuario, mail_usuario 
FROM v_resumen_pedidos;
-- Resultado esperado para ambas direcciones: 0 filas


-- 4. Validar v_detalle_pedidos
SELECT pedido_id, producto_id, nombre_producto, cantidad, precio_unitario, subtotal, estado_pedido 
FROM v_detalle_pedidos
EXCEPT
SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal, p.estado 
FROM detalle_pedido dp
INNER JOIN pedido p ON dp.pedido_id = p.id
INNER JOIN producto pr ON dp.producto_id = pr.id;

SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal, p.estado 
FROM detalle_pedido dp
INNER JOIN pedido p ON dp.pedido_id = p.id
INNER JOIN producto pr ON dp.producto_id = pr.id
EXCEPT
SELECT pedido_id, producto_id, nombre_producto, cantidad, precio_unitario, subtotal, estado_pedido 
FROM v_detalle_pedidos;
-- Resultado esperado para ambas direcciones: 0 filas