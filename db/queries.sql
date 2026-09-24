-- ==============================================================================
-- queries.sql
-- Consultas de negocio y analíticas resueltas en las Semanas 3 y 4 (Food Store)
-- ==============================================================================

-- 1. Facturación histórica por categoría (TP4 - Semana 4, Parte 1)
SELECT 
    c.nombre AS categoria, 
    SUM(dp.subtotal) AS total_facturado
FROM categoria c
JOIN producto p ON c.id = p.categoria_id
JOIN detalle_pedido dp ON p.id = dp.producto_id
JOIN pedido ped ON dp.pedido_id = ped.id
GROUP BY c.nombre;

-- 2. Ranking/Historial de usuarios por gasto y cantidad (TP4 - Semana 4, Parte 1)
SELECT 
    u.mail, 
    COUNT(DISTINCT p.id) AS cantidad_pedidos, 
    SUM(dp.subtotal) AS total_gastado
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
GROUP BY u.mail
ORDER BY total_gastado DESC
LIMIT 50;

-- 3. Búsqueda de historial de usuario específico (TP4 - Semana 4, Optimizada)
SELECT 
    u.mail, 
    COUNT(DISTINCT p.id) AS cantidad_pedidos, 
    SUM(dp.subtotal) AS total_gastado
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE u.mail = 'usuario584@test.com'
GROUP BY u.mail;

-- 4. Ranking de Usuarios con Función de Ventana (TP4 - Semana 4, Parte 3)
SELECT 
    u.mail,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM usuario u
JOIN pedido p ON u.id = p.usuario_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE p.estado != 'CANCELADO'
GROUP BY u.mail
ORDER BY total_gastado DESC;

-- 5. Precio máximo por categoría con Subconsulta Correlacionada (TP4 - Semana 4, Parte 3)
SELECT 
    c.nombre,
    (
        SELECT MAX(p.precio) 
        FROM producto p 
        WHERE p.categoria_id = c.id AND p.activo = true
    ) AS precio_maximo
FROM categoria c
ORDER BY c.nombre;

-- 6. Filtro de catálogo activo de alto valor (TP3 - Semana 3, Índice parcial)
SELECT 
    id, nombre, precio, stock
FROM producto
WHERE precio > 4000 
  AND activo = true
ORDER BY precio DESC;