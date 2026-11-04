-- =============================================================================
-- Food Store - Unidad 5 (Parte A: Diseño e implementación de roles y permisos)
-- Integrantes: Máximo, Andrés y Octavio
-- Descripción: Esquema de roles de grupo y de login bajo el principio de
--              mínimo privilegio, permisos a nivel de columna y políticas de
--              herencia para tablas futuras (ALTER DEFAULT PRIVILEGES).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0. Vista agregada de negocio para el rol de reportes (sin datos sensibles)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_ventas_por_categoria AS
SELECT
    c.id AS categoria_id,
    c.nombre AS categoria,
    COUNT(DISTINCT dp.pedido_id) AS cantidad_pedidos,
    COALESCE(SUM(dp.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM(dp.subtotal), 0.00) AS total_facturado
FROM categoria c
LEFT JOIN producto pr ON pr.categoria_id = c.id
LEFT JOIN detalle_pedido dp ON dp.producto_id = pr.id
GROUP BY c.id, c.nombre;

-- -----------------------------------------------------------------------------
-- 1. Creación idempotente de Roles de Grupo (NOLOGIN) y Roles de Login
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    -- Roles de grupo (sin login)
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    ELSE
        ALTER ROLE rol_app_lectura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    ELSE
        ALTER ROLE rol_app_escritura NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    ELSE
        ALTER ROLE rol_soporte NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    ELSE
        ALTER ROLE rol_reportes NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;

    -- Roles de login
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web WITH LOGIN PASSWORD 'AppWeb_Segura2026' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
    ELSE
        ALTER ROLE app_web WITH LOGIN PASSWORD 'AppWeb_Segura2026' NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos WITH LOGIN PASSWORD 'Admin_Seguro2026' NOSUPERUSER NOCREATEDB CREATEROLE INHERIT;
    ELSE
        ALTER ROLE admin_datos WITH LOGIN PASSWORD 'Admin_Seguro2026' NOSUPERUSER NOCREATEDB CREATEROLE INHERIT;
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 2. Limpieza preventiva de privilegios previos (REVOKE)
--    Garantiza que ningún rol conserve permisos amplios de pruebas anteriores
--    (como el GRANT INSERT, UPDATE, DELETE ON ALL TABLES de la Clase 1).
-- -----------------------------------------------------------------------------
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, app_web, admin_datos;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, app_web, admin_datos;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, app_web, admin_datos;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, app_web, admin_datos;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, app_web, admin_datos;

-- -----------------------------------------------------------------------------
-- 3. Permisos para rol_app_lectura (Lectura sobre tablas operativas)
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
GRANT SELECT ON TABLE categoria, producto, pedido, detalle_pedido, usuario TO rol_app_lectura;

-- Política para tablas futuras: heredan SELECT para rol_app_lectura
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

-- -----------------------------------------------------------------------------
-- 4. Permisos para rol_app_escritura (Escritura transaccional acotada)
--    Corrección respecto a Clase 1: se rechaza GRANT INSERT, UPDATE, DELETE ON ALL TABLES
--    y se otorgan únicamente los privilegios de tabla y columna necesarios.
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_app_escritura;
GRANT INSERT ON TABLE pedido, detalle_pedido TO rol_app_escritura;
GRANT UPDATE (stock) ON TABLE producto TO rol_app_escritura;
GRANT UPDATE (estado) ON TABLE pedido TO rol_app_escritura;
GRANT DELETE ON TABLE detalle_pedido TO rol_app_escritura;

-- Si existe la tabla de auditoría o resumen desnormalizado disparado por triggers, permitir inserción/actualización
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'auditoria') THEN
        EXECUTE 'GRANT INSERT ON TABLE auditoria TO rol_app_escritura';
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE auditoria_id_seq TO rol_app_escritura';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ventas_diarias_categoria') THEN
        EXECUTE 'GRANT SELECT, INSERT, UPDATE ON TABLE ventas_diarias_categoria TO rol_app_escritura';
    END IF;
END
$$;

-- Permisos sobre secuencias de identidad para poder insertar pedidos
GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq TO rol_app_escritura;

-- Permiso de ejecución sobre las funciones de autenticación de Clase 2 (sin acceso directo de escritura a usuario)
GRANT EXECUTE ON FUNCTION fn_autenticar(VARCHAR, VARCHAR) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION fn_resetear_password(VARCHAR, VARCHAR) TO rol_app_escritura;

-- -----------------------------------------------------------------------------
-- 5. Permisos para rol_soporte (Mínimo privilegio a nivel de columna)
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_soporte;
GRANT SELECT (id, mail) ON TABLE usuario TO rol_soporte;
GRANT SELECT ON TABLE pedido, detalle_pedido TO rol_soporte;

-- -----------------------------------------------------------------------------
-- 6. Permisos para rol_reportes (Solo lectura sobre vistas agregadas)
-- -----------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO rol_reportes;
GRANT SELECT ON TABLE v_ventas_por_categoria TO rol_reportes;

-- -----------------------------------------------------------------------------
-- 7. Asignación de membresías y privilegios a Roles de Login
-- -----------------------------------------------------------------------------
-- app_web hereda lectura y escritura operativa
GRANT rol_app_lectura, rol_app_escritura TO app_web;

-- admin_datos posee control completo sobre el esquema public y tablas futuras
GRANT USAGE, CREATE ON SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL PRIVILEGES ON SEQUENCES TO admin_datos;

COMMIT;
