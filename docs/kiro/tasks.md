# Tasks — TP8: Implementación del Semáforo de Sincronización
## Food Store | Bases de Datos II

**Fecha:** 5 de Noviembre de 2026

---

## Resumen

Crear el esquema SQLite de la tablet (4 tablas) y el script del semáforo que evalúa borradores contra el servidor PostgreSQL, emitiendo uno de los estados `CONFLICTO`, `RECHAZADO` o `SIMULADO_APROBADO`.

---

## Tareas

### Tarea 1 — Crear el archivo `db/sqlite_schema.sql`

Crear el script SQL con las 4 tablas del esquema SQLite de la tablet.

- [ ] 1.1 Crear tabla `producto_cache`
  - Campos: `id`, `nombre`, `precio` (REAL), `stock` (INTEGER), `activo` (INTEGER 0/1), `ultima_sync` (TEXT ISO-8601)
  - PRIMARY KEY en `id` (mismo id que `producto.id` en PostgreSQL)
  - _Requisito: REQ-04 (precio_visto se compara contra este caché)_

- [ ] 1.2 Crear tabla `pedido_borrador`
  - Campos: `id` (AUTOINCREMENT), `usuario_id`, `creado_en` (TEXT ISO-8601), `forma_pago`
  - CHECK: `forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')`
  - _Requisito: REQ-04_

- [ ] 1.3 Crear tabla `item_borrador`
  - Campos: `borrador_id` (FK → `pedido_borrador`), `producto_id` (FK → `producto_cache`), `cantidad` (CHECK > 0), `precio_visto` (REAL)
  - PRIMARY KEY compuesta: `(borrador_id, producto_id)`
  - _Requisitos: REQ-01, REQ-02, REQ-03, REQ-04_

- [ ] 1.4 Crear tabla `cola_sync`
  - Campos: `id` (AUTOINCREMENT), `borrador_id` (FK → `pedido_borrador`), `estado` (DEFAULT `'PENDIENTE'`), `detalle_rechazo` (TEXT, JSON libre), `aprobado_en` (TEXT), `evaluado_en` (TEXT)
  - CHECK: `estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')`
  - _Requisitos: REQ-01, REQ-02, REQ-03, REQ-04_

- [ ] 1.5 Agregar sentencia `\set ON_ERROR_STOP on` y comentarios de cabecera al script
  - Incluir: descripción, fecha, integrantes, motor objetivo (SQLite 3.x)

---

### Tarea 2 — Crear datos de prueba en `db/sqlite_seed.sql`

Insertar filas mínimas que permitan ejecutar los casos C2, C3, C4 y C5.

- [ ] 2.1 Insertar al menos 4 filas en `producto_cache` (una por caso de prueba)
  - C2: producto con precio que diferirá del servidor (ej. precio_cache = 1000, precio_servidor = 1200)
  - C3: producto con stock menor a la cantidad del borrador (ej. stock = 2, borrador pide 5)
  - C4: producto con `activo = 0`
  - C5: producto completamente válido (precio coincide, stock suficiente, activo = 1)

- [ ] 2.2 Insertar 4 filas en `pedido_borrador` (uno por caso)

- [ ] 2.3 Insertar 4 filas en `item_borrador` (una por borrador, usando el producto correspondiente)

- [ ] 2.4 Insertar 4 filas en `cola_sync` con `estado = 'PENDIENTE'` para cada borrador

---

### Tarea 3 — Crear el script del semáforo `sql/semaforo_sync.sql`

Script PostgreSQL que lee la `cola_sync` con estado `PENDIENTE` y actualiza el estado según las reglas de los requisitos.

- [ ] 3.1 Escribir la función `evaluar_borrador(p_borrador_id INTEGER)` en PL/pgSQL
  - Recorrer cada ítem de `item_borrador` con un cursor o `FOR`
  - Por cada ítem, consultar `producto.precio`, `producto.activo`, `producto.stock` en PostgreSQL
  - _Requisito: REQ-01_ — IF `item.precio_visto ≠ producto.precio` THEN registrar `CONFLICTO` en `cola_sync.detalle_rechazo` (JSON) y salir del loop del ítem
  - _Requisito: REQ-03_ — ELSE IF `producto.activo = FALSE` THEN registrar `RECHAZADO` con `razon = 'PRODUCTO_INACTIVO'`
  - _Requisito: REQ-02_ — ELSE IF `item.cantidad > producto.stock` THEN registrar `RECHAZADO` con `razon = 'STOCK_INSUFICIENTE'` y `stock_disponible`
  - _Requisito: REQ-04_ — Si ningún ítem disparó error, registrar `SIMULADO_APROBADO` y `aprobado_en = NOW()`
  - Actualizar `cola_sync.estado`, `cola_sync.detalle_rechazo`, `cola_sync.evaluado_en`

