## Declaración de Uso de IA (DUIA - Parte 2)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Spec o prompt utilizado** | "Explicar la causa teórica y qué nivel de aislamiento evita las anomalías de Espera por Bloqueo, Lectura no Repetible y Lectura Fantasma según la ejecución paso a paso en PostgreSQL." |
| **Qué generó** | Las explicaciones teóricas y la propuesta de usar `REPEATABLE READ` para solucionar los escenarios de lectura. |
| **Qué se aceptó** | El diagnóstico teórico y niveles de aislamiento. |
| **Qué se modificó o descartó** | Ningún cambio técnico; se agregaron las evidencias con los comandos SQL propios de nuestro esquema. |
| **Verificación realizada** | Comprobación directa en DBeaver cambiando de `READ COMMITTED` a `REPEATABLE READ` en las sesiones concurrentes. |