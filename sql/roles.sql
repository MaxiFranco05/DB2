BEGIN;

-- 1. Crear roles de grupo (sin permisos de login)
CREATE ROLE rol_app_lectura;
CREATE ROLE rol_app_escritura;
CREATE ROLE rol_soporte;
CREATE ROLE rol_reportes;

-- 2. Permisos para rol_app_lectura (solo SELECT)
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_app_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_app_lectura;

-- 3. Permisos para rol_app_escritura (INSERT, UPDATE, DELETE)
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT INSERT, UPDATE, DELETE ON TABLES TO rol_app_escritura;

-- 4. Permisos para rol_soporte (Principio de mínimo privilegio a nivel columna)
GRANT USAGE ON SCHEMA public TO rol_soporte;
GRANT SELECT (id, mail) ON usuario TO rol_soporte; 
-- (No tiene acceso a la columna de contraseña ni a otras tablas)

-- 5. Crear roles de Login y asignarles los grupos
-- Nota: Las contraseñas en un entorno real van por variable de entorno (.env)
CREATE ROLE app_web WITH LOGIN PASSWORD 'AppWeb_Segura2026';
GRANT rol_app_lectura, rol_app_escritura TO app_web;

CREATE ROLE admin_datos WITH LOGIN CREATEDB CREATEROLE PASSWORD 'Admin_Seguro2026';
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_datos;

COMMIT;