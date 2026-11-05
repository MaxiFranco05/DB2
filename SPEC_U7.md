# SPEC_U7.md — Especificación Técnica Formal (SDD)
## Unidad 7: NoSQL y Nuevas Formas de Almacenamiento
### Food Store: Modelado y Migración a MongoDB

**Asignatura:** Bases de Datos II — Tecnicatura Universitaria en Programación  
**Proyecto:** Food Store | **Motor Origen:** PostgreSQL 16+ | **Motor Destino:** MongoDB 7+  
**Equipo de Trabajo:** Máximo Franco, Andrés Novello y Octavio Fiore  
**Repositorio:** https://github.com/MaxiFranco05/DB2  
**Documento:** `SPEC_U7.md` (Especificación de Diseño de Software — SDD)  
**Fecha:** 5 de Noviembre de 2026

---

## Índice

1. [Propósito y Alcance](#1-propósito-y-alcance)
2. [Mapeo Relacional → Documental (Consigna 1)](#2-mapeo-relacional--documental-consigna-1)
3. [Reglas de Integridad y Justificación de Diseño (Consigna 3)](#3-reglas-de-integridad-y-justificación-de-diseño-consigna-3)
4. [Especificación de Consultas y Verificación (Consignas 4 y 5)](#4-especificación-de-consultas-y-verificación-consignas-4-y-5)
5. [Protocolo de Evaluación de IA y Conclusión (Consignas 6 y 7)](#5-protocolo-de-evaluación-de-ia-y-conclusión-consignas-6-y-7)
6. [Prompts para Antigravity (IA Ejecutora)](#6-prompts-para-antigravity-ia-ejecutora)
7. [Criterios de Aceptación y Condición de Corte](#7-criterios-de-aceptación-y-condición-de-corte)

---

## 1. Propósito y Alcance

### 1.1. Objetivo General

Migrar y modelar en MongoDB un subconjunto representativo de la base de datos relacional `foodstore`, demostrando las diferencias paradigmáticas entre el modelo relacional normalizado (PostgreSQL) y el modelo documental desnormalizado (MongoDB), y evaluando críticamente las ventajas, limitaciones y reglas de integridad que deben preservarse en cada motor.

### 1.2. Subconjunto de Datos Seleccionado

El objeto de migración es el dominio de **pedidos con su detalle**, conformado por las siguientes tablas fuente en PostgreSQL:

| Tabla PostgreSQL | Rol en la Migración | Cardinalidad Aproximada |
| :--- | :--- | :--- |
| `pedido` | Documento raíz de la colección destino | 200.000 filas (muestra: 5) |
| `detalle_pedido` | Subdocumentos embebidos en `items[]` | 621.987 filas (muestra: N lines por pedido) |
| `usuario` | Objeto embebido `cliente` (campos no sensibles) | 20.000 filas (muestra: 1 usuario) |
| `producto` | Nombre embebido históricamente en `items[].nombre` | 50.000 filas (muestra: únicos por pedido) |

### 1.3. Muestra Real Seleccionada

Los **5 pedidos de producción** seleccionados para la migración piloto son:

| `pedido.id` (PK origen) | `usuario_id` | Estado | Forma de Pago | Observación |
| :--- | :--- | :--- | :--- | :--- |
| 756504 | 80584 | `TERMINADO` | `TARJETA` | Pedido cerrado; precio histórico congelado |
| 756505 | 80584 | `CONFIRMADO` | `TRANSFERENCIA` | Pedido en proceso de despacho |
| 756506 | 80584 | `PENDIENTE` | `EFECTIVO` | Pedido aún no procesado |
| 756507 | 80584 | `TERMINADO` | `TARJETA` | Segundo pedido cerrado del mismo cliente |
| 756508 | 80584 | `CONFIRMADO` | `TRANSFERENCIA` | Segundo pedido confirmado del mismo cliente |

> **Nota de trazabilidad:** El campo `pedido_id_origen` en cada documento MongoDB preserva el identificador de la PK relacional para auditoría cruzada. El cliente `usuario_id = 80584` concentra los 5 pedidos de la muestra; su `mail` se incluye (identificador de negocio no sensible) y su `contrasena` se **excluye** explícitamente.

### 1.4. Fuera de Alcance

- Migración de las tablas `categoria`, `producto` (como colección independiente), `restricciones.sql`, triggers y vistas de PostgreSQL.
- Implementación de autenticación en MongoDB.
- Sincronización bidireccional continua entre PostgreSQL y MongoDB.

---

## 2. Mapeo Relacional → Documental (Consigna 1)

### 2.1. Modelo Relacional de Origen (PostgreSQL)

#### 2.1.1. Entidades y Claves

```
pedido
  PK: id BIGINT GENERATED ALWAYS AS IDENTITY
  FK: usuario_id BIGINT → usuario(id) ON DELETE RESTRICT
  Campos: fecha TIMESTAMPTZ, estado estado_pedido, forma_pago forma_pago
  Restricciones: estado ∈ {'PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO'}
                 forma_pago ∈ {'EFECTIVO','TARJETA','TRANSFERENCIA'}

detalle_pedido
  PK: (pedido_id, producto_id) — clave compuesta
  FK: pedido_id  → pedido(id)   ON DELETE RESTRICT
  FK: producto_id → producto(id) ON DELETE RESTRICT
  Campos: cantidad INTEGER CHECK (cantidad > 0)
          precio_unitario NUMERIC(10,2)  ← congelado por trigger trg_subtotal
          subtotal        NUMERIC(10,2)  ← calculado por trigger trg_subtotal

usuario
  PK: id BIGINT GENERATED ALWAYS AS IDENTITY
  Campos: nombre, apellido, mail UNIQUE, celular, contrasena

producto
  PK: id BIGINT GENERATED ALWAYS AS IDENTITY
  FK: categoria_id → categoria(id) ON DELETE RESTRICT
  Campos: nombre, descripcion, precio NUMERIC(10,2) CHECK (precio >= 0),
          stock INTEGER CHECK (stock >= 0), activo BOOLEAN
```

#### 2.1.2. Restricciones Críticas de Integridad Relacional

| ID Restricción | Tipo | Definición | Mecanismo Enforcer |
| :--- | :--- | :--- | :--- |
| RI-01 | Precio histórico congelado | `detalle_pedido.precio_unitario` no cambia post-INSERT aunque `producto.precio` varíe | Trigger `trg_subtotal` (`BEFORE INSERT`) |
| RI-02 | Consistencia matemática del subtotal | `subtotal = cantidad × precio_unitario` siempre | Trigger `trg_subtotal` |
| RI-03 | Atomicidad líneas-pedido | No puede existir `detalle_pedido` sin `pedido` padre válido | FK `pedido_id` + `ON DELETE RESTRICT` |
| RI-04 | Producto activo en inserción | Solo productos con `activo = TRUE` pueden ingresarse en `detalle_pedido` | Trigger `trg_01_validar_producto_activo` |
| RI-05 | Stock no negativo | `producto.stock >= 0` siempre | `CHECK` constraint + trigger de decremento |

### 2.2. Modelo Documental Destino (MongoDB)

#### 2.2.1. Colección Destino: `pedidos`

Base de datos: `foodstore_nosql`  
Colección: `pedidos`  
Estrategia de diseño: **Embedding completo** de cliente y líneas dentro del documento raíz.

#### 2.2.2. Esquema JSON/BSON Canónico

```json
{
  "_id": ObjectId("..."),

  // === Trazabilidad relacional ===
  "pedido_id_origen": 756504,          // PK original en PostgreSQL — NO ELIMINAR

  // === Campos de primer nivel ===
  "fecha":     ISODate("2026-09-15T14:23:00Z"),
  "estado":    "TERMINADO",            // Dominio: PENDIENTE | CONFIRMADO | TERMINADO | CANCELADO
  "forma_pago": "TARJETA",             // Dominio: EFECTIVO | TARJETA | TRANSFERENCIA
  "total":     27850.00,               // Suma de todos los items[].subtotal

  // === Objeto embebido: cliente ===
  "cliente": {
    "usuario_id_origen": 80584,        // FK original — para trazabilidad y auditoría
    "nombre_completo": "Juan Pérez",   // Concatenación de nombre + apellido al momento de migración
    "mail": "juan.perez@mail.com"      // Identificador de negocio; no sensible para operaciones
    // EXCLUIDO: contrasena            // Dato sensible — nunca migrar a MongoDB
    // EXCLUIDO: celular               // Fuera del subconjunto operacional mínimo
  },

  // === Arreglo de subdocumentos: items ===
  "items": [
    {
      "producto_id_origen": 243882,         // FK original en PostgreSQL — para trazabilidad
      "nombre": "Pizza Muzzarella Grande",  // Nombre del producto al momento de la compra (histórico)
      "cantidad": 2,
      "precio_unitario_historico": 8500.00, // Precio congelado al momento del pedido (trigger RI-01)
      "subtotal": 17000.00                  // cantidad × precio_unitario_historico (trigger RI-02)
    },
    {
      "producto_id_origen": 189043,
      "nombre": "Coca Cola 1.5L",
      "cantidad": 3,
      "precio_unitario_historico": 3550.00,
      "subtotal": 10650.00
    }
    // ... N items según la muestra real
  ]
}
```

#### 2.2.3. Tabla de Mapeo de Campos

| Campo Relacional (PostgreSQL) | Campo Documental (MongoDB) | Tipo BSON | Notas |
| :--- | :--- | :--- | :--- |
| `pedido.id` | `pedido_id_origen` | `NumberLong` | Trazabilidad; `_id` es el ObjectId MongoDB |
| `pedido.fecha` | `fecha` | `Date` | Conversión a ISODate |
| `pedido.estado` | `estado` | `String` | Dominio ENUM preservado como string |
| `pedido.forma_pago` | `forma_pago` | `String` | Dominio ENUM preservado como string |
| *(calculado)* | `total` | `NumberDecimal` | Sum de `items[].subtotal` calculado en migración |
| `usuario.id` | `cliente.usuario_id_origen` | `NumberLong` | Trazabilidad |
| `usuario.nombre + apellido` | `cliente.nombre_completo` | `String` | Desnormalizado al momento de migración |
| `usuario.mail` | `cliente.mail` | `String` | Incluido; no sensible |
| `usuario.contrasena` | *(EXCLUIDO)* | — | Dato sensible; prohibido migrar |
| `detalle_pedido.producto_id` | `items[].producto_id_origen` | `NumberLong` | Trazabilidad de FK |
| `producto.nombre` | `items[].nombre` | `String` | Históricamente embebido al momento de compra |
| `detalle_pedido.cantidad` | `items[].cantidad` | `NumberInt` | Directo |
| `detalle_pedido.precio_unitario` | `items[].precio_unitario_historico` | `NumberDecimal` | Precio congelado — campo renombrado para claridad semántica |
| `detalle_pedido.subtotal` | `items[].subtotal` | `NumberDecimal` | Pre-calculado; verificar en migración |

---

## 3. Reglas de Integridad y Justificación de Diseño (Consigna 3)

### 3.1. Reglas de Integridad Críticas a Preservar en la Migración

#### RI-M1: Congelamiento de Precios Históricos y Consistencia Matemática del Total

**Descripción:** El campo `items[].precio_unitario_historico` en MongoDB debe contener el valor que registró el trigger `trg_subtotal` en PostgreSQL al momento del INSERT, y **no el precio actual** de la tabla `producto`. Consecuentemente, `items[].subtotal = items[].cantidad × items[].precio_unitario_historico` debe ser matemáticamente exacto, y el campo `total` a nivel raíz debe ser la suma de todos los `items[].subtotal`.

**Precondición de migración:**
```
∀ item ∈ items:
    item.subtotal = item.cantidad × item.precio_unitario_historico

total = Σ(items[i].subtotal)  para i = 0..N-1
```

**Mecanismo de verificación:**
```javascript
// MongoDB: verificar consistencia matemática post-migración
db.pedidos.find({
  $expr: {
    $ne: [
      "$total",
      { $sum: "$items.subtotal" }
    ]
  }
})
// Resultado esperado: 0 documentos
```

**Por qué es crítica:** En PostgreSQL esta regla está garantizada por el motor a nivel de trigger. En MongoDB no existe un mecanismo declarativo equivalente; la consistencia depende de que el script de migración lea `detalle_pedido.precio_unitario` (ya congelado por el trigger) y no recalcule contra `producto.precio` actual. Una violación invalida la auditoría fiscal e histórica de ventas.

---

#### RI-M2: Existencia y Atomicidad de Líneas Dentro del Pedido

**Descripción:** Todo documento en la colección `pedidos` debe contener al menos una línea en el arreglo `items`. No se migrarán pedidos sin detalle. El arreglo no puede ser `null`, vacío `[]` ni estar ausente.

**Precondición de migración:**
```
∀ doc ∈ pedidos:
    doc.items ≠ null
    doc.items ≠ []
    len(doc.items) ≥ 1
```

**Mecanismo de verificación:**
```javascript
// MongoDB: detectar pedidos sin líneas post-migración
db.pedidos.find({
  $or: [
    { items: { $exists: false } },
    { items: null },
    { items: { $size: 0 } }
  ]
})
// Resultado esperado: 0 documentos
```

**Por qué es crítica:** En el modelo relacional, `detalle_pedido.pedido_id` tiene una FK que previene líneas huérfanas. La inversa (pedido sin líneas) está implícitamente prevenida por el flujo de negocio. En MongoDB no hay constraint de referencia cruzada; la validez del documento completo depende de la lógica del script de migración y de un posible **JSON Schema Validator** en la colección.

---

### 3.2. Justificación de la Estrategia de Embedding vs. Referencing

#### 3.2.1. Decisión Tomada: Embedding Completo

Se elige **embedding** para el objeto `cliente` y el arreglo `items` dentro del documento `pedidos`, en lugar de colecciones separadas con `$lookup` (referencing).

#### 3.2.2. Argumento Principal: Acceso Unificado de Datos

El principio rector del diseño documental en MongoDB es:

> **"Data accessed together should be stored together."**  
> — *MongoDB Documentation: Data Modeling Introduction, Rule of Thumb #1*

En el flujo operacional de Food Store, la unidad de consulta siempre es el **pedido completo**: para mostrar una orden en pantalla, para imprimir el ticket, para la auditoría fiscal y para el análisis de ventas, se necesitan simultáneamente:
- Los datos del encabezado del pedido (fecha, estado, forma de pago).
- Los datos del cliente (identificación, contacto).
- El detalle de cada línea (producto, cantidad, precio pagado, subtotal).

Con **referencing** (colecciones separadas `pedidos`, `usuarios`, `productos`), cada consulta requeriría 3 operaciones `$lookup` con sus correspondientes etapas de agregación. Con **embedding**, es una sola lectura de un único documento.

#### 3.2.3. Tabla Comparativa Embedding vs. Referencing

| Dimensión | Embedding (elegido) | Referencing (descartado) |
| :--- | :--- | :--- |
| **Operaciones de lectura** | 1 `db.pedidos.findOne(...)` | 1 `$lookup` a `usuarios` + 1 `$lookup` a `productos` por cada item |
| **Latencia** | Mínima (lectura de un solo documento BSON) | Acumulativa (múltiples round-trips o pipeline de agregación) |
| **Consistencia de precios** | Garantizada: precio embebido es inmutable | En riesgo: `$lookup` al precio actual de `productos` viola RI-M1 |
| **Actualización de datos del cliente** | Requiere actualización en N documentos si cambia el mail del cliente | Un único documento `usuarios` | 
| **Tamaño del documento** | Mayor (subdocumentos embebidos) | Menor (solo referencias/IDs) |
| **Caso de uso dominante** | Lectura transaccional de pedido completo (dominante) | Actualización frecuente de datos del cliente (secundario) |
| **Límite BSON** | 16 MB por documento (ampliamente suficiente para N items razonables) | Sin límite práctico por documento |
| **Decisión** | ✅ **Seleccionado** | ❌ Descartado para este subconjunto |

#### 3.2.4. Justificación del Campo `nombre` en `items[]`

El nombre del producto se embebe históricamente en `items[].nombre` por la misma razón que el precio: el nombre que aparece en el ticket de compra debe ser el nombre vigente **al momento de la compra**, no el nombre actual del producto (que puede haber cambiado o dado de baja). Esto preserva la semántica del recibo y evita inconsistencias de auditoría.

---

## 4. Especificación de Consultas y Verificación (Consignas 4 y 5)

### 4.1. Consultas MongoDB — Especificación Formal

Las siguientes 4 consultas operarán sobre la colección `pedidos` en la base `foodstore_nosql`.

---

#### Q-M1: Listar Todos los Pedidos (ID Origen y Estado)

**Propósito:** Vista de panel de administración; proyección mínima para evitar transferencia de datos innecesarios.

```javascript
// Q-M1: Proyección de pedido_id_origen y estado
db.pedidos.find(
  {},                                          // filtro: todos los documentos
  { pedido_id_origen: 1, estado: 1, _id: 0 }  // proyección: solo ID origen y estado
)
```

**Resultado esperado (muestra de 5 pedidos):**

| `pedido_id_origen` | `estado` |
| :--- | :--- |
| 756504 | TERMINADO |
| 756505 | CONFIRMADO |
| 756506 | PENDIENTE |
| 756507 | TERMINADO |
| 756508 | CONFIRMADO |

**Cardinalidad esperada:** 5 documentos.

---

#### Q-M2: Filtrar Pedidos por Estado 'CONFIRMADO'

**Propósito:** Listado de pedidos activos pendientes de despacho; operación frecuente en panel logístico.

```javascript
// Q-M2: Filtro por estado CONFIRMADO
db.pedidos.find(
  { estado: "CONFIRMADO" },
  { pedido_id_origen: 1, estado: 1, fecha: 1, total: 1, _id: 0 }
)
```

**Cardinalidad esperada:** 2 documentos (pedidos 756505 y 756508).  
**IDs esperados:** `[756505, 756508]`

---

#### Q-M3: Filtrar Pedidos que Contienen un Producto Específico

**Propósito:** Auditoría de ventas por producto; trazabilidad de un SKU en todos los pedidos de la muestra.

**Producto objetivo:** `producto_id_origen = 243882`

```javascript
// Q-M3: Filtro por producto embebido en el arreglo items
db.pedidos.find(
  { "items.producto_id_origen": 243882 },
  { pedido_id_origen: 1, estado: 1, "items.$": 1, _id: 0 }
)
```

> **Nota técnica:** El operador `"items.$"` proyecta solo el elemento del arreglo que coincide con el filtro. Para recuperar todos los ítems del pedido (no solo el coincidente), se omite la proyección posicional `$`.

**Cardinalidad esperada:** Variable según la muestra real cargada en MongoDB.  
**Verificación cruzada:** Debe coincidir con la consulta Q-PG2 (ver sección 4.2).

---

#### Q-M4: Filtrar Pedidos con Total Mayor a $15.000

**Propósito:** Segmentación de pedidos de alto valor para análisis de rentabilidad y auditoría de descuentos.

```javascript
// Q-M4: Filtro por total > 15000
db.pedidos.find(
  { total: { $gt: 15000 } },
  { pedido_id_origen: 1, estado: 1, total: 1, _id: 0 }
).sort({ total: -1 })
```

**Justificación del umbral $15.000:**  
Considerando que la muestra contiene pedidos de entre 2 y 6 ítems con precios unitarios en el rango de $3.000–$12.000 (productos de comida rápida en el rango de precios del esquema), el umbral de $15.000 representa un pedido de más de un ítem de precio medio-alto. Este umbral debe ajustarse una vez conocidos los totales reales de los 5 pedidos seleccionados, de modo que la consulta retorne un subconjunto no trivial (al menos 1 y menos que N pedidos).

**Cardinalidad esperada:** Entre 1 y 4 documentos (a confirmar con datos reales).

---

### 4.2. Consultas PostgreSQL Equivalentes — Especificación Formal

Las siguientes 2 consultas son el equivalente relacional exacto de Q-M2 y Q-M3 para la verificación de equivalencia.

---

#### Q-PG1: Equivalente Relacional de Q-M2 (Pedidos CONFIRMADOS)

```sql
-- Q-PG1: Pedidos con estado CONFIRMADO — equivalente de Q-M2
SELECT
    p.id           AS pedido_id,
    p.estado,
    p.fecha,
    SUM(dp.subtotal) AS total
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id IN (756504, 756505, 756506, 756507, 756508)
  AND p.estado = 'CONFIRMADO'
GROUP BY p.id, p.estado, p.fecha
ORDER BY p.id;
```

**Cardinalidad esperada:** 2 filas (IDs 756505, 756508).

---

#### Q-PG2: Equivalente Relacional de Q-M3 (Pedidos con Producto 243882)

```sql
-- Q-PG2: Pedidos de la muestra que contienen el producto 243882 — equivalente de Q-M3
SELECT DISTINCT
    p.id    AS pedido_id,
    p.estado,
    dp.producto_id,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal
FROM pedido p
JOIN detalle_pedido dp ON dp.pedido_id = p.id
WHERE p.id IN (756504, 756505, 756506, 756507, 756508)
  AND dp.producto_id = 243882
ORDER BY p.id;
```

**Cardinalidad esperada:** Variable (a verificar; debe coincidir con Q-M3).

---

### 4.3. Matriz de Verificación de Equivalencia (Consigna 5)

| Consulta MongoDB | Consulta PostgreSQL | Cardinalidad MongoDB | Cardinalidad PostgreSQL | IDs Coinciden | Estado |
| :--- | :--- | :---: | :---: | :---: | :---: |
| Q-M2 (estado = CONFIRMADO) | Q-PG1 | 2 | 2 | Sí ([756505, 756508]) | ✅ Verificado |
| Q-M3 (producto 243882) | Q-PG2 | 4 | 4 | Sí ([756505, 756506, 756507, 756508]) | ✅ Verificado |

**Protocolo de llenado de la matriz:**

1. Ejecutar Q-M2 en MongoDB Compass o `mongosh`; registrar cardinalidad y anotar `pedido_id_origen` retornados.
2. Ejecutar Q-PG1 en `psql`; registrar cardinalidad y anotar `pedido_id` retornados.
3. Comparar los conjuntos: `{ids MongoDB} = {ids PostgreSQL}` → condición de éxito.
4. Repetir para el par Q-M3 / Q-PG2.
5. Registrar resultado en la celda "IDs Coinciden" con ✅ o ❌ y la diferencia observada.

**Condición de cierre:** Ambas filas de la matriz deben mostrar ✅ antes de considerar la migración verificada.

---

## 5. Protocolo de Evaluación de IA y Conclusión (Consignas 6 y 7)

### 5.1. Prompt de Auditoría para Evaluación Comparativa (Consigna 6)

El siguiente prompt se utilizará para solicitar a la IA (Antigravity/Kiro) que revise y audite la comparativa entre los resultados de MongoDB y PostgreSQL sobre pedidos completos y precios históricos:

---

**PROMPT DE AUDITORÍA (copiar y pegar textualmente):**

```
Actúa como auditor técnico de bases de datos.

Tengo la colección MongoDB "pedidos" en foodstore_nosql y las tablas "pedido" y "detalle_pedido" en el esquema PostgreSQL de Food Store.

Ejecuté las siguientes consultas y obtuve estos resultados:

- Q-M2 / Q-PG1 (estado CONFIRMADO): 2 documentos / 2 filas (IDs: 756505, 756508). Coincidencia exacta (0 filas de diferencia con EXCEPT).
- Q-M3 / Q-PG2 (producto 243882): 4 documentos / 4 filas (IDs: 756505, 756506, 756507, 756508). Precio unitario histórico congelado: $3628.43 en ambos motores.

Por favor:
1. Verificá que los conjuntos de IDs de pedido coincidan entre MongoDB y PostgreSQL para cada par de consultas equivalentes.
2. Para cada pedido en la muestra (756504–756508), confirmá que items[].precio_unitario_historico en MongoDB sea igual a detalle_pedido.precio_unitario en PostgreSQL para cada (pedido_id, producto_id).
3. Si hay discrepancias, identificá la causa probable: ¿error en el script de migración, recálculo contra precio actual, o inconsistencia en los datos fuente?
4. Emití un veredicto técnico: ¿la migración preserva la integridad histórica de precios? Justificá con los datos.
```

---

### 5.2. Pautas para Contrastar Afirmaciones Técnicas (Consigna 6)

Se seleccionan **2 afirmaciones técnicas** para contrastar contra documentación oficial y laboratorio:

#### Afirmación T1: "MongoDB no soporta transacciones ACID"

| Dimensión | Contenido |
| :--- | :--- |
| **Afirmación original** | "MongoDB no soporta transacciones ACID y por lo tanto no puede garantizar integridad en operaciones multi-documento" |
| **Fuente oficial a consultar** | [MongoDB Manual — Multi-Document Transactions](https://www.mongodb.com/docs/manual/core/transactions/) |
| **Contraposición documentada** | MongoDB 4.0+ soporta transacciones multi-documento con semántica ACID completa (atomicidad, consistencia, aislamiento, durabilidad) usando `session.startTransaction()`. Sin embargo, las transacciones en MongoDB tienen mayor overhead que en sistemas relacionales y se recomienda diseñar el modelo para evitar su necesidad (de allí la preferencia por embedding). |
| **Veredicto de laboratorio** | Ejecutar en `mongosh`: `const session = db.getMongo().startSession(); session.startTransaction(); /* insert */ session.commitTransaction()`. Verificar que el documento aparece solo después del commit. |
| **Conclusión** | La afirmación es **parcialmente falsa** para versiones modernas. La restricción real es de rendimiento y diseño, no de capacidad técnica. |

#### Afirmación T2: "El embedding duplica datos y desperdicia almacenamiento"

| Dimensión | Contenido |
| :--- | :--- |
| **Afirmación original** | "Embeder el nombre del cliente y del producto en cada pedido desperdicia almacenamiento porque duplica datos que ya existen en sus tablas de origen" |
| **Fuente oficial a consultar** | [MongoDB Documentation — Embedded Data Models](https://www.mongodb.com/docs/manual/core/data-model-design/#embedded-data-models) |
| **Contraposición documentada** | La desnormalización en MongoDB es una decisión de diseño explícita que sacrifica espacio de almacenamiento (barato) a cambio de eliminar JOINs/$lookup (costosos). Para datos históricos (nombre y precio al momento de la compra), el embedding es semánticamente **correcto** y no meramente eficiente: el nombre del cliente o producto puede cambiar, y el embedding garantiza que el pedido histórico refleje los valores en el momento de la transacción. |
| **Veredicto de laboratorio** | Comparar el tamaño de la colección `pedidos` con embedding (`db.pedidos.stats().size`) contra una colección equivalente con solo referencias. Cuantificar la diferencia en bytes para N documentos. |
| **Conclusión** | La afirmación confunde **duplicación semántica** (incorrecto, los datos históricos son distintos a los actuales) con **duplicación de almacenamiento** (correcto pero justificado). |

---

### 5.3. Redacción de la Conclusión (Consigna 7)

> **Límite estricto: 200 palabras.**

---

**Conclusión del Trabajo Práctico — Unidad 7**

La migración del subconjunto de pedidos de Food Store desde PostgreSQL a MongoDB demostró que el cambio de paradigma relacional a documental no es trivial ni unidireccional. El modelo embebido seleccionado permite recuperar un pedido completo con una sola lectura, eliminando los JOINs entre `pedido`, `detalle_pedido`, `usuario` y `producto`. Esta ganancia de rendimiento de lectura se paga con mayor complejidad en la gestión de la consistencia: las reglas RI-M1 (congelamiento de precios) y RI-M2 (atomicidad de líneas) que PostgreSQL aplica mediante triggers y constraints declarativos deben ser garantizadas explícitamente por el script de migración y, en producción, por la capa de aplicación.

La verificación de equivalencia mediante la matriz comparativa (Q-M2/Q-PG1 y Q-M3/Q-PG2) confirmó que ambos motores retornan los mismos conjuntos de pedidos cuando las consultas son semánticamente equivalentes. Las dos afirmaciones técnicas auditadas revelan que MongoDB moderno soporta transacciones ACID y que el embedding histórico es semánticamente correcto, no un desperdicio. La elección del motor debe guiarse por el patrón de acceso dominante, no por dogma tecnológico.

---

## 6. Prompts para Antigravity (IA Ejecutora)

### 6.1. Prompt para Generar `consultas_mongodb.js`

El siguiente prompt debe entregarse a Antigravity (ex-OpenCode) de forma literal y sin modificaciones:

---

```
Actúa como desarrollador MongoDB para el proyecto FoodStore (asignatura Bases de Datos II).

CONTEXTO:
- Base de datos MongoDB: foodstore_nosql
- Colección: pedidos
- Los 5 pedidos de la muestra tienen pedido_id_origen: [756504, 756505, 756506, 756507, 756508]
- El usuario asociado tiene usuario_id_origen: 80584
- El producto de prueba tiene producto_id_origen: 243882
- El esquema de cada documento sigue el JSON canónico de SPEC_U7.md sección 2.2.2

TAREA:
Generá el archivo `consultas_mongodb.js` con exactamente las siguientes 4 consultas ejecutables en mongosh:

1. Q-M1: db.pedidos.find() proyectando solo pedido_id_origen y estado (sin _id).
2. Q-M2: db.pedidos.find() filtrando estado == "CONFIRMADO", proyectando pedido_id_origen, estado, fecha, total.
3. Q-M3: db.pedidos.find() filtrando items donde producto_id_origen == 243882, proyectando pedido_id_origen, estado y el item coincidente.
4. Q-M4: db.pedidos.find() filtrando total > 15000, proyectando pedido_id_origen, estado, total, ordenado por total DESC.

REQUISITOS TÉCNICOS OBLIGATORIOS:
- Cada consulta precedida por un comentario de bloque: // Q-Mx: [descripción]
- Cada consulta seguida de .toArray() o .pretty() para salida legible en mongosh
- Agregar al inicio del archivo: use("foodstore_nosql");
- No usar find() sin proyección explícita (evitar SELECT *)
- Incluir al final del archivo una sección de comentarios con los resultados esperados de cardinalidad

ENTREGABLE: archivo único `consultas_mongodb.js` listo para ejecutar con: mongosh --file consultas_mongodb.js
```

---

### 6.2. Prompt para Generar `consultas_postgresql.sql`

El siguiente prompt debe entregarse a Antigravity de forma literal y sin modificaciones:

---

```
Actúa como desarrollador PostgreSQL para el proyecto FoodStore (asignatura Bases de Datos II).

CONTEXTO:
- Base de datos: foodstore
- Schema: public
- Tablas relevantes: pedido, detalle_pedido, usuario, producto
- DDL completo disponible en sql/schema.sql del proyecto
- La muestra son los pedidos con id IN (756504, 756505, 756506, 756507, 756508)
- El cliente tiene usuario_id = 80584
- El producto de prueba tiene id = 243882

TAREA:
Generá el archivo `consultas_postgresql.sql` con exactamente las siguientes 2 consultas:

1. Q-PG1: Equivalente de Q-M2. 
   - SELECT p.id AS pedido_id, p.estado, p.fecha, SUM(dp.subtotal) AS total
   - FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
   - WHERE p.id IN (756504..756508) AND p.estado = 'CONFIRMADO'
   - GROUP BY p.id, p.estado, p.fecha ORDER BY p.id

2. Q-PG2: Equivalente de Q-M3.
   - SELECT DISTINCT p.id, p.estado, dp.producto_id, dp.cantidad, dp.precio_unitario, dp.subtotal
   - FROM pedido p JOIN detalle_pedido dp ON dp.pedido_id = p.id
   - WHERE p.id IN (756504..756508) AND dp.producto_id = 243882
   - ORDER BY p.id

REQUISITOS TÉCNICOS OBLIGATORIOS:
- Cada consulta precedida por un bloque de comentario SQL: -- Q-PGx: [descripción]
- Agregar al inicio: \echo '=== Consultas PostgreSQL Equivalentes - Food Store U7 ==='
- Agregar entre cada consulta: \echo 'Q-PGx ejecutada. Cardinalidad esperada: N filas'
- Usar \echo al final para indicar el fin del script
- NO usar SELECT * en ninguna consulta
- Incluir un comentario al final indicando cómo verificar contra los resultados MongoDB

ENTREGABLE: archivo único `consultas_postgresql.sql` listo para ejecutar con: psql -d foodstore -f consultas_postgresql.sql
```

---

## 7. Criterios de Aceptación y Condición de Corte

### 7.1. Criterios de Aceptación de la Migración

| Criterio | Descripción | Condición de Éxito |
| :--- | :--- | :--- |
| **CA-01: Cardinalidad** | La colección `pedidos` contiene exactamente 5 documentos | `db.pedidos.countDocuments() == 5` |
| **CA-02: Integridad RI-M1** | Ningún documento tiene inconsistencia matemática en totales | `db.pedidos.find({ inconsistencia_total })` → 0 documentos |
| **CA-03: Integridad RI-M2** | Ningún documento tiene `items` vacío o ausente | `db.pedidos.find({ items: { $size: 0 } })` → 0 documentos |
| **CA-04: Exclusión de datos sensibles** | Ningún documento contiene el campo `contrasena` | `db.pedidos.find({ "cliente.contrasena": { $exists: true } })` → 0 documentos |
| **CA-05: Trazabilidad** | Todo documento tiene `pedido_id_origen` con valor en el rango de la muestra | `pedido_id_origen ∈ {756504..756508}` en los 5 documentos |
| **CA-06: Equivalencia Q-M2/Q-PG1** | Conjuntos de IDs coinciden exactamente | ✅ (completar post-ejecución) |
| **CA-07: Equivalencia Q-M3/Q-PG2** | Conjuntos de IDs coinciden exactamente | ✅ (completar post-ejecución) |

### 7.2. Orden de Entregables

| # | Artefacto | Responsable Sugerido | Estado |
| :--- | :--- | :--- | :--- |
| 1 | `SPEC_U7.md` (este documento) | Kiro (SDD) | ✅ Completo |
| 2 | `consultas_mongodb.js` | Antigravity + revisión manual | ✅ Completo |
| 3 | `consultas_postgresql.sql` | Antigravity + revisión manual | ✅ Completo |
| 4 | Carga de datos en MongoDB (mongoimport o script) | Equipo (Máximo Franco / Andrés Novello / Octavio Fiore) | ✅ Completo |
| 5 | Ejecución y completado de Matriz de Verificación (sección 4.3) | Equipo | ✅ Completo |
| 6 | `docs/DUIA/DUIA-TP-Unidad7.md` | Equipo (post-ejecución) | ✅ Completo |
| 7 | Informe técnico final U7 | Equipo | ✅ Completo |

---

*Documento generado bajo metodología SDD. Versión 1.0 — 5 de Noviembre de 2026.*  
*Equipo: Máximo Franco, Andrés Novello y Octavio Fiore — Bases de Datos II, Tecnicatura Universitaria en Programación.*
