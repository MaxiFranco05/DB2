# Protección de Datos Personales: Anonimización y Verificación de Equivalencia (Parte D)

**Asignatura:** Base de Datos II — Unidad 5  
**Proyecto:** Food Store (`food_store_copia`)  
**Integrantes:** Máximo, Andrés y Octavio  

---

## 1. Estrategia de anonimización determinista en `usuario_anon` (Punto D.1)

El script `sql/usuario_anon.sql` construye la tabla `usuario_anon` a partir de las 20.000 filas de `usuario` aplicando reglas de seudonimización y enmascaramiento deterministas:

| Columna | Transformación aplicada en `usuario_anon` | Qué protege y qué preserva |
| :--- | :--- | :--- |
| `id` | Se conserva el `BIGINT` (`u.id`) | Preserva la integridad referencial para cruzar con `pedido` sin revelar la identidad civil del cliente. |
| `nombre` | `'Nombre_Sintetico_' \|\| SUBSTR(MD5(u.id::text \|\| '_nombre'), 1, 8)` | Oculta el nombre real de pila con un valor determinista reproducible. |
| `apellido` | `'Apellido_Sintetico_' \|\| SUBSTR(MD5(u.id::text \|\| '_apellido'), 1, 8)` | Oculta el apellido real con un valor determinista reproducible. |
| `mail` | `'usr_' \|\| LPAD(u.id::text, 5, '0') \|\| '@' \|\| SPLIT_PART(u.mail, '@', 2)` | Reemplaza la parte local identificable del correo manteniendo la unicidad (`UNIQUE`) y preservando el dominio (`@test.com`) para análisis estadísticos. |
| `celular` | `SUBSTR(u.celular, 1, 4) \|\| 'XXXXXX'` | Enmascara los últimos 6 dígitos del teléfono móvil, conservando solo el prefijo de área/característica (`2614`, `2615`, `2616`). |
| `contrasena` | `'HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD'` | Elimina por completo el hash real de `pgcrypto` para impedir ataques de diccionario offline en entornos de prueba o IA. |
| `rol_usuario` y `fecha_alta` | Se conservan sin alteración (`CLIENTE_ESTANDAR`, `FRECUENTE`, `VIP` y `DATE`) | Son atributos analíticos no identificables individualmente que permiten mantener intactas las distribuciones agregadas. |

Muestra de las primeras 5 filas generadas en `usuario_anon`:
```text
 id |          nombre           |          apellido           |        mail        |  celular   |                 contrasena                 |   rol_usuario    | fecha_alta 
----+---------------------------+-----------------------------+--------------------+------------+--------------------------------------------+------------------+------------
  1 | Nombre_Sintetico_cebc9652 | Apellido_Sintetico_788fe686 | usr_00001@test.com | 2616XXXXXX | HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD | CLIENTE_ESTANDAR | 2026-01-08
  2 | Nombre_Sintetico_4d5a2e90 | Apellido_Sintetico_d979d445 | usr_00002@test.com | 2614XXXXXX | HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD | CLIENTE_ESTANDAR | 2026-01-15
  3 | Nombre_Sintetico_2bc9afed | Apellido_Sintetico_b7ef0a59 | usr_00003@test.com | 2614XXXXXX | HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD | CLIENTE_ESTANDAR | 2026-01-22
  4 | Nombre_Sintetico_9f105e8c | Apellido_Sintetico_eb0388ed | usr_00004@test.com | 2614XXXXXX | HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD | CLIENTE_ESTANDAR | 2026-01-29
  5 | Nombre_Sintetico_41f80cea | Apellido_Sintetico_f4b9321d | usr_00005@test.com | 2615XXXXXX | HASH_DESCARTADO_POR_POLITICA_DE_PRIVACIDAD | FRECUENTE        | 2026-02-05
```

---

## 2. Consultas de agregación generadas con OpenCode (Punto D.2)

### Consulta A — Sobre la tabla anonimizada (`usuario_anon`):
```sql
SELECT
    TO_CHAR(DATE_TRUNC('month', ua.fecha_alta), 'YYYY-MM') AS mes_alta,
    ua.rol_usuario,
    SPLIT_PART(ua.mail, '@', 2)                            AS dominio_mail,
    COUNT(*)                                               AS cantidad_usuarios
FROM usuario_anon ua
GROUP BY 1, 2, 3
ORDER BY 1 ASC, 2 ASC;
```

### Consulta B — Equivalente sobre la tabla real (`usuario`):
```sql
SELECT
    TO_CHAR(DATE_TRUNC('month', u.fecha_alta), 'YYYY-MM') AS mes_alta,
    u.rol_usuario,
    SPLIT_PART(u.mail, '@', 2)                            AS dominio_mail,
    COUNT(*)                                              AS cantidad_usuarios
FROM usuario u
GROUP BY 1, 2, 3
ORDER BY 1 ASC, 2 ASC;
```

---

## 3. Verificación de equivalencia lado a lado y con `EXCEPT` (Punto D.3)

### Comparativa lado a lado de los resultados ejecutados en PostgreSQL (27 grupos, 20.000 usuarios totales):

