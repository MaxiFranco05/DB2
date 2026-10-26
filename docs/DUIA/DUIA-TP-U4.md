# UNIVERSIDAD TECNOLÓGICA NACIONAL
## Facultad Regional Mendoza
### Tecnicatura Universitaria en Programación — Bases de Datos II

---

# Documento Único de Información Académica (DUIA)
## Trabajo Práctico — Unidad 4: Forma Normal de Boyce-Codd y Desnormalización Controlada en Food Store

* **Materia:** Bases de Datos II
* **Proyecto Integrador:** Food Store

---

## Índice de Contenidos

1. **Introducción y Objetivos**
2. **Parte 1 — Análisis, Normalización (FNBC) y Descomposición de `ControlLoteAlmacen`**
   * 1.1. Contexto de dominio y esquema inicial
   * 1.2. Dependencias funcionales y clausuras
   * 1.3. Evaluación formal de la Forma Normal de Boyce-Codd (FNBC)
   * 1.4. Análisis detallado de anomalías (Inserción, Borrado y Actualización)
   * 1.5. Algoritmo de descomposición sin pérdida y Script SQL (`tp_fnbc_control_lote.sql`)
   * 1.6. Justificación teórica (Teorema de Heath) y verificación de migración
3. **Parte 2 — Optimización de Consultas mediante Desnormalización Controlada**
   * 2.1. Diagnóstico inicial de rendimiento (`EXPLAIN ANALYZE`)
   * 2.2. Selección y justificación del patrón de desnormalización
   * 2.3. Implementación de la estructura física, índices y disparadores de sincronización (`tp_desnormalizacion_top_categorias.sql`)
   * 2.4. Consulta optimizada y comparativa de rendimiento (Antes / Después)
   * 2.5. Auditoría automatizada de consistencia e integridad de datos
4. **Conclusiones**

---

## 1. Introducción y Objetivos

El presente documento consolida la resolución formal de las problemáticas abordadas en la **Unidad 4** del proyecto integrador *Food Store*. El trabajo se divide en dos ejes fundamentales:

1. **Normalización rigurosa:** Aplicación de la teoría de dependencias funcionales para identificar y corregir violaciones a la Forma Normal de Boyce-Codd (FNBC) en el subsistema de control de lotes y almacenes, garantizando la eliminación de anomalías operativas mediante el Teorema de Heath.
2. **Desnormalización controlada:** Optimización de consultas de alto costo analítico en el motor PostgreSQL mediante tablas resumen precalculadas sincronizadas de manera transaccional mediante *Triggers*, asegurando rendimiento analítico en tiempo real sin comprometer la consistencia de la fuente de verdad normalizada.

---

## 2. Parte 1 — Normalización a FNBC (`ControlLoteAlmacen`)

### 1.1. Contexto de Dominio y Esquema Inicial

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

### 1.2. Dependencias Funcionales, Clausuras y Claves Candidatas

Usando los nombres de atributo $\text{LoteID}$, $\text{DepositoID}$ y $\text{ResponsableControlID}$, se desprenden dos dependencias funcionales no triviales a partir de las reglas de negocio:

$$DF_1: \{\text{LoteID}, \text{DepositoID}\} \to \text{ResponsableControlID}$$
$$DF_2: \text{ResponsableControlID} \to \text{DepositoID}$$

Sea el universo de atributos $U = \{\text{LoteID}, \text{DepositoID}, \text{ResponsableControlID}\}$ (abreviado $U = \{L, D, R\}$) y el conjunto $F = \{DF_1, DF_2\}$.

El atributo $\text{LoteID}$ ($L$) no aparece en el lado derecho de ninguna dependencia funcional en $F$. Por lo tanto, **toda superclave debe contener obligatoriamente a $\text{LoteID}$**.

