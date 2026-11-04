-- =============================================================================
-- Food Store - Unidad 5 (Parte C: Laboratorio - Simulacro de incidente)
-- Integrantes: Máximo, Andrés y Octavio
-- Descripción: Secuencia controlada sobre el entorno propio de desarrollo
--              ejecutada bajo la identidad comprometida de aplicación (app_web):
--              1) Varios intentos fallidos de inicio de sesión contra fn_autenticar.
--              2) Un inicio de sesión exitoso contra fn_autenticar.
--              3) Lectura masiva (exfiltración) de la tabla usuario.
--              4) Intento de escalamiento de privilegios (otorgar membresía en
--                 admin_datos a rol_soporte/app_web y borrar tabla auditoria).
-- =============================================================================

-- Paso 1: Intentos fallidos de inicio de sesión por fuerza bruta / diccionario
SELECT fn_autenticar('usuario1@test.com', '12345678')          AS intento_1;
SELECT fn_autenticar('usuario1@test.com', 'admin2026')         AS intento_2;
SELECT fn_autenticar('usuario1@test.com', 'foodstore123')      AS intento_3;
SELECT fn_autenticar('usuario1@test.com', 'Password_Invalida') AS intento_4;

-- Paso 2: Inicio de sesión exitoso (credencial válida del usuario objetivo)
-- Nota: Al ser un SELECT que no dispara WARNING y estar log_statement = 'mod',
-- este evento exitoso ocurre en la base pero no deja línea en el log nativo.
SELECT fn_autenticar('usuario1@test.com', 'ClaveSegura_2026')  AS login_exitoso_id;

-- Paso 3: Lectura masiva (exfiltración) de la tabla usuario
-- Nota: Se leen las 20.000 filas de usuario (incluyendo mail, celular y hashes).
-- Con log_statement = 'mod', esta lectura masiva tampoco aparece en el log.
SELECT COUNT(*) AS total_usuarios_exfiltrados,
       MIN(mail) AS primer_mail_leido,
       MAX(mail) AS ultimo_mail_leido
FROM (
    SELECT id, nombre, apellido, mail, celular, contrasena
    FROM usuario
) AS exfiltracion_masiva;

-- Paso 4: Intento de escalamiento de privilegios (debe FALLAR por Parte A)
-- 4a) Intentar otorgarle al rol de bajo privilegio (app_web / rol_soporte) membresía en admin_datos
GRANT admin_datos TO rol_soporte;

-- 4b) Intentar ejecutar una operación destructiva reservada a admin_datos
DROP TABLE auditoria;