| `mes_alta` | `rol_usuario` | `dominio_mail` | Conteo en `usuario_anon` | Conteo en `usuario` (Real) | ¿Coincide? |
| :---: | :--- | :---: | :---: | :---: | :---: |
| `2026-01` | `CLIENTE_ESTANDAR` | `test.com` | `1780` | `1780` | ✅ Idéntico |
| `2026-01` | `FRECUENTE` | `test.com` | `370` | `370` | ✅ Idéntico |
| `2026-01` | `VIP` | `test.com` | `148` | `148` | ✅ Idéntico |
| `2026-02` | `CLIENTE_ESTANDAR` | `test.com` | `1705` | `1705` | ✅ Idéntico |
| `2026-02` | `FRECUENTE` | `test.com` | `297` | `297` | ✅ Idéntico |
| `2026-02` | `VIP` | `test.com` | `74` | `74` | ✅ Idéntico |
| `2026-03` | `CLIENTE_ESTANDAR` | `test.com` | `1853` | `1853` | ✅ Idéntico |
| `2026-03` | `FRECUENTE` | `test.com` | `334` | `334` | ✅ Idéntico |
| `2026-03` | `VIP` | `test.com` | `111` | `111` | ✅ Idéntico |
| `2026-04` | `CLIENTE_ESTANDAR` | `test.com` | `1780` | `1780` | ✅ Idéntico |
| `2026-04` | `FRECUENTE` | `test.com` | `334` | `334` | ✅ Idéntico |
| `2026-04` | `VIP` | `test.com` | `111` | `111` | ✅ Idéntico |
| `2026-05` | `CLIENTE_ESTANDAR` | `test.com` | `1778` | `1778` | ✅ Idéntico |
| `2026-05` | `FRECUENTE` | `test.com` | `370` | `370` | ✅ Idéntico |
| `2026-05` | `VIP` | `test.com` | `149` | `149` | ✅ Idéntico |
| `2026-06` | `CLIENTE_ESTANDAR` | `test.com` | `1776` | `1776` | ✅ Idéntico |
| `2026-06` | `FRECUENTE` | `test.com` | `333` | `333` | ✅ Idéntico |
| `2026-06` | `VIP` | `test.com` | `111` | `111` | ✅ Idéntico |
| `2026-07` | `CLIENTE_ESTANDAR` | `test.com` | `1850` | `1850` | ✅ Idéntico |
| `2026-07` | `FRECUENTE` | `test.com` | `333` | `333` | ✅ Idéntico |
| `2026-07` | `VIP` | `test.com` | `111` | `111` | ✅ Idéntico |
| `2026-08` | `CLIENTE_ESTANDAR` | `test.com` | `1850` | `1850` | ✅ Idéntico |
| `2026-08` | `FRECUENTE` | `test.com` | `333` | `333` | ✅ Idéntico |
| `2026-08` | `VIP` | `test.com` | `111` | `111` | ✅ Idéntico |
| `2026-09` | `CLIENTE_ESTANDAR` | `test.com` | `1628` | `1628` | ✅ Idéntico |
| `2026-09` | `FRECUENTE` | `test.com` | `296` | `296` | ✅ Idéntico |
| `2026-09` | `VIP` | `test.com` | `74` | `74` | ✅ Idéntico |

### Prueba formal de diferencia simétrica con `EXCEPT`:
```sql
WITH agregados_anon AS (
    SELECT TO_CHAR(DATE_TRUNC('month', ua.fecha_alta), 'YYYY-MM') AS mes_alta,
           ua.rol_usuario, SPLIT_PART(ua.mail, '@', 2) AS dominio_mail, COUNT(*) AS cantidad_usuarios
    FROM usuario_anon ua GROUP BY 1, 2, 3
),
agregados_real AS (
    SELECT TO_CHAR(DATE_TRUNC('month', u.fecha_alta), 'YYYY-MM') AS mes_alta,
           u.rol_usuario, SPLIT_PART(u.mail, '@', 2) AS dominio_mail, COUNT(*) AS cantidad_usuarios
    FROM usuario u GROUP BY 1, 2, 3
)
(SELECT * FROM agregados_anon EXCEPT SELECT * FROM agregados_real)
UNION ALL
(SELECT * FROM agregados_real EXCEPT SELECT * FROM agregados_anon);
```

Salida obtenida en el motor:
```text
 mes_alta | rol_usuario | dominio_mail | cantidad_usuarios 
----------+-------------+--------------+-------------------
(0 filas)
```

---

## 4. Frontera de privacidad: qué información nunca debe enviarse a un asistente de IA sin anonimizar (Punto D.4)

Nunca deben salir hacia un asistente de inteligencia artificial externo ni incluirse en prompts, capturas de resultados o fragmentos de logs los **datos personales identificables (PII)** de la tabla `usuario` —concretamente las columnas `nombre`, `apellido`, la parte local de `mail` y el número completo de `celular`—, dado que permiten identificar o contactar de forma directa a personas reales y están alcanzados por el deber de confidencialidad y protección de datos personales. Tampoco deben exponerse jamás los hashes o credenciales de `usuario.contrasena`, las contraseñas reales de conexión de roles (`.env` / `ALTER ROLE ... PASSWORD`) ni las direcciones IP públicas o rutas sensibles del servidor sin antes sustituirlos por valores sintéticos deterministas como los aplicados en `usuario_anon` y en `log_simulacro_anonimizado.txt`.
