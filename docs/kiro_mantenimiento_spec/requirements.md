# Requirements Document — Unidad 6: Mantenimiento, Respaldo y Recuperación

## Introduction

Este documento formaliza los requisitos para el plan de mantenimiento, respaldo periódico, monitoreo preventivo y recuperación ante desastres (Disaster Recovery) para la base de datos `foodstore` sobre **PostgreSQL 16+**. El trabajo es desarrollado para el proyecto integrador **Food Store** de la cátedra Bases de Datos II por el equipo (**Máximo, Andrés y Octavio**).

El entorno de producción opera con alta concurrencia transaccional (OLTP). El plan busca mitigar el riesgo de pérdida de datos, degradación de rendimiento por acumulación de tuplas muertas (*table bloat*) y asegurar la continuidad operativa mediante un procedimiento de restauración automatizado y medible en tiempo y punto de recuperación (**RTO** y **RPO**).

---

## Glossary

- **PostgreSQL 16+**: Motor de base de datos relacional transaccional (OLTP).
- **foodstore**: Base de datos principal de producción. En simulacros nunca se elimina ni sobreescribe.
- **foodstore_restore_test**: Base de datos descartable creada exclusivamente para validar la restauración.
- **pg_dump**: Utilidad nativa de respaldo de PostgreSQL.
- **Formato Custom (`-Fc`)**: Formato de archivo binario comprimido de PostgreSQL compatible con `pg_restore`, que permite reordenar objetos, restaurar en paralelo y validar metadatos sin ejecutar scripts SQL de texto plano.
- **pg_restore**: Utilidad nativa para restaurar bases de datos creadas por `pg_dump` en formatos no planos.
- **RTO (Recovery Time Objective)**: Tiempo objetivo y medido necesario para restablecer la operatividad completa del servicio desde la declaración del desastre hasta la finalización de las validaciones de consistencia.
- **RPO (Recovery Point Objective)**: Período máximo tolerable de pérdida de datos medido en tiempo; en el simulacro, corresponde a la antigüedad del respaldo utilizado respecto al momento del incidente.
- **Table Bloat / Tuplas Muertas (`n_dead_tup`)**: Espacio ocupado por versiones obsoletas de filas no purgadas tras operaciones `UPDATE` o `DELETE`.
- **Autovacuum**: Proceso de fondo nativo de PostgreSQL que recupera espacio y actualiza estadísticas automáticamente.
- **VACUUM FULL**: Comando de mantenimiento agresivo que reconstruye la tabla y sus índices bloqueándola en modo exclusivo (`AccessExclusiveLock`). Su uso está explícitamente desaconsejado en planes periódicos estándar.
- **ANALYZE**: Recolección de estadísticas del optimizador de consultas (`pg_statistic`).

---

## Requirements

### Requirement 1 — Política y Especificación Formal del Plan (`SPEC_U6.md`)

**User Story:** Como administrador de bases de datos (DBA), quiero una especificación formal consolidada de máximo una página, para que el equipo operativo conozca exactamente qué se automatiza, con qué frecuencia, qué evidencia genera y cuáles son las reglas de seguridad.

#### Acceptance Criteria

1. THE Sistema SHALL contar con un archivo `SPEC_U6.md` en la raíz del repositorio con una extensión máxima de una página.
2. THE Sistema SHALL definir una matriz de tareas mínimas que contemple:
   - Respaldo diario de `foodstore` generando archivo `.dump` con fecha/hora y registro de log.
   - Chequeo diario de salud ejecutando consultas de diagnóstico sobre `foodstore`.
   - Revisión semanal de mantenimiento evaluando tuplas muertas, actividad de `autovacuum` y estadísticas.
   - Restauración de prueba semanal en la base aislada `foodstore_restore_test`.
3. THE Sistema SHALL explicitar que ninguna contraseña puede quedar hardcodeada ni expuesta en scripts o repositorios.
4. THE Sistema SHALL prohibir el uso periódico de `VACUUM FULL` como rutina programada.

---

### Requirement 2 — Script Automatizado de Respaldo (`backup_foodstore.ps1`)

**User Story:** Como operador de infraestructura, quiero un script automatizado en PowerShell para respaldar la base de datos `foodstore`, de modo que pueda ejecutarse de forma programada o manual registrando evidencias y garantizando el formato custom binario.

#### Acceptance Criteria

1. THE Sistema SHALL ejecutar `pg_dump` utilizando el formato custom binario comprimido (`-Fc`).
2. THE Sistema SHALL generar el archivo de respaldo bajo la ruta `backups/foodstore_yyyyMMdd_HHmmss.dump`.
3. THE Sistema SHALL registrar en la carpeta `logs/` un archivo `backup_yyyyMMdd_HHmmss.log` con fecha/hora de inicio, parámetros (host, port, user, db), duración de la ejecución, tamaño en bytes del archivo `.dump` generado y código de salida del proceso.
4. IF `pg_dump` falla o retorna un código de salida diferente de cero, THEN THE Sistema SHALL capturar `$LASTEXITCODE`, escribir el error en el archivo de log y terminar el script con código de salida `1` (`exit 1`).
5. IF el respaldo finaliza con éxito, THEN THE Sistema SHALL finalizar con código de salida `0` (`exit 0`).
6. THE Sistema SHALL verificar y crear automáticamente los directorios `backups/` y `logs/` si no existen previamente.
7. THE Sistema SHALL operar sin exponer contraseñas en su código fuente, consumiendo credenciales mediante la variable de entorno de sesión `PGPASSWORD` o archivo `pgpass.conf`.

