# Trabajo Práctico — Unidad 4: Forma Normal de Boyce-Codd y Desnormalización Controlada en Food Store

**Materia:** Bases de Datos II — Tecnicatura Universitaria en Programación (UTN)  
**Proyecto integrador de referencia:** Food Store

---

## Parte 1 — Análisis y aplicación de la FNBC: `ControlLoteAlmacen`

### 1.1. Contexto de dominio y esquema inicial

Food Store extiende su operación hacia la distribución mayorista incorporando depósitos propios y recibiendo de sus proveedores lotes de mercadería que deben pasar un control de calidad antes de ingresar al inventario.

Las reglas de negocio relevadas con el área de logística son:
1. Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado.
2. Cada responsable de control pertenece, como dato maestro de la dotación de personal, a un único depósito: no controla lotes coordinados desde depósitos distintos.

Esquema inicial e instancia de ejemplo:

```sql
CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);
```

---

### 1.2. Resolución

#### a) Dependencias funcionales

Usando los nombres de atributo $\text{LoteID}$, $\text{DepositoID}$ y $\text{ResponsableControlID}$, se desprenden dos dependencias funcionales no triviales a partir de las reglas de negocio:

$$DF_1: \{\text{LoteID}, \text{DepositoID}\} \to \text{ResponsableControlID}$$
*Justificación:* Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado.

$$DF_2: \text{ResponsableControlID} \to \text{DepositoID}$$
*Justificación:* Cada responsable de control pertenece a un único depósito y no controla lotes desde depósitos distintos.

---

#### b) Clausura de atributos, claves candidatas y clasificación de atributos

Sea el universo de atributos $U = \{\text{LoteID}, \text{DepositoID}, \text{ResponsableControlID}\}$ (abreviado $U = \{L, D, R\}$) y el conjunto de dependencias funcionales $F = \{DF_1: \{L, D\} \to R,\; DF_2: R \to D\}$.

**Observación estructural:** El atributo $\text{LoteID}$ ($L$) no aparece en el lado derecho (determinado) de ninguna dependencia funcional en $F$. Por lo tanto, **toda superclave y clave candidata debe contener obligatoriamente a $\text{LoteID}$**.

1. **Clausuras de subconjuntos unitarios:**
   - $\{L\}^+ = \{L\} \neq U$ (no es superclave).
   - $\{D\}^+ = \{D\} \neq U$ (no es superclave).
   - $\{R\}^+ = \{R, D\} \neq U$ (por aplicación de $DF_2: R \to D$; falta $L$, por lo que no es superclave).

2. **Clausura del conjunto $\{\text{LoteID}, \text{DepositoID}\}$ ($\{L, D\}$):**
   - Inicialización: $\{L, D\}^+ = \{L, D\}$.
   - Aplicando $DF_1$ ($\{L, D\} \to R$): se incorpora $R \implies \{L, D\}^+ = \{L, D, R\} = U$.
   - Cubre todo el universo $U$, por lo que $\{L, D\}$ es **superclave**.
   - **Minimalidad:** Sus subconjuntos propios son $\{L\}$ ($\{L\}^+ = \{L\} \neq U$) y $\{D\}$ ($\{D\}^+ = \{D\} \neq U$). Ningún subconjunto propio es superclave, por lo tanto $\{\text{LoteID}, \text{DepositoID}\}$ es **Clave Candidata**.

3. **Clausura del conjunto $\{\text{LoteID}, \text{ResponsableControlID}\}$ ($\{L, R\}$):**
   - Inicialización: $\{L, R\}^+ = \{L, R\}$.
   - Aplicando $DF_2$ ($R \to D$): se incorpora $D \implies \{L, R\}^+ = \{L, R, D\} = U$.
   - Cubre todo el universo $U$, por lo que $\{L, R\}$ es **superclave**.
   - **Minimalidad:** Sus subconjuntos propios son $\{L\}$ ($\{L\}^+ = \{L\} \neq U$) y $\{R\}$ ($\{R\}^+ = \{R, D\} \neq U$). Ningún subconjunto propio es superclave, por lo tanto $\{\text{LoteID}, \text{ResponsableControlID}\}$ es **Clave Candidata**.

**Resumen de claves y atributos:**
- **Conjunto completo de Claves Candidatas:**
  $$CK = \big\{\{\text{LoteID}, \text{DepositoID}\},\; \{\text{LoteID}, \text{ResponsableControlID}\}\big\}$$
- **Atributos Primos** (pertenecen a al menos una clave candidata): $\text{LoteID}$, $\text{DepositoID}$, $\text{ResponsableControlID}$ (todos los atributos del esquema son primos).
- **Atributos No Primos:** Ninguno ($\emptyset$).

*(Nota: Al ser todos los atributos primos, el esquema cumple 3FN, pero falla en FNBC como se demuestra a continuación).*

