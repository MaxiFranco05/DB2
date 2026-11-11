# Design — TP8: Arquitectura del Semáforo de Sincronización

**Food Store | Bases de Datos II**  
**Comisión:** C3 · Prof. Sergio Neira  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  

---

## 1. Regla de Oro: Separación de Fuentes de Verdad

```text
┌─────────────────────────────────────────────────────────────┐
│                 TABLET (SQLite 3.37+ STRICT)                │
│                                                             │
│  snapshot_servidor ─── Staging de instantánea descargada    │
│  producto_cache    ─── Catálogo local con dinero en centavos│
│  pedido_borrador   ─── Cabecera del pedido local            │
│  item_borrador     ─── Líneas con precio_centavos_visto     │
│  cola_sync         ─── Fila pendiente y evaluada            │
│                                                             │
│  Rol: CONSULTA OFFLINE Y ARMADO DE BORRADORES               │
│  No descuenta stock. No confirma ventas en central.         │
└──────────────────────────────┬──────────────────────────────┘
                               │ Conexión y sincronización
                               ▼
┌─────────────────────────────────────────────────────────────┐
│            SERVIDOR CENTRAL (PostgreSQL 16+)                │
│                                                             │
│  producto       ─── Precios oficiales y stock real          │
│  pedido         ─── Pedidos firmes confirmados              │
│  detalle_pedido ─── Líneas de detalle facturadas            │
│  v_snapshot_movil ── Catálogo con fecha_copia para exportar │
│                                                             │
│  Rol: ÚNICA AUTORIDAD Y FUENTE DE VERDAD                    │
│  Descuenta stock. Confirma ventas. Cobra.                   │
└─────────────────────────────────────────────────────────────┘
```

**Consecuencia directa:** La tablet jamás modifica stock ni confirma ventas por sí misma. El estado `SIMULADO_APROBADO` en SQLite indica prefactibilidad técnica, pero solo PostgreSQL es la autoridad final.

---

## 2. Modelo de Datos SQLite (Modo STRICT y Centavos Enteros)

Para eliminar imprecisiones por aritmética de coma flotante binaria (IEEE 754), se eliminó el tipo `REAL` y se forzó `INTEGER` en centavos (`precio * 100`).

```sql
PRAGMA foreign_keys = ON;

-- 1. Tabla staging para la instantánea exportada
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL,
    disponible      TEXT    NOT NULL,
    eliminado       TEXT    NOT NULL,
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- 2. Caché de catálogo local en la tablet
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- 3. Pedidos borradores locales
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY,
    usuario    TEXT NOT NULL,
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL
) STRICT;

-- 4. Ítems del borrador con precio congelado en centavos
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- 5. Cola de sincronización local
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT
) STRICT;
```

---

## 3. Lógica Jerárquica del Semáforo

El semáforo evalúa cada solicitud en estado `PENDIENTE` contra `snapshot_servidor` siguiendo un orden estricto de prioridades:

```
Para cada ítem en item_borrador de la solicitud:
 1. ¿El producto no existe, está inactivo (eliminado = 't') o no disponible?
    → RECHAZADO (Prioridad 1)
 2. ¿La cantidad solicitada supera el stock disponible en snapshot_servidor?
    → RECHAZADO (Prioridad 1)
 3. ¿El precio_centavos_visto difiere del precio_centavos en el servidor?
    → CONFLICTO (Prioridad 2)
 4. Si ningún ítem generó RECHAZADO ni CONFLICTO:
    → SIMULADO_APROBADO (Prioridad 3)
```
