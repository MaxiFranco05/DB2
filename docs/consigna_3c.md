### Consigna 3.c - Code Review con IA

| Archivo / Unidad Afectada | Hallazgo / Mejora Propuesta | Decisión | Motivo / Justificación Técnica |
| :--- | :--- | :--- | :--- |
| `sql/roles.sql` (Unidad 5) | **Seguridad: contraseñas en texto plano.** Sugiere cambiar las contraseñas escritas directamente en el script por variables de entorno (`APP_WEB_PASSWORD`) que se lean al ejecutar el comando con `psql -v`. | **Aceptado** | Evita que las credenciales queden expuestas en el historial de Git (reparando el incumplimiento del Requisito 5.1). |
| `consultas_mongodb.js` (Unidad 7) | **Integridad e Índices:** Sugiere usar `$jsonSchema` al crear la colección para exigir la RI-M2 (array con mínimo 1 ítem) antes de insertar, y crear índices (ej: `estado`) para optimizar Q-M2 y Q-M3. | **Aceptado** | Evita la inserción de documentos inválidos y optimiza búsquedas futuras, evitando un `COLLSCAN` cuando el volumen crezca a 200.000 registros. |
| `sql/restricciones.sql` (Unidad 1 y 3) | **Concurrencia: condición de carrera en el stock.** Sugiere cambiar el `SELECT` del trigger por un `UPDATE` condicional que descuente y bloquee la fila, para evitar ventas de más bajo el nivel `READ COMMITTED`. | **Descartado** | **Intencional por el alcance del TP.** El script actual está diseñado explícitamente para *validar* las reglas, pero no tiene el alcance de alterar los datos físicos del stock. Si aplicamos este `UPDATE`, interferiría con los scripts de carga masiva (`Genera_registros.sql`), rompiendo la base de prueba de la cátedra y generando mediciones de rendimiento inconsistentes. |

> *Nota metodológica para la Bitácora:* La revisión de este código se realizó utilizando el Agente Plan de OpenCode, conforme a lo estipulado por las directrices de la evaluación.
