# Informe de Laboratorio: Simulacro de Incidente de Acceso Indebido (Parte C)

**Asignatura:** Base de Datos II — Unidad 5  
**Proyecto:** Food Store (`food_store_copia`)  
**Integrantes:** Máximo, Andrés y Octavio  

---

## 1. Diseño y ejecución del simulacro sobre la base propia (Puntos C.1 y C.2)

Se diseñó y ejecutó el script `sql/simulacro_incidente.sql` exclusivamente sobre la instancia local de desarrollo (`food_store_copia`), conectando bajo la identidad del rol de aplicación `app_web`. La secuencia reproducida fue:

1. **Intentos fallidos de inicio de sesión contra `fn_autenticar`:** Cuatro llamadas consecutivas a `SELECT fn_autenticar('usuario1@test.com', ...)` con contraseñas erróneas (`12345678`, `admin2026`, `foodstore123`, `Password_Invalida`), que devolvieron `NULL` y dispararon cuatro eventos `WARNING` en el log del motor.
2. **Inicio de sesión exitoso:** Una quinta llamada `SELECT fn_autenticar('usuario1@test.com', 'ClaveSegura_2026')` que devolvió exitosamente el identificador `1`.
3. **Lectura masiva de la tabla `usuario` (Exfiltración):** Ejecución de una consulta `SELECT id, nombre, apellido, mail, celular, contrasena FROM usuario`, la cual leyó las **20.000 filas** de clientes registrados (gracias a que `app_web` hereda `rol_app_lectura`).
4. **Intento de escalamiento de privilegios y sabotaje de auditoría:**
   - Ejecución de `GRANT admin_datos TO rol_soporte;` para intentar otorgar membresía en el rol administrador `admin_datos` a un rol de bajo privilegio.
   - Ejecución de `DROP TABLE auditoria;` para intentar destruir el registro de auditoría.

### Verificación del fallo de escalamiento (Punto C.2):
Se verificó y dejó constancia de que **ambos intentos de escalamiento fallaron de forma inmediata**:
- Ante `GRANT admin_datos TO rol_soporte;`, PostgreSQL respondió:  
  `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos» — DETALLE: Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.`
- Ante `DROP TABLE auditoria;`, PostgreSQL respondió:  
  `ERROR: debe ser dueño de la tabla auditoria`.

Esto confirma que el diseño de mínimo privilegio implementado en la Parte A (`app_web` con `NOSUPERUSER NOCREATEROLE NOCREATEDB` y sin opción `ADMIN` sobre otros roles) contuvo efectivamente el escalamiento vertical de privilegios.

---

## 2. Extracción y anonimización del log (Punto C.3)

Antes de enviar cualquier evidencia a OpenCode, el equipo extrajo el fragmento del archivo de log correspondiente al PID `[11476]` y **anonimizó todos los datos identificables** en `docs/log_simulacro_anonimizado.txt`:
- El correo real afectado (`usuario1@test.com`) fue reemplazado de forma determinista por el identificador sintético `usr_anon_00001@foodstore.anon`.
- La ruta local del sistema de archivos del servidor fue reemplazada por `RUTA_CONFIG_ANONIMIZADA/pg_hba.conf:117`.

---

## 3. Reconstrucción solicitada a OpenCode sin contexto adicional (Punto C.4)

### Prompt enviado a OpenCode:
> *"Analizá el siguiente fragmento de log de PostgreSQL (previamente anonimizado), reconstruí cronológicamente qué ocurrió durante la sesión y proponé una hipótesis de contención."* (Se adjuntó únicamente el contenido literal de `docs/log_simulacro_anonimizado.txt`, sin mencionar el script `simulacro_incidente.sql`).

### Respuesta completa generada por la IA:
> **Reconstrucción cronológica del incidente (según el log analizado):**
> 1. **Inicio de sesión del rol de aplicación (`19:52:15 -03`, PID `11476`):** Se establece una conexión local (`host=::1`, puerto `52756`) hacia la base `food_store_copia` utilizando el rol `app_web` mediante el cliente `psql`, autenticada por el método `trust` en `pg_hba.conf`.
> 2. **Ataque de fuerza bruta fallido contra una cuenta de usuario (`19:52:15 -03`):** Dentro de la misma sesión `11476`, se registran cuatro advertencias (`WARNING`) consecutivas emitidas por la función `fn_autenticar(character varying, character varying)` informando `"Fallo de autenticación para el correo: usr_anon_00001@foodstore.anon"`. Como no se observan eventos posteriores de autenticación exitosa para ese correo, se infiere que el atacante no logró adivinar la contraseña del usuario objetivo.
> 3. **Intento fallido de escalamiento de privilegios y borrado de rastros (`19:52:15 -03`):** Al no lograr autenticarse como el usuario de aplicación, el atacante intentó aprovechar una vulnerabilidad de inyección SQL en el endpoint de login para ejecutar `GRANT admin_datos TO rol_soporte;` (rechazado con `ERROR: se ha denegado el permiso para otorgar el rol «admin_datos»`) y posteriormente intentó eliminar la tabla de trazabilidad con `DROP TABLE auditoria;` (rechazado con `ERROR: debe ser dueño de la tabla auditoria`).
> 4. **Cierre de sesión:** La sesión finaliza tras `0.066` segundos sin haber logrado comprometer datos ni alterar permisos.
>
> **Hipótesis de contención sugerida por la IA:**
> - Cambiar el método `trust` a `scram-sha-256` en `pg_hba.conf`.
> - Bloquear la cuenta `usr_anon_00001@foodstore.anon` preventivamente tras los 4 intentos fallidos y aplicar *rate limiting* en la función `fn_autenticar`.
> - Revisar y parametrizar el código del backend para mitigar la supuesta inyección SQL, dado que según el log no hubo exposición de información ni compromisos exitosos.

