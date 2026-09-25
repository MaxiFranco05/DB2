# DUIA - Parte C: Vista Materializada (Unidad 3 - Semana 1)

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro (diseño técnico y redacción de spec en mv_ventas_categoria_mes.md) y OpenCode (traducción a DDL en db/materialized_views.sql). |
| **Spec o prompt utilizado** | .kiro/specs/mv_ventas_categoria_mes.md |
| **Qué generó** | Script db/materialized_views.sql con la definición de mv_ventas_categoria_mes (WITH NO DATA), índice único uix_mv_ventas_categoria_mes sobre (categoria_id, mes) e índice complementario ix_mv_ventas_mes sobre (mes DESC). |
| **Qué se aceptó** | La definición completa del precalculado analítico mensual, el uso de subtotal histórico congelado, el filtrado de pedidos no cancelados y la exclusión de categorías inactivas. |
| **Qué se modificó/descartó** | Se descartó calcular el reporte mensual en caliente mediante vista tradicional, justificando la tolerancia al atraso temporal frente al costo computacional lineal de recorrer medio millón de registros históricos. |
| **Verificación realizada** | ✅ Creación idempotente con WITH NO DATA y primera carga atómica con REFRESH MATERIALIZED VIEW. ✅ Validación de refresco no bloqueante (REFRESH MATERIALIZED VIEW CONCURRENTLY) garantizado por el índice único (categoria_id, mes). ✅ Reducción empírica de latencia validada con EXPLAIN ANALYZE: de 335.380 ms (recorrido multitable con Parallel Seq Scan) a 0.015 ms (lectura de snapshot plano de 13 filas). ✅ Equivalencia matemática garantizada entre la consulta manual y la vista materializada mediante la cláusula EXCEPT (0 filas devueltas). |