- [ ] 3.2 Escribir el bloque de ejecución `DO $$` que llama a `evaluar_borrador()` para todos los registros con `estado = 'PENDIENTE'` en `cola_sync`

- [ ] 3.3 Agregar consulta de verificación al final del script
  - `SELECT borrador_id, estado, detalle_rechazo, aprobado_en FROM cola_sync ORDER BY borrador_id;`
  - Resultado esperado: una fila por borrador con el estado correcto (C2→CONFLICTO, C3→RECHAZADO, C4→RECHAZADO, C5→SIMULADO_APROBADO)

---

### Tarea 4 — Verificar propiedades de corrección

Ejecutar consultas de verificación para confirmar que el semáforo cumple los 4 requisitos.

- [ ] 4.1 Verificar REQ-01 (C2 → CONFLICTO)
  - Consulta: `SELECT * FROM cola_sync WHERE borrador_id = <id_C2> AND estado = 'CONFLICTO';`
  - Resultado esperado: 1 fila; `detalle_rechazo` contiene `precio_visto` y `precio_actual`

- [ ] 4.2 Verificar REQ-02 (C3 → RECHAZADO por stock)
  - Consulta: `SELECT * FROM cola_sync WHERE borrador_id = <id_C3> AND estado = 'RECHAZADO';`
  - Resultado esperado: 1 fila; `detalle_rechazo` contiene `razon = 'STOCK_INSUFICIENTE'` y `stock_disponible`

- [ ] 4.3 Verificar REQ-03 (C4 → RECHAZADO por baja lógica)
  - Consulta: `SELECT * FROM cola_sync WHERE borrador_id = <id_C4> AND estado = 'RECHAZADO';`
  - Resultado esperado: 1 fila; `detalle_rechazo` contiene `razon = 'PRODUCTO_INACTIVO'`

- [ ] 4.4 Verificar REQ-04 (C5 → SIMULADO_APROBADO)
  - Consulta: `SELECT * FROM cola_sync WHERE borrador_id = <id_C5> AND estado = 'SIMULADO_APROBADO';`
  - Resultado esperado: 1 fila; `aprobado_en` no nulo

- [ ] 4.5 Verificar que no existen registros en `PENDIENTE` luego de la ejecución
  - Consulta: `SELECT COUNT(*) FROM cola_sync WHERE estado = 'PENDIENTE';`
  - Resultado esperado: 0

---

### Tarea 5 — Documentación

- [ ] 5.1 Crear `docs/DUIA/DUIA-TP-Unidad8.md` con la tabla DUIA del TP8 al finalizar la implementación

- [ ] 5.2 Actualizar `BITACORA.md` con el registro de sesión del TP8

---

## Grafo de dependencias

```
Wave 0: 1.1 → 1.2 → 1.3 → 1.4 → 1.5   (secuencial — FK entre tablas)
Wave 1: 2.1 → 2.2 → 2.3 → 2.4          (secuencial — FK entre seeds)
Wave 2: 3.1 → 3.2 → 3.3                 (secuencial — función antes que llamada)
Wave 3: 4.1, 4.2, 4.3, 4.4, 4.5        (paralelo — verificaciones independientes)
Wave 4: 5.1, 5.2                         (paralelo — documentación)
```

## Notas

- El script `semaforo_sync.sql` corre en PostgreSQL pero lee la `cola_sync` que originó en SQLite. En la integración real, la tablet envía los datos de `cola_sync` + `item_borrador` al servidor antes de ejecutar el semáforo.
- Las columnas `detalle_rechazo` se almacenan como JSON libre (TEXT en SQLite, `jsonb` en PostgreSQL recomendado).
- Los casos de prueba C2–C5 deben poder ejecutarse de forma aislada; los seeds deben ser idempotentes (usar `INSERT OR REPLACE` en SQLite).
