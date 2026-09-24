# Spec: v_productos_vigentes

## Metadata
- **Parte:** B — Vistas
- **Vista:** `v_productos_vigentes`
- **Tablas base:** `producto`, `categoria`
- **Tipo:** Vista de múltiples tablas (JOIN) — no actualizable automáticamente en PostgreSQL
- **Autor:** Spec generada para el proyecto integrador FoodStore — DB2

---

## 1. Objetivo y Contexto

### Propósito
Exponer el catálogo comercialmente disponible del sistema: únicamente los productos cuyo propio estado es activo (`producto.activo = TRUE`) **y** cuya categoría también está activa (`categoria.activa = TRUE`). Esta vista es el contrato entre la base de datos y cualquier capa que necesite presentar productos al cliente final o al personal operativo.

### Rol de la vista en la arquitectura
- **Encapsulamiento de doble filtro lógico:** la regla de negocio más compleja del catálogo (un producto puede estar activo pero su categoría no) queda declarada una sola vez. Las consultas de la API, el backoffice y los reportes la consumen sin duplicar lógica.
- **Seguridad por proyección selectiva:** la columna `producto.stock` puede incluirse o excluirse según el perfil de acceso. En esta spec se incluye porque la disponibilidad de stock es información operativa legítima para el proceso de venta.
- **Aclaración de rendimiento:** el JOIN entre `producto` y `categoria` se beneficia del índice existente `idx_producto_categoria` sobre `producto(categoria_id)`. La vista en sí no agrega caché ni materialización; el planificador de PostgreSQL ejecuta el SELECT subyacente en cada consulta.

---

## 2. Tablas y Columnas Involucradas

| Columna en la vista   | Tabla fuente | Columna fuente      | Tipo            | Notas                                             |
|-----------------------|--------------|---------------------|-----------------|---------------------------------------------------|
| `producto_id`         | `producto`   | `id`                | `BIGINT`        | PK del producto                                   |
| `nombre_producto`     | `producto`   | `nombre`            | `VARCHAR(150)`  | Alias para evitar ambigüedad con `nombre` de categoria |
| `descripcion`         | `producto`   | `descripcion`       | `TEXT`          | Descripción comercial                             |
| `precio`              | `producto`   | `precio`            | `NUMERIC(10,2)` | Precio de lista vigente                           |
| `stock`               | `producto`   | `stock`             | `INTEGER`       | Unidades disponibles                              |
| `categoria_id`        | `producto`   | `categoria_id`      | `BIGINT`        | FK — permite filtrar por categoría                |
| `nombre_categoria`    | `categoria`  | `nombre`            | `VARCHAR(100)`  | Alias descriptivo                                 |

> **Columnas excluidas:** `producto.activo` y `categoria.activa` — son columnas de control interno de baja lógica. En esta vista todos los registros satisfacen ambas condiciones por definición; exponerlas resultaría redundante.

---

## 3. Reglas de Negocio Explícitas

### RN-PROD-01 — Filtro de baja lógica sobre el producto
**Condición:** `producto.activo = TRUE`

Un producto dado de baja no debe aparecer en el catálogo disponible aunque su categoría siga activa. La baja es un acto de negocio explícito (ej. producto descontinuado, sin stock indefinido, retirado del menú).

### RN-PROD-02 — Filtro de baja lógica sobre la categoría *(decisión de negocio crítica)*
**Condición:** `categoria.activa = TRUE`

**Pregunta planteada por la cátedra:** ¿qué ocurre con los productos de una categoría dada de baja? ¿Deben desaparecer de esta vista aunque su propia columna `activo` sea `TRUE`?

**Decisión adoptada y justificación:**

> **Sí. Un producto cuya categoría esté inactiva NO debe aparecer en `v_productos_vigentes`, aunque `producto.activo = TRUE`.**

Razonamiento:

1. **Coherencia semántica del catálogo:** una categoría inactiva implica que ese grupo de productos ya no forma parte de la oferta vigente del negocio. Mostrar productos "huérfanos" de una categoría desactivada sería engañoso para el cliente.
2. **Evitar estados inconsistentes visibles:** el sistema permite la baja de una categoría con productos asociados (porque `ON DELETE RESTRICT` solo impide el borrado físico, no la baja lógica). Si esta vista mostrara esos productos, el cliente vería ítems sin una categoría navegable.
3. **Diferenciación de vistas:** `v_productos_vigentes` representa el **catálogo activo**. Para auditoría o recuperación de datos históricos existe la tabla base directamente. No es responsabilidad de esta vista exponer el estado interno de los productos desactivados por cascada lógica.
4. **Consecuencia operativa:** cuando una categoría se reactiva (`activa = TRUE`), los productos con `activo = TRUE` vuelven a aparecer automáticamente en la vista sin intervención adicional. Esto es correcto y deseable.

**Implementación:**

```sql
INNER JOIN categoria ON producto.categoria_id = categoria.id
WHERE producto.activo = TRUE
  AND categoria.activa = TRUE
```

