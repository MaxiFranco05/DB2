# Spec: v_resumen_pedidos

## Metadata
- **Parte:** B — Vistas
- **Vista:** `v_resumen_pedidos`
- **Tablas base:** `pedido`, `usuario`
- **Tipo:** Vista de múltiples tablas (JOIN) — no actualizable automáticamente en PostgreSQL
- **Autor:** Spec generada para el proyecto integrador FoodStore — DB2

---

## 1. Objetivo y Contexto

### Propósito
Consolidar en una única superficie de consulta los datos de cada pedido junto con la información identificatoria del usuario que lo realizó. Esta vista es el punto de entrada principal para reportes de gestión, seguimiento de órdenes y auditoría comercial.

### Rol de la vista en la arquitectura
- **Encapsulamiento del JOIN operacional:** el cruce entre `pedido` y `usuario` ocurre en un único lugar; las capas superiores no necesitan conocer la estructura del JOIN ni los nombres internos de las columnas.
- **Seguridad por proyección selectiva:** la columna `usuario.contrasena` queda **explícitamente excluida** de la vista. Aunque almacenada como hash, su exposición en superficies de consulta genéricas viola el principio de mínimo privilegio. Ningún reporte o listado de pedidos tiene motivo legítimo para acceder al hash de contraseña.
- **Aclaración de rendimiento:** el rendimiento del JOIN se beneficia del índice existente `idx_pedido_usuario` sobre `pedido(usuario_id)`. La vista no materializa datos.

---

## 2. Tablas y Columnas Involucradas

| Columna en la vista   | Tabla fuente | Columna fuente  | Tipo                | Notas                                                    |
|-----------------------|--------------|-----------------|---------------------|----------------------------------------------------------|
| `pedido_id`           | `pedido`     | `id`            | `BIGINT`            | PK del pedido                                            |
| `fecha`               | `pedido`     | `fecha`         | `TIMESTAMPTZ`       | Fecha y hora con zona horaria                            |
| `estado`              | `pedido`     | `estado`        | `estado_pedido`     | ENUM: PENDIENTE, CONFIRMADO, TERMINADO, CANCELADO        |
| `forma_pago`          | `pedido`     | `forma_pago`    | `forma_pago`        | ENUM: EFECTIVO, TARJETA, TRANSFERENCIA                   |
| `usuario_id`          | `pedido`     | `usuario_id`    | `BIGINT`            | FK al usuario                                            |
| `nombre_usuario`      | `usuario`    | `nombre`        | `VARCHAR(100)`      | Nombre del cliente                                       |
| `apellido_usuario`    | `usuario`    | `apellido`      | `VARCHAR(100)`      | Apellido del cliente                                     |
| `mail_usuario`        | `usuario`    | `mail`          | `VARCHAR(255)`      | Correo del cliente — útil para notificaciones            |

> **Columnas excluidas:**
> - `usuario.contrasena` — hash de credencial; nunca debe exponerse en una vista de negocio.
> - `usuario.celular` — dato de contacto que puede incluirse en una vista extendida con mayor restricción de acceso, pero se omite aquí por precaución de privacidad.

---

## 3. Reglas de Negocio Explícitas

### RN-PED-01 — Sin filtro de baja lógica sobre pedidos
La tabla `pedido` no implementa baja lógica. El estado de un pedido se gestiona mediante el tipo enumerado `estado_pedido` (PENDIENTE, CONFIRMADO, TERMINADO, CANCELADO). Un pedido CANCELADO es un hecho histórico válido, no un registro "eliminado". Por lo tanto, esta vista expone **todos los pedidos** sin filtrar por estado.

Si se requiere una vista filtrada por estado (ej. solo pedidos activos), debe crearse como una vista derivada adicional, no modificando esta spec.

### RN-PED-02 — Historial de usuarios dados de baja *(decisión de negocio crítica)*
**Pregunta planteada por la cátedra:** ¿el historial de un usuario dado de baja debe seguir siendo consultable?

**Nota de diseño previo:** la tabla `usuario` **no tiene columna de baja lógica** en el esquema actual. La baja lógica de usuarios no está implementada. La restricción `ON DELETE RESTRICT` en `pedido.usuario_id` impide el borrado físico de un usuario que tenga pedidos asociados.

**Decisión adoptada y justificación:**

> **Sí. El historial de pedidos de un usuario dado de baja debe seguir siendo completamente consultable.**

Razonamiento:

1. **Trazabilidad legal y fiscal:** los pedidos representan transacciones comerciales. Las regulaciones contables y fiscales exigen conservar el historial de ventas independientemente del estado del cliente. Ocultar pedidos de un usuario "inactivo" equivaldría a destruir registros contables.
2. **Integridad referencial ya garantizada por el esquema:** `ON DELETE RESTRICT` en `pedido.usuario_id` asegura que no puede existir un pedido sin usuario. Si el negocio decide dar de baja a un usuario en el futuro (agregando una columna `activo` a `usuario`), los pedidos históricos deben seguir vinculados a ese usuario y ser visibles en reportes.
3. **Separación de responsabilidades:** el concepto de "usuario activo para realizar nuevos pedidos" es distinto de "usuario cuyo historial es consultable". La vista `v_resumen_pedidos` responde al segundo caso; una vista operativa de "clientes activos" respondería al primero.
4. **Consistencia con el modelo de datos:** dado que el esquema actual no tiene baja lógica en `usuario`, aplicar un filtro hipotético aquí sería prematuro. La spec documenta la decisión para que, cuando se implemente baja lógica en `usuario`, quede explícito que este filtro **no debe agregarse a `v_resumen_pedidos`**.

