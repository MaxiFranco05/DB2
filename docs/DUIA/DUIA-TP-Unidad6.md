| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro (SDD) + OpenCode |
| **Spec o prompt utilizado** | `SPEC_U6.md` y prompt: *"Generar el script automatizado de respaldo `backup_foodstore.ps1` para PostgreSQL 16+ en Windows con formato custom `-Fc`, fecha/hora en nombre, logging en `logs/`, validación de `$LASTEXITCODE` y sin contraseñas hardcodeadas."* |
| **Qué generó** | Estructura base del script en PowerShell invocando `pg_dump -Fc` con redirección de salida y guardado del archivo `.dump` en `backups/`. |
| **Qué se aceptó** | 90% de la lógica de creación de directorios, nomenclatura con timestamp y formato binario comprimido. |
| **Qué se modificó o descartó, y por qué** | 1. Se descartó la interpolación de expresiones con comillas y caracteres especiales que provocaban errores de parseo en PowerShell 5.1 (Windows-1252 ANSI).<br>2. Se forzó la captura inmediata de `$dumpExitCode = $LASTEXITCODE` en la línea consecutiva a `pg_dump` para evitar que cmdlets auxiliares de PowerShell reseteen el código de salida del motor.<br>3. Se incorporó verificación de tamaño mayor a 0 bytes. |
| **Verificación realizada** | ✅ Ejecución manual exitosa de `backup_foodstore.ps1` generando `backups/foodstore_20261104_164552.dump` (3.94 MB) en 1.33 segundos.<br>✅ Inspección de catálogo del dump mediante `pg_restore -l` confirmando 58 entradas TOC íntegras.<br>✅ Log generado en `logs/backup_20261104_164552.log` con código de salida 0. |

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Spec o prompt utilizado** | `SPEC_U6.md` y prompt: *"Construir los scripts `sql/health_check.sql` (con 4 controles: tamaño, transacciones, tuplas muertas/autovacuum y queries lentas) y `sql/maintenance.sql` (con diagnóstico previo y acción segura justificada)."* |
| **Qué generó** | - Script `sql/health_check.sql` con consultas a `pg_database_size`, `pg_stat_database`, `pg_stat_user_tables` y `pg_stat_activity`.<br>- Propuesta inicial para `sql/maintenance.sql` que sugería la opción de ejecutar `VACUUM FULL` sobre las tablas con tuplas muertas para recuperar espacio físico en disco. |
| **Qué se aceptó** | Se aceptaron al 100% las 4 consultas de monitoreo de `sql/health_check.sql` formateadas con `\echo` y encabezados legibles. |
| **Qué se modificó o descartó, y por qué** | 1. El equipo (**Máximo, Andrés y Octavio**) rechazó y descartó tajantemente la propuesta de `VACUUM FULL`: este comando adquiere `AccessExclusiveLock` bloqueando tanto escrituras como lecturas concurrentes, causando una caída de servicio inaceptable para una aplicación de comidas en producción.<br>2. Se reemplazó por `VACUUM ANALYZE` concurrente no bloqueante (`ShareUpdateExclusiveLock`), que libera espacio reutilizable y actualiza `pg_statistic` sin degradar el servicio. |
| **Verificación realizada** | ✅ Ejecución de `sql/health_check.sql` sobre `foodstore` (tamaño: 155 MB, 1 conexión activa, 0 interbloqueos).<br>✅ Ejecución de `sql/maintenance.sql` actualizando `last_vacuum` y `last_analyze` en las 5 tablas principales (621.987 detalles, 200.000 pedidos, 50.000 productos, 20.000 usuarios, 5 categorías).<br>✅ Verificación en catálogo con `0 filas` de bloqueo exclusivo y actualización efectiva de métricas. |

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro + OpenCode |
| **Spec o prompt utilizado** | `SPEC_U6.md` y prompt: *"Generar el script `restore_test.ps1` para automatizar el simulacro de recuperación contra reloj en `foodstore_restore_test`, midiendo RTO y RPO y ejecutando las validaciones mínimas de cardinalidad e integridad lógica."* |
| **Qué generó** | Script de PowerShell con comandos `createdb`, `pg_restore` y consultas de validación de filas e inconsistencias. |
| **Qué se aceptó** | La lógica de automatización de pruebas, la invocación de `createdb`/`pg_restore` y las consultas de validación lógica (`precio < 0 OR stock < 0`, `cantidad <= 0 OR precio_unitario < 0`). |
| **Qué se modificó o descartó, y por qué** | 1. Se añadieron los flags obligatorios `--no-owner --no-privileges` en `pg_restore` para evitar errores de roles de base de datos en entornos heterogéneos.<br>2. Se instrumentó un cronómetro de alta precisión (`[System.Diagnostics.Stopwatch]`) arrancando inmediatamente antes de `createdb` y deteniéndose tras el fin de las validaciones para calcular el RTO exacto.<br>3. Se calculó la antigüedad del dump para determinar el RPO observado.<br>4. Se resolvió la discrepancia nominal creando la vista `cliente` sobre `usuario`. |
| **Verificación realizada** | ✅ Ejecución exitosa de `restore_test.ps1` restaurando los 891.992 registros en `foodstore_restore_test`.<br>✅ Medición de RTO: **6.95 segundos** (frente al objetivo SLA de < 300 segundos).<br>✅ Medición de RPO: **332.3 segundos (~5.54 minutos)**.<br>✅ Validación de integridad: `0` productos inválidos y `0` detalles inválidos. Prueba de diferencia con `EXCEPT` bidireccional de conteos contra la base origen arrojando `0 filas` de diferencia. |