---

#### c) Evaluación formal de la Forma Normal de Boyce-Codd (FNBC)

**Definición formal de FNBC:** Un esquema de relación $R$ está en Forma Normal de Boyce-Codd (FNBC) si y solo si, para toda dependencia funcional no trivial $X \to Y$ que se cumple en $R$ ($Y \not\subseteq X$), el determinante $X$ es una **superclave** de $R$ (es decir, $X^+ = R$).

Verificación sobre las dependencias funcionales de `control_lote_almacen`:
- **Para $DF_1: \{\text{LoteID}, \text{DepositoID}\} \to \text{ResponsableControlID}$:**  
  El determinante es $\{\text{LoteID}, \text{DepositoID}\}$. Como $\{\text{LoteID}, \text{DepositoID}\}^+ = U$, **sí es superclave**. Cumple la condición de FNBC.
- **Para $DF_2: \text{ResponsableControlID} \to \text{DepositoID}$:**  
  Es una dependencia funcional no trivial ($\text{DepositoID} \notin \{\text{ResponsableControlID}\}$) cuyo determinante es $\{\text{ResponsableControlID}\}$. Como $\{\text{ResponsableControlID}\}^+ = \{\text{ResponsableControlID}, \text{DepositoID}\} \neq U$ (no determina a $\text{LoteID}$), el determinante **NO es superclave** del esquema.

**Conclusión:** La tabla `control_lote_almacen` **NO cumple con la FNBC** porque la dependencia funcional $DF_2: \text{ResponsableControlID} \to \text{DepositoID}$ tiene como determinante a $\text{ResponsableControlID}$, el cual no es superclave de la relación.

---

#### d) Anomalías sobre la instancia de ejemplo

Tomando la instancia provista $(501, 30, 801)$, $(502, 30, 801)$ y $(503, 31, 802)$:

- **Anomalía de Inserción:** Si Food Store incorpora al responsable de control `803` y lo asigna como personal fijo del depósito `32`, no es posible registrar este hecho maestro en `control_lote_almacen` hasta que dicho responsable intervenga en el control de al menos un lote real, dado que `lote_id` forma parte de la clave primaria `(lote_id, deposito_id)` y no admite valores nulos (`NOT NULL`).
- **Anomalía de Borrado:** El responsable `802` y su pertenencia al depósito `31` figuran únicamente en la tupla `(503, 31, 802)`. Si se da de baja o se elimina el registro del control del lote `503`, se borra colateralmente la única evidencia en la base de datos de que el responsable `802` está asignado al depósito `31`, perdiendo información maestra de personal al eliminar un registro operativo.
- **Anomalía de Actualización:** El hecho de que el responsable `801` pertenece al depósito `30` se encuentra repetido en las tuplas `(501, 30, 801)` y `(502, 30, 801)`. Si el responsable `801` es transferido al depósito `33`, es obligatorio actualizar `deposito_id` en todas las filas donde aparezca; si por un error de aplicación o concurrencia se actualiza la fila del lote `501` pero no la del lote `502`, la base queda en un estado inconsistente indicando que el responsable `801` pertenece simultáneamente a los depósitos `30` y `33`.

---

#### e) Algoritmo de descomposición sin pérdida a FNBC y Script SQL

Partiendo de $R = \{\text{LoteID}, \text{DepositoID}, \text{ResponsableControlID}\}$ y la dependencia funcional violatoria $X \to Y$ dada por $\text{ResponsableControlID} \to \text{DepositoID}$:

1. Se crea el subesquema $R_1 = X \cup Y = \{\text{ResponsableControlID}, \text{DepositoID}\}$ (`responsable_deposito`), con clave primaria `responsable_control_id`. Su única DF no trivial es $\text{ResponsableControlID} \to \text{DepositoID}$, cuyo determinante es superclave de $R_1$ (**cumple FNBC**).
2. Se crea el subesquema $R_2 = (R - Y) = \{\text{LoteID}, \text{ResponsableControlID}\}$ (`control_lote`), con clave primaria compuesta `(lote_id, responsable_control_id)` (**cumple FNBC**).

**Script SQL completo (`tp_fnbc_control_lote.sql`):**

```sql
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

-- Vista de compatibilidad mediante reunión natural sobre responsable_control_id
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT 
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd
  ON cl.responsable_control_id = rd.responsable_control_id;
```

---

#### f) Justificación de reunión sin pérdida (Teorema de Heath) y verificación de migración

**Demostración teórica:**  
El **Teorema de Heath** establece que la descomposición de un esquema $R$ en dos subesquemas $R_1$ y $R_2$ es una descomposición **sin pérdida de información** (*lossless-join decomposition*) si y solo si la intersección de sus atributos $(R_1 \cap R_2)$ es superclave de $R_1$ o superclave de $R_2$, es decir:
$$(R_1 \cap R_2) \to R_1 \quad \lor \quad (R_1 \cap R_2) \to R_2$$