---

## 4. Contraste crítico: Respuesta de la IA vs. Secuencia realmente ejecutada (Punto C.5)

El equipo (Máximo, Andrés y Octavio) contrastó línea por línea la reconstrucción de la IA contra lo que efectivamente se ejecutó en `sql/simulacro_incidente.sql`, identificando aciertos, omisiones críticas y afirmaciones sin sustento:

| Criterio de evaluación | Análisis crítico del equipo (Máximo, Andrés y Octavio) |
| :--- | :--- |
| **1. Qué acertó la IA** | - Identificó correctamente el PID de la sesión (`11476`), el rol utilizado (`app_web`), el origen local (`::1`), el método `trust` en `pg_hba.conf` y la duración (`0.066 s`).<br>- Reconstruyó con exactitud los 4 intentos fallidos contra `fn_autenticar` sobre `usr_anon_00001@foodstore.anon`.<br>- Detectó los dos intentos de escalamiento/sabotaje (`GRANT admin_datos TO rol_soporte;` y `DROP TABLE auditoria;`) y confirmó que el motor los rechazó por falta de privilegios (`ADMIN OPTION` y propiedad de tabla). |
| **2. Qué omitió la IA (y por qué)** | - **Omitió el inicio de sesión exitoso (Paso 2 del script):** En la realidad, el 5° intento contra `fn_autenticar` **sí fue exitoso** y devolvió el `id = 1`. La IA no lo vio porque `fn_autenticar` solo emite `RAISE WARNING` cuando falla, y con `log_statement = 'mod'` las sentencias `SELECT` exitosas no se registran en el log.<br>- **Omitió la lectura masiva / exfiltración de las 20.000 filas de `usuario` (Paso 3 del script):** Este es el error más grave de la reconstrucción. La IA concluyó que *"no hubo exposición de información"*, cuando en realidad el atacante ejecutó `SELECT id, nombre, apellido, mail, celular, contrasena FROM usuario` y exfiltró toda la base de clientes. El log nativo en nivel `'mod'` es ciego a las lecturas (`SELECT`), lo que indujo a la IA a un **falso negativo crítico**. |
| **3. Qué afirmó la IA sin evidencia en el log** | - **Asumió una causa no sustentada (Inyección SQL en endpoint web):** La IA afirmó que el atacante explotó una inyección SQL desde un formulario web al frustrarse con el login, cuando el propio log indica explícitamente `nombre_de_aplicación=psql` y `método=trust` desde `host=::1` (fue una conexión directa por terminal local usando la identidad `app_web`).<br>- **Afirmó que el ataque fue 100% inocuo:** Basándose únicamente en la ausencia de líneas entre el 4° `WARNING` y el `GRANT`, asumió erróneamente que ningún dato había sido leído. |

---

## 5. Decisión final de contención del equipo (Punto C.6)

> **Declaración explícita de criterio humano:**  
> La siguiente decisión de contención y remediación es **tomada autónomamente por el equipo (Máximo, Andrés y Octavio) a partir de la evidencia técnica completa** (el contraste entre el log, la configuración de auditoría y los permisos de `app_web`), y **no** es una acción ejecutada automáticamente a partir de la sugerencia de la IA. De hecho, seguir a ciegas la conclusión de la IA (que asumió que no hubo fuga de datos) habría dejado expuestas las 20.000 cuentas de usuarios de Food Store.

En un caso real ante este incidente, el equipo ejecuta el siguiente plan de contención en orden de prioridad:

1. **Contención inmediata en la red y el motor (`pg_hba.conf` y sesiones):**
   - Terminar de inmediato cualquier sesión activa de `app_web` mediante `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'app_web';`.
   - Reemplazar en `pg_hba.conf` el método `trust` por `scram-sha-256` restringiendo las IPs permitidas únicamente al servidor de backend autorizado, y rotar inmediatamente la contraseña del rol `app_web` (`ALTER ROLE app_web WITH PASSWORD ...`).
2. **Respuesta ante la exfiltración masiva de `usuario` (omitida por la IA):**
   - Dado que el equipo sabe que `app_web` tiene permiso `SELECT` sobre `usuario` (vía `rol_app_lectura`) y que las 20.000 filas fueron leídas tras el acceso indebido, se debe **invalidar y forzar el reseteo masivo de las contraseñas de los usuarios finales** (especialmente la cuenta comprometida `usuario1@test.com`) y notificar el incidente de exposición de datos personales.
3. **Remediación arquitectónica de mínimo privilegio sobre `usuario`:**
   - Para evitar que una sesión comprometida de `app_web` pueda volver a ejecutar un `SELECT * FROM usuario` masivo, **revocar el `SELECT` directo de `rol_app_lectura` sobre la columna `contrasena` (o sobre toda la tabla `usuario`)**, obligando a que toda lectura de perfil o autenticación pase exclusivamente por funciones `SECURITY DEFINER` acotadas por ID (como `fn_autenticar`) y activando auditoría de lecturas sobre la tabla `usuario` (mediante `pgaudit`) o agregando un evento `RAISE LOG` de inicio exitoso dentro de `fn_autenticar`.