El uso de `INNER JOIN` (en lugar de `LEFT JOIN`) refuerza sintácticamente la intención: solo se exponen productos que tienen una categoría activa. Un `LEFT JOIN` con el filtro en el `WHERE` produciría el mismo resultado matemático, pero la elección de `INNER JOIN` comunica la intención de forma más legible.

### RN-PROD-03 — El filtro NO es transitivo hacia pedidos históricos
Este filtro aplica exclusivamente a `v_productos_vigentes`. Las vistas `v_resumen_pedidos` y `v_detalle_pedidos` no deben usarla como fuente, porque el historial de pedidos ya realizados debe incluir productos y categorías que en su momento estaban activos, independientemente de su estado actual.

---

## 4. DDL de Referencia

```sql
CREATE OR REPLACE VIEW v_productos_vigentes AS
    SELECT
        p.id            AS producto_id,
        p.nombre        AS nombre_producto,
        p.descripcion,
        p.precio,
        p.stock,
        p.categoria_id,
        c.nombre        AS nombre_categoria
    FROM producto p
    INNER JOIN categoria c ON p.categoria_id = c.id
    WHERE p.activo = TRUE
      AND c.activa = TRUE;
```

> Esta vista **no es actualizable automáticamente** en PostgreSQL porque involucra un JOIN. Las operaciones de escritura deben realizarse directamente sobre las tablas base `producto` y `categoria`.

---

## 5. Criterios de Aceptación

### CA-01 — Equivalencia perfecta con la consulta manual (EXCEPT bidireccional)

```sql
-- Dirección 1: filas en la vista que NO están en la consulta manual
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria
FROM v_productos_vigentes
EXCEPT
SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre
FROM producto p
INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE
  AND c.activa = TRUE;
-- Resultado esperado: 0 filas ✅

-- Dirección 2: filas en la consulta manual que NO están en la vista
SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.categoria_id, c.nombre
FROM producto p
INNER JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE
  AND c.activa = TRUE
EXCEPT
SELECT producto_id, nombre_producto, descripcion, precio, stock, categoria_id, nombre_categoria
FROM v_productos_vigentes;
-- Resultado esperado: 0 filas ✅
```

### CA-02 — Producto inactivo queda excluido aunque su categoría esté activa

```sql
UPDATE producto SET activo = FALSE WHERE nombre = 'Margherita';

SELECT * FROM v_productos_vigentes WHERE nombre_producto = 'Margherita';
-- Resultado esperado: 0 filas ✅
```

### CA-03 — Productos de categoría inactiva quedan excluidos aunque el producto esté activo

```sql
-- Registrar cuántos productos vigentes tiene la categoría antes de la baja
SELECT COUNT(*) FROM v_productos_vigentes WHERE nombre_categoria = 'Bebidas';
-- Supongamos: 5

UPDATE categoria SET activa = FALSE WHERE nombre = 'Bebidas';

SELECT COUNT(*) FROM v_productos_vigentes WHERE nombre_categoria = 'Bebidas';
-- Resultado esperado: 0 filas ✅ (los 5 productos desaparecen aunque producto.activo = TRUE)
```

### CA-04 — Reactivar categoría restaura la visibilidad de sus productos

```sql
UPDATE categoria SET activa = TRUE WHERE nombre = 'Bebidas';

SELECT COUNT(*) FROM v_productos_vigentes WHERE nombre_categoria = 'Bebidas';
-- Resultado esperado: mismo conteo que antes de la baja (ej. 5) ✅
```

### CA-05 — La vista no expone productos sin categoría (integridad referencial)

```sql
-- Verificar que no hay producto_id en la vista sin categoria_id válido
SELECT v.producto_id
FROM v_productos_vigentes v
LEFT JOIN categoria c ON v.categoria_id = c.id
WHERE c.id IS NULL;
-- Resultado esperado: 0 filas ✅
```

---

## 6. Dependencias y Relaciones

| Elemento                 | Relación                                                                     |
|--------------------------|------------------------------------------------------------------------------|
| `v_categorias_vigentes`  | Comparten la misma condición `categoria.activa = TRUE` pero son independientes |
| `v_detalle_pedidos`      | No debe usar `v_productos_vigentes` como fuente; usa `producto` directamente para preservar historial |
| `idx_producto_categoria` | Índice existente sobre `producto(categoria_id)` que optimiza el JOIN         |

---

## 7. Notas de Implementación

- **Orden de creación:** puede crearse en cualquier orden respecto a `v_categorias_vigentes`, ya que ambas acceden directamente a las tablas base.
- **Sin WITH CHECK OPTION:** al no ser actualizable automáticamente, la cláusula no aplica.
- **Permisos sugeridos:** `GRANT SELECT ON v_productos_vigentes TO rol_consulta, rol_operador;`. Las modificaciones de estado se hacen sobre las tablas base con roles con privilegios específicos.
