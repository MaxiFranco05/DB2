# Requirements Document

## Introduction

Este documento especifica los requisitos funcionales y de seguridad del modelo de roles y permisos para la base de datos `foodstore` (`food_store` / `food_store_copia`), consensuado por el equipo (Máximo, Andrés y Octavio). El sistema aplica el principio de mínimo privilegio: cada rol recibe únicamente los permisos imprescindibles para cumplir su función.

El esquema `public` de la base `foodstore` contiene las tablas operativas `categoria`, `producto`, `pedido`, `detalle_pedido` y `usuario` (además de la tabla de soporte `auditoria` y vistas agregadas). El modelo distingue dos capas: roles de grupo (sin login) que encapsulan conjuntos cohesivos de permisos, y roles de login que heredan uno o más roles de grupo y representan identidades de conexión reales.

### Síntesis de justificación de mínimo privilegio por rol (en una oración)

- **`rol_app_lectura` (grupo):** Habilita únicamente `SELECT` sobre las tablas operativas (y tablas futuras mediante `ALTER DEFAULT PRIVILEGES`) porque la capa de presentación necesita consultar el catálogo y el estado de los pedidos sin capacidad de alterar ni eliminar ningún registro.
- **`rol_app_escritura` (grupo):** Habilita exclusivamente `INSERT` en `pedido`/`detalle_pedido` (y `auditoria`), `UPDATE` acotado a `producto(stock)` y `pedido(estado)`, `DELETE` en `detalle_pedido` y `EXECUTE` sobre `fn_autenticar`/`fn_resetear_password` porque la operatoria transaccional requiere registrar ventas y actualizar inventario sin poder modificar precios, catálogos ni datos directos de `usuario`.
- **`rol_soporte` (grupo):** Habilita únicamente `SELECT` sobre las columnas `id` y `mail` de `usuario` y lectura sobre `pedido` y `detalle_pedido` porque la mesa de ayuda necesita vincular el reclamo de un cliente con sus órdenes sin exponerse a contraseñas, teléfonos ni datos filiatorios completos.
- **`rol_reportes` (grupo):** Habilita exclusivamente `SELECT` sobre vistas agregadas de negocio (`v_ventas_por_categoria`) porque el análisis estadístico requiere métricas consolidadas y nunca acceso directo a filas transaccionales crudas ni datos personales.
- **`app_web` (login):** Habilita la conexión (`CONNECT`) del backend heredando `rol_app_lectura` y `rol_app_escritura` sin atributos administrativos (`NOSUPERUSER NOCREATEROLE NOCREATEDB`) porque la aplicación necesita operar lecturas y escrituras del giro comercial sin privilegios de gestión sobre el motor ni sobre otros roles.
- **`admin_datos` (login):** Habilita el control total (`ALL PRIVILEGES` sobre tablas, secuencias y funciones del esquema `public` más `CREATEROLE` y `ALTER DEFAULT PRIVILEGES`) sin llegar a `SUPERUSER` porque el administrador de datos necesita ejecutar migraciones, gestionar roles y auditar el esquema manteniendo acotado el riesgo a nivel de instancia.

## Glossary

- **PostgreSQL**: Sistema gestor de bases de datos relacional objeto usado como motor del proyecto.
- **Sistema**: El motor PostgreSQL configurado para la base de datos `foodstore`.
- **Rol de grupo**: Rol de PostgreSQL sin atributo `LOGIN` que encapsula un conjunto de permisos. No puede autenticarse directamente.
- **Rol de login**: Rol de PostgreSQL con atributo `LOGIN` y contraseña. Representa una identidad de conexión real.
- **Esquema `public`**: Espacio de nombres de PostgreSQL que contiene las tablas operativas de `foodstore`.
- **Mínimo privilegio**: Principio de seguridad por el cual un rol recibe únicamente los permisos imprescindibles para su función.
- **Permiso a nivel de columna**: Privilegio de PostgreSQL que restringe el `SELECT` a columnas específicas dentro de una tabla.
- **`rol_app_lectura`**: Rol de grupo que otorga lectura sobre todas las tablas operativas del esquema `public`.
- **`rol_app_escritura`**: Rol de grupo que otorga escritura operativa (INSERT, UPDATE, DELETE) sobre las tablas de transacción.
- **`rol_soporte`**: Rol de grupo que otorga lectura a nivel de columna sobre datos de contacto del usuario y sus pedidos.
- **`rol_reportes`**: Rol de grupo que otorga lectura sobre vistas agregadas de negocio.
- **`app_web`**: Rol de login que hereda `rol_app_lectura` y `rol_app_escritura`. Es la identidad de conexión del backend.
- **`admin_datos`**: Rol de login con acceso completo al esquema `public`. Es la identidad de administración y auditoría.
- **Vista agregada**: Objeto de base de datos que expone métricas consolidadas sin revelar filas individuales de datos sensibles.
- **Columna sensible**: Columna que contiene datos personales de alta exposición: `contrasena`, `celular`, `nombre`, `apellido`.

