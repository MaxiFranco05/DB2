# Spec: mv_ventas_categoria_mes

## Metadata
- **Parte:** C — Vista Materializada
- **Objeto:** `mv_ventas_categoria_mes`
- **Tipo:** `MATERIALIZED VIEW`
- **Tablas base:** `detalle_pedido`, `pedido`, `producto`, `categoria`
- **Autor:** Spec generada para el proyecto integrador FoodStore — DB2

---

## 1. Objetivo y Contexto

### Propósito
Precalcular y almacenar físicamente la facturación mensual (`total_facturado`) y las unidades vendidas (`total_unidades`) agrupadas por categoría de producto y mes calendario. El resultado es una tabla snapshot persistida en disco, consultable con latencia mínima independientemente del volumen de pedidos históricos.

### Por qué una vista materializada y no una vista normal

Una vista normal (`CREATE VIEW`) es un alias de consulta: cada vez que se la llama, PostgreSQL ejecuta el SELECT completo desde cero sobre las tablas base. Para el caso de uso analítico de ventas mensuales, eso implica:

| Factor                    | Vista normal                                                    | Vista materializada                                        |
|---------------------------|-----------------------------------------------------------------|------------------------------------------------------------|
| **Costo por consulta**    | Recalcula siempre. Con millones de filas en `detalle_pedido` el costo crece linealmente con la historia. | El resultado ya está calculado; la consulta es un simple `SELECT` sobre una tabla pequeña. |
| **Latencia**              | Alta y variable; depende del volumen histórico.                 | Baja y constante; depende solo del número de categorías × meses. |
| **Frescura de datos**     | Siempre al día.                                                 | Desactualizada hasta el próximo REFRESH. **Tolerancia al atraso aceptada para este caso de uso.** |
| **Uso de índices**        | Los índices de las tablas base ayudan, pero el JOIN y la agregación siguen siendo costosos. | Se crean índices propios sobre la vista materializada, optimizando lecturas directamente. |
| **Bloqueos**              | No aplica (no hay datos persistidos).                           | `REFRESH CONCURRENTLY` con índice único permite refrescar sin bloquear lecturas simultáneas. |

**Justificación de la tolerancia al atraso:** el reporte de ventas por categoría y mes es inherentemente retrospectivo. Un comercio consulta las ventas del mes anterior para tomar decisiones de compra o marketing; no necesita la precisión al minuto de una vista normal. Un atraso de horas (o incluso de un día) es aceptable para este caso de uso. Si se requiriera precisión en tiempo real, el diseño correcto sería una vista normal o una tabla de agregados actualizada por trigger, con el costo de rendimiento correspondiente.

---

## 2. Definición de la Consulta (Query)

### Tablas involucradas y relaciones

```
detalle_pedido ──► pedido ──► (filtro: estado != 'CANCELADO')
detalle_pedido ──► producto ──► categoria ──► (filtro: activa = TRUE)
```

### Justificación de los filtros

#### Filtro 1 — Excluir pedidos CANCELADOS
**Condición:** `ped.estado != 'CANCELADO'`

Un pedido cancelado no representa una venta efectiva. Incluirlo en la facturación mensual inflaría los totales con transacciones que nunca se completaron. Los estados válidos para contabilizar como venta son: `PENDIENTE`, `CONFIRMADO` y `TERMINADO`.

- `TERMINADO`: venta completada → incluir ✅
- `CONFIRMADO`: venta en proceso de entrega → incluir ✅ (representa compromiso comercial firme)
- `PENDIENTE`: venta iniciada pero no confirmada → incluir ✅ (representa intención de compra en curso; excluirlo dependería de la política de negocio, pero la postura conservadora es incluirlo)
- `CANCELADO`: transacción anulada → excluir ✅

> **Nota de diseño:** si la cátedra o el negocio define que solo `TERMINADO` representa una venta real, el filtro debe ajustarse a `ped.estado = 'TERMINADO'`. Esta spec adopta `!= 'CANCELADO'` como criterio más inclusivo y lo documenta explícitamente para permitir debate.

