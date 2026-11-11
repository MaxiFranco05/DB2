-- =============================================================================
-- Food Store - Trabajo Práctico N.° 8 (Consigna 1.b: La base de la tablet)
-- Motor: SQLite 3.37+ (Modo STRICT)
-- Comisión: C3 · Prof. Sergio Neira
-- Equipo: Máximo Franco, Andrés Novello y Octavio Fiore
-- =============================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- 1. Tabla staging receptora del snapshot exportado desde PostgreSQL
--    Almacena la instantánea exacta del CSV generado con 10_snapshot_catalogo.sql
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL,
    disponible      TEXT    NOT NULL, -- 't' o 'f' proveniente del CSV
    eliminado       TEXT    NOT NULL, -- 't' o 'f' proveniente del CSV
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- 2. Caché local de catálogo utilizado por la interfaz de la tablet
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- 3. Cabecera del pedido borrador armado offline en la tablet
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY,
    usuario    TEXT NOT NULL,
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL
) STRICT;

-- 4. Ítems del pedido borrador con claves foráneas y validación de cantidad > 0
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- 5. Cola de sincronización local evaluada por el semáforo
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT
) STRICT;