---

## Requirements

### Requirement 1 — Rol de lectura operativa (`rol_app_lectura`)

**User Story:** As a backend developer, I want a read-only group role over all operational tables, so that the presentation layer can display menus, catalogs and order statuses without any risk of accidental data modification.

#### Acceptance Criteria

1. THE Sistema SHALL create `rol_app_lectura` as a group role without the `LOGIN` attribute and without an assigned password.
2. THE Sistema SHALL grant `USAGE` on schema `public` to `rol_app_lectura`.
3. THE Sistema SHALL grant `SELECT` on tables `categoria`, `producto`, `pedido`, `detalle_pedido`, and `usuario` to `rol_app_lectura`.
4. IF `rol_app_lectura` attempts to execute `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE` on any operational table, THEN THE Sistema SHALL deny the operation.
5. IF `rol_app_lectura` attempts to execute any DDL statement (CREATE, ALTER, DROP), THEN THE Sistema SHALL deny the operation.

---

### Requirement 2 — Rol de escritura operativa (`rol_app_escritura`)

**User Story:** As a backend developer, I want a write group role scoped to transactional tables and specific columns, so that the application can register orders and update inventory without broader write access than necessary.

#### Acceptance Criteria

1. THE Sistema SHALL create `rol_app_escritura` as a group role without the `LOGIN` attribute and without an assigned password.
2. THE Sistema SHALL grant `USAGE` on schema `public` to `rol_app_escritura`.
3. THE Sistema SHALL grant `INSERT` on tables `pedido` and `detalle_pedido` to `rol_app_escritura`.
4. THE Sistema SHALL grant `UPDATE` on column `stock` of table `producto` to `rol_app_escritura`.
5. THE Sistema SHALL grant `UPDATE` on column `estado` of table `pedido` to `rol_app_escritura`.
6. THE Sistema SHALL grant `DELETE` on table `detalle_pedido` to `rol_app_escritura`.
7. THE Sistema SHALL grant `USAGE` and `SELECT` on the identity sequences of `pedido` and `detalle_pedido` to `rol_app_escritura`.
8. IF `rol_app_escritura` attempts to execute `TRUNCATE` on any table, THEN THE Sistema SHALL deny the operation.
9. IF `rol_app_escritura` attempts to execute any DDL statement, THEN THE Sistema SHALL deny the operation.
10. IF `rol_app_escritura` attempts to access any column of table `usuario`, THEN THE Sistema SHALL deny the operation.

---

### Requirement 3 — Rol de soporte al cliente (`rol_soporte`)

**User Story:** As a customer support agent, I want read access to a customer's email and their orders, so that I can assist clients without being exposed to sensitive personal data.

#### Acceptance Criteria

1. THE Sistema SHALL create `rol_soporte` as a group role without the `LOGIN` attribute and without an assigned password.
2. THE Sistema SHALL grant `USAGE` on schema `public` to `rol_soporte`.
3. THE Sistema SHALL grant `SELECT` on columns `id` and `mail` of table `usuario` to `rol_soporte`.
4. THE Sistema SHALL grant `SELECT` on all columns of tables `pedido` and `detalle_pedido` to `rol_soporte`.
5. IF `rol_soporte` attempts to read columns `nombre`, `apellido`, `celular`, or `contrasena` from table `usuario`, THEN THE Sistema SHALL deny the operation.
6. IF `rol_soporte` attempts to execute `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE` on any table, THEN THE Sistema SHALL deny the operation.
7. IF `rol_soporte` attempts to access table `categoria` or table `producto`, THEN THE Sistema SHALL deny the operation.

