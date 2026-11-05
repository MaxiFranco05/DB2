# Especificación y Plan de Mantenimiento — Unidad 6: Food Store

**Asignatura:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store | **Motor:** PostgreSQL 16+  
**Equipo de Trabajo:** Máximo, Andrés y Octavio  
**Documento:** `SPEC_U6.md` (Especificación Operativa del Plan de Continuidad y Mantenimiento)

---

## 1. Propósito y Alcance
Garantizar la disponibilidad, rendimiento e integridad de la base de datos de producción `foodstore`. Se establece una rutina de mantenimiento preventivo, copias de seguridad consistentes, monitoreo de salud del motor y un procedimiento de recuperación ante desastres (*Disaster Recovery*) probado y cronometrado contra el entorno descartable `foodstore_restore_test`.

---

## 2. Matriz de Mantenimiento y Automatización

| Tarea Mínima | Frecuencia Propuesta | Mecanismo / Script | Evidencia y Condición de Éxito |
| :--- | :--- | :--- | :--- |
| **Respaldo de `foodstore`** | Diaria (02:00 AM) | `backup_foodstore.ps1` ejecutando `pg_dump -Fc` | Archivo `backups/foodstore_YYYYMMDD_HHMMSS.dump` íntegro (>0 bytes) y log en `logs/` con `$LASTEXITCODE == 0`. |
| **Chequeo de Salud** | Diaria (06:00 AM) | `sql/health_check.sql` | Registro de métricas: tamaño de BD, conexiones concurrentes, commits/rollbacks, tuplas muertas y queries activas. |
| **Revisión de Mantenimiento** | Semanal (Domingos 03:00 AM) | `sql/maintenance.sql` | Diagnóstico previo de *bloat*; ejecución de `VACUUM ANALYZE` no bloqueante sobre tablas con churn de datos. Actualización de `last_autoanalyze`. |
| **Restauración de Prueba** | Semanal (Domingos 04:00 AM) | `restore_test.ps1` con `pg_restore` | Creación y restauración exitosa en `foodstore_restore_test`. Validación con 0 inconsistencias y medición de **RTO** y **RPO**. |

---

## 3. Políticas y Reglas Estrictas de Seguridad

1. **Aislamiento de Producción:** La base principal `foodstore` **nunca se destruye ni sobreescribe** durante las pruebas. Todas las operaciones de restauración y pruebas destructivas se ejecutan de manera aislada sobre la base descartable `foodstore_restore_test`.
2. **Cero Exposición de Credenciales:** Prohibición absoluta de incluir contraseñas en scripts (`.ps1`, `.sh`, `.sql`) o archivos versionados en Git. Las herramientas utilizarán autenticación por entorno de sesión (`$env:PGPASSWORD`) o archivos de credenciales protegidos del sistema operativo (`pgpass.conf`).
3. **Formato Binario Comprimido:** Los respaldos se generan en formato *custom* (`-Fc`) mediante `pg_dump`. Esto permite compresión nativa, verificación de integridad previa mediante catálogo (TOC) y portabilidad con `pg_restore` utilizando las banderas `--no-owner` y `--no-privileges`.
4. **Política de Mantenimiento Seguro (Prohibición de `VACUUM FULL`):**
   - **Regla:** Queda **estrictamente prohibido** el uso de `VACUUM FULL` como mantenimiento periódico programado.
   - **Justificación Técnica:** `VACUUM FULL` adquiere un bloqueo exclusivo (`AccessExclusiveLock`) que impide consultas de lectura (`SELECT`) y de escritura (`INSERT`/`UPDATE`), provocando indisponibilidad operativa total (*downtime*) en la aplicación de pedidos.
   - **Alternativa Implementada:** `VACUUM` concurrente estándar y `ANALYZE` selectivo, los cuales operan bajo `ShareUpdateExclusiveLock` permitiendo lecturas y escrituras concurrentes.

---

## 4. Criterios de Aceptación y Condición de Corte

- **Respaldo Válido:** Retorno `$LASTEXITCODE = 0`, archivo dump legible por `pg_restore -l` y registro de timestamp en `logs/`.
- **Restauración Íntegra:**
  1. Coincidencia simétrica en el conteo de filas de `categoria`, `cliente`/`usuario`, `producto`, `pedido` y `detalle_pedido` entre `foodstore` y `foodstore_restore_test`.
  2. Integridad de dominio: `COUNT(*) == 0` para productos con `precio < 0 OR stock < 0`.
  3. Integridad de transacciones: `COUNT(*) == 0` para detalles con `cantidad <= 0 OR precio_unitario < 0`.
- **Métricas Operativas:** Registro obligatorio del tiempo total medido (**RTO observado**) y de la antigüedad del respaldo (**RPO observado**).
