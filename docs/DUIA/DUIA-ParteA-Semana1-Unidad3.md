# DUIA - Parte A: Índices (Unidad 3 - Semana 1)

| **Campo** | **Completar** |
| :--- | :--- |
| **Herramienta** | Kiro (asistencia en redacción de especificaciones de diseño) y OpenCode (generación de script SQL) |
| **Spec o prompt utilizado** | .kiro/specs/indice_pedidos_pendientes.txt, .kiro/specs/indice_detalle_producto.txt, .kiro/specs/indice_estado_redundante.txt |
| **Qué generó** | Script transaccional (indices.sql) proponiendo tres índices B-tree: compuesto (estado, fecha), simple (estado), y cubridor (producto_id) INCLUDE (cantidad) |
| **Qué se aceptó** | idx_pedido_pendiente_fecha e idx_detalle_producto. Se validó su impacto positivo en el rendimiento de consultas masivas y de alta frecuencia |
| **Qué se modificó/descartó** | Se descartó idx_pedido_estado. Al ser 'estado' una columna ENUM de pocos valores, posee muy baja selectividad. El optimizador de PostgreSQL lo ignora prefiriendo un recorrido secuencial, por lo que su instalación solo degradaría las escrituras en silencio |
| **Verificación realizada** | ✅ Eliminación de recorridos secuenciales en el camino crítico confirmada vía EXPLAIN ANALYZE (mejora de 37.228 ms a 1.001 ms). ✅ Penalidad de mantenimiento en escrituras registrada y medida empíricamente (+0.066 ms de latencia en cláusulas INSERT masivas). ✅ Integridad matemática y equivalencia de las consultas garantizada mediante el operador EXCEPT (0 filas devueltas) |