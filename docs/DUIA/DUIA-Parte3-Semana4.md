# DUIA - Parte 3: Especificaciones SQL (Semana 4)

## Tabla 1 - Ranking de Usuarios

| **Herramienta** | SQL query generation |
| **Spec o prompt utilizado** | Ranking histórico de gasto por usuario usando DENSE_RANK(), ignorando pedidos con estado 'CANCELADO' |
| **Qué generó** | Consulta con Window Function |
| **Qué se aceptó** | El 100% de la lógica generada |
| **Qué se modificó o descartó, y por qué** | Nada. La consulta cumple todas las reglas: DENSE_RANK para ranking sin saltes de puesto, ignora pedidos CANCELADO, muestra mail y total_gastado, no usa SELECT * |
| **Verificación realizada** | Prueba de equivalencia con EXCEPT bidireccional contra una versión alternativa construida con CTE y conteo correlacionado. Resultado: 0 filas de diferencia en ambos sentidos ✅ |

---

## Tabla 2 - Precio Máximo por Categoría

| **Herramienta** | SQL query generation |
| **Spec o prompt utilizado** | Búsqueda del precio máximo de productos activos por categoría usando una subconsulta correlacionada en el SELECT, prohibido usar JOINs |
| **Qué generó** | Consulta con subconsulta en el SELECT |
| **Qué se aceptó** | El 100% de la lógica generada |
| **Qué se modificó o descartó, y por qué** | Nada. La consulta cumple todas las reglas: subconsulta correlacionada en SELECT, filtro activo = true, no usa JOINs ni GROUP BY en la consulta principal, muestra nombre y precio_maximo |
| **Verificación realizada** | Prueba de equivalencia con EXCEPT bidireccional contra una versión alternativa construida con LEFT JOIN y GROUP BY. Resultado: 0 filas de diferencia en ambos sentidos ✅ |