# Declaración de Uso de IA (DUIA) - Parte 3

## Ejercicio de Lectura Crítica de Scripts

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Spec o prompt utilizado** | "Analizar el comportamiento real de las sentencias UPDATE y DELETE de la Parte 3 e identificar fallas de lógica en SQL frente a la consigna planteada." |
| **Qué generó** | Diagnóstico del impacto masivo en `UPDATE` por ausencia de la cláusula `WHERE`, y la explicación técnica de la evaluación de tres valores (*Three-Valued Logic*) en `NOT IN` con valores `NULL` para el `DELETE`. |
| **Qué se aceptó** | La explicación teórica del fallo silencioso por valores `NULL` y las versiones corregidas del código SQL. |
| **Qué se modificó o descartó** | Se conservó únicamente la variante con `NOT EXISTS` por ser la solución más robusta frente a valores nulos en el modelo relacional. |
| **Verificación realizada** | Ejecución en PostgreSQL dentro de una transacción con `BEGIN; ... ROLLBACK;` creando datos de prueba con `NULL` para confirmar que `NOT IN` efectivamente devuelve 0 filas afectadas. |