#### Filtro 2 — Excluir categorías inactivas
**Condición:** `cat.activa = TRUE`

Una categoría dada de baja no debe aparecer en reportes de ventas futuros. Sin embargo, existe una tensión con el historial:

**Decisión adoptada:** incluir únicamente categorías activas al momento del refresco.

Razonamiento: el propósito de esta vista es orientar decisiones comerciales prospectivas (¿qué categorías vender más? ¿cuál es la tendencia?). Una categoría dada de baja ya no es relevante para esas decisiones. El historial completo sin filtro está disponible directamente en las tablas base para auditoría.

Si se requiere el historial de categorías inactivas, se implementa una vista materializada separada (`mv_ventas_historico_completo`) sin este filtro.

### DDL de la vista materializada

```sql
CREATE MATERIALIZED VIEW mv_ventas_categoria_mes AS
    SELECT
        cat.id                                    AS categoria_id,
        cat.nombre                                AS nombre_categoria,
        date_trunc('month', ped.fecha)::date      AS mes,
        SUM(dp.subtotal)                          AS total_facturado,
        SUM(dp.cantidad)                          AS total_unidades
    FROM detalle_pedido dp
    INNER JOIN pedido   ped ON dp.pedido_id   = ped.id
    INNER JOIN producto pro ON dp.producto_id = pro.id
    INNER JOIN categoria cat ON pro.categoria_id = cat.id
    WHERE ped.estado != 'CANCELADO'
      AND cat.activa  = TRUE
    GROUP BY
        cat.id,
        cat.nombre,
        date_trunc('month', ped.fecha)::date
    ORDER BY
        mes DESC,
        cat.nombre ASC
WITH NO DATA;
```

> **`WITH NO DATA`:** la vista se crea vacía. El primer `REFRESH` (sin `CONCURRENTLY`, ya que la vista está vacía) la puebla por primera vez. Esto sigue la práctica recomendada para creación en entornos de CI/CD donde los datos reales pueden no estar presentes en el momento del despliegue del DDL.

### Detalle de columnas resultantes

| Columna            | Tipo            | Descripción                                                              |
|--------------------|-----------------|--------------------------------------------------------------------------|
| `categoria_id`     | `BIGINT`        | PK de la categoría; clave del índice único                               |
| `nombre_categoria` | `VARCHAR(100)`  | Nombre de la categoría al momento del refresco                           |
| `mes`              | `DATE`          | Primer día del mes (`date_trunc('month', ...)::date`). Ej: `2025-03-01`  |
| `total_facturado`  | `NUMERIC`       | Suma de subtotales históricos congelados del período                     |
| `total_unidades`   | `INTEGER`       | Suma de unidades pedidas en el período                                   |

**Por qué `::date` sobre `date_trunc`:** `date_trunc('month', ped.fecha)` devuelve `TIMESTAMPTZ`. El cast `::date` lo convierte a un tipo más liviano, legible (`2025-03-01` en lugar de `2025-03-01 00:00:00+00`) y más eficiente para el índice único.

**Por qué `SUM(dp.subtotal)` y no `SUM(dp.cantidad * dp.precio_unitario)`:** `subtotal` ya fue calculado por el trigger `trg_subtotal` al momento del INSERT y está almacenado en la tabla. Usar `dp.subtotal` evita recalcular y garantiza que la vista materializada refleja exactamente los mismos valores que el sistema registró. Son matemáticamente equivalentes, pero `dp.subtotal` es la fuente de verdad persistida.

---

## 3. Estrategia de Índices

### Índice único obligatorio para REFRESH CONCURRENTLY

```sql
CREATE UNIQUE INDEX uix_mv_ventas_categoria_mes
    ON mv_ventas_categoria_mes (categoria_id, mes);
```

#### Justificación técnica

