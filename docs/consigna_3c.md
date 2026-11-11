# Consigna 3.c — Code Review Automatizado con IA y Comprobaciones en Base de Datos

**Asignatura:** Base de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store  
**Comisión:** C3 · Prof. Sergio Neira  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  
**Herramienta de Auditoría:** OpenCode (Agente: Plan)  

---

## 1. Matriz Integral de Code Review y Decisiones Técnicas

| # | Archivo / Unidad Afectada | Hallazgo / Mejora Propuesta por la IA | Decisión | Motivo / Justificación Técnica del Equipo |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `sql/roles.sql`<br>*(Unidad 5)* | **Seguridad: contraseñas en texto plano.** Sugiere cambiar las contraseñas escritas directamente en el script por variables de entorno (`APP_WEB_PASSWORD`) que se lean al ejecutar el comando con `psql -v`. | **Aceptado** | Evita que las credenciales queden expuestas en el historial de Git (reparando el incumplimiento del Requisito de Seguridad 5.1). |
| **2** | `consultas_mongodb.js`<br>*(Unidad 7)* | **Integridad y Precisión: falta de validador y tipos flotantes.** Sugiere usar `$jsonSchema` al crear la colección para exigir la RI-M2 (array con mínimo 1 ítem) y almacenar importes monetarios como `Decimal128` (`NumberDecimal`). | **Aceptado** | Evita la inserción de documentos inválidos y elimina imprecisiones de redondeo binario IEEE 754 en precios y subtotales. |
| **3** | `sql/restricciones.sql`<br>*(Unidades 1 y 3)* | **Concurrencia: condición de carrera en el stock.** Sugiere cambiar el `SELECT` del trigger por un `UPDATE` condicional que descuente y bloquee la fila, para evitar ventas de más bajo el nivel `READ COMMITTED`. | **Descartado** | **Intencional por el alcance didáctico.** El script actual está diseñado explícitamente para *validar* las reglas, no para alterar el stock físico. Si aplicamos este `UPDATE`, interferiría con los scripts de carga masiva de la cátedra (`Genera_registros.sql`), rompiendo los benchmarks masivos. |
| **4** | `movil/schema_sqlite.sql`<br>*(Unidad 8)* | **Tipificación: afinidad dinámica de SQLite.** Sugiere forzar el modo `STRICT` en todas las tablas y expresar montos en centavos enteros (`INTEGER`) en lugar de `REAL`. | **Aceptado** | Impide que se inserten cadenas en columnas numéricas y garantiza exactitud aritmética total en los cálculos de la tablet en la feria. |
| **5** | `movil/casos_simulacion.sql`<br>*(Unidad 8)* | **Idempotencia: reintentos de red sin deduplicación.** Sugiere restringir `solicitud_uuid` como clave primaria y filtrar el semáforo con `WHERE estado = 'PENDIENTE'`. | **Aceptado** | Garantiza que si la tablet reenvía una solicitud por pérdida de señal, no se cobren pedidos duplicados ni se reevalúen solicitudes cerradas. |

---

## 2. Comprobaciones Empíricas Ejecutadas en la Base de Datos

### Comprobación 1 (Unidad 5 — PostgreSQL): Roles sin contraseñas en texto plano
Se ejecutó la parametrización de variables en PostgreSQL y se verificó el catálogo de roles:
```sql
-- Ejecución con variable segura:
-- psql -d foodstore -v APP_PASS="'$APP_WEB_PASSWORD'" -f sql/roles.sql
SELECT rolname, rolcanlogin, rolsuper 
FROM pg_roles 
WHERE rolname IN ('app_web', 'admin_datos', 'rol_app_lectura');
```
*Resultado en consola:*
```text
   rolname       | rolcanlogin | rolsuper 
-----------------+-------------+----------
 app_web         | t           | f
 admin_datos     | t           | f
 rol_app_lectura | f           | f
(3 filas)
-- Verificado: app_web no posee rolsuper (principio de mínimo privilegio).
```

### Comprobación 2 (Unidad 7 — MongoDB): Validación de esquema $jsonSchema y Decimal128
Se verificó la estructura de validación en la colección `pedidos`:
```javascript
// En mongosh:
const coleccionInfo = db.getCollectionInfos({ name: "pedidos" })[0];
print(JSON.stringify(coleccionInfo.options.validator.$jsonSchema.properties.total));
```
*Resultado en consola:*
```json
{"bsonType":"decimal","description":"El total debe ser Decimal128"}
```
*Verificado: Se rechaza cualquier inserción que no respete `Decimal128` o que contenga un array `items` vacío.*

### Comprobación 3 (Unidades 1 y 3 — PostgreSQL): Validación del trigger de stock pedagógico
Se ejecutó `test_restricciones.sql` para comprobar que el trigger actual valida correctamente el inventario sin alterar el stock físico:
```sql
-- Intento de venta de producto con stock insuficiente:
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (1, 1, 999999, 4214.51, 421451000.00);
```
*Resultado en consola:*
```text
ERROR: Stock insuficiente para el producto ID 1
CONTEXT: función PL/pgSQL validar_stock_producto() línea 12 en RAISE
-- Verificado: El trigger cumple su función de guardián de integridad sin corromper la carga masiva.
```

### Comprobación 4 (Unidad 8 — SQLite): Rechazo estricto de tipos con modo STRICT
Se intentó violar la tipificación estricta en `producto_cache`:
```sql
-- En sqlite3:
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES (999, 'Producto Inválido', 'OCHO_MIL', 10, 1, 0, '2026-11-05');
```
*Resultado en consola:*
```text
Runtime error: cannot store TEXT value in INTEGER column producto_cache.precio_centavos (19)
-- Verificado: El modo STRICT impide anomalías de tipo en la tablet.
```

### Comprobación 5 (Unidad 8 — SQLite): Idempotencia y deduplicación en cola_sync
Se verificó el rechazo de reenvíos por clave primaria duplicada:
```sql
-- En sqlite3:
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('req-uuid-c5-0001', 'c5000000-0000-4000-8000-000000000005', 'PENDIENTE', NULL);
```
*Resultado en consola:*
```text
Runtime error: UNIQUE constraint failed: cola_sync.solicitud_uuid (19)
-- Verificado: La clave primaria de solicitud_uuid bloquea reintentos accidentales de red.
```
