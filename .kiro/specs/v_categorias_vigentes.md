# Spec: v_categorias_vigentes

## Metadata
- **Parte:** B — Vistas
- **Vista:** `v_categorias_vigentes`
- **Tabla base:** `categoria`
- **Tipo:** Vista simple (single-table, actualizable)
- **Autor:** Spec generada para el proyecto integrador FoodStore — DB2

---

## 1. Objetivo y Contexto

### Propósito
Proveer una capa de acceso controlada sobre la tabla `categoria` que exponga únicamente las filas lógicamente activas, es decir, aquellas cuya columna `activa = TRUE`. De esta forma, el código de aplicación y los usuarios sin privilegios sobre la tabla base nunca ven categorías dadas de baja sin necesidad de escribir el filtro en cada consulta.

### Rol de la vista en la arquitectura
- **Encapsulamiento de la política de baja lógica:** el filtro `activa = TRUE` queda declarado una sola vez en la vista; las capas superiores (API, reportes, otras vistas) lo consumen sin duplicarlo.
- **Seguridad por ocultamiento:** si en el futuro la tabla `categoria` incorpora columnas internas (fecha_baja, auditoria_usuario, etc.), se pueden excluir de la vista sin alterar los contratos de las consultas externas.
- **Aclaración de rendimiento:** una vista no es un índice y no acelera consultas por sí misma. El rendimiento se obtiene de los índices subyacentes de `categoria`. Actualmente la tabla no tiene un índice explícito sobre `activa`; para cargas con miles de categorías convendría evaluar un índice parcial `CREATE INDEX ON categoria(id) WHERE activa = TRUE`.

---

## 2. Tablas y Columnas Involucradas

| Columna en la vista | Columna en `categoria` | Tipo           | Notas                                      |
|---------------------|------------------------|----------------|--------------------------------------------|
| `id`                | `id`                   | `BIGINT`       | PK generada por `GENERATED ALWAYS AS IDENTITY` |
| `nombre`            | `nombre`               | `VARCHAR(100)` | Nombre comercial de la categoría           |

> **Columna excluida:** `activa BOOLEAN` — es la columna de control de baja lógica. Se omite intencionalmente de la proyección porque, dentro de esta vista, todas las filas tienen `activa = TRUE` por definición. Exponerla sería redundante y podría confundir a un desarrollador que la lea como dato variable.

---

## 3. Reglas de Negocio Explícitas

### RN-CAT-01 — Filtro de baja lógica
**Condición:** `WHERE activa = TRUE`

Una categoría dada de baja (`activa = FALSE`) deja de aparecer en esta vista de inmediato. El sistema no usa borrado físico (`DELETE`) sobre `categoria` por dos razones:
1. `ON DELETE RESTRICT` en `producto.categoria_id` impide el borrado físico mientras existan productos asociados.
2. El historial de productos ya vendidos mantiene la integridad referencial, necesaria para la trazabilidad de pedidos históricos.

### RN-CAT-02 — Vista actualizable y `WITH CHECK OPTION`
La vista cumple todas las condiciones de PostgreSQL para ser actualizable de forma automática (single-table, sin DISTINCT, sin GROUP BY, sin funciones de agregación, sin LIMIT). Esto permite ejecutar `INSERT`, `UPDATE` y `DELETE` directamente sobre la vista.

La cláusula `WITH CHECK OPTION` es **obligatoria** para mantener la consistencia de la política de baja lógica:

```sql
CREATE OR REPLACE VIEW v_categorias_vigentes AS
    SELECT id, nombre
    FROM categoria
    WHERE activa = TRUE
WITH CHECK OPTION;
```