PostgreSQL requiere un **índice único** sobre la vista materializada para poder ejecutar `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Sin él, el refresco concurrente falla con error:

```
ERROR: cannot refresh materialized view "mv_ventas_categoria_mes" concurrently
DETAIL: A unique index on the materialized view is required.
```

El índice no concurrente (`REFRESH MATERIALIZED VIEW` sin `CONCURRENTLY`) adquiere un lock exclusivo sobre la vista, bloqueando todas las lecturas durante el refresco. Para una vista de reportes que puede ser consultada constantemente por el backoffice, esto es inaceptable.

#### Por qué `(categoria_id, mes)` como clave del índice único

1. **Unicidad garantizada por la semántica del GROUP BY:** la consulta agrupa por `(cat.id, date_trunc('month', ...))`. Por definición, no puede haber dos filas con el mismo `categoria_id` y el mismo `mes`. El índice único refleja esta invariante.
2. **Cardinalidad apropiada:** el número de filas en la vista es `N_categorías × N_meses_con_ventas`. Con 5 categorías y 24 meses de historia, son 120 filas como máximo. El índice es trivialmente pequeño.
3. **Cobertura de consultas frecuentes:** las consultas típicas sobre esta vista filtran o agrupan por `categoria_id`, `mes`, o ambos. El índice compuesto `(categoria_id, mes)` cubre estos patrones eficientemente.

#### Índice adicional recomendado (no obligatorio)

```sql
CREATE INDEX ix_mv_ventas_mes
    ON mv_ventas_categoria_mes (mes DESC);
```

Justificación: las consultas de "ventas del último mes" o "evolución temporal de una categoría" filtran por `mes`. Un índice sobre `mes DESC` optimiza estas consultas sin duplicar el índice único.

---

## 4. Política de Refresco

### Modo de refresco

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes;
```

#### Semántica de CONCURRENTLY

- PostgreSQL calcula el nuevo conjunto de datos en una tabla temporal interna.
- Compara el resultado nuevo con el contenido actual usando el índice único `(categoria_id, mes)`.
- Aplica las diferencias (INSERT de filas nuevas, UPDATE de filas modificadas, DELETE de filas que ya no existen) como operaciones individuales.
- Durante todo el proceso, la vista sigue siendo legible por consultas concurrentes con el dato anterior (snapshot isolation).
- Al finalizar, las lecturas nuevas ven el dato actualizado.

**Restricción importante:** `CONCURRENTLY` requiere que la vista **no esté vacía** en el momento del refresco. El primer refresco (tras la creación con `WITH NO DATA`) debe ejecutarse sin `CONCURRENTLY`:

```sql
-- Primera carga (una sola vez, tras el despliegue inicial):
REFRESH MATERIALIZED VIEW mv_ventas_categoria_mes;

-- Refrescos subsiguientes (rutinarios, sin bloqueo):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes;
```

### Frecuencia de actualización

| Escenario                     | Frecuencia recomendada | Justificación                                                              |
|-------------------------------|------------------------|----------------------------------------------------------------------------|
| Operación normal de producción | 1 vez por día (madrugada) | Reportes de ventas son retrospectivos; un atraso de hasta 24 hs es aceptable |
| Cierre de mes                 | Al finalizar el último día del mes + refresco inmediato | Garantiza que los totales del mes cerrado sean definitivos antes de los reportes de dirección |
| Alta carga de pedidos (temporadas) | Cada 4-6 horas       | Reducir el atraso durante picos de actividad sin impactar el rendimiento transaccional |
| Bajo volumen (< 100 pedidos/día) | Bajo demanda o 1 vez por semana | El costo del refresco es mínimo; la frecuencia puede reducirse sin impacto percibido |

### Quién ejecuta el refresco

**Responsable:** el scheduler de base de datos o el sistema de tareas programadas del entorno de despliegue. Las opciones son:

1. **`pg_cron` (extensión PostgreSQL nativa):**
```sql
-- Refresco diario a las 03:00 AM (requiere pg_cron instalado)
SELECT cron.schedule(
    'refresh_mv_ventas',
    '0 3 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes'
);
```

2. **Cron del sistema operativo:**
```bash
# Entrada en crontab del usuario postgres
0 3 * * * psql -d foodstore -c "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes;" >> /var/log/mv_refresh.log 2>&1
```