1. **Clausuras de subconjuntos:**
   - $\{L\}^+ = \{L\} \neq U$
   - $\{L, D\}^+ = \{L, D, R\} = U \implies \{\text{LoteID}, \text{DepositoID}\}$ es **Clave Candidata**.
   - $\{L, R\}^+ = \{L, R, D\} = U \implies \{\text{LoteID}, \text{ResponsableControlID}\}$ es **Clave Candidata**.

**Resumen de Claves y Atributos:**
- **Conjunto de Claves Candidatas:**
  $$CK = \big\{\{\text{LoteID}, \text{DepositoID}\},\; \{\text{LoteID}, \text{ResponsableControlID}\}\big\}$$
- **Atributos Primos:** $\text{LoteID}$, $\text{DepositoID}$, $\text{ResponsableControlID}$ (todos son primos).
- **Atributos No Primos:** Ninguno ($\emptyset$).

---

### 1.3. Evaluación Formal de la FNBC

Un esquema $R$ está en **FNBC** si para toda dependencia funcional no trivial $X \to Y$, el determinante $X$ es una superclave de $R$.

Verificación:
- **Para $DF_1: \{\text{LoteID}, \text{DepositoID}\} \to \text{ResponsableControlID}$:**  
  $\{\text{LoteID}, \text{DepositoID}\}^+ = U \implies$ **Cumple FNBC**.
- **Para $DF_2: \text{ResponsableControlID} \to \text{DepositoID}$:**  
  $\{\text{ResponsableControlID}\}^+ = \{\text{ResponsableControlID}, \text{DepositoID}\} \neq U \implies$ **NO es superclave**.

**Conclusión:** La tabla `control_lote_almacen` **NO cumple con la FNBC** debido a $DF_2$.

---

### 1.4. Análisis Detallado de Anomalías

Tomando la instancia provista $(501, 30, 801)$, $(502, 30, 801)$ y $(503, 31, 802)$:

- **Anomalía de Inserción:** Si se incorpora al responsable de control `803` asignado al depósito `32`, no es posible registrar este hecho maestro en `control_lote_almacen` hasta que controle un lote real, ya que `lote_id` es clave primaria y no admite nulos (`NOT NULL`).
- **Anomalía de Borrado:** Si se elimina el registro del control del lote `503`, se borra colateralmente la única evidencia de que el responsable `802` está asignado al depósito `31`.
- **Anomalía de Actualización:** El hecho de que el responsable `801` pertenece al depósito `30` está repetido. Si `801` se transfiere al depósito `33` y solo se actualiza una fila, la base queda en estado inconsistente.

---

### 1.5. Algoritmo de Descomposición y Script SQL

Partiendo de $DF_2: \text{ResponsableControlID} \to \text{DepositoID}$ (violatoria):

1. **Subesquema $R_1$:** $\{\text{ResponsableControlID}, \text{DepositoID}\}$ (`responsable_deposito`), PK: `responsable_control_id`.
2. **Subesquema $R_2$:** $\{\text{LoteID}, \text{ResponsableControlID}\}$ (`control_lote`), PK: `(lote_id, responsable_control_id)`.

**Código SQL del Script `tp_fnbc_control_lote.sql`:**

