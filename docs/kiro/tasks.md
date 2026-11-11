# Tasks — TP8: Implementación del Semáforo de Sincronización

**Food Store | Bases de Datos II**  
**Comisión:** C3 · Prof. Sergio Neira  
**Equipo:** Máximo Franco, Andrés Novello y Octavio Fiore  

---

## Resumen
Crear el esquema SQLite de la tablet (5 tablas) con modo `STRICT`, importación de `snapshot_servidor` con `fecha_copia`, catálogo en centavos enteros (`INTEGER`), y el script del semáforo con jerarquía de prioridades: Rechazo > Conflicto > Aprobado.

---

## Tareas Técnicas

### Tarea 1 — DDL de la Tablet en SQLite (`movil/schema_sqlite.sql`)
- [x] 1.1 Crear tabla `snapshot_servidor` en modo `STRICT` con columna `fecha_copia`.
- [x] 1.2 Crear tabla `producto_cache` con `precio_centavos INTEGER` y `stock_visto INTEGER`.
- [x] 1.3 Crear tabla `pedido_borrador` con `id_local TEXT PRIMARY KEY`.
- [x] 1.4 Crear tabla `item_borrador` con `ON DELETE CASCADE` y `precio_centavos_visto INTEGER`.
- [x] 1.5 Crear tabla `cola_sync` con `solicitud_uuid TEXT PRIMARY KEY` y estados validados por `CHECK`.
- [x] 1.6 Activar directiva `PRAGMA foreign_keys = ON;`.

### Tarea 2 — Instantánea y Carga de Catálogo
- [x] 2.1 Crear vista `v_snapshot_movil` en PostgreSQL con `to_char(CURRENT_TIMESTAMP, ...)` como `fecha_copia`.
- [x] 2.2 Exportar catálogo a `movil/servidor_snapshot.csv`.
- [x] 2.3 Scriptar importación hacia `snapshot_servidor` y recarga en `producto_cache`.

### Tarea 3 — Algoritmo del Semáforo (`movil/semaforo.sql`)
- [x] 3.1 Implementar consulta transaccional CTE con evaluación jerárquica:
  - Rechazo por baja lógica / inexistencia / falta de stock (Prioridad 1).
  - Conflicto por variación de precio (Prioridad 2).
  - Aprobación simulada si todo coincide (Prioridad 3).
- [x] 3.2 Filtrar por `WHERE estado = 'PENDIENTE'` para asegurar idempotencia.

### Tarea 4 — Batería de Simulación Ejecutable (`movil/casos_simulacion.sql`)
- [x] 4.1 Caso C2: Conflicto de precio -> Aceptación del cliente (450000) -> `SIMULADO_APROBADO`.
- [x] 4.2 Caso C3: Pedido por 50 unidades sobre 36 en stock -> `RECHAZADO`.
- [x] 4.3 Caso C4: Baja lógica de Producto 3 en servidor -> `RECHAZADO` y conservación de lápida.
- [x] 4.4 Caso C5: Borrador sin alteraciones -> `SIMULADO_APROBADO`.
- [x] 4.5 Caso C6: Reintento de solicitud con mismo UUID -> Idempotencia garantizada por `PRIMARY KEY`.

### Tarea 5 — Verificación de Aislamiento en Servidor (`consulta_final.sql`)
- [x] 5.1 Comprobar que `pedidos_nuevos_en_servidor` es 0.
- [x] 5.2 Comprobar que en PostgreSQL el Producto 1 tiene precio 4500.00 y el Producto 3 tiene `activo = false`, sin alteraciones de stock por las ventas simuladas de la tablet.
