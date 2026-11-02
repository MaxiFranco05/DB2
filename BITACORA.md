# Bitácora de Uso de Inteligencia Artificial — Trabajo Práctico Unidad 5

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store (Administración, Seguridad, Auditoría y Protección de Datos Personales)  
**Integrantes:** Máximo, Andrés y Octavio  
**Herramientas utilizadas:** Kiro (especificación y diseño), OpenCode (asistente de IA de terminal) y Git (control de versiones)

---

## Registro de interacciones y validación crítica (Formato Cátedra + Estándar DUIA)

| Prompt enviado a la IA | Respuesta relevante recibida | Validación o corrección humana aplicada |
| :--- | :--- | :--- |
| **[Etapa 0 — Reconstrucción Clase 2]**<br>*"Necesitamos reconstruir para la base `foodstore` en PostgreSQL 16+ las funciones vistas en la Clase 2: `fn_autenticar(p_mail, p_password)` y `fn_resetear_password(p_mail, p_nueva_password)` utilizando la extensión `pgcrypto` (`crypt` y `gen_salt('bf')`) con `SECURITY DEFINER` para que el rol de aplicación pueda invocarlas sin requerir acceso directo a los hashes de la tabla `usuario`."* | La IA generó el bloque DDL con `CREATE EXTENSION IF NOT EXISTS pgcrypto;` y las dos funciones en PL/pgSQL marcadas como `SECURITY DEFINER`:\n1. `fn_autenticar`: busca el `id` y `contrasena` por `mail` y compara con `crypt(p_password, v_hash_actual)`.\n2. `fn_resetear_password`: ejecuta un `UPDATE` sobre `usuario` asignando `crypt(p_nueva_password, gen_salt('bf'))` sin validaciones adicionales ni configuración de `search_path`. | **Qué se aceptó:** La estructura base en PL/pgSQL, el uso de `pgcrypto` con algoritmo Blowfish (`bf`) y el encapsulamiento mediante `SECURITY DEFINER`.<br><br>**Qué se modificó o descartó, y por qué:**<br>1. **Vulnerabilidad de `SECURITY DEFINER` sin `search_path`:** La IA omitió fijar el esquema de búsqueda. El equipo agregó `SET search_path = public` en ambas funciones para prevenir ataques de secuestro de esquema (*search_path hijacking*).<br>2. **Trazabilidad en logs para auditoría (Parte C):** Se incorporó `RAISE WARNING` ante intentos fallidos de inicio de sesión o reseteos sobre correos inexistentes para garantizar que los fallos contra `fn_autenticar` queden registrados en el log del motor.<br>3. **Política mínima de longitud:** Se agregó una validación explícita en `fn_resetear_password` que rechaza contraseñas nulas o menores a 8 caracteres.<br><br>**Verificación realizada:**<br>✅ Ejecución sin errores de `sql/seguridad_autenticacion.sql` sobre `food_store` y `food_store_copia`.<br>✅ Verificación en catálogo con `\df fn_*` confirmando la creación de ambas funciones.<br>✅ Prueba de reseteo y autenticación exitosa y fallida verificando el retorno esperado y el disparo del `WARNING`. |
