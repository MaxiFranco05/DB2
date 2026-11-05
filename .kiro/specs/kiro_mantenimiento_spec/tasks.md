# Implementation Tasks — Unidad 6: Mantenimiento, Respaldo y Recuperación

- [x] **Task 1: Especificación Formal y Acondicionamiento del Entorno**
  - [x] 1.1 Redactar el documento raíz `SPEC_U6.md` (1 página) con la matriz de 4 tareas, frecuencias, evidencias y directivas de seguridad.
  - [x] 1.2 Verificar y asegurar la base canónica `foodstore` en PostgreSQL con el esquema y dataset completo (incluyendo vista de compatibilidad `cliente`).

- [x] **Task 2: Script Automatizado de Respaldo (`backup_foodstore.ps1`)**
  - [x] 2.1 Implementar `backup_foodstore.ps1` con creación dinámica de carpetas `backups/` y `logs/`.
  - [x] 2.2 Configurar el comando `pg_dump` en formato binario custom (`-Fc`) con timestamp `yyyyMMdd_HHmmss`.
  - [x] 2.3 Implementar captura rigurosa de `$LASTEXITCODE`, registro detallado en archivo `.log` y terminación con código de error si falla.
  - [x] 2.4 Ejecutar manualmente y verificar la creación del dump y del log.

- [x] **Task 3: Consultas de Monitoreo y Mantenimiento Seguro**
  - [x] 3.1 Implementar `sql/health_check.sql` con los 4 controles obligatorios (volumen, transacciones de base, tuplas muertas y consultas lentas activas).
  - [x] 3.2 Implementar `sql/maintenance.sql` con diagnóstico previo, rechazo fundamentado de `VACUUM FULL` y acción preventiva segura (`ANALYZE` / `VACUUM` concurrente).
  - [x] 3.3 Ejecutar ambos scripts contra `foodstore` y registrar las métricas basales.

- [x] **Task 4: Automatización del Simulacro de Desastre (`restore_test.ps1`)**
  - [x] 4.1 Implementar `restore_test.ps1` con selección automática del último respaldo en `backups/`.
  - [x] 4.2 Incorporar cronómetro `[System.Diagnostics.Stopwatch]` desde el inicio de creación de `foodstore_restore_test` hasta el fin de las validaciones.
  - [x] 4.3 Ejecutar `pg_restore` con flags `--no-owner --no-privileges`.
  - [x] 4.4 Ejecutar consultas de validación de cardinalidad (conteos de tablas) y consistencia lógica (precios, stock y cantidades válidas).
  - [x] 4.5 Calcular y reportar en pantalla el RTO medido y el RPO observado.

- [x] **Task 5: Ejecución del Simulacro y Recolección de Evidencias**
  - [x] 5.1 Correr el ciclo completo de backup y restauración cronometrada.
  - [x] 5.2 Capturar salida de validaciones con `0` discrepancias lógicas y coincidencia de registros.
  - [x] 5.3 Registrar tiempos finales de RTO y RPO.

- [x] **Task 6: Documentación, Informe Post-Incidente y DUIA**
  - [x] 6.1 Redactar el informe de 1 página `docs/informe_u6.md` y generar `informe_u6.pdf`.
  - [x] 6.2 Completar la tabla vertical de 6 campos en `docs/DUIA/DUIA-TP-Unidad6.md` siguiendo estrictamente la directiva de `AGENTS.md`.
  - [x] 6.3 Actualizar la bitácora del equipo en `BITACORA.md`.
