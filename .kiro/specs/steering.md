# Contexto del Proyecto: Food Store - Sistema de Gestión de Pedidos

## 1. Visión General del Dominio
Food Store es una base de datos transaccional (OLTP) diseñada en PostgreSQL para gestionar el catálogo, los clientes y las ventas de un local de comidas. El diseño prioriza la integridad referencial, la trazabilidad histórica de los precios y la preservación de datos mediante borrado lógico.

## 2. Reglas de Negocio Estrictas (Core Business Rules)
El sistema debe garantizar mediante restricciones (Constraints, Triggers o Funciones) las siguientes reglas dictadas por el dominio:
* **R1 (Categorización):** Todo producto pertenece exactamente a una categoría. Una categoría puede no tener productos (ej. recién creada).
* **R2 (Propiedad del pedido):** Todo pedido pertenece obligatoriamente a un único usuario (cliente) registrado.
* **R3 (Relación Pedido-Producto):** Relación de muchos a muchos resuelta a través de la tabla `detalle_pedido`.
* **R4 (Inmutabilidad Histórica):** El precio de un producto en un pedido facturado no debe alterarse si el precio de lista actual cambia. Se garantiza copiando el `precio` actual al `precio_unitario` de `detalle_pedido` en el momento de la compra.
* **R5 (Valores Positivos):** Un producto no puede tener stock negativo ni precio negativo (`CHECK >= 0`). La cantidad en un detalle de pedido debe ser estrictamente mayor a cero (`CHECK > 0`).
* **R6 (Identidad del Cliente):** El correo electrónico (`mail`) identifica de forma única a cada usuario (`UNIQUE`).
* **R7 (Retención Histórica y Borrado Lógico):** No se eliminan físicamente productos ni categorías. Se utiliza el atributo booleano `activa` / `activo` (`DEFAULT TRUE`). Las claves foráneas utilizan `ON DELETE RESTRICT` para evitar la pérdida de historial de pedidos referenciados.

## 3. Estándares de Arquitectura y Nomenclatura SQL
* **Tablas:** Formato `snake_case`, minúsculas, sustantivo singular (ej: `usuario`, `pedido`, `detalle_pedido`).
* **Claves Primarias (PK):** Nombradas estrictamente como `id`. Definidas como `BIGINT GENERATED ALWAYS AS IDENTITY`.
* **Claves Foráneas (FK):** Formato `[tabla_referenciada]_id` (ej: `categoria_id`, `usuario_id`).
* **Reglas de Integridad:** El motor se encarga del cálculo de derivados. El campo `subtotal` en `detalle_pedido` es de sólo lectura para la aplicación; lo completa y mantiene un trigger en base a la cantidad y el precio unitario.

## 4. Dominios Cerrados (Tipos ENUM)
* **forma_pago:** `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`.
* **estado_pedido:** `PENDIENTE`, `CONFIRMADO`, `TERMINADO`, `CANCELADO`.

## 5. Directivas Operativas para Agentes de IA (Kiro / OpenCode)
* **Scripts de DML/DDL:** Todo script generado que modifique datos o esquemas DEBE estar envuelto en un bloque de transacción explícito (`BEGIN; ... COMMIT/ROLLBACK;`).
* **Manejo de Nulos:** Al generar consultas (especialmente con `NOT IN`), se debe tener precaución y manejar explícitamente los valores `NULL` para evitar resultados vacíos inesperados.
* **Prohibición Destructiva:** Jamás se deben proponer scripts que utilicen `DROP CASCADE` sobre el esquema de producción o `DELETE` sin una cláusula `WHERE` explícita y validada.