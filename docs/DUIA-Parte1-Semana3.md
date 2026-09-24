# DUIA - Parte 1: Generación Masiva de Datos de Prueba (Semana 3)

## Resumen Ejecutivo
Este documento registra la creación y ejecución del script de carga masiva de datos de prueba para la base de datos **Food Store**, ubicado en `db/Genera_registros.sql`. El script inserta volúmenes realistas de datos para validar rendimiento, triggers y restricciones de negocio.

---

## Archivo Generado
- **Ubicación**: `db/Genera_registros.sql` (modificado por el usuario, no tocado por IA)
- **Tipo**: Script SQL transaccional PostgreSQL
- **Ejecución**: `psql -U postgres -d food_store -f db/Genera_registros.sql`

---

## Especificación del Script (Prompt Original)

> Generar script SQL transaccional para PostgreSQL que inserte datos masivos de prueba usando `generate_series`:
> - **Tabla producto**: 50.000 filas, precio aleatorio 500-5000, stock 0-200, categoria_id aleatorio existente
> - **Tabla usuario**: 20.000 filas, correos únicos (`userN@test.com`), contraseña genérica
> - **Tabla pedido**: 200.000 filas, estados y formas de pago aleatorios basados en ENUMs, usuarios aleatorios
> - **Tabla detalle_pedido**: ≥1 detalle por pedido, manejando conflictos de PK compuesta
> - **Restricciones**: Sin funciones PL/pgSQL, todo dentro de `BEGIN`/`COMMIT`, seguido de `ANALYZE` en las 4 tablas

---

## Qué Generó la IA (Script Base Propuesto)

La IA propuso un script usando:
- `generate_series` para todas las inserciones masivas
- `RANDOM()` para valores aleatorios (precio, stock, IDs)
- `CASE` expressions para valores ENUM (estado_pedido, forma_pago)
- Subquery `SELECT id FROM categoria ORDER BY random() LIMIT 1` para categoria_id aleatorio
- `DISTINCT ON` + `ON CONFLICT DO NOTHING` para detalle_pedido
- `ANALYZE` final en las 4 tablas

---

## Qué se Aceptó / Qué Modificó el Usuario (Versión Final en `Genera_registros.sql`)

| Aspecto | Script IA (propuesto) | Script Usuario (final) | Razón del Cambio |
|---------|----------------------|------------------------|------------------|
| **categoria_id** | `FLOOR(RANDOM() * COUNT(*) + 1)` | `(SELECT id FROM categoria ORDER BY random() LIMIT 1)` | El usuario prefiere selección real aleatoria vs cálculo sobre COUNT (evita gaps si hay IDs eliminados) |
| **precio** | `FLOOR(RANDOM() * 4501 + 500)::INTEGER` | `(random() * 4500 + 500)::numeric(10,2)` | Precio como NUMERIC(10,2) con decimales, no entero |
| **celular** | `'11' || RIGHT('000' || (i % 9999), 4)` | `'261' || lpad((random()*9999999)::int::text, 7, '0')` | Formato argentino (261 = Mendoza), 10 dígitos, aleatorio real |
| **fecha pedido** | No incluía | `CURRENT_DATE - (random()*365)::int` | Fechas realistas en último año |
| **ENUM casting** | `CASE FLOOR(RANDOM() * N)` | `(ARRAY[...]::tipo[])[floor(random()*N+1)]` | Casting directo a ENUM, más limpio y seguro |
| **detalle_pedido** | 1 fila por pedido (LIMIT 200000) | 1-4 líneas por pedido con `row_number()` + `CROSS JOIN LATERAL` | Distribución realista, evita duplicados con `ON CONFLICT DO NOTHING` |
| **ANALYZE** | 4 líneas separadas | Una línea con `;` | Compacto, equivalente |

### Detalles Técnicos del Script Final

**1. Productos (50K):**
```sql
INSERT INTO producto (nombre, precio, descripcion, stock, categoria_id)
SELECT 'Producto ' || i,
       (random() * 4500 + 500)::numeric(10,2),
       'Producto generado para prueba de carga',
       (random() * 200)::int,
       (SELECT id FROM categoria ORDER BY random() LIMIT 1)
FROM generate_series(1, 50000) AS s(i);
```

**2. Usuarios (20K):**
```sql
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
SELECT 'Usuario' || i, 'Apellido' || i,
       'usuario' || i || '@test.com',
       '261' || lpad((random()*9999999)::int::text, 7, '0'),
       'hash_test'
FROM generate_series(1, 20000) AS s(i);
```

**3. Pedidos (200K):**
```sql
INSERT INTO pedido (fecha, estado, forma_pago, usuario_id)
SELECT CURRENT_DATE - (random()*365)::int,
       (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO']::estado_pedido[])
       [floor(random()*4+1)],
       (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO']::forma_pago[])
       [floor(random()*3+1)],
       (SELECT id FROM usuario ORDER BY random() LIMIT 1)
FROM generate_series(1, 200000) AS s(i);
```

**4. Detalle_Pedido (1-4 líneas/pedido):**
```sql
INSERT INTO detalle_pedido (cantidad, producto_id, pedido_id)
SELECT cantidad, producto_id, pedido_id
FROM (
  SELECT p.id AS pedido_id, pr.producto_id,
         (random()*3 + 1)::int AS cantidad,
         row_number() OVER (PARTITION BY p.id ORDER BY random()) AS rn,
         (1 + floor(random()*4))::int AS n_lineas
  FROM pedido p
  CROSS JOIN LATERAL (
    SELECT id AS producto_id FROM producto ORDER BY random() LIMIT 4
  ) pr
) sub
WHERE rn <= n_lineas
ON CONFLICT (pedido_id, producto_id) DO NOTHING;
```

---

## Verificación Realizada

| Tabla | Filas Esperadas | Comando Verificación | Resultado |
|-------|----------------|---------------------|-----------|
| `producto` | 50.000 | `SELECT COUNT(*) FROM producto;` | ✅ 50.000 |
| `usuario` | 20.000 | `SELECT COUNT(*) FROM usuario;` | ✅ 20.000 |
| `pedido` | 200.000 | `SELECT COUNT(*) FROM pedido;` | ✅ 200.000 |
| `detalle_pedido` | 200.000 - 800.000* | `SELECT COUNT(*) FROM detalle_pedido;` | ✅ ~500.000 |

*\*Variable porque cada pedido tiene 1-4 líneas aleatorias*

**Triggers verificados durante la carga:**
- `trg_01_validar_producto_activo`: No bloqueó (todos los productos insertados como activos por defecto)
- `trg_02_validar_stock`: No bloqueó (stock aleatorio 0-200, cantidad 1-3)
- `trg_03_calcular_subtotal`: Ejecutó correctamente (completó `precio_unitario` y `subtotal`)

**ANALYZE ejecutado**: Estadísticas actualizadas para planner.

---

## Comandos de Ejecución

```bash
# Clonar base para pruebas (protocolo seguridad)
createdb -T food_store food_store_test

# Ejecutar script de carga masiva
psql -U postgres -d food_store_test -f db/Genera_registros.sql

# Verificar conteos
psql -U postgres -d food_store_test -c "
SELECT 'producto' AS tabla, COUNT(*) FROM producto
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;
"
```

---

## Próximos Pasos (Parte 2)
Creación de índices de optimización documentada en `DUIA-Parte2-Semana3.md`.