**Implementación:**

```sql
INNER JOIN usuario u ON p.usuario_id = u.id
-- Sin cláusula WHERE sobre usuario; todos los pedidos son visibles
```

El uso de `INNER JOIN` (en lugar de `LEFT JOIN`) es correcto porque `pedido.usuario_id` es `NOT NULL` y tiene `ON DELETE RESTRICT`: siempre existirá un usuario correspondiente. Un `LEFT JOIN` nunca produciría NULLs en la parte de usuario; el `INNER JOIN` comunica esa certeza explícitamente.

---

## 4. DDL de Referencia

```sql
CREATE OR REPLACE VIEW v_resumen_pedidos AS
    SELECT
        p.id            AS pedido_id,
        p.fecha,
        p.estado,
        p.forma_pago,
        p.usuario_id,
        u.nombre        AS nombre_usuario,
        u.apellido      AS apellido_usuario,
        u.mail          AS mail_usuario
    FROM pedido p
    INNER JOIN usuario u ON p.usuario_id = u.id;
```

> Esta vista **no es actualizable automáticamente** en PostgreSQL porque involucra un JOIN. Las operaciones de escritura se realizan directamente sobre las tablas base.

---

## 5. Criterios de Aceptación

### CA-01 — Equivalencia perfecta con la consulta manual (EXCEPT bidireccional)

```sql
-- Dirección 1: filas en la vista que NO están en la consulta manual
SELECT pedido_id, fecha, estado, forma_pago, usuario_id,
       nombre_usuario, apellido_usuario, mail_usuario
FROM v_resumen_pedidos
EXCEPT
SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id,
       u.nombre, u.apellido, u.mail
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id;
-- Resultado esperado: 0 filas ✅

-- Dirección 2: filas en la consulta manual que NO están en la vista
SELECT p.id, p.fecha, p.estado, p.forma_pago, p.usuario_id,
       u.nombre, u.apellido, u.mail
FROM pedido p
INNER JOIN usuario u ON p.usuario_id = u.id
EXCEPT
SELECT pedido_id, fecha, estado, forma_pago, usuario_id,
       nombre_usuario, apellido_usuario, mail_usuario
FROM v_resumen_pedidos;
-- Resultado esperado: 0 filas ✅
```

### CA-02 — La vista incluye todos los estados de pedido

```sql
SELECT DISTINCT estado FROM v_resumen_pedidos;
-- Resultado esperado: los 4 valores del ENUM que existan en la tabla
-- (PENDIENTE, CONFIRMADO, TERMINADO, CANCELADO) ✅
```

### CA-03 — La contraseña del usuario no es accesible desde la vista

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'v_resumen_pedidos'
  AND column_name = 'contrasena';
-- Resultado esperado: 0 filas ✅
```

### CA-04 — Conteo de pedidos en la vista iguala al conteo de la tabla base

```sql
SELECT
    (SELECT COUNT(*) FROM v_resumen_pedidos) AS total_vista,
    (SELECT COUNT(*) FROM pedido)            AS total_tabla;
-- Resultado esperado: total_vista = total_tabla ✅
```

### CA-05 — No existen pedidos en la vista sin datos de usuario (integridad del JOIN)

```sql
SELECT pedido_id
FROM v_resumen_pedidos
WHERE nombre_usuario IS NULL
   OR apellido_usuario IS NULL
   OR mail_usuario IS NULL;
-- Resultado esperado: 0 filas ✅
-- (garantizado por NOT NULL en usuario y por INNER JOIN)
```

---

## 6. Dependencias y Relaciones

| Elemento               | Relación                                                                      |
|------------------------|-------------------------------------------------------------------------------|
| `v_detalle_pedidos`    | Vista hermana; comparte el modelo de datos de `pedido` pero va al nivel de línea |
| `idx_pedido_usuario`   | Índice existente sobre `pedido(usuario_id)` que optimiza el JOIN              |
| `usuario.contrasena`   | Excluida explícitamente; política de seguridad documentada en esta spec       |

---

## 7. Notas de Implementación

- **Extensión futura:** si se agrega baja lógica a `usuario` (ej. columna `activo BOOLEAN`), NO se debe agregar `WHERE u.activo = TRUE` a esta vista. Crear una vista separada `v_clientes_activos` para el caso de uso operativo.
- **Permisos sugeridos:** `GRANT SELECT ON v_resumen_pedidos TO rol_consulta, rol_operador, rol_administrador;`. Dado que excluye la contraseña, el acceso de lectura puede ser amplio dentro de los roles internos del sistema.