---

### Requirement 4 — Rol de reportes de negocio (`rol_reportes`)

**User Story:** As a business analyst, I want read access to aggregate business views, so that I can generate reports on sales and orders without accessing raw transactional rows or sensitive personal data.

#### Acceptance Criteria

1. THE Sistema SHALL create `rol_reportes` as a group role without the `LOGIN` attribute and without an assigned password.
2. THE Sistema SHALL grant `USAGE` on schema `public` to `rol_reportes`.
3. WHEN aggregate business views are created in the `public` schema, THE Sistema SHALL grant `SELECT` on each new view to `rol_reportes`.
4. IF `rol_reportes` attempts to access any operational table directly (`categoria`, `producto`, `pedido`, `detalle_pedido`, `usuario`), THEN THE Sistema SHALL deny the operation.
5. IF `rol_reportes` attempts to execute `INSERT`, `UPDATE`, `DELETE`, or `TRUNCATE`, THEN THE Sistema SHALL deny the operation.
6. THE Sistema SHALL ensure that every aggregate view accessible by `rol_reportes` does not expose columns `contrasena`, `celular`, `nombre`, or `apellido`; this constraint is enforced through manual design review before any `SELECT` grant is issued to `rol_reportes`, not through automated database-level prevention such as triggers or DDL checks.

---

### Requirement 5 — Rol de login de la aplicación web (`app_web`)

**User Story:** As a backend engineer, I want a login role for the web application that combines read and write group roles, so that the backend can connect to the database with precisely the permissions it needs and nothing more.

#### Acceptance Criteria

1. THE Sistema SHALL create `app_web` as a login role with a password stored exclusively in the `.env` file, never in source code.
2. THE Sistema SHALL grant `CONNECT` on database `foodstore` to `app_web`.
3. THE Sistema SHALL assign `app_web` as a member of `rol_app_lectura`.
4. THE Sistema SHALL assign `app_web` as a member of `rol_app_escritura`.
5. IF `app_web` is created, THEN THE Sistema SHALL ensure the role does not have the `SUPERUSER`, `CREATEROLE`, or `CREATEDB` attributes.
6. WHILE connected as `app_web`, THE Sistema SHALL enforce only the permissions inherited from `rol_app_lectura` and `rol_app_escritura`, with no additional privileges.

---

### Requirement 6 — Rol de login de administración (`admin_datos`)

**User Story:** As a database administrator, I want a login role with full privileges over the `public` schema, so that I can perform migrations, maintenance, and auditing operations in a controlled and traceable manner.

#### Acceptance Criteria

1. THE Sistema SHALL create `admin_datos` as a login role with a strong password stored exclusively in the `.env` file.
2. THE Sistema SHALL grant `CONNECT` on database `foodstore` to `admin_datos`.
3. THE Sistema SHALL grant `ALL PRIVILEGES` on all tables, sequences, and views in schema `public` to `admin_datos`.
4. THE Sistema SHALL grant `CREATEROLE` to `admin_datos` to allow role management.
5. IF `admin_datos` is created, THEN THE Sistema SHALL ensure the role does not have the `SUPERUSER` attribute.
6. THE Sistema SHALL ensure `admin_datos` is not used as the habitual connection identity of the application.

---

### Requirement 7 — Restricciones transversales del modelo de roles

**User Story:** As a database administrator, I want consistent baseline security constraints applied to all roles, so that the role model remains coherent and auditable across the entire `foodstore` database.

#### Acceptance Criteria

1. THE Sistema SHALL create every group role (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`) without the `LOGIN` attribute.
2. THE Sistema SHALL create every group role without an assigned password.
3. THE Sistema SHALL grant `USAGE` on schema `public` to every role that requires access to objects within it.
4. THE Sistema SHALL grant `CONNECT` on database `foodstore` exclusively to login roles `app_web` and `admin_datos`.
5. IF any group role is altered to add the `LOGIN` attribute without explicit administrative authorization, THEN THE Sistema SHALL allow the change to take effect and SHALL record the resulting state as a misconfiguration flagged for audit review; the Sistema does not block the alteration or revert the `LOGIN` attribute automatically.
6. THE Sistema SHALL create all roles within the `foodstore` database under the `public` schema context.
