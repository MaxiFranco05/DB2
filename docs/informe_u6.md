# Informe Post-Incidente y Recuperación ante Desastres — Unidad 6

**Asignatura:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto Integrador:** Food Store (PostgreSQL 16+)  
**Equipo:** Máximo, Andrés y Octavio  
**Fecha de Realización:** 04/11/2026 | **Entorno de Prueba:** `foodstore_restore_test`

---

## 1. Datos Generales del Respaldo Utilizado
- **Archivo Dump:** `backups/foodstore_20261104_164552.dump` (Formato Custom `-Fc`, 58 entradas TOC).
- **Fecha y Hora de Generación:** 2026-11-04 16:45:54.
- **Tamaño del Respaldo:** 4.133.600 bytes (3,94 MB) para 891.992 registros totales.

---

## 2. Métricas de Recuperación ante Desastres: RTO y RPO

| Métrica | Definición Operativa | Valor Previsto (SLA) | Valor Observado (Real) | Desvío / Cumplimiento |
| :--- | :--- | :---: | :---: | :---: |
| **RTO (Recovery Time Objective)** | Tiempo total desde inicio de `createdb`, ejecución de `pg_restore` y finalización de las validaciones lógicas. | < 300,00 s (5 min) | **6,95 segundos** | **-97,7%** (Ampliamente dentro del objetivo) |
| **RPO (Recovery Point Objective)** | Antigüedad del respaldo al momento del simulacro (pérdida potencial de transacciones). | $\le$ 24,00 horas (Diario) | **332,3 segundos** (~5,54 min) | **Cumple** ventana de respaldo diario |

---

## 3. Resultado de Validaciones de Integridad y Restricciones Lógicas

| Tabla / Control | Cardinalidad Origen (`foodstore`) | Cardinalidad Destino (`foodstore_restore_test`) | Estado |
| :--- | :---: | :---: | :---: |
| `categoria` | 5 | 5 | Coincidencia exacta (100%) |
| `cliente` (vista sobre `usuario`) | 20.000 | 20.000 | Coincidencia exacta (100%) |
| `producto` | 50.000 | 50.000 | Coincidencia exacta (100%) |
| `pedido` | 200.000 | 200.000 | Coincidencia exacta (100%) |
| `detalle_pedido` | 621.987 | 621.987 | Coincidencia exacta (100%) |
| **Productos inválidos (`precio < 0 OR stock < 0`)** | 0 | 0 | **Aprobado** (0 anomalías) |
| **Detalles inválidos (`cantidad <= 0 OR precio_unitario < 0`)** | 0 | 0 | **Aprobado** (0 anomalías) |

---

## 4. Problemas Reales Encontrados durante el Procedimiento
1. **Desbalanceo de comillas por codificación ANSI en PowerShell 5.1:** El uso de caracteres tipográficos UTF-8 sin BOM (como el guion largo `—`, bytes `E2 80 94`) provocó que PowerShell interpretara el byte `0x94` como comilla tipográfica doble de cierre (`”`), rompiendo el analizador léxico. Se solucionó normalizando a caracteres estándar en los scripts `.ps1`.
2. **Discrepancia nominal de esquema (`cliente` vs `usuario`):** Las consultas de validación de la cátedra consultaban la tabla `cliente`, pero en el esquema histórico canónico se denomina `usuario`. Se resolvió arquitectónicamente creando la vista `CREATE VIEW cliente AS SELECT * FROM usuario;`, garantizando portabilidad sin alterar el modelo relacional.

---

## 5. Mejora Concreta para la Siguiente Ejecución
- **Rotación y compresión paralela:** Implementar en `backup_foodstore.ps1` un mecanismo de retención automática de las últimas 7 copias diarias eliminando dumps obsoletos, e incorporar el modificador multihilo `-j 4` en `pg_restore` para optimizar la reconstrucción de índices en servidores de producción con múltiples núcleos.

---

## 6. Asistencia de Inteligencia Artificial (OpenCode/Kiro) y Verificación Humana
- **Qué generó la IA:** Kiro y OpenCode formularon la primera versión de `SPEC_U6.md`, el script de backup y la propuesta de mantenimiento que sugería `VACUUM FULL`.
- **Intervención y corrección humana:** El equipo (**Máximo, Andrés y Octavio**) rechazó categóricamente `VACUUM FULL` por su bloqueo exclusivo total (`AccessExclusiveLock`) y lo sustituyó por `VACUUM ANALYZE` concurrente; corrigió la captura de `$LASTEXITCODE` en PowerShell; y agregó `--no-owner --no-privileges` en `pg_restore`.
- **Verificación:** Ejecución real en motor PostgreSQL 17.10 con cronómetro de precisión, log auditado y prueba de diferencia con `EXCEPT` de 0 filas.
