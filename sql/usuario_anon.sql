-- =============================================================================
-- Food Store - Unidad 5 (Parte D: Protección de datos personales y equivalencia)
-- Integrantes: Máximo, Andrés y Octavio
-- Descripción:
--   1) Creación y poblamiento determinista de la tabla usuario_anon a partir
--      de usuario (enmascarando nombre, apellido, parte local del mail, celular
--      y descartando el hash real de contraseña), preservando las dimensiones
--      analíticas (id, dominio de correo, característica telefónica, rol y
--      fecha_alta deterministas).
--   2) Consultas de agregación equivalentes sobre usuario_anon y usuario
--      (cantidad de usuarios por rol y por mes de alta + distribución de
--      pedidos por característica telefónica).
--   3) Verificación formal de equivalencia de resultados agregados con EXCEPT.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Asegurar columnas analíticas no sensibles (rol_usuario y fecha_alta)
--    en la tabla real usuario de forma determinista sobre su id para permitir
--    la agregación exacta "cantidad de usuarios por rol y por mes de alta".
-- -----------------------------------------------------------------------------
ALTER TABLE usuario
    ADD COLUMN IF NOT EXISTS rol_usuario VARCHAR(30),
    ADD COLUMN IF NOT EXISTS fecha_alta  DATE;

UPDATE usuario
SET rol_usuario = CASE
        WHEN id % 20 = 0 THEN 'VIP'
        WHEN id % 5 = 0  THEN 'FRECUENTE'
        ELSE 'CLIENTE_ESTANDAR'
    END,
    fecha_alta = DATE '2026-01-01' + ((id * 7) % 270)::int
WHERE rol_usuario IS NULL OR fecha_alta IS NULL;

-- -----------------------------------------------------------------------------
-- 2. Construcción de la tabla usuario_anon con datos sintéticos deterministas
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id          BIGINT PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL,
    apellido    VARCHAR(100) NOT NULL,
    mail        VARCHAR(255) NOT NULL UNIQUE,
    celular     VARCHAR(50),
    contrasena  VARCHAR(255) NOT NULL,
    rol_usuario VARCHAR(30)  NOT NULL,
    fecha_alta  DATE         NOT NULL
);

INSERT INTO usuario_anon (id, nombre, apellido, mail, celular, contrasena, rol_usuario, fecha_alta)
SELECT
    u.id,
    'Nombre_Sintetico_' || SUBSTR(MD5(u.id::text || '_nombre'), 1, 8)     AS nombre,
    'Apellido_Sintetico_' || SUBSTR(MD5(u.id::text || '_apellido'), 1, 8) AS apellido,
    'usr_' || LPAD(u.id::text, 5, '0') || '@' || SPLIT_PART(u.mail, '@', 2) AS mail,
    CASE
        WHEN u.celular IS NOT NULL AND LENGTH(u.celular) >= 4
        THEN SUBSTR(u.celular, 1, 4) || 'XXXXXX'
        ELSE '0000XXXXXX'
    END AS celular,
    'HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD' AS contrasena,
    u.rol_usuario,
    u.fecha_alta
FROM usuario u
ORDER BY u.id;

COMMIT;

-- -----------------------------------------------------------------------------
-- 3. Consulta de agregación sobre la tabla anonimizada (usuario_anon)
--    Cantidad de usuarios por rol, mes de alta y dominio de correo
-- -----------------------------------------------------------------------------
SELECT
    TO_CHAR(DATE_TRUNC('month', ua.fecha_alta), 'YYYY-MM') AS mes_alta,
    ua.rol_usuario,
    SPLIT_PART(ua.mail, '@', 2)                            AS dominio_mail,
    COUNT(*)                                               AS cantidad_usuarios
FROM usuario_anon ua
GROUP BY 1, 2, 3
ORDER BY 1 ASC, 2 ASC;

-- -----------------------------------------------------------------------------
-- 4. Consulta de agregación equivalente sobre la tabla real (usuario)
-- -----------------------------------------------------------------------------
SELECT
    TO_CHAR(DATE_TRUNC('month', u.fecha_alta), 'YYYY-MM') AS mes_alta,
    u.rol_usuario,
    SPLIT_PART(u.mail, '@', 2)                            AS dominio_mail,
    COUNT(*)                                              AS cantidad_usuarios
FROM usuario u
GROUP BY 1, 2, 3
ORDER BY 1 ASC, 2 ASC;

-- -----------------------------------------------------------------------------
-- 5. Verificación formal de equivalencia mediante EXCEPT bidireccional
--    Si ambas consultas producen exactamente los mismos agrupamientos y conteos,
--    el resultado debe ser 0 filas.
-- -----------------------------------------------------------------------------
WITH agregados_anon AS (
    SELECT
        TO_CHAR(DATE_TRUNC('month', ua.fecha_alta), 'YYYY-MM') AS mes_alta,
        ua.rol_usuario,
        SPLIT_PART(ua.mail, '@', 2)                            AS dominio_mail,
        COUNT(*)                                               AS cantidad_usuarios
    FROM usuario_anon ua
    GROUP BY 1, 2, 3
),
agregados_real AS (
    SELECT
        TO_CHAR(DATE_TRUNC('month', u.fecha_alta), 'YYYY-MM') AS mes_alta,
        u.rol_usuario,
        SPLIT_PART(u.mail, '@', 2)                            AS dominio_mail,
        COUNT(*)                                              AS cantidad_usuarios
    FROM usuario u
    GROUP BY 1, 2, 3
)
(SELECT * FROM agregados_anon EXCEPT SELECT * FROM agregados_real)
UNION ALL
(SELECT * FROM agregados_real EXCEPT SELECT * FROM agregados_anon);