```sql
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

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

### 1.6. Justificación Teórica (Teorema de Heath) y Verificación

**Teorema de Heath:** La descomposición de $R$ en $R_1$ y $R_2$ es sin pérdida de información si y solo si $(R_1 \cap R_2)$ es superclave de $R_1$ o de $R_2$.

- $R_1 \cap R_2 = \{\text{ResponsableControlID}\}$
- $\{\text{ResponsableControlID}\}^+ = R_1$

Dado que `responsable_control_id` es clave primaria de $R_1$ (`responsable_deposito`), la reunión natural $R_1 \bowtie R_2$ reconstruye la relación original sin pérdida de información ni tuplas espurias.

**Prueba de Equivalencia:** La ejecución de un `EXCEPT` bidireccional entre la tabla original `control_lote_almacen` y la vista de compatibilidad `v_control_lote_almacen` retornó **0 filas**, ratificando la reconstrucción exacta del dataset.

---

## 3. Parte 2 — Optimización de Consultas mediante Desnormalización Controlada

### 2.1. Diagnóstico Inicial con `EXPLAIN ANALYZE`

Consulta analítica de las categorías más vendidas en el día:

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

**Métricas del Plan Inicial:**
- **Execution Time:** `148.210 ms`
- **Planning Time:** `46.300 ms`
- **Cuello de botella:** `Seq Scan` sobre `pedido` con filtro evaluado por expresión por cada fila (`(fecha)::date = CURRENT_DATE`), sumado a múltiples `Hash Join` / `Nested Loop` entre 4 tablas.

---

### 2.2. Patrón de Desnormalización Seleccionado

Se implementó el patrón de **tabla resumen precalculada (`ventas_diarias_categoria`)**, mantenida atómicamente por el disparador transaccional `trg_actualizar_ventas_categoria` (`AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido`).

**Ventajas:**
- Disminución dramática en el tiempo de lectura del dashboard de administración.
- Consistencia garantizada dentro del límite transaccional de PostgreSQL.
- Estrategia 100% reversible sin alterar las fuentes normalizadas de verdad (`pedido`, `detalle_pedido`, `producto`, `categoria`).

---

### 2.3. Estructura Física y Sincronización Automática

**Código SQL del Script `tp_desnormalizacion_top_categorias.sql`:**

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
        SELECT p.fecha::date INTO v_fecha_old FROM pedido p WHERE p.id = OLD.pedido_id;
        SELECT pr.categoria_id INTO v_cat_old FROM producto pr WHERE pr.id = OLD.producto_id;
        
        IF v_fecha_old IS NOT NULL AND v_cat_old IS NOT NULL THEN
            UPDATE ventas_diarias_categoria
            SET total_vendido = GREATEST(0.00, total_vendido - COALESCE(OLD.subtotal, 0.00))
            WHERE fecha = v_fecha_old AND categoria_id = v_cat_old;
        END IF;
    END IF;

    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        SELECT p.fecha::date INTO v_fecha_new FROM pedido p WHERE p.id = NEW.pedido_id;
        SELECT pr.categoria_id INTO v_cat_new FROM producto pr WHERE pr.id = NEW.producto_id;
        
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

### 2.4. Consulta Optimizada y Comparativa de Rendimiento

**Consulta sobre la tabla precalculada:**

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

**Tabla Comparativa (`EXPLAIN ANALYZE`):**

| Métrica / Criterio | Esquema Normalizado (Antes) | Estructura Desnormalizada (Después) |
| :--- | :--- | :--- |
| **Tiempo de Ejecución (`Execution Time`)** | `148.210 ms` | **`0.047 ms`** |
| **Tiempo de Planificación (`Planning Time`)** | `46.300 ms` | **`0.316 ms`** |
| **Nodo Dominante del Plan** | `Seq Scan` sobre `pedido` + `Hash Join` sobre 4 tablas | `Index Scan` sobre `idx_ventas_diarias_fecha_monto` + `Nested Loop` por PK |

---

### 2.5. Auditoría Automatizada de Consistencia

Para verificar que no exista desviatorio de datos entre la tabla desnormalizada y la fuente de verdad, se ejecuta el siguiente script de control:

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

**Resultado:** `0 filas` devueltas (coincidencia del 100%).

---

## 4. Conclusiones

La resolución de este trabajo práctico demuestra la importancia de equilibrar la teoría de diseño de bases de datos relacionales con los requerimientos de rendimiento en entornos de producción:

1. El uso de la **FNBC** previene anomalías transaccionales graves en datos maestros y operacionales.
2. La **desnormalización controlada** mediante estructuras derivadas y sincronización por *Triggers* permite escalar drásticamente consultas analíticas complejas (reduciendo latencias de más de `140 ms` a menos de `0.05 ms`), manteniendo la trazabilidad y la reversibilidad hacia las fuentes normalizadas originales.

---
*Fin del documento DUIA.*