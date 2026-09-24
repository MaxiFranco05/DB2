# Spec: v_detalle_pedidos

## Metadata
- **Parte:** B — Vistas
- **Vista:** `v_detalle_pedidos`
- **Tablas base:** `detalle_pedido`, `pedido`, `producto`
- **Tipo:** Vista de múltiples tablas (JOINs) — no actualizable automáticamente en PostgreSQL
- **Autor:** Spec generada para el proyecto integrador FoodStore — DB2

---

## 1. Objetivo y Contexto

### Propósito
Exponer cada línea de detalle de pedido enriquecida con el contexto mínimo necesario: el estado del pedido al que pertenece y el nombre del producto. Esta vista es la fuente de datos para reportes de ventas por ítem, análisis de productos más pedidos y verificación de subtotales.

### Rol de la vista en la arquitectura
- **Encapsulamiento del modelo línea-pedido-producto:** los tres JOINs necesarios (detalle → pedido → producto) quedan centralizados. Las consultas analíticas y operativas acceden a la superficie plana sin conocer el modelo relacional subyacente.
- **Preservación del precio histórico:** el campo `precio_unitario` en `detalle_pedido` fue congelado por el trigger `trg_subtotal` en el momento del INSERT. La vista lo expone directamente sin referenciar `producto.precio`, garantizando que los reportes históricos nunca se distorsionen por cambios de precio futuros.
- **Aclaración de rendimiento:** el rendimiento del JOIN entre `detalle_pedido` y `pedido` se beneficia de la PK compuesta `(pedido_id, producto_id)` de `detalle_pedido`. Un índice adicional sobre `detalle_pedido(pedido_id)` mejoraría la búsqueda cuando se filtra por un pedido específico; actualmente solo existe el índice implícito de la PK.

---

## 2. Tablas y Columnas Involucradas

| Columna en la vista   | Tabla fuente      | Columna fuente    | Tipo            | Notas                                                        |
|-----------------------|-------------------|-------------------|-----------------|--------------------------------------------------------------|
| `pedido_id`           | `detalle_pedido`  | `pedido_id`       | `BIGINT`        | FK + parte de PK compuesta                                   |
| `producto_id`         | `detalle_pedido`  | `producto_id`     | `BIGINT`        | FK + parte de PK compuesta                                   |
| `nombre_producto`     | `producto`        | `nombre`          | `VARCHAR(150)`  | Nombre al momento de la consulta (no histórico)              |
| `cantidad`            | `detalle_pedido`  | `cantidad`        | `INTEGER`       | Unidades pedidas; congelado en el INSERT                      |
| `precio_unitario`     | `detalle_pedido`  | `precio_unitario` | `NUMERIC(10,2)` | Precio histórico congelado por trigger `trg_subtotal`        |
| `subtotal`            | `detalle_pedido`  | `subtotal`        | `NUMERIC(10,2)` | `cantidad × precio_unitario`; calculado por trigger          |
| `estado_pedido`       | `pedido`          | `estado`          | `estado_pedido` | ENUM del pedido padre; clave para la asimetría de negocio    |

> **Nota sobre `nombre_producto`:** a diferencia de `precio_unitario`, el nombre del producto **no** fue congelado históricamente. Si el producto es renombrado, los detalles históricos mostrarán el nombre actual. Esta es una limitación conocida del diseño actual del esquema. Para registros de auditoría estricta, se requeriría almacenar el nombre en `detalle_pedido` en el momento del INSERT (extensión futura).

---

## 3. Reglas de Negocio Explícitas

### RN-DET-01 — Sin filtro de baja lógica sobre productos en detalles históricos
Los productos referenciados en `detalle_pedido` no deben filtrarse por `producto.activo`. Un producto puede haberse dado de baja después de ser pedido; su línea de detalle es un hecho histórico inmutable. Filtrar por `producto.activo = TRUE` eliminaría silenciosamente líneas de pedidos existentes, corrompiendo los totales y la trazabilidad.

### RN-DET-02 — Asimetría de negocio: ¿filtrar por estado del pedido? *(análisis central de esta spec)*

**Pregunta planteada por la cátedra:** ¿debe `v_detalle_pedidos` filtrar las líneas según el estado del pedido al que pertenecen?

**Análisis de los cuatro estados posibles:**

