# TP Food Store - Parte A: Mediciones de Optimización de Índices

## Introducción
Este documento presenta las mediciones empíricas obtenidas mediante `EXPLAIN ANALYZE` para evaluar el impacto de los índices creados sobre el esquema de la base de datos Food Store. Se comparan los tiempos de ejecución antes y después de la indexación, junto con el costo de escritura correspondiente.

---

## 1. Consulta 1: Panel de pedidos pendientes

| Métrica | ANTES | DESPUÉS | Variación |
|---------|-------|---------|-----------|
| **Tipo de plan** | Parallel Seq Scan on pedido | Bitmap Heap Scan -> Bitmap Index Scan sobre idx_pedido_pendiente_fecha | - |
| **Tiempo de ejecución** | 37.228 ms | 1.001 ms | **↓ 97.3% de mejora** |
| **Conclusión** | Mejora masiva eliminando el escaneo secuencial | Índice compuesto (estado, fecha) optimizó tanto el filtro de igualdad como el rango + ORDER BY | Recomendación: Mantener idx_pedido_pendiente_fecha |

---

## 2. Consulta 2: Facturación histórica

| Métrica | ANTES | DESPUÉS | Variación |
|---------|-------|---------|-----------|
| **Tipo de plan** | Parallel Seq Scan on detalle_pedido | Parallel Seq Scan on detalle_pedido | - |
| **Tiempo de ejecución** | 310.535 ms | 291.197 ms | **↓ 6.2% de mejora** |
| **Conclusión** | - | El planificador optó por mantener el Seq Scan en lugar de usar el covering index, lo cual es el comportamiento esperado al procesar agregaciones masivas (SUM) que involucran una lectura mayoritaria de la tabla hija | Recomendación: El idx_detalle_producto con INCLUDE podría ser beneficioso para consultas con filtros adicionales o menor cardinalidad |

---

## 3. Consulta 3: Precio máximo por categoría

| Métrica | ANTES | DESPUÉS | Variación |
|---------|-------|---------|-----------|
| **Tipo de plan** | Seq Scan on categoria c | Index Scan Backward usando idx_producto_precio_activo | - |
| **Tiempo de ejecución** | 81.069 ms | 90.087 ms | **↑ 10.9% de empeoramiento** |
| **Conclusión** | - | El planificador eligió un Index Scan Backward, aunque el tiempo fue ligeramente superior. Se recomienda validar con cardinalidad real y considerar la selectividad de la condición `activo = true` | Recomendación: Monitorear con datos representativos; el índice parcial sigue siendo valioso para cargas de trabajo con filtrado pesado sobre productos activos |

---

## 4. Medición del Costo de Escritura (Penalidad en INSERTs)

| Métrica | ANTES de los índices extra | DESPUÉS de los índices extra | Variación |
|---------|---------------------------|------------------------------|-----------|
| **Operación** | Creación de 1 pedido con 4 detalles (cláusula WITH) | Igual operación con índices presentes | - |
| **Tiempo de ejecución** | 2.634 ms | 2.700 ms | - |
| **Penalidad medida** | - | **+0.066 ms de latencia por transacción** | **↑ 2.5% de overhead** |
| **Justificación** | - | El overhead se debe al mantenimiento de los árboles B durante la inserción de registros en las tablas pedido y detalle_pedido | Recomendación: El costo es aceptable para la ganancia de lectura obtenida en las consultas críticas |

---

## 5. Justificación del índice descartado (idx_pedido_estado)

Se decidió **formalmente descartar** la creación de un índice simple sobre la columna `estado` de la tabla `pedido` basado en los siguientes argumentos técnicos:

La columna `estado` es un campo `ENUM` con solo **4 valores posibles** (`PENDIENTE`, `CONFIRMADO`, `TERMINADO`, `CANCELADO`), lo que implica una **baja selectividad** (~25% de la tabla por cada valor). Según la teoría de índices B-tree, cuando una columna tiene tan baja selectividad, el optimizador del planificador de PostgreSQL tiende a **ignorar el índice** y ejecutar un `Seq Scan` en su lugar, ya que el costo de navegar por el árbol más el fetch de filas resulta más costoso que un escaneo secuencial directo.

En este escenario, el índice se convertiría en un elemento de **costo puro**: incrementaría el overhead de escritura (INSERT/UPDATE/DELETE) por el mantenimiento del árbol B, y consumiría espacio de almacenamiento sin proporcionar beneficio en tiempo de ejecución para las consultas sobre pedidos. Además, las consultas típicas sobre la tabla `pedido` ya cuentan con el índice compuesto `idx_pedido_pendiente_fecha` que cubre tanto el filtro por `estado` como el rango sobre `fecha` y la ordenación, haciendo redundante cualquier índice aislado sobre `estado`.

Por tanto, se descarta formalmente la creación de `idx_pedido_estado` para evitar penalizaciones de escritura innecesarias y almacenamiento desperdiciado, confiando en que el índice compuesto existente satisfaga las necesidades de filtrado de la aplicación.

---

## Resumen Ejecutivo

| Índice | Impacto en Lectura | Impacto en Escritura | Decisión Final |
|--------|-------------------|---------------------|----------------|
| `idx_pedido_pendiente_fecha` | **Alto**: 97.3% de mejora en panel de pedidos | Bajo: +0.066 ms por transacción | **Mantener** |
| `idx_detalle_producto` (con INCLUDE) | Moderado: 6.2% ligera mejora, pero planificador prefiere Seq Scan para agregaciones masivas | Bajo: Índice existente sin penalización adicional | **Evaluar por caso de uso** |
| `idx_producto_precio_activo` | Variables: mejoró plan pero ligeramente aumentó tiempo; requierevalidación con datos reales | Ninguno (índice ya existía) | **Monitorear** |
| `idx_pedido_estado` (simple) | Ninguno (optimizador lo ignora por baja selectividad) | Negativo: +0.066 ms overhead sin beneficio | **Descartar** |

---

## Próximos Pasos

1. Validar los planes de ejecución con datos de producción representativos
2. Considerar `ANALYZE` actualizado después de crear los índices si las estadísticas han cambiado significativamente
3. Evaluar la creación de índices compuestos adicionales para consultas de reporte que involucren múltiples columnas de filtrado
4. Monitorear `pg_stat_user_indexes` para confirmar el uso efectivo de los índices creados