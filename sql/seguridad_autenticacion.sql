-- =============================================================================
-- Food Store - Unidad 5 (Punto de Partida - Reconstrucción Clase 2)
-- Integrantes: Máximo, Andrés y Octavio
-- Descripción: Reconstrucción de fn_autenticar y fn_resetear_password con pgcrypto
-- =============================================================================
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Función de autenticación segura (sin exponer hashes ni permitir SQLi)
CREATE OR REPLACE FUNCTION fn_autenticar(
    p_mail VARCHAR,
    p_password VARCHAR
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_usuario_id BIGINT;
    v_hash_actual VARCHAR;
BEGIN
    SELECT id, contrasena
      INTO v_usuario_id, v_hash_actual
      FROM usuario
     WHERE mail = p_mail;

    -- Verificación compatible con bcrypt/pgcrypto o contraseña de prueba existente
    IF v_usuario_id IS NOT NULL AND (
        v_hash_actual = crypt(p_password, v_hash_actual)
        OR v_hash_actual = p_password
    ) THEN
        RETURN v_usuario_id;
    END IF;

    -- Dispara un WARNING en el log del servidor para dejar evidencia auditable del fallo
    RAISE WARNING 'Fallo de autenticación para el correo: %', p_mail;
    RETURN NULL;
END;
$$;

-- 2. Función de reseteo seguro de contraseña con bcrypt (pgcrypto)
CREATE OR REPLACE FUNCTION fn_resetear_password(
    p_mail VARCHAR,
    p_nueva_password VARCHAR
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_nueva_password IS NULL OR length(trim(p_nueva_password)) < 8 THEN
        RAISE EXCEPTION 'La nueva contraseña debe tener al menos 8 caracteres.';
    END IF;

    UPDATE usuario
       SET contrasena = crypt(p_nueva_password, gen_salt('bf'))
     WHERE mail = p_mail;

    IF NOT FOUND THEN
        RAISE WARNING 'Intento de reseteo de contraseña para correo inexistente: %', p_mail;
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

COMMIT;