| Estado del pedido | ¿Incluir las líneas en la vista? | Razonamiento                                                                                   |
|-------------------|----------------------------------|-----------------------------------------------------------------------------------------------|
| `PENDIENTE`       | ✅ Sí                            | El pedido está en curso; las líneas son activamente operativas. Excluirlas rompería el flujo de trabajo |
| `CONFIRMADO`      | ✅ Sí                            | El pedido fue aceptado; las líneas deben ser visibles para preparación y despacho             |
| `TERMINADO`       | ✅ Sí                            | Pedido completado y facturado; sus líneas son el registro histórico de la venta               |
| `CANCELADO`       | ✅ Sí                            | La cancelación es un evento de negocio legítimo. Las líneas de un pedido cancelado son evidencia del intento de transacción, útil para análisis de abandono, reversión de stock y auditoría |

**Decisión adoptada y justificación:**

> **`v_detalle_pedidos` NO filtra por estado del pedido. Expone las líneas de detalle de TODOS los pedidos sin excepción.**

La asimetría que plantea la cátedra es la siguiente: intuitivamente, "vista de detalles vigentes" podría sugerir "solo pedidos activos (no cancelados)". Sin embargo, esto sería incorrecto por estas razones:

1. **Los detalles son hechos, no estados:** el estado del pedido puede cambiar (PENDIENTE → CANCELADO), pero las líneas de detalle registran lo que se *intentó* comprar. Son datos factuales que no deben borrarse ni ocultarse al cambiar el estado del pedido padre.
2. **Análisis de negocio requiere visibilidad completa:** los reportes de cancelaciones, los análisis de productos más abandonados y la gestión de devoluciones de stock necesitan acceder a las líneas de pedidos cancelados.
3. **Consistencia con `v_resumen_pedidos`:** si `v_resumen_pedidos` expone todos los pedidos (incluyendo cancelados), la vista de detalles debe mantener la misma política para que los JOINs entre ambas vistas sean coherentes y completos.
4. **Separación de responsabilidades:** si el caso de uso requiere "líneas de pedidos activos solamente", esa lógica pertenece a la capa de aplicación o a una vista derivada específica (ej. `v_detalle_pedidos_activos`), no a la vista base.

**La asimetría real y su resolución:**

La asimetría no es "filtrar o no filtrar" sino que surge del hecho de que `v_detalle_pedidos` incluye una columna `estado_pedido` justamente para que quien consuma la vista pueda aplicar su propio filtro de forma declarativa:

```sql
-- Consulta específica de la capa de aplicación:
SELECT * FROM v_detalle_pedidos WHERE estado_pedido != 'CANCELADO';
```

Esto transfiere la decisión de filtrado al consumidor sin imponer una política restrictiva en la vista base.

---

## 4. DDL de Referencia

```sql
CREATE OR REPLACE VIEW v_detalle_pedidos AS
    SELECT
        dp.pedido_id,
        dp.producto_id,
        pr.nombre           AS nombre_producto,
        dp.cantidad,
        dp.precio_unitario,
        dp.subtotal,
        p.estado            AS estado_pedido
    FROM detalle_pedido dp
    INNER JOIN pedido   p  ON dp.pedido_id   = p.id
    INNER JOIN producto pr ON dp.producto_id = pr.id;
```

> **Por qué `INNER JOIN` y no `LEFT JOIN`:**
> - `detalle_pedido.pedido_id` es `NOT NULL` con `ON DELETE RESTRICT` → siempre existe el pedido padre.
> - `detalle_pedido.producto_id` es `NOT NULL` con `ON DELETE RESTRICT` → siempre existe el producto.
> - Los `INNER JOIN` son semánticamente correctos y comunican la invariante del modelo.

---

## 5. Criterios de Aceptación

### CA-01 — Equivalencia perfecta con la consulta manual (EXCEPT bidireccional)