3. **Pipeline de orquestación (ej. Airflow, dbt):** apropiado si el proyecto ya tiene infraestructura de ELT/ETL. El refresco se modela como un nodo del DAG tras la carga de pedidos del día.

### Manejo de errores

| Situación                             | Comportamiento                                                              | Acción correctiva                                              |
|---------------------------------------|-----------------------------------------------------------------------------|----------------------------------------------------------------|
| Refresco falla por lock en las tablas base | El refresco aborta; la vista queda con el dato anterior                | Reintentar en el próximo ciclo; loggear el error              |
| Primera ejecución con `CONCURRENTLY` sobre vista vacía | `ERROR: cannot refresh concurrently` | Ejecutar una vez sin `CONCURRENTLY`; luego continuar con el modo normal |
| Categoría dada de baja entre refrescos | Las filas de esa categoría desaparecen en el siguiente refresco        | Comportamiento correcto por diseño; no requiere intervención  |
| Falla de consistencia (dato corrupto) | La vista puede quedar en estado `invalid` (flag en `pg_matviews`)       | `REFRESH MATERIALIZED VIEW mv_ventas_categoria_mes;` (sin CONCURRENTLY) fuerza reconstrucción completa |

```sql
-- Consulta de monitoreo: verificar estado de la vista materializada
SELECT
    schemaname,
    matviewname,
    ispopulated,
    definition
FROM pg_matviews
WHERE matviewname = 'mv_ventas_categoria_mes';
-- ispopulated = TRUE indica que la vista tiene datos y está lista ✅
```

---

## 5. Criterios de Aceptación

### CA-01 — La vista materializada produce resultados equivalentes a la consulta en caliente (EXCEPT bidireccional)

```sql
-- Consulta manual equivalente (referencia para comparación)
WITH consulta_manual AS (
    SELECT
        cat.id                                AS categoria_id,
        cat.nombre                            AS nombre_categoria,
        date_trunc('month', ped.fecha)::date  AS mes,
        SUM(dp.subtotal)                      AS total_facturado,
        SUM(dp.cantidad)                      AS total_unidades
    FROM detalle_pedido dp
    INNER JOIN pedido    ped ON dp.pedido_id   = ped.id
    INNER JOIN producto  pro ON dp.producto_id = pro.id
    INNER JOIN categoria cat ON pro.categoria_id = cat.id
    WHERE ped.estado != 'CANCELADO'
      AND cat.activa  = TRUE
    GROUP BY cat.id, cat.nombre, date_trunc('month', ped.fecha)::date
)

-- Dirección 1: filas en la vista materializada que NO están en la consulta manual
SELECT categoria_id, mes, total_facturado, total_unidades
FROM mv_ventas_categoria_mes
EXCEPT
SELECT categoria_id, mes, total_facturado, total_unidades
FROM consulta_manual;
-- Resultado esperado: 0 filas ✅

-- Dirección 2: filas en la consulta manual que NO están en la vista materializada
SELECT categoria_id, mes, total_facturado, total_unidades
FROM consulta_manual
EXCEPT
SELECT categoria_id, mes, total_facturado, total_unidades
FROM mv_ventas_categoria_mes;
-- Resultado esperado: 0 filas ✅
-- NOTA: ejecutar inmediatamente después de un REFRESH para garantizar frescura
```

### CA-02 — El índice único existe y tiene la estructura correcta

```sql
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'mv_ventas_categoria_mes'
  AND indexname = 'uix_mv_ventas_categoria_mes';
-- Resultado esperado: 1 fila con el DDL del índice único ✅
```

### CA-03 — REFRESH CONCURRENTLY no bloquea lecturas simultáneas

```sql
-- Sesión 1: iniciar refresco
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes;

-- Sesión 2 (simultánea): debe responder sin esperar a que Sesión 1 termine
SELECT COUNT(*) FROM mv_ventas_categoria_mes;
-- Resultado esperado: responde inmediatamente con el dato previo al refresco ✅
```

### CA-04 — Pedidos CANCELADOS no están incluidos en los totales

