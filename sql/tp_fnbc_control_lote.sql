-- =====================================================================
-- Trabajo Práctico Unidad 4 - Parte 1: FNBC en Control Lote Almacén
-- =====================================================================

BEGIN;

-- =====================================================================
-- 0. LIMPIEZA PREVIA (Idempotencia)
-- =====================================================================
DROP VIEW IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote;
DROP TABLE IF EXISTS responsable_deposito;
DROP TABLE IF EXISTS control_lote_almacen;
DROP TABLE IF EXISTS lote;
DROP TABLE IF EXISTS deposito;

-- =====================================================================
-- 1. ESQUEMA ORIGINAL E INSTANCIA DE EJEMPLO
-- =====================================================================

-- Creación de tablas maestras auxiliares de la extensión mayorista
CREATE TABLE lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE deposito (
    id BIGINT PRIMARY KEY
);

-- Garantizamos que existan los usuarios 801 y 802 en la tabla maestra usuario
INSERT INTO usuario (id, nombre, apellido, mail, celular, contrasena)
OVERRIDING SYSTEM VALUE
VALUES
    (801, 'Responsable', 'Depósito 30', 'resp801@foodstore.com', '1100000801', 'hash_seguro_801'),
    (802, 'Responsable', 'Depósito 31', 'resp802@foodstore.com', '1100000802', 'hash_seguro_802')
ON CONFLICT (id) DO NOTHING;

-- Tabla inicial con anomalías (no cumple FNBC)
CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Inserción de la instancia de ejemplo provista por la cátedra
INSERT INTO lote (id) VALUES (501), (502), (503) ON CONFLICT DO NOTHING;
INSERT INTO deposito (id) VALUES (30), (31) ON CONFLICT DO NOTHING;

INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id) VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802)
ON CONFLICT DO NOTHING;


-- =====================================================================
-- 2. TABLAS DESCOMPUESTAS (Corrección de violación a la FNBC - Punto 4.2e)
-- =====================================================================
-- Se descompone debido a la DF2: responsable_control_id -> deposito_id
-- donde el determinante {responsable_control_id} no es superclave del esquema.

-- R1: Tabla maestra de asignación de responsable a depósito
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

-- R2: Tabla relacional de lotes y responsables de control
CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);


-- =====================================================================
-- 3. VISTA DE COMPATIBILIDAD (Punto 4.2e)
-- =====================================================================
-- Reconstruye la relación original mediante reunión natural sobre el
-- atributo común responsable_control_id (Teorema de Heath).
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT 
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd
  ON cl.responsable_control_id = rd.responsable_control_id;


-- =====================================================================
-- 4. MIGRACIÓN Y VERIFICACIÓN DE DATOS (Punto 4.2f)
-- =====================================================================

-- Paso A: Migrar proyecciones únicas hacia R1 (responsable_deposito)
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen
ON CONFLICT (responsable_control_id) DO NOTHING;

-- Paso B: Migrar asignaciones de lote hacia R2 (control_lote)
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM control_lote_almacen
ON CONFLICT (lote_id, responsable_control_id) DO NOTHING;

-- Paso C: Consulta de verificación sobre la vista de compatibilidad
-- (Devuelve exactamente las 3 tuplas originales de la instancia de ejemplo)
SELECT lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen
ORDER BY lote_id;

-- Paso D: Verificación formal de equivalencia sin pérdida (EXCEPT bidireccional)
-- Debe retornar 0 filas si la reconstrucción por la vista es idéntica al original.
(
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
)
UNION ALL
(
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
);

COMMIT;
