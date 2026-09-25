# DUIA - Parte B: Vistas (Unidad 3 - Semana 1)

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro (diseño intelectual y especificación de reglas de negocio) y OpenCode (generación de script DDL views.sql y de pruebas de validación). |
| **Spec o prompt utilizado** | .kiro/specs/v_categorias_vigentes.md, .kiro/specs/v_productos_vigentes.md, .kiro/specs/v_resumen_pedidos.md, .kiro/specs/v_detalle_pedidos.md |
| **Qué generó** | Script DDL (db/views.sql) y script de pruebas automatizadas (db/test_views.sql) con las cuatro vistas obligatorias: v_categorias_vigentes (con WITH CHECK OPTION), v_productos_vigentes (JOIN de doble baja lógica), v_resumen_pedidos (historial completo sin filtro de estado y sin exponer credenciales), y v_detalle_pedidos (líneas con precio histórico congelado y estado expuesto). |
| **Qué se aceptó** | Las cuatro definiciones de vistas en su totalidad y su script de validación integral, validando que encapsulan correctamente la lógica de negocio, la seguridad y la trazabilidad histórica sin alterar las tablas base. |
| **Qué se modificó/descartó** | Se descartó aplicar filtros restrictivos de estado sobre el detalle de pedidos y el resumen de pedidos, decidiendo mantener la visibilidad histórica completa para auditoría y análisis de negocio. |
| **Verificación realizada** | ✅ Validación de equivalencia matemática bidireccional mediante la cláusula EXCEPT ejecutada y automatizada en test_views.sql (0 filas de diferencia frente a las consultas manuales equivalentes). ✅ Comprobación de que WITH CHECK OPTION en v_categorias_vigentes rechaza inserciones inválidas. ✅ Verificación de proyección segura (exclusión estricta de usuario.contrasena). |