```sql
-- Dirección 1: filas en la vista que NO están en la consulta manual
SELECT pedido_id, producto_id, nombre_producto, cantidad,
       precio_unitario, subtotal, estado_pedido
FROM v_detalle_pedidos
EXCEPT
SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad,
       dp.precio_unitario, dp.subtotal, p.estado
FROM detalle_pedido dp
INNER JOIN pedido   p  ON dp.pedido_id   = p.id
INNER JOIN producto pr ON dp.producto_id = pr.id;
-- Resultado esperado: 0 filas ✅

-- Dirección 2: filas en la consulta manual que NO están en la vista
SELECT dp.pedido_id, dp.producto_id, pr.nombre, dp.cantidad,
       dp.precio_unitario, dp.subtotal, p.estado
FROM detalle_pedido dp
INNER JOIN pedido   p  ON dp.pedido_id   = p.id
INNER JOIN producto pr ON dp.producto_id = pr.id
EXCEPT
SELECT pedido_id, producto_id, nombre_producto, cantidad,
       precio_unitario, subtotal, estado_pedido
FROM v_detalle_pedidos;
-- Resultado esperado: 0 filas ✅
```

### CA-02 — La vista incluye líneas de pedidos cancelados

```sql
SELECT COUNT(*) FROM v_detalle_pedidos WHERE estado_pedido = 'CANCELADO';
-- Resultado esperado: igual al COUNT de detalle_pedido JOIN pedido WHERE estado = 'CANCELADO' ✅
```

### CA-03 — El precio_unitario en la vista coincide con el registrado en la tabla base (no con precio actual)

```sql
-- Verificar que el precio_unitario de la vista es el histórico, no el de lista actual
SELECT
    vd.pedido_id,
    vd.producto_id,
    vd.precio_unitario          AS precio_historico_vista,
    pr.precio                   AS precio_actual_producto
FROM v_detalle_pedidos vd
INNER JOIN producto pr ON vd.producto_id = pr.id
WHERE vd.precio_unitario != pr.precio
LIMIT 5;
-- Este query puede devolver filas si hubo cambios de precio (es esperable y correcto).
-- Lo importante es que vd.precio_unitario = detalle_pedido.precio_unitario (validación siguiente).

-- Validación formal: precio_unitario de la vista iguala al de la tabla base
SELECT vd.pedido_id, vd.producto_id
FROM v_detalle_pedidos vd
INNER JOIN detalle_pedido dp
    ON vd.pedido_id = dp.pedido_id AND vd.producto_id = dp.producto_id
WHERE vd.precio_unitario != dp.precio_unitario;
-- Resultado esperado: 0 filas ✅
```

### CA-04 — El subtotal en la vista es consistente con cantidad × precio_unitario

```sql
SELECT pedido_id, producto_id, cantidad, precio_unitario, subtotal,
       (cantidad * precio_unitario) AS subtotal_calculado
FROM v_detalle_pedidos
WHERE subtotal != (cantidad * precio_unitario);
-- Resultado esperado: 0 filas ✅ (garantizado por el trigger trg_subtotal)
```

### CA-05 — Conteo de líneas en la vista iguala al conteo de la tabla base

```sql
SELECT
    (SELECT COUNT(*) FROM v_detalle_pedidos) AS total_vista,
    (SELECT COUNT(*) FROM detalle_pedido)    AS total_tabla;
-- Resultado esperado: total_vista = total_tabla ✅
```

---

## 6. Dependencias y Relaciones

| Elemento              | Relación                                                                              |
|-----------------------|---------------------------------------------------------------------------------------|
| `v_resumen_pedidos`   | Vista hermana de nivel pedido; se puede hacer JOIN con `v_detalle_pedidos` por `pedido_id` |
| `trg_subtotal`        | Trigger que congela `precio_unitario` y calcula `subtotal` al momento del INSERT; la vista depende de esos valores |
| `producto.precio`     | La vista NO usa `producto.precio` directamente; usa `detalle_pedido.precio_unitario`  |

---

## 7. Notas de Implementación

- **Extensión futura para precio histórico de nombre:** si se requiere congelar el nombre del producto al momento del pedido, agregar columna `nombre_producto VARCHAR(150)` a `detalle_pedido` y poblarla en el trigger `trg_subtotal`. La vista debería entonces usar esa columna en lugar de `producto.nombre`.
- **Orden de creación:** debe crearse después de que `pedido`, `detalle_pedido` y `producto` existan. No depende de otras vistas.
- **Permisos sugeridos:** `GRANT SELECT ON v_detalle_pedidos TO rol_consulta, rol_operador, rol_administrador;`. Dado que expone precios históricos y estados, considerar restringir a `rol_consulta` en entornos con requisitos de privacidad estrictos.
