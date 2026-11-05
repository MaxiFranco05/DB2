# Consigna 2.c — Casos de Prueba del Semáforo (C2 a C6) y Verificación en Servidor

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store (`food_store_copia` en PostgreSQL y `movil/foodstore_movil.db` en SQLite)  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  

---

## Preparación de la instantánea en la copia del servidor

Luego de que la tablet armó los borradores locales en `movil/casos_simulacion.sql`, en la copia del servidor PostgreSQL se actualizó el precio del `Producto 1` (de `4214.51` a `4500.00`, es decir `450000` centavos) y se dio de baja lógica al `Producto 3` (`activo = FALSE`), exportándose la nueva instantánea a `movil/servidor_snapshot.csv` e importándose en `snapshot_servidor` dentro de SQLite:

```sql
-- En PostgreSQL de pruebas (food_store_copia)
UPDATE producto SET precio = 4500.00 WHERE id = 1;
UPDATE producto SET activo = FALSE   WHERE id = 3;
\copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER
```

---

## Caso C2 — Cambio de precio en el servidor (`CONFLICTO` → Aceptación → `SIMULADO_APROBADO`)

### 1. Comando utilizado:
```sql
-- 1) Borrador armado con el precio anterior del Producto 1 (421451 centavos)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c2000000-0000-4000-8000-000000000002', 'operador_feria', 'TARJETA', '2026-11-05T19:15:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c2000000-0000-4000-8000-000000000002', 1, 2, 421451);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c2-0001', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- 2) Tras ejecutar movil/semaforo.sql (da CONFLICTO), el cliente acepta el nuevo precio (450000):
UPDATE item_borrador
SET precio_centavos_visto = 450000
WHERE id_local = 'c2000000-0000-4000-8000-000000000002' AND producto_id = 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c2-0002', 'c2000000-0000-4000-8000-000000000002', 'PENDIENTE', NULL);

-- 3) Se vuelve a correr movil/semaforo.sql y se consulta cola_sync:
SELECT solicitud_uuid, estado, motivo
FROM cola_sync
WHERE solicitud_uuid IN ('req-uuid-c2-0001', 'req-uuid-c2-0002')
ORDER BY solicitud_uuid;
```

### 2. Resultado esperado vs. Resultado obtenido:
- **Resultado esperado:** Primera solicitud en `CONFLICTO`; luego de actualizar el precio del borrador y generar una solicitud nueva, pasa a `SIMULADO_APROBADO`.
- **Resultado obtenido en SQLite:**
```text
solicitud_uuid   | estado            | motivo
-----------------+-------------------+-----------------------------------------------------------------------------------
req-uuid-c2-0001 | CONFLICTO         | CONFLICTO: El precio actual en el servidor difiere del precio visto en el borrador
req-uuid-c2-0002 | SIMULADO_APROBADO | OK: Precio, disponibilidad y stock verificados en la instantánea
```

### 3. Explicación:
El semáforo detecta que el producto sigue activo y con stock suficiente (`184 >= 2`), pero como `precio_centavos_visto` (`421451`) difiere de `snapshot_servidor.precio_centavos` (`450000`), marca la solicitud original `req-uuid-c2-0001` en amarillo (`CONFLICTO`). Cuando el cliente acepta el nuevo importe, se actualiza `precio_centavos_visto = 450000` en el borrador y se encola una nueva solicitud (`req-uuid-c2-0002`), la cual al reevaluarse coincide exactamente con la instantánea y recibe `SIMULADO_APROBADO` sin pisar la auditoría del intento anterior.

---

## Caso C3 — Borrador por más unidades de las que quedan (`RECHAZADO`)

### 1. Comando utilizado:
```sql
-- Producto 2 tiene stock = 36 en el servidor; el borrador solicita cantidad = 50
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c3000000-0000-4000-8000-000000000003', 'operador_feria', 'EFECTIVO', '2026-11-05T19:16:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c3000000-0000-4000-8000-000000000003', 2, 50, 76689);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c3-0001', 'c3000000-0000-4000-8000-000000000003', 'PENDIENTE', NULL);

-- Luego de ejecutar movil/semaforo.sql:
SELECT solicitud_uuid, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'req-uuid-c3-0001';
```

