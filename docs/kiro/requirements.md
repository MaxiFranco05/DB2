# Requirements — TP8: Semáforo de Sincronización SQLite ↔ PostgreSQL

**Food Store | Bases de Datos II**  
**Asignatura:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store | **Motor Tablet:** SQLite 3.37+ (offline) | **Motor Servidor:** PostgreSQL (fuente de verdad)  
**Comisión:** C3 · Prof. Sergio Neira  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  

---

## Glosario
* **Tablet:** dispositivo cliente (móvil/embedded) que corre SQLite en modo offline.
* **Servidor:** instancia PostgreSQL que actúa como única fuente de verdad para precios, stock y ventas.
* **Borrador:** pedido construido localmente en la tablet, aún no confirmado en el servidor.
* **Instantánea (snapshot):** copia local del catálogo descargada del servidor en un momento determinado (`precio_centavos` + `activo` + `stock` + `fecha_copia`).
* **Cola de sincronización (`cola_sync`):** tabla SQLite que registra cada borrador pendiente de resolución.
* **Semáforo:** lógica de resolución que compara el borrador contra el estado actual del servidor y emite uno de los cuatro estados jerárquicos: `RECHAZADO`, `CONFLICTO`, `SIMULADO_APROBADO` o `PENDIENTE`.
* **C2–C6:** identificadores de casos de prueba formales definidos en la consigna del TP8.

---

## Requisitos Funcionales (Orden Jerárquico de Evaluación)

### REQ-01 — Rechazo por baja lógica de producto (Prioridad 1)
**User Story:** Como operador de la tablet, quiero que el sistema rechace de inmediato un borrador que incluya un producto dado de baja en el servidor, para evitar vender ítems que ya no están vigentes en el catálogo.

**Acceptance Criteria:**
1. WHEN un producto incluido en `item_borrador` tiene `disponible = 'f'` o `eliminado = 't'` (`activo = FALSE` en PostgreSQL), THEN THE SYSTEM SHALL marcar el registro correspondiente en `cola_sync` con estado `RECHAZADO`.
2. IF el estado resultante es `RECHAZADO` por baja lógica, THEN THE SYSTEM SHALL registrar en `cola_sync.motivo` el detalle `RECHAZADO: Producto dado de baja lógica (eliminado)`.
3. THE SYSTEM SHALL evaluar las condiciones de rechazo con prioridad absoluta sobre la evaluación de conflicto de precios. Si un producto está inactivo, no se evalúa su precio.
* **Caso de prueba:** C4

---

### REQ-02 — Rechazo por stock insuficiente (Prioridad 1)
**User Story:** Como operador de la tablet, quiero que el sistema rechace automáticamente un borrador si el stock disponible en el servidor es menor a la cantidad solicitada, para evitar confirmar ventas que no se pueden despachar.

**Acceptance Criteria:**
1. WHEN la cantidad indicada en `item_borrador.cantidad` supera el valor actual de `snapshot_servidor.stock`, THEN THE SYSTEM SHALL marcar el registro correspondiente en `cola_sync` con estado `RECHAZADO`.
2. IF el estado resultante es `RECHAZADO` por stock insuficiente, THEN THE SYSTEM SHALL registrar en `cola_sync.motivo` la razón `RECHAZADO: Stock insuficiente en el servidor para la cantidad solicitada`.
3. THE SYSTEM SHALL evaluar la falta de stock con prioridad sobre cualquier conflicto de precio.
* **Caso de prueba:** C3

---

### REQ-03 — Detección de conflicto de precio (Prioridad 2)
**User Story:** Como operador de la tablet, quiero saber si el precio de un producto cambió en el servidor desde que armé el borrador (siempre que el producto esté activo y con stock suficiente), para consultar al cliente en el mostrador antes de confirmar el pedido.

**Acceptance Criteria:**
1. WHEN el precio registrado en `item_borrador.precio_centavos_visto` difiere de `snapshot_servidor.precio_centavos`, AND el producto existe, está activo y tiene stock suficiente, THEN THE SYSTEM SHALL marcar el registro en `cola_sync` con estado `CONFLICTO`.
2. IF el estado resultante es `CONFLICTO`, THEN THE SYSTEM SHALL conservar el registro del borrador y permitir encolar una nueva solicitud (`solicitud_uuid`) una vez que el cliente acepte el nuevo importe.
* **Caso de prueba:** C2

---

### REQ-04 — Aprobación simulada de borrador válido (Prioridad 3)
**User Story:** Como operador de la tablet, quiero que el sistema confirme la prefactibilidad de un borrador cuando todos sus ítems coinciden exactamente con la instantánea actual del servidor.

**Acceptance Criteria:**
1. WHEN todos los ítems de un borrador cumplen simultáneamente: (a) precio en centavos coincide exactamente, (b) cantidad solicitada $\le$ stock disponible, y (c) producto activo y disponible, THEN THE SYSTEM SHALL marcar el registro en `cola_sync` con estado `SIMULADO_APROBADO`.
2. THE SYSTEM SHALL emitir `SIMULADO_APROBADO` únicamente cuando ninguno de los ítems disparó `RECHAZADO` ni `CONFLICTO`.
3. `SIMULADO_APROBADO` valida la prefactibilidad local en la simulación, pero no modifica stock ni inserta pedidos firmes en PostgreSQL (*el móvil propone, el servidor dispone*).
* **Caso de prueba:** C5

---

## Matriz de Trazabilidad de Requisitos

| Requisito | Jerarquía | Estado emitido | Caso de prueba | Condición disparadora |
| :--- | :---: | :--- | :---: | :--- |
| **REQ-01** | **Prioridad 1** | `RECHAZADO` | **C4** | `s.eliminado = 't' OR s.disponible = 'f'` |
| **REQ-02** | **Prioridad 1** | `RECHAZADO` | **C3** | `i.cantidad > s.stock` |
| **REQ-03** | **Prioridad 2** | `CONFLICTO` | **C2** | `i.precio_centavos_visto <> s.precio_centavos` (con stock y activo) |
| **REQ-04** | **Prioridad 3** | `SIMULADO_APROBADO` | **C5** | Precio coincidente + Stock suficiente + Activo |
