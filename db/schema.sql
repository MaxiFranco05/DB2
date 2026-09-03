-- 1. Creación de Tipos Enumerados
-- Dominios cerrados para evitar inconsistencias en los datos.
CREATE TYPE forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE', 'CONFIRMADO', 'TERMINADO', 'CANCELADO');

-- 2. Tabla Categoria
CREATE TABLE categoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE -- Se utiliza DEFAULT TRUE para manejar bajas lógicas.
);

-- 3. Tabla Usuario
CREATE TABLE usuario (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    mail VARCHAR(255) NOT NULL UNIQUE, -- Unique garantiza que el correo identifique unívocamente al cliente.
    celular VARCHAR(50),
    contrasena VARCHAR(255) NOT NULL
);

-- 4. Tabla Producto
CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10, 2) NOT NULL CHECK (precio >= 0), -- CHECK impide valores monetarios negativos.
    stock INTEGER NOT NULL CHECK (stock >= 0), -- CHECK asegura la validez del inventario.
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- Se utiliza DEFAULT TRUE para manejar bajas lógicas.
    categoria_id BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT -- RESTRICT evita borrar categorías con productos asociados para mantener el historial.
);

-- 5. Tabla Pedido
CREATE TABLE pedido (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    estado estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    forma_pago forma_pago NOT NULL,
    usuario_id BIGINT NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT -- RESTRICT evita borrar usuarios con pedidos para no perder trazabilidad histórica.
);

-- 6. Tabla Detalle_Pedido
CREATE TABLE detalle_pedido (
    pedido_id BIGINT NOT NULL REFERENCES pedido(id) ON DELETE RESTRICT,
    producto_id BIGINT NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10, 2), -- Calculado automáticamente mediante trigger para congelar el precio histórico.
    subtotal NUMERIC(10, 2),        -- Calculado automáticamente mediante trigger (cantidad * precio_unitario).
    PRIMARY KEY (pedido_id, producto_id) -- Clave primaria compuesta para asegurar la relación N:M.
);

-- 7. Creación de Índices
-- Acelera listar los productos al filtrar por una categoría específica.
CREATE INDEX idx_producto_categoria ON producto(categoria_id);
-- Acelera la búsqueda del historial de pedidos de un usuario específico.
CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);

-- 8. Función y Trigger para Subtotal
-- Función que obtiene el precio actual del producto y calcula el subtotal.
CREATE OR REPLACE FUNCTION calcular_subtotal_detalle()
RETURNS TRIGGER AS $$
DECLARE
    v_precio_actual NUMERIC(10, 2);
BEGIN
    -- Obtener el precio actual de la tabla producto
    SELECT precio INTO v_precio_actual
    FROM producto
    WHERE id = NEW.producto_id;

    -- Si no se insertó un precio_unitario, tomar el actual de la lista
    IF NEW.precio_unitario IS NULL THEN
        NEW.precio_unitario := v_precio_actual;
    END IF;

    -- Calcular el subtotal
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger que ejecuta la función antes de cada INSERT en detalle_pedido
CREATE TRIGGER trg_subtotal
BEFORE INSERT ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION calcular_subtotal_detalle();

-- 9. Carga inicial de categorías 
-- Inserción necesaria para que el script de carga masiva de pruebas (Genera_registros.sql) funcione correctamente.
INSERT INTO categoria (nombre, activa) VALUES 
('Pizzas', true),
('Bebidas', true),
('Empanadas', true),
('Hamburguesas', true),
('Postres', true);
