BEGIN;
-- 1) Productos: 50.000 filas repartidas entre las categorías existentes
INSERT INTO producto (nombre, precio, descripcion, stock, categoria_id)
SELECT 'Producto ' || i,
(random() * 4500 + 500)::numeric(10,2),
'Producto generado para prueba de carga',
(random() * 200)::int,
(SELECT id FROM categoria ORDER BY random() LIMIT 1)
FROM generate_series(1, 50000) AS s(i);
-- 2) Usuarios: 20.000 filas
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
SELECT 'Usuario' || i, 'Apellido' || i,
'usuario' || i || '@test.com',
'261' || lpad((random()*9999999)::int::text, 7, '0'),
'hash_test'
FROM generate_series(1, 20000) AS s(i);
-- 3) Pedidos: 200.000 filas, con usuario existente elegido al azar
INSERT INTO pedido (fecha, estado, forma_pago, usuario_id)
SELECT CURRENT_DATE - (random()*365)::int,
(ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO']::estado_pedido[])
[floor(random()*4+1)],
(ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO']::forma_pago[])
[floor(random()*3+1)],
(SELECT id FROM usuario ORDER BY random() LIMIT 1)
FROM generate_series(1, 200000) AS s(i);
-- 4) Detalle de pedido: entre 1 y 4 líneas por pedido, sin repetir producto
-- (precio_unitario y subtotal los completa el trigger trg_subtotal)
INSERT INTO detalle_pedido (cantidad, producto_id, pedido_id)
SELECT cantidad, producto_id, pedido_id
FROM (
SELECT p.id AS pedido_id, pr.producto_id,
(random()*3 + 1)::int AS cantidad,
row_number() OVER (PARTITION BY p.id ORDER BY random()) AS rn,
(1 + floor(random()*4))::int AS n_lineas
FROM pedido p
CROSS JOIN LATERAL (
SELECT id AS producto_id FROM producto
ORDER BY random() LIMIT 4
) pr
) sub
WHERE rn <= n_lineas
ON CONFLICT (pedido_id, producto_id) DO NOTHING;
COMMIT;
ANALYZE producto; ANALYZE usuario; ANALYZE pedido; ANALYZE detalle_pedido;