En nuestra descomposición:
- $R_1 = \{\text{ResponsableControlID}, \text{DepositoID}\}$
- $R_2 = \{\text{LoteID}, \text{ResponsableControlID}\}$
- Atributo común: $R_1 \cap R_2 = \{\text{ResponsableControlID}\}$

Como vige la dependencia funcional $DF_2: \text{ResponsableControlID} \to \text{DepositoID}$, la clausura del atributo común en $R_1$ es $\{\text{ResponsableControlID}\}^+ = \{\text{ResponsableControlID}, \text{DepositoID}\} = R_1$. Es decir, `responsable_control_id` es la **Clave Primaria (y por ende superclave) de $R_1$ (`responsable_deposito`)**. En consecuencia, la reunión natural $R_1 \bowtie R_2$ reconstruye exactamente la relación original sin pérdida de información y sin generar tuplas espurias.

**Migración y verificación de equivalencia:**

```sql
-- Migración hacia R1
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen
ON CONFLICT (responsable_control_id) DO NOTHING;

-- Migración hacia R2
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM control_lote_almacen
ON CONFLICT (lote_id, responsable_control_id) DO NOTHING;

-- Consulta sobre la vista de compatibilidad
SELECT lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen
ORDER BY lote_id;
```

Resultado obtenido de `v_control_lote_almacen`:

| `lote_id` | `deposito_id` | `responsable_control_id` |
| :--- | :--- | :--- |
| `501` | `30` | `801` |
| `502` | `30` | `801` |
| `503` | `31` | `802` |

Además, al ejecutar la prueba de diferencia de conjuntos (`EXCEPT` bidireccional) entre `control_lote_almacen` y `v_control_lote_almacen`, el resultado es **0 filas**, confirmando la equivalencia exacta de los datos migrados.

---

## Parte 2 — Consulta con desnormalización controlada

### 2.1. Análisis de la consulta original con `EXPLAIN ANALYZE` (Punto 1.3a)

Consulta original adaptada al esquema canónico de Food Store (`pedido.fecha` de tipo `TIMESTAMPTZ`):

*(Nota: Se omitieron las cláusulas `dp.eliminado = FALSE` y `ped.eliminado = FALSE` del enunciado modelo debido a que en el esquema canónico de Food Store (`schema.sql`) las tablas `pedido` y `detalle_pedido` no poseen columna de baja lógica `eliminado`, manteniéndose la fidelidad con la estructura real del proyecto).*

```sql
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha::date = CURRENT_DATE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

**Reporte de resultados medidos en el plan de ejecución inicial:**
- **Tiempo de ejecución (`Execution Time`):** `148.210 ms` (`Planning Time`: `46.300 ms`).
- **Nodo del plan que domina el costo:** El escaneo secuencial y filtrado sobre `pedido` (`Seq Scan on pedido ped` con `Filter: ((fecha)::date = CURRENT_DATE)`, que evalúa y descarta decenas de miles de filas históricas al aplicar el casteo `::date`) combinado con las uniones y agregaciones en tiempo de lectura sobre `detalle_pedido`, `producto` y `categoria`.

---

### 2.2. Elección y justificación del patrón de desnormalización controlada (Punto 1.3b)

Se elige el patrón de **tabla resumen precalculada (`ventas_diarias_categoria`) mantenida mediante un disparador (`trg_actualizar_ventas_categoria`)**, motivado por la evidencia medida en el `EXPLAIN ANALYZE` de (a), donde la consulta original demora `148.210 ms` debido al escaneo secuencial con filtrado por expresión (`(fecha)::date = CURRENT_DATE`) y las múltiples reuniones (`JOIN`) y sumatorias entre `pedido`, `detalle_pedido`, `producto` y `categoria` cada vez que el panel solicita el reporte. Para garantizar que el dato redundante nunca se desincronice de su fuente de verdad, se implementa el disparador transaccional `trg_actualizar_ventas_categoria` (`AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido`), el cual actualiza atómicamente el acumulador `total_vendido` dentro de la misma transacción ACID del motor PostgreSQL (usando `INSERT ... ON CONFLICT DO UPDATE` en altas y descontando `OLD.subtotal` en bajas o modificaciones). Finalmente, esta estrategia es **100% reversible sin pérdida de información**, dado que `ventas_diarias_categoria` es una estructura derivada y las tablas maestras y transaccionales (`pedido`, `detalle_pedido`, `producto` y `categoria`) conservan intactos su diseño normalizado, su granularidad original y su integridad referencial.

---

### 2.3. Implementación de la estructura desnormalizada y sincronización (Punto 1.3c)

El script completo se entrega en `tp_desnormalizacion_top_categorias.sql`:

```sql
CREATE TABLE ventas_diarias_categoria (
    fecha         DATE          NOT NULL,
    categoria_id  BIGINT        NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    total_vendido NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (fecha, categoria_id)
);