**Por qué es crítico `WITH CHECK OPTION`:**
Sin esta cláusula, sería posible ejecutar:
```sql
UPDATE v_categorias_vigentes SET nombre = 'Bebidas Premium' WHERE id = 2;
```
…y también, inadvertidamente:
```sql
-- Sin WITH CHECK OPTION esto no fallaría pero la fila desaparecería de la vista silenciosamente:
INSERT INTO v_categorias_vigentes (nombre) VALUES ('Nueva Cat');  -- activa queda NULL o FALSE
```
Con `WITH CHECK OPTION`, PostgreSQL rechaza cualquier `INSERT` o `UPDATE` cuyo resultado no satisfaga el predicado `activa = TRUE`, evitando que se introduzcan filas que la propia vista no podría mostrar.

### RN-CAT-03 — Integridad por `DEFAULT TRUE`
La columna `activa` tiene `DEFAULT TRUE` en la tabla base. Al insertar a través de la vista (que no expone `activa`), el DEFAULT garantiza que la nueva categoría sea activa. `WITH CHECK OPTION` actúa como segunda línea de defensa.

---

## 4. DDL de Referencia

```sql
CREATE OR REPLACE VIEW v_categorias_vigentes AS
    SELECT
        id,
        nombre
    FROM categoria
    WHERE activa = TRUE
WITH CHECK OPTION;
```

---

## 5. Criterios de Aceptación

### CA-01 — Equivalencia perfecta con la consulta manual
La vista debe devolver exactamente el mismo conjunto de filas que la consulta directa sobre la tabla base con el mismo filtro. La validación usa `EXCEPT` en ambas direcciones para garantizar diferencia simétrica nula (0 filas):

```sql
-- Dirección 1: filas en la vista que NO están en la consulta manual
SELECT id, nombre
FROM v_categorias_vigentes
EXCEPT
SELECT id, nombre
FROM categoria
WHERE activa = TRUE;
-- Resultado esperado: 0 filas ✅

-- Dirección 2: filas en la consulta manual que NO están en la vista
SELECT id, nombre
FROM categoria
WHERE activa = TRUE
EXCEPT
SELECT id, nombre
FROM v_categorias_vigentes;
-- Resultado esperado: 0 filas ✅
```

### CA-02 — Categorías inactivas quedan excluidas
```sql
-- Dar de baja una categoría de prueba
UPDATE categoria SET activa = FALSE WHERE nombre = 'Postres';

-- Verificar que no aparece en la vista
SELECT * FROM v_categorias_vigentes WHERE nombre = 'Postres';
-- Resultado esperado: 0 filas ✅
```

### CA-03 — `WITH CHECK OPTION` rechaza inserciones inválidas
```sql
-- Esto debe fallar con ERROR
INSERT INTO v_categorias_vigentes (nombre)
SELECT 'Cat Fantasma'
WHERE EXISTS (
    SELECT 1 FROM categoria WHERE activa = FALSE LIMIT 1
);
-- Si el motor permite el INSERT pero activa resultaría FALSE → debe lanzar error ✅
```

### CA-04 — INSERT válido a través de la vista persiste como activo
```sql
INSERT INTO v_categorias_vigentes (nombre) VALUES ('Wraps');

SELECT activa FROM categoria WHERE nombre = 'Wraps';
-- Resultado esperado: TRUE ✅
```

---

## 6. Dependencias y Relaciones

| Elemento            | Relación                                                               |
|---------------------|------------------------------------------------------------------------|
| `v_productos_vigentes` | Depende de esta vista (o de la tabla base con el mismo filtro) para encadenar categorías activas con productos activos |
| `producto.categoria_id` | FK con `ON DELETE RESTRICT`; garantiza que no se puede borrar físicamente una categoría referenciada |

---

## 7. Notas de Implementación

- **Orden de creación:** esta vista debe crearse antes que `v_productos_vigentes`.
- **Permisos sugeridos:** `GRANT SELECT ON v_categorias_vigentes TO rol_consulta;` y `GRANT INSERT, UPDATE ON v_categorias_vigentes TO rol_operador;`. El `DELETE` sobre la vista (que ejecutaría un DELETE físico sobre `categoria`) no debería otorgarse; la baja lógica se realiza con `UPDATE activa = FALSE` directamente sobre la tabla base.