```sql
-- Calcular el total facturado que tendría si se incluyeran cancelados
SELECT SUM(dp.subtotal) AS con_cancelados
FROM detalle_pedido dp
INNER JOIN pedido ped ON dp.pedido_id = ped.id
INNER JOIN producto pro ON dp.producto_id = pro.id
INNER JOIN categoria cat ON pro.categoria_id = cat.id
WHERE cat.activa = TRUE;

-- Total facturado en la vista (sin cancelados)
SELECT SUM(total_facturado) AS sin_cancelados
FROM mv_ventas_categoria_mes;

-- con_cancelados >= sin_cancelados siempre (nunca al revés) ✅
-- La diferencia representa el monto de pedidos cancelados excluidos correctamente
```

### CA-05 — La granularidad temporal es mensual (no diaria ni anual)

```sql
-- Verificar que todos los valores de 'mes' son el primer día del mes
SELECT mes
FROM mv_ventas_categoria_mes
WHERE EXTRACT(DAY FROM mes) != 1
   OR mes != date_trunc('month', mes)::date;
-- Resultado esperado: 0 filas ✅
```

### CA-06 — Unicidad de la clave (categoria_id, mes)

```sql
SELECT categoria_id, mes, COUNT(*) AS ocurrencias
FROM mv_ventas_categoria_mes
GROUP BY categoria_id, mes
HAVING COUNT(*) > 1;
-- Resultado esperado: 0 filas ✅
```

---

## 6. Dependencias y Relaciones

| Elemento                 | Relación                                                                          |
|--------------------------|-----------------------------------------------------------------------------------|
| `detalle_pedido`         | Fuente de `subtotal` y `cantidad`; trigger `trg_subtotal` garantiza integridad de esos valores |
| `pedido`                 | Fuente del `estado` y `fecha`; el filtro `!= 'CANCELADO'` se aplica aquí         |
| `producto`               | Puente entre `detalle_pedido` y `categoria` vía `categoria_id`                   |
| `categoria`              | Fuente de `nombre_categoria`; el filtro `activa = TRUE` se aplica aquí           |
| `idx_producto_categoria` | Índice existente que acelera el JOIN `producto → categoria` durante el refresco  |
| `idx_pedido_usuario`     | No utilizado en esta vista materializada                                          |

---

## 7. Notas de Implementación

### Orden de creación en `db/schema.sql`

```sql
-- 1. Crear la vista materializada (vacía)
CREATE MATERIALIZED VIEW mv_ventas_categoria_mes AS ... WITH NO DATA;

-- 2. Crear el índice único (obligatorio antes del primer REFRESH CONCURRENTLY)
CREATE UNIQUE INDEX uix_mv_ventas_categoria_mes
    ON mv_ventas_categoria_mes (categoria_id, mes);

-- 3. Primer refresco (sin CONCURRENTLY porque está vacía)
REFRESH MATERIALIZED VIEW mv_ventas_categoria_mes;
```

El índice debe crearse **antes** del primer refresco con `CONCURRENTLY`. Si se omite y se ejecuta el REFRESH sin CONCURRENTLY, los datos se cargan pero el modo concurrente no estará disponible hasta que se cree el índice.

### Consulta típica de uso

```sql
-- Ventas del mes actual por categoría
SELECT nombre_categoria, total_facturado, total_unidades
FROM mv_ventas_categoria_mes
WHERE mes = date_trunc('month', CURRENT_DATE)::date
ORDER BY total_facturado DESC;

-- Evolución mensual de una categoría específica
SELECT mes, total_facturado, total_unidades
FROM mv_ventas_categoria_mes
WHERE categoria_id = 1
ORDER BY mes DESC;
```

### Extensión futura: automatización con pg_cron

Si el entorno de producción cuenta con la extensión `pg_cron`, el refresco automático se habilita en una sola sentencia sin necesidad de infraestructura externa:

```sql
-- Instalar pg_cron (requiere superusuario y reinicio de PostgreSQL)
-- shared_preload_libraries = 'pg_cron'  (en postgresql.conf)

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'refresh_mv_ventas',      -- nombre del job
    '0 3 * * *',              -- cron expression: todos los días a las 03:00
    $$REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_mes$$
);
```