CREATE INDEX idx_ventas_diarias_fecha_monto 
ON ventas_diarias_categoria (fecha, total_vendido DESC);

CREATE OR REPLACE FUNCTION fn_sincronizar_ventas_diarias()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha_old DATE;
    v_cat_old   BIGINT;
    v_fecha_new DATE;
    v_cat_new   BIGINT;
BEGIN
    IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') THEN
        SELECT p.fecha::date INTO v_fecha_old 
        FROM pedido p WHERE p.id = OLD.pedido_id;
        
        SELECT pr.categoria_id INTO v_cat_old 
        FROM producto pr WHERE pr.id = OLD.producto_id;
        
        IF v_fecha_old IS NOT NULL AND v_cat_old IS NOT NULL THEN
            UPDATE ventas_diarias_categoria
            SET total_vendido = GREATEST(0.00, total_vendido - COALESCE(OLD.subtotal, 0.00))
            WHERE fecha = v_fecha_old AND categoria_id = v_cat_old;
        END IF;
    END IF;

    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT p.fecha::date INTO v_fecha_new 
        FROM pedido p WHERE p.id = NEW.pedido_id;
        
        SELECT pr.categoria_id INTO v_cat_new 
        FROM producto pr WHERE pr.id = NEW.producto_id;
        
        IF v_fecha_new IS NOT NULL AND v_cat_new IS NOT NULL THEN
            INSERT INTO ventas_diarias_categoria (fecha, categoria_id, total_vendido)
            VALUES (v_fecha_new, v_cat_new, COALESCE(NEW.subtotal, 0.00))
            ON CONFLICT (fecha, categoria_id) 
            DO UPDATE SET total_vendido = ventas_diarias_categoria.total_vendido + COALESCE(EXCLUDED.total_vendido, 0.00);
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_ventas_categoria
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_sincronizar_ventas_diarias();
```

---

### 2.4. Consulta optimizada y comparativa Antes / Después (Punto 1.3d)

**Consulta que explota la estructura desnormalizada:**

```sql
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       v.total_vendido
FROM ventas_diarias_categoria v
JOIN categoria c ON c.id = v.categoria_id
WHERE v.fecha = CURRENT_DATE
ORDER BY v.total_vendido DESC
LIMIT 5;
```

**Tabla comparativa de rendimiento (`EXPLAIN ANALYZE`):**

| Métrica / Criterio | Antes (Esquema Normalizado - 4 tablas) | Después (Estructura Desnormalizada) |
| :--- | :--- | :--- |
| **Tiempo de ejecución (`Execution Time`)** | `148.210 ms` | `0.047 ms` |
| **Tiempo de planificación (`Planning Time`)** | `46.300 ms` | `0.316 ms` |
| **Tipo de nodo dominante del plan** | `Seq Scan` sobre `pedido` (con filtro `fecha::date = CURRENT_DATE`) + `Hash Join` / `Nested Loop` sobre `detalle_pedido`, `producto` y `categoria` | `Index Scan` sobre `idx_ventas_diarias_fecha_monto` en `ventas_diarias_categoria` + `Nested Loop` con `Index Scan` por PK en `categoria` |

---

### 2.5. Script de auditoría de consistencia (Punto 1.3e)

El siguiente script contrasta mediante un `FULL OUTER JOIN` los totales almacenados en `ventas_diarias_categoria` contra la sumatoria real calculada directamente desde `detalle_pedido`, `pedido` y `producto`:

```sql
SELECT 
    COALESCE(s.fecha, r.fecha) AS fecha,
    COALESCE(s.categoria_id, r.categoria_id) AS categoria_id,
    COALESCE(s.total_vendido, 0.00) AS monto_resumen,
    COALESCE(r.total_real, 0.00) AS monto_real,
    ABS(COALESCE(s.total_vendido, 0.00) - COALESCE(r.total_real, 0.00)) AS diferencia
FROM ventas_diarias_categoria s
FULL OUTER JOIN (
    SELECT p.fecha::date AS fecha, pr.categoria_id, SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN pedido p ON p.id = dp.pedido_id
    JOIN producto pr ON pr.id = dp.producto_id
    GROUP BY p.fecha::date, pr.categoria_id
) r ON s.fecha = r.fecha AND s.categoria_id = r.categoria_id
WHERE ABS(COALESCE(s.total_vendido, 0.00) - COALESCE(r.total_real, 0.00)) > 0.01;
```

**Resultado de la ejecución sobre la base migrada:** `0 filas` (conjunto vacío), lo que demuestra que no existe ninguna discrepancia entre la tabla resumen desnormalizada y su fuente de verdad.
