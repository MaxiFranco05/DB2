# Design — TP8: Arquitectura del Semáforo de Sincronización
## Food Store | Bases de Datos II

**Fecha:** 5 de Noviembre de 2026

---

## 1. Regla de oro: fuentes de verdad separadas

```
┌─────────────────────────────────────────────────────────────┐
│                   TABLET (SQLite — offline)                  │
│                                                             │
│  producto_cache  ←── snapshot del catálogo del servidor     │
│  pedido_borrador ←── cabecera del pedido local              │
│  item_borrador   ←── líneas del pedido local                │
│  cola_sync       ←── fila pendiente de resolución           │
│                                                             │
│  Rol: SOLO CONSULTA Y ARMADO DE BORRADORES                  │
│  No descuenta stock. No confirma precios. No registra ventas│
└─────────────────────┬───────────────────────────────────────┘
                      │  conexión (cuando hay red)
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               SERVIDOR (PostgreSQL — fuente de verdad)       │
│                                                             │
│  producto    ←── precios y stock reales                     │
│  pedido      ←── pedidos confirmados                        │
│  detalle_pedido ← líneas confirmadas                        │
│                                                             │
│  Rol: ÚNICA AUTORIDAD que decide si un pedido es válido     │
│  Descuenta stock. Congela precio. Registra la venta.        │
└─────────────────────────────────────────────────────────────┘
```

**Consecuencia directa:** la tablet nunca decide si un pedido "puede hacerse". Construye un borrador basado en su caché local y luego envía ese borrador al semáforo, que lo compara contra el estado actual del servidor. El resultado es siempre una decisión del servidor.

---

## 2. Modelo de datos SQLite

### 2.1 `producto_cache`

Copia local del catálogo descargada del servidor. Se actualiza al reconectar.

```sql
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,  -- mismo id que producto.id en PostgreSQL
    nombre          TEXT    NOT NULL,
    precio          REAL    NOT NULL,     -- precio al momento del último sync
    stock           INTEGER NOT NULL,
    activo          INTEGER NOT NULL DEFAULT 1,  -- 1 = activo, 0 = baja lógica
    ultima_sync     TEXT    NOT NULL      -- ISO-8601: cuándo se descargó este snapshot
);
```

### 2.2 `pedido_borrador`

Cabecera del pedido construido offline. Una fila por borrador pendiente.

```sql
CREATE TABLE pedido_borrador (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id      INTEGER NOT NULL,     -- id del operador/cliente local
    creado_en       TEXT    NOT NULL,     -- ISO-8601
    forma_pago      TEXT    NOT NULL      -- 'EFECTIVO' | 'TARJETA' | 'TRANSFERENCIA'
);
```

### 2.3 `item_borrador`

Líneas del borrador. Guarda el precio visto al momento de armar el pedido.

```sql
CREATE TABLE item_borrador (
    borrador_id     INTEGER NOT NULL REFERENCES pedido_borrador(id),
    producto_id     INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad        INTEGER NOT NULL CHECK (cantidad > 0),
    precio_visto    REAL    NOT NULL,     -- precio del snapshot al armar el borrador
    PRIMARY KEY (borrador_id, producto_id)
);
```

### 2.4 `cola_sync`

Fila de sincronización. Registra el resultado de la evaluación del semáforo.

```sql
CREATE TABLE cola_sync (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    borrador_id     INTEGER NOT NULL REFERENCES pedido_borrador(id),
    estado          TEXT    NOT NULL DEFAULT 'PENDIENTE',
                    -- 'PENDIENTE' | 'CONFLICTO' | 'RECHAZADO' | 'SIMULADO_APROBADO'
    detalle_rechazo TEXT,                -- JSON con razón del rechazo o conflicto
    aprobado_en     TEXT,                -- ISO-8601; solo si estado = 'SIMULADO_APROBADO'
    evaluado_en     TEXT                 -- ISO-8601; marca de la última evaluación
);
```

---

## 3. Lógica del semáforo

El semáforo es la función central del sistema. Recibe un `borrador_id`, consulta el estado actual del servidor PostgreSQL y recorre cada ítem evaluando tres condiciones en orden estricto:

```
Para cada item en item_borrador donde borrador_id = X:

  1. ¿precio_visto ≠ producto.precio (servidor)?
        → estado = CONFLICTO
        → guardar { "producto_id": N, "precio_visto": P1, "precio_actual": P2 }
        → cortar evaluación del ítem

  2. ¿producto.activo = FALSE (servidor)?
        → estado = RECHAZADO
        → guardar { "producto_id": N, "razon": "PRODUCTO_INACTIVO" }
        → cortar evaluación del ítem

  3. ¿item.cantidad > producto.stock (servidor)?
        → estado = RECHAZADO
        → guardar { "producto_id": N, "razon": "STOCK_INSUFICIENTE",
                    "stock_disponible": S }
        → cortar evaluación del ítem

Si ningún ítem disparó CONFLICTO ni RECHAZADO:
  → estado = SIMULADO_APROBADO
  → registrar aprobado_en = now()
```

**Orden de evaluación:** conflicto de precio → baja lógica → stock insuficiente. Este orden garantiza que el operador vea primero el problema más crítico (precio incorrecto) antes de enterarse de problemas de stock.

---

## 4. Casos de prueba formales

| ID | Escenario | Condición en servidor | Estado esperado |
|----|-----------|----------------------|-----------------|
| C2 | Precio cambió tras armar borrador | `precio_visto ≠ producto.precio` | `CONFLICTO` |
| C3 | Stock insuficiente al sincronizar | `item.cantidad > producto.stock` | `RECHAZADO` |
| C4 | Producto dado de baja lógica | `producto.activo = FALSE` | `RECHAZADO` |
| C5 | Borrador íntegramente válido | precio ✓ + stock ✓ + activo ✓ | `SIMULADO_APROBADO` |

---

## 5. Flujo de sincronización

```
Tablet (offline)                           Servidor (PostgreSQL)
─────────────────                          ─────────────────────
1. Operador arma borrador
   (usa producto_cache)
2. Guarda item_borrador
   con precio_visto
3. Inserta cola_sync
   estado = PENDIENTE
                        ── reconexión ──►
                                          4. Semáforo lee borrador
                                          5. Consulta producto.precio
                                             producto.stock
                                             producto.activo
                                          6. Evalúa REQ-01 → REQ-04
                                          7. Actualiza cola_sync.estado
                        ◄── respuesta ───
8. Tablet muestra resultado
   al operador
```

---

## 6. Archivos relacionados

| Archivo | Descripción |
|---------|-------------|
| `sql/schema.sql` | Esquema PostgreSQL canónico (tablas, triggers, índices) |
| `docs/kiro/requirements.md` | Requisitos funcionales REQ-01 a REQ-04 |
| `docs/kiro/tasks.md` | Lista de tareas de implementación |
