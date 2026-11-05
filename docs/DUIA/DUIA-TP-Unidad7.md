| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro (SDD) |
| **Spec o prompt utilizado** | Prompt para Kiro: generación de `SPEC_U7.md` para el modelado NoSQL y migración de pedidos de Food Store a MongoDB. |
| **Qué generó** | Documento formal de especificación `SPEC_U7.md` con 7 secciones (mapeo relacional a BSON, reglas de integridad RI-M1 y RI-M2, justificación de embedding vs referencing, matriz de consultas y prompts normativos). |
| **Qué se aceptó** | 100% de la estructura de modelado, definición del esquema BSON canónico, precondiciones matemáticas y diseño de consultas. |
| **Qué se modificó o descartó, y por qué** | 1. Se descartó la sugerencia de generar ObjectIds sintéticos sin guardar el `pedido_id_origen`, incorporando explícitamente `pedido_id_origen` y `usuario_id_origen` para trazabilidad relacional.<br>2. Se excluyó tajantemente la columna `contrasena` del objeto embebido `cliente` por directiva de privacidad y mínimo privilegio.<br>3. Se calibró el umbral de Q-M4 a $15.000 para segmentar pedidos representativos según los datos reales de la muestra. |
| **Verificación realizada** | ✅ Revisión del esquema contra los 5 pedidos reales del dump (`756504` a `756508`).<br>✅ Comprobación de que `SPEC_U7.md` no contiene `SELECT *`.<br>✅ Validación de consistencia matemática de totales pre-migración arrojando 0 discrepancias. |

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Antigravity (ex-OpenCode) |
| **Spec o prompt utilizado** | `SPEC_U7.md` (Sección 6.1) y prompt: *"Generar el script `consultas_mongodb.js` con inicialización idempotente insertMany de los 5 pedidos de muestra y las 4 consultas Q-M1 a Q-M4 sin proyecciones abiertas."* |
| **Qué generó** | Script JavaScript ejecutable en `mongosh` con inicialización de `foodstore_nosql.pedidos`, inserción de los 5 documentos con precios históricos congelados, las 4 consultas documentales con `.toArray()` y chequeos de integridad para RI-M1 y RI-M2. |
| **Qué se aceptó** | 95% del código generado, la estructura de embedding de ítems y cliente, y las consultas Q-M1 a Q-M4. |
| **Qué se modificó o descartó, y por qué** | 1. Se corrigió la consulta Q-M3 incorporando la proyección posicional `"items.$": 1` para devolver únicamente el producto buscado (243882) dentro del arreglo y no la lista completa de ítems del pedido.<br>2. Se añadió limpieza idempotente con `deleteMany` antes del `insertMany` para evitar duplicación de claves en ejecuciones repetidas.<br>3. Se agregaron validaciones programáticas de integridad RI-M1 y RI-M2 con `$sum` y `$or`. |
| **Verificación realizada** | ✅ Ejecución del script en entorno de prueba retornando 5 documentos en Q-M1, 2 en Q-M2, 4 en Q-M3 y 3 en Q-M4.<br>✅ Comprobación de integridad RI-M1: 0 diferencias matemáticas en totales ($|total - \sum subtotal| = 0$).<br>✅ Comprobación de integridad RI-M2: 0 documentos huérfanos o con arreglo de ítems vacío. |

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Antigravity (ex-OpenCode) |
| **Spec o prompt utilizado** | `SPEC_U7.md` (Sección 6.2) y prompt: *"Generar el script `consultas_postgresql.sql` con las consultas relacionales equivalentes Q-PG1 y Q-PG2 con encabezados \echo y sin SELECT *."* |
| **Qué generó** | Script SQL con las consultas de agregación y filtrado relacional para pedidos `CONFIRMADO` (Q-PG1) y producto `243882` (Q-PG2) sobre las tablas `pedido` y `detalle_pedido`. |
| **Qué se aceptó** | 100% de la lógica SQL con `JOIN`, `GROUP BY`, `SUM(dp.subtotal)` y `SELECT DISTINCT`. |
| **Qué se modificó o descartó, y por qué** | 1. Se descartó el uso de consultas genéricas sin filtro de muestra, acotando explícitamente a `p.id IN (756504, 756505, 756506, 756507, 756508)` para garantizar la comparabilidad exacta con el subconjunto migrado.<br>2. Se formatearon los nombres de salida de columnas (`pedido_id`, `precio_unitario_historico`) para que coincidan con la semántica del informe. |
| **Verificación realizada** | ✅ Validación de coincidencia simétrica con EXCEPT bidireccional entre los IDs retornados por PostgreSQL y MongoDB para Q-PG1/Q-M2 arrojando 0 filas de discrepancia (IDs `[756505, 756508]`).<br>✅ Validación con EXCEPT bidireccional para Q-PG2/Q-M3 arrojando 0 filas de discrepancia (IDs `[756505, 756506, 756507, 756508]`).<br>✅ Verificación de paridad de precios históricos para el producto 243882: $3628.43 exactos en ambos motores. |