### 2. Resultado esperado vs. Resultado obtenido:
- **Resultado esperado:** `RECHAZADO`.
- **Resultado obtenido en SQLite:**
```text
solicitud_uuid   | estado    | motivo
-----------------+-----------+-------------------------------------------------------------------------
req-uuid-c3-0001 | RECHAZADO | RECHAZADO: Stock insuficiente en el servidor para la cantidad solicitada
```

### 3. Explicación:
Al comparar `item_borrador.cantidad` (`50`) contra `snapshot_servidor.stock` (`36`) para el `Producto 2`, la condición de semáforo rojo (`i.cantidad > s.stock`) se cumple y la solicitud pasa a `RECHAZADO`. De esta forma, el servidor impide que la tablet confirme una venta sin inventario suficiente para despacharla.

---

## Caso C4 — Producto dado de baja lógica (`RECHAZADO` y lápida en catálogo)

### 1. Comando utilizado:
```sql
-- 1) Borrador armado con Producto 3 antes de su baja lógica en el servidor
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c4000000-0000-4000-8000-000000000004', 'operador_feria', 'TRANSFERENCIA', '2026-11-05T19:17:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c4000000-0000-4000-8000-000000000004', 3, 1, 328926);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c4-0001', 'c4000000-0000-4000-8000-000000000004', 'PENDIENTE', NULL);

-- 2) Tras ejecutar movil/semaforo.sql y recargar producto_cache desde snapshot_servidor:
SELECT solicitud_uuid, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'req-uuid-c4-0001';
SELECT id, nombre, disponible, eliminado FROM producto_cache WHERE id = 3;
SELECT id, nombre, precio_centavos, stock_visto FROM producto_cache
WHERE disponible = 1 AND eliminado = 0 AND stock_visto > 0 AND id <= 4 ORDER BY id;
```

### 2. Resultado esperado vs. Resultado obtenido:
- **Resultado esperado:** `RECHAZADO`; al recargar el catálogo, el producto ya no aparece entre los disponibles pero la fila sigue existiendo en `producto_cache` (lápida).
- **Resultado obtenido en SQLite:**
```text
-- Estado en cola_sync:
req-uuid-c4-0001 | RECHAZADO | RECHAZADO: Producto dado de baja lógica (eliminado)

-- Fila conservada en producto_cache (lápida: disponible = 0, eliminado = 1):
(3, 'Producto 3', 0, 1)

-- Consulta del catálogo disponible (id <= 4): el Producto 3 ya no aparece
(1, 'Producto 1', 450000, 184)
(2, 'Producto 2',  76689,  36)
(4, 'Producto 4',  63036, 154)
```

### 3. Explicación:
En la instantánea del servidor el `Producto 3` viaja como lápida (`disponible = f`, `eliminado = t`), por lo que el semáforo marca la solicitud `req-uuid-c4-0001` como `RECHAZADO`. Al actualizar `producto_cache`, la fila no se borra con `DELETE` sino que permanece con `eliminado = 1` y `disponible = 0`: así se preserva la integridad referencial (`FOREIGN KEY`) de los borradores históricos mientras la consulta del catálogo (C1) oculta el producto a nuevas ventas.

---

## Caso C5 — Borrador sin cambios (`SIMULADO_APROBADO`)

### 1. Comando utilizado:
```sql
-- Producto 4 no sufrió cambios (precio 63036 coincide, cantidad 3 <= stock 154, disponible = t)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c5000000-0000-4000-8000-000000000005', 'operador_feria', 'EFECTIVO', '2026-11-05T19:18:00Z');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c5000000-0000-4000-8000-000000000005', 4, 3, 63036);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);

-- Luego de ejecutar movil/semaforo.sql:
SELECT solicitud_uuid, estado, motivo FROM cola_sync WHERE solicitud_uuid = 'req-uuid-c5-0001';
```

