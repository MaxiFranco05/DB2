# Informe de Concurrencia - Trabajo Práctico 2

---

## Escenario 1: Espera por Bloqueo (FOR UPDATE)

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Espera por bloqueo con `FOR UPDATE` sobre la misma fila de la tabla `producto`. |
| **Cómo se reprodujo** | **1. Sesión A:** `BEGIN; SELECT * FROM producto WHERE id = 1 FOR UPDATE;`<br>**2. Sesión B:** `BEGIN; SELECT * FROM producto WHERE id = 1 FOR UPDATE;`<br>**3. Sesión A:** `COMMIT;` |
| **Qué se observó** | En el paso 2, la **Sesión B quedó retenida/esperando** (no devolvió filas ni finalizó la consulta). Al ejecutar el paso 3 (`COMMIT` en Sesión A), la **Sesión B respondió inmediatamente** mostrando los datos. |
| **Explicación de la IA** | *(OpenCode)*: "PostgreSQL implementa bloqueos a nivel de fila (*row-level locks*). Al usar `FOR UPDATE`, la Sesión A adquiere un bloqueo exclusivo de actualización sobre la fila `id = 1`. Cuando la Sesión B intenta adquirir el mismo bloqueo, entra en cola de espera hasta que la Sesión A libera la transacción mediante `COMMIT` o `ROLLBACK`." |
| **Verificación en el motor** | Se confirmó en el motor real. Al ejecutar `SELECT * FROM producto;` mientras la Sesión B esperaba, se verificó la existencia de un bloqueo de tipo `RowShareLock` en estado `granted = false` para la Sesión B. |
| **Conclusión** | **Explicación confirmada.** El mecanismo que resuelve o controla este comportamiento son los bloqueos implícitos/explícitos a nivel de fila (`FOR UPDATE`, `FOR SHARE`) y el parámetro `lock_timeout` si se desea evitar esperas indefinidas. |

---

## Escenario 2: Lectura No Repetible

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Lectura no repetible en la tabla `producto`. |
| **Cómo se reprodujo** | **1. Sesión A:** `BEGIN; SELECT precio FROM producto WHERE id = 1;` *(Devuelve 100.00)*<br>**2. Sesión B:** `BEGIN; UPDATE producto SET precio = 150.00 WHERE id = 1; COMMIT;`<br>**3. Sesión A:** `SELECT precio FROM producto WHERE id = 1; COMMIT;` |
| **Qué se observó** | En la **Sesión A**, dentro de la misma transacción, la primera consulta devolvió `100.00` y la segunda consulta devolvió `150.00` tras el commit de la Sesión B. |
| **Explicación de la IA** | *(OpenCode)*: "En el nivel de aislamiento predeterminado de PostgreSQL (`READ COMMITTED`), cada consulta individual dentro de una transacción ve solo los datos comprometidos antes de que comience esa consulta específica. Por ello, si otra sesión modifica y confirma un cambio en el medio, la misma transacción verá valores distintos." |
| **Verificación en el motor** | Se repitió la prueba en la Sesión A iniciando con `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;`. Al ejecutar los mismos pasos, la segunda consulta devolvió **`100.00`**, manteniendo la foto consistente de los datos. |
| **Conclusión** | **Explicación confirmada.** El nivel de aislamiento `REPEATABLE READ` o `SERIALIZABLE` evita la lectura no repetible garantizando una visión estática (*snapshot*) de la base de datos al inicio de la transacción. |

---

## Escenario 3: Lectura Fantasma

| Campo | Contenido |
| :--- | :--- |
| **Escenario** | Lectura fantasma mediante consulta de agregación (`COUNT`) en la tabla `pedido`. |
| **Cómo se reprodujo** | **1. Sesión A:** `BEGIN; SELECT COUNT(*) FROM pedido WHERE estado = 'PENDIENTE';` *(Devuelve 2)*<br>**2. Sesión B:** `INSERT INTO pedido (usuario_id, forma_pago) VALUES (1, 'EFECTIVO'); COMMIT;`<br>**3. Sesión A:** `SELECT COUNT(*) FROM pedido WHERE estado = 'PENDIENTE'; COMMIT;` |
| **Qué se observó** | La primera lectura en **Sesión A** reportó **2** registros. La segunda lectura, dentro de la misma transacción, reportó **3** registros debido a la inserción confirmada por la Sesión B. |
| **Explicación de la IA** | *(OpenCode)*: "Ocurre una lectura fantasma cuando una transacción vuelve a ejecutar una consulta que busca filas que cumplen una condición y encuentra que el conjunto de filas ha cambiado debido a transacciones recientemente confirmadas por otra sesión." |
| **Verificación en el motor** | Se verificó repitiendo el flujo con `SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;` en la Sesión A. En este nivel, el segundo `COUNT(*)` mantuvo el resultado en **2**, ignorando el registro insertado por la Sesión B. |
| **Conclusión** | **Explicación confirmada.** En PostgreSQL, el nivel `REPEATABLE READ` evita tanto las lecturas no repetibles como las lecturas fantasmas gracias a su implementación con MVCC (*Multi-Version Concurrency Control*). |

---