---

### Requirement 3 — Monitoreo de Salud Operativa (`health_check.sql`)

**User Story:** Como DBA, quiero un conjunto de consultas no invasivas de monitoreo, para evaluar rápidamente el volumen, conexiones, concurrencia y salud de los índices y tablas sin degradar la base en producción.

#### Acceptance Criteria

1. THE Sistema SHALL medir el tamaño físico de la base de datos `foodstore` formateado para lectura humana mediante `pg_size_pretty(pg_database_size('foodstore'))`.
2. THE Sistema SHALL consultar el número de conexiones concurrentes (`numbackends`), transacciones confirmadas (`xact_commit`) y abortadas (`xact_rollback`) desde la vista de catálogo `pg_stat_database`.
3. THE Sistema SHALL auditar el estado de tuplas vivas (`n_live_tup`), tuplas muertas (`n_dead_tup`) y la fecha/hora del último `last_autovacuum` y `last_autoanalyze` desde `pg_stat_user_tables`, ordenadas de forma descendente por `n_dead_tup`.
4. THE Sistema SHALL listar las consultas activas en ejecución no ociosas (`state <> 'idle'`), exponiendo `pid`, `state`, duración (`now() - query_start`) y texto de la consulta desde `pg_stat_activity`.

---

### Requirement 4 — Mantenimiento Preventivo Seguro y Justificado (`maintenance.sql`)

**User Story:** Como DBA, quiero un procedimiento de mantenimiento seguro que justifique técnicamente cualquier intervención manual previa observación del estado de las tablas.

#### Acceptance Criteria

1. THE Sistema SHALL incluir una consulta de diagnóstico para identificar tablas que requieran refresco de estadísticas o recolección de espacio antes de ejecutar cualquier acción.
2. THE Sistema SHALL ejecutar únicamente comandos no bloqueantes como `VACUUM` estándar o `ANALYZE` selectivo sobre tablas con actividad DML reciente.
3. THE Sistema SHALL NO utilizar `VACUUM FULL` en rutinas de mantenimiento periódico para preservar la disponibilidad del servicio y evitar el bloqueo exclusivo de lectura y escritura (`AccessExclusiveLock`).
4. THE Sistema SHALL documentar en el encabezado del script la justificación técnica de la acción de mantenimiento elegida.

---

### Requirement 5 — Simulacro de Desastre Contra Reloj y Validación (`restore_test.ps1`)

**User Story:** Como responsable de continuidad del negocio, quiero realizar un simulacro de recuperación cronometrado restaurando el último respaldo sobre un entorno descartable, para certificar que el respaldo es íntegro y medir el RTO y RPO reales.

#### Acceptance Criteria

1. THE Sistema SHALL iniciar un cronómetro de alta precisión inmediatamente antes de crear la base descartable `foodstore_restore_test`.
2. THE Sistema SHALL restaurar el archivo `.dump` más reciente mediante `pg_restore` utilizando los modificadores `--no-owner` y `--no-privileges` para garantizar portabilidad de roles.
3. THE Sistema SHALL ejecutar validaciones mínimas de consistencia sobre `foodstore_restore_test`:
   - Conteo de filas de las tablas operativas (`categoria`, `cliente`/`usuario`, `producto`, `pedido`, `detalle_pedido`) contrastado contra los registros de la base original.
   - Validación de dominio e integridad: `SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0` (debe retornar estrictamente `0`).
   - Validación de detalles de pedido: `SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0` (debe retornar estrictamente `0`).
4. THE Sistema SHALL detener el cronómetro únicamente cuando las validaciones hayan finalizado con éxito.
5. THE Sistema SHALL registrar y presentar el tiempo total observado como **RTO** del simulacro.
6. THE Sistema SHALL calcular la diferencia entre la fecha/hora del dump y el momento del simulacro para reportar el **RPO** observado.
7. THE Sistema SHALL preservar intacta la base original `foodstore` durante todo el simulacro.

---

### Requirement 6 — Informe Post-Incidente y Declaración DUIA

**User Story:** Como equipo de proyecto, queremos documentar las evidencias, el análisis de métricas y la interacción con herramientas de IA, para cumplir con los estándares académicos y profesionales de entrega.

#### Acceptance Criteria

1. THE Sistema SHALL documentar en `informe_u6.md` (y su versión compilada `informe_u6.pdf`) un reporte de máximo 1 página con:
   - Fecha y hora del respaldo utilizado.
   - RTO y RPO previstos vs. observados.
   - Resultados de las validaciones de datos y reglas de negocio.
   - Problemas reales encontrados y mejoras propuestas para la siguiente iteración.
   - Indicación de las partes asistidas por IA y su validación humana.
2. THE Sistema SHALL registrar en `docs/DUIA/DUIA-TP-Unidad6.md` la tabla vertical obligatoria de 6 campos bajo el formato estricto de `AGENTS.md`.
3. THE Sistema SHALL reflejar en `BITACORA.md` el registro crítico de intervenciones del equipo.
