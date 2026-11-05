# Requirements — TP8: Semáforo de Sincronización SQLite ↔ PostgreSQL
## Food Store | Bases de Datos II

**Asignatura:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store | **Motor Tablet:** SQLite (offline) | **Motor Servidor:** PostgreSQL (fuente de verdad)  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  
**Fecha:** 5 de Noviembre de 2026

---

## Glosario

- **Tablet:** dispositivo cliente (móvil/embedded) que corre SQLite en modo offline.
- **Servidor:** instancia PostgreSQL que actúa como única fuente de verdad para precios, stock y ventas.
- **Borrador:** pedido construido localmente en la tablet, aún no confirmado en el servidor.
- **Instantánea (snapshot):** copia local del catálogo descargada del servidor en un momento determinado (precio + activo + stock).
- **Cola de sincronización (`cola_sync`):** tabla SQLite que registra cada borrador pendiente de resolución.
- **Semáforo:** lógica de resolución que compara el borrador contra el estado actual del servidor y emite uno de los cuatro estados: `CONFLICTO`, `RECHAZADO`, `SIMULADO_APROBADO` o `PENDIENTE`.
- **C2–C5:** identificadores de casos de prueba formales definidos en la consigna del TP8.

---

## Requisitos Funcionales

### REQ-01 — Detección de conflicto de precio

**User Story:** Como operador de la tablet, quiero saber cuando el precio de un producto cambió en el servidor desde que armé el borrador, para que el sistema me alerte antes de confirmar un pedido con precios desactualizados.

#### Acceptance Criteria

1. WHEN el precio registrado en `pedido_borrador.precio_visto` para un ítem difiere del precio actual del producto en el servidor PostgreSQL, THEN THE SYSTEM SHALL marcar el registro correspondiente en `cola_sync` con estado `CONFLICTO`.
2. IF el estado resultante es `CONFLICTO`, THEN THE SYSTEM SHALL conservar el valor `precio_visto` original del borrador para que el operador pueda compararlo contra el precio nuevo del servidor.
3. THE SYSTEM SHALL evaluar la condición de conflicto de precio antes de evaluar cualquier otra condición de rechazo sobre el mismo ítem.

**Caso de prueba:** C2

---

### REQ-02 — Rechazo por stock insuficiente

**User Story:** Como operador de la tablet, quiero que el sistema rechace automáticamente un borrador si el stock disponible en el servidor es menor a la cantidad solicitada, para evitar confirmar ventas que no pueden despacharse.

#### Acceptance Criteria

1. WHEN la cantidad indicada en `item_borrador.cantidad` supera el valor actual de `producto.stock` en el servidor PostgreSQL, THEN THE SYSTEM SHALL marcar el registro correspondiente en `cola_sync` con estado `RECHAZADO`.
2. IF el estado resultante es `RECHAZADO` por stock insuficiente, THEN THE SYSTEM SHALL registrar en `cola_sync.detalle_rechazo` el stock disponible al momento de la evaluación.
3. THE SYSTEM SHALL evaluar la condición de stock después de evaluar el conflicto de precio (REQ-01); un ítem con conflicto de precio no avanza a la evaluación de stock.

**Caso de prueba:** C3

---

### REQ-03 — Rechazo por baja lógica de producto

**User Story:** Como operador de la tablet, quiero que el sistema rechace un borrador que incluya un producto dado de baja en el servidor, para evitar vender ítems que ya no están disponibles en el catálogo.

#### Acceptance Criteria

1. WHEN un producto incluido en `item_borrador` tiene el campo `activo = FALSE` en la tabla `producto` del servidor PostgreSQL, THEN THE SYSTEM SHALL marcar el registro correspondiente en `cola_sync` con estado `RECHAZADO`.
2. IF el estado resultante es `RECHAZADO` por baja lógica, THEN THE SYSTEM SHALL registrar en `cola_sync.detalle_rechazo` el identificador del producto dado de baja y la razón `PRODUCTO_INACTIVO`.
3. THE SYSTEM SHALL evaluar la condición de baja lógica en la misma pasada que la condición de stock (REQ-02); si un producto está inactivo, no se evalúa su stock.

**Caso de prueba:** C4

---

### REQ-04 — Aprobación simulada de borrador válido

**User Story:** Como operador de la tablet, quiero que el sistema confirme automáticamente un borrador cuando todos sus ítems coinciden exactamente con la instantánea actual del servidor, para agilizar el cierre de pedidos sin intervención manual.

#### Acceptance Criteria

1. WHEN todos los ítems de un borrador cumplen simultáneamente las siguientes condiciones al compararse contra el servidor PostgreSQL — (a) precio coincide exactamente con el precio actual, (b) cantidad solicitada no supera el stock disponible, y (c) el producto tiene `activo = TRUE` — THEN THE SYSTEM SHALL marcar el registro en `cola_sync` con estado `SIMULADO_APROBADO`.
2. IF el estado resultante es `SIMULADO_APROBADO`, THEN THE SYSTEM SHALL registrar en `cola_sync` la marca de tiempo de aprobación (`aprobado_en`).
3. THE SYSTEM SHALL emitir el estado `SIMULADO_APROBADO` únicamente cuando ninguno de los estados `CONFLICTO` ni `RECHAZADO` fue asignado a ningún ítem del borrador.

**Caso de prueba:** C5

---

## Matriz de trazabilidad

| Requisito | Estado emitido       | Caso de prueba | Condición disparadora                                   |
|-----------|----------------------|----------------|---------------------------------------------------------|
| REQ-01    | `CONFLICTO`          | C2             | `precio_visto ≠ producto.precio` (servidor)             |
| REQ-02    | `RECHAZADO`          | C3             | `item.cantidad > producto.stock` (servidor)             |
| REQ-03    | `RECHAZADO`          | C4             | `producto.activo = FALSE` (servidor)                    |
| REQ-04    | `SIMULADO_APROBADO`  | C5             | Precio ✓ + Stock ✓ + Activo ✓ (todos los ítems)         |