### 2. Resultado esperado vs. Resultado obtenido:
- **Resultado esperado:** `SIMULADO_APROBADO`.
- **Resultado obtenido en SQLite:**
```text
solicitud_uuid   | estado            | motivo
-----------------+-------------------+-----------------------------------------------------------------
req-uuid-c5-0001 | SIMULADO_APROBADO | OK: Precio, disponibilidad y stock verificados en la instantánea
```

### 3. Explicación:
Todos los ítems del borrador superan las validaciones contra `snapshot_servidor` (el `Producto 4` existe, está activo, tiene stock `154 >= 3` y su precio `63036` no varió), por lo que el semáforo le asigna luz verde (`SIMULADO_APROBADO`). Cabe recordar que `SIMULADO_APROBADO` valida la prefactibilidad del borrador en la simulación, pero no representa por sí mismo una venta confirmada en PostgreSQL.

---

## Caso C6 — Reenviar la misma solicitud con el mismo UUID (Idempotencia)

### 1. Comando utilizado:
```sql
-- 1) Intento de reinsertar la misma solicitud con el mismo solicitud_uuid ('req-uuid-c5-0001')
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);

-- 2) Reejecución completa de movil/semaforo.sql
```

### 2. Resultado esperado vs. Resultado obtenido:
- **Resultado esperado:** No se duplica: el UUID repetido da error de clave primaria y repetir la simulación no reevalúa las solicitudes ya resueltas.
- **Resultado obtenido en SQLite:**
```text
Error al reinsertar el mismo UUID:
UNIQUE constraint failed: cola_sync.solicitud_uuid

Estado de cola_sync tras volver a correr movil/semaforo.sql (sin cambios ni reevaluaciones):
req-uuid-c2-0001 | CONFLICTO
req-uuid-c2-0002 | SIMULADO_APROBADO
req-uuid-c3-0001 | RECHAZADO
req-uuid-c4-0001 | RECHAZADO
req-uuid-c5-0001 | SIMULADO_APROBADO
```

### 3. Explicación y protección real en el servidor (Parada 8):
La clave primaria `solicitud_uuid TEXT PRIMARY KEY` en `cola_sync` rechaza cualquier intento de encolar dos veces el mismo identificador de solicitud, y la cláusula `WHERE estado = 'PENDIENTE'` de `semaforo.sql` garantiza que correr el semáforo múltiples veces sea idempotente y no reevalúe solicitudes ya cerradas. **En un sistema de producción real (Parada 8), la protección definitiva contra duplicados por reintentos de red debe residir en el servidor PostgreSQL mediante una columna `solicitud_uuid UUID UNIQUE` (o tabla de llaves de idempotencia) en la tabla `pedido`, de modo que si la tablet reenvía un paquete cuyo ACK se perdió, PostgreSQL detecte la clave `UNIQUE` dentro de la transacción y devuelva el resultado previo sin volver a insertar el pedido ni descontar el stock dos veces.**

---

## Verificación final en PostgreSQL: Cantidad de pedidos y stock inalterados

Para demostrar la regla de oro (*"La tablet nunca cambia el stock ni el precio del servidor, ni confirma ventas: `SIMULADO_APROBADO` no es una venta"*), se ejecutó en PostgreSQL (`food_store_copia`) la consulta de control antes y después de correr toda la batería del semáforo en SQLite:

```sql
SELECT COUNT(*) AS total_pedidos FROM pedido;

SELECT id, nombre, precio, stock, activo
FROM producto
WHERE id IN (1, 2, 3, 4)
ORDER BY id;
```

Resultado obtenido en PostgreSQL (exactamente los mismos valores iniciales, sin ningún pedido nuevo ni descuento de stock):
```text
 total_pedidos 
---------------
        200001
(1 fila)

 id |   nombre   | precio  | stock | activo 
----+------------+---------+-------+--------
  1 | Producto 1 | 4214.51 |   184 | t
  2 | Producto 2 |  766.89 |    36 | t
  3 | Producto 3 | 3289.26 |   199 | t
  4 | Producto 4 |  630.36 |   154 | t
(4 filas)
```
