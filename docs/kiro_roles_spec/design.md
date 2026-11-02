# Design: Roles y Permisos — FoodStore

## 1. Objetivo del diseño

Este documento describe la arquitectura de seguridad del sistema de roles de la base de datos `foodstore`. El diseño aplica el principio de mínimo privilegio mediante una separación en dos capas:

1. **Roles de grupo** (sin login): encapsulan conjuntos cohesivos de permisos.
2. **Roles de login**: representan identidades de conexión reales que heredan uno o más roles de grupo.

Este esquema permite modificar los permisos de un perfil funcional en un único lugar (el rol de grupo) sin afectar a los usuarios de conexión.

---

## 2. Modelo de jerarquía de roles

```
                        ┌─────────────────────┐
                        │     admin_datos      │  ← login
                        │  (acceso completo)   │
                        └─────────────────────┘

          ┌─────────────────────────────────────┐
          │               app_web               │  ← login
          └────────────┬────────────────────────┘
                       │  hereda
         ┌─────────────┴──────────────┐
         ▼                            ▼
 ┌───────────────┐     ┌──────────────────────┐
 │ rol_app_      │     │   rol_app_           │  ← grupos
 │ lectura       │     │   escritura          │
 └───────────────┘     └──────────────────────┘

       ┌───────────────────────────────────┐
       │  (sin herencia — roles independientes)
       ▼                                   ▼
 ┌─────────────┐               ┌──────────────────┐
 │ rol_soporte │               │  rol_reportes    │  ← grupos
 └─────────────┘               └──────────────────┘
```

`admin_datos` no hereda roles de grupo: recibe sus privilegios directamente mediante `ALL PRIVILEGES` sobre el esquema `public`.

---

## 3. Matriz de permisos por tabla

Los permisos marcados con `(col)` son a nivel de columna. El símbolo `—` indica acceso denegado.

| Tabla              | `rol_app_lectura` | `rol_app_escritura`          | `rol_soporte`              | `rol_reportes` |
|--------------------|:-----------------:|:----------------------------:|:--------------------------:|:--------------:|
| `categoria`        | SELECT            | —                            | —                          | —              |
| `producto`         | SELECT            | UPDATE (col: `stock`)        | —                          | —              |
| `pedido`           | SELECT            | INSERT, UPDATE (col: `estado`) | SELECT                   | —              |
| `detalle_pedido`   | SELECT            | INSERT, DELETE               | SELECT                     | —              |
| `usuario`          | SELECT            | —                            | SELECT (col: `id`, `mail`) | —              |
| Vistas agregadas   | —                 | —                            | —                          | SELECT         |

`admin_datos` (login): `ALL PRIVILEGES` sobre todas las tablas, secuencias y vistas del esquema `public`.

---

## 4. Detalle técnico de cada rol

### 4.1 `rol_app_lectura`

- **Tipo:** rol de grupo, sin `LOGIN`, sin contraseña
- **Scope:** esquema `public`, base `foodstore`
- **Permisos sobre el esquema:** `USAGE`
- **Permisos sobre objetos:**
  - `SELECT` en: `categoria`, `producto`, `pedido`, `detalle_pedido`, `usuario`
- **Operaciones denegadas:** `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, cualquier DDL
- **Propósito:** Soporte de lectura para la capa de presentación (menús, catálogos, estados de pedido).

```sql
CREATE ROLE rol_app_lectura NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA public TO rol_app_lectura;
GRANT SELECT ON TABLE categoria, producto, pedido, detalle_pedido, usuario
    TO rol_app_lectura;
```

---

### 4.2 `rol_app_escritura`

- **Tipo:** rol de grupo, sin `LOGIN`, sin contraseña
- **Scope:** esquema `public`, base `foodstore`
- **Permisos sobre el esquema:** `USAGE`
- **Permisos sobre objetos:**
  - `INSERT` en: `pedido`, `detalle_pedido`
  - `UPDATE` en: `producto` (columna `stock`)
  - `UPDATE` en: `pedido` (columna `estado`)
  - `DELETE` en: `detalle_pedido`
- **Acceso a secuencias:** `USAGE` y `SELECT` sobre las secuencias de identidad de `pedido` y `detalle_pedido` (requerido por `GENERATED ALWAYS AS IDENTITY`)
- **Operaciones denegadas sobre `usuario`:** cualquier privilegio (SELECT, INSERT, UPDATE, DELETE)
- **Operaciones denegadas generales:** `TRUNCATE`, cualquier DDL
- **Propósito:** Soporte de escritura para la operatoria diaria (registro de pedidos, descuento de stock, cambio de estado).

```sql
CREATE ROLE rol_app_escritura NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA public TO rol_app_escritura;
GRANT INSERT ON TABLE pedido, detalle_pedido TO rol_app_escritura;
GRANT UPDATE (stock) ON TABLE producto TO rol_app_escritura;
GRANT UPDATE (estado) ON TABLE pedido TO rol_app_escritura;
GRANT DELETE ON TABLE detalle_pedido TO rol_app_escritura;
GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq, detalle_pedido_pedido_id_seq
    TO rol_app_escritura;
```

---

### 4.3 `rol_soporte`

- **Tipo:** rol de grupo, sin `LOGIN`, sin contraseña
- **Scope:** esquema `public`, base `foodstore`
- **Permisos sobre el esquema:** `USAGE`
- **Permisos sobre objetos:**
  - `SELECT` (columnas `id`, `mail`) en: `usuario`
  - `SELECT` en: `pedido`, `detalle_pedido`
- **Columnas denegadas en `usuario`:** `nombre`, `apellido`, `celular`, `contrasena`
- **Tablas completamente denegadas:** `categoria`, `producto`
- **Operaciones denegadas:** `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` sobre cualquier tabla
- **Nota de implementación:** PostgreSQL deniega por defecto el acceso a columnas no otorgadas explícitamente cuando el `SELECT` se otorga a nivel de columna. No se requiere denegación explícita de columnas sensibles.
- **Propósito:** Atención al cliente — identificar al usuario por mail y consultar sus pedidos sin acceder a datos personales sensibles.

```sql
CREATE ROLE rol_soporte NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA public TO rol_soporte;
GRANT SELECT (id, mail) ON TABLE usuario TO rol_soporte;
GRANT SELECT ON TABLE pedido, detalle_pedido TO rol_soporte;
```

---

### 4.4 `rol_reportes`

- **Tipo:** rol de grupo, sin `LOGIN`, sin contraseña
- **Scope:** esquema `public`, base `foodstore`
- **Permisos sobre el esquema:** `USAGE`
- **Permisos sobre objetos:**
  - `SELECT` sobre las vistas agregadas de negocio (a crear en fase futura)
- **Sin acceso directo** a ninguna tabla operativa
- **Operaciones denegadas:** `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`
- **Vistas previstas (fase futura):**

  | Vista (tentativa)           | Descripción                                    |
  |-----------------------------|------------------------------------------------|
  | `v_ventas_por_categoria`    | Total vendido agrupado por categoría y período |
  | `v_pedidos_por_estado`      | Cantidad de pedidos por estado en un período   |
  | `v_productos_mas_vendidos`  | Ranking de productos por unidades vendidas     |
  | `v_ingresos_diarios`        | Suma de subtotales por día                     |

  Cada vista debe otorgarse explícitamente al momento de su creación:
  ```sql
  GRANT SELECT ON VIEW <nombre_vista> TO rol_reportes;
  ```

- **Propósito:** Análisis de negocio con aislamiento total de los datos transaccionales y sensibles.

```sql
CREATE ROLE rol_reportes NOLOGIN NOINHERIT;
GRANT USAGE ON SCHEMA public TO rol_reportes;
-- Los SELECT sobre vistas se otorgan al momento de crear cada vista.
```

---

### 4.5 `app_web` (rol de login)

- **Tipo:** rol de login, con contraseña (valor definido en `.env`, nunca en código fuente)
- **Membresía:** hereda `rol_app_lectura` + `rol_app_escritura`
- **Permisos de conexión:** `CONNECT` sobre la base `foodstore`
- **Atributos de seguridad:** sin `SUPERUSER`, sin `CREATEROLE`, sin `CREATEDB`
- **Permisos efectivos:** exactamente la unión de los permisos de `rol_app_lectura` y `rol_app_escritura`, sin privilegios adicionales directos
- **Propósito:** Identidad de conexión del backend de la aplicación web.

```sql
CREATE ROLE app_web LOGIN PASSWORD :'APP_WEB_PASSWORD' NOSUPERUSER NOCREATEROLE NOCREATEDB;
GRANT CONNECT ON DATABASE foodstore TO app_web;
GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;
```

---

### 4.6 `admin_datos` (rol de login)

- **Tipo:** rol de login, con contraseña fuerte (valor definido en `.env`, nunca en código fuente)
- **Permisos:** `ALL PRIVILEGES` sobre todas las tablas, vistas y secuencias del esquema `public`
- **Permisos de conexión:** `CONNECT` sobre la base `foodstore`
- **Capacidades adicionales:** `CREATEROLE` para administrar el modelo de roles
- **Atributos de seguridad:** sin `SUPERUSER` (principio de mínimo privilegio a nivel de instancia)
- **Uso esperado:** sesiones administrativas, migraciones, auditorías — no como identidad habitual de la aplicación
- **Propósito:** Administración del sistema de datos, migraciones de esquema y auditoría.

```sql
CREATE ROLE admin_datos LOGIN PASSWORD :'ADMIN_DATOS_PASSWORD' NOSUPERUSER CREATEROLE NOCREATEDB;
GRANT CONNECT ON DATABASE foodstore TO admin_datos;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;
```

---

## 5. Flujo de acceso por caso de uso

| Caso de uso                           | Rol de login   | Roles heredados                               | Operación efectiva                                   |
|---------------------------------------|----------------|-----------------------------------------------|------------------------------------------------------|
| Usuario navega el catálogo            | `app_web`      | `rol_app_lectura`                             | SELECT en `categoria`, `producto`                    |
| Usuario consulta estado de su pedido  | `app_web`      | `rol_app_lectura`                             | SELECT en `pedido`, `detalle_pedido`                 |
| Usuario realiza un pedido             | `app_web`      | `rol_app_escritura`                           | INSERT en `pedido`, `detalle_pedido`                 |
| Sistema descuenta stock               | `app_web`      | `rol_app_escritura`                           | UPDATE `producto.stock`                              |
| Sistema actualiza estado de pedido    | `app_web`      | `rol_app_escritura`                           | UPDATE `pedido.estado`                               |
| Soporte busca pedidos de un cliente   | *(rol soporte)* | `rol_soporte`                                | SELECT `usuario(id, mail)`, SELECT `pedido`          |
| Analista genera reporte de ventas     | *(rol analista)* | `rol_reportes`                              | SELECT sobre vistas agregadas                        |
| DBA aplica migración de esquema       | `admin_datos`  | —                                             | DDL + ALL PRIVILEGES sobre `public`                  |
| DBA audita sesiones administrativas   | `admin_datos`  | —                                             | Consultas sobre `pg_stat_activity`, logs             |

---

## 6. Consideraciones de implementación

### 6.1 Orden de creación

Los objetos deben crearse en este orden para respetar las dependencias entre ellos:

1. Crear roles de grupo: `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`
2. Crear roles de login: `app_web`, `admin_datos`
3. Otorgar membresía: asignar grupos a `app_web`
4. Otorgar `CONNECT` a la base de datos a los roles de login
5. Otorgar `USAGE` sobre el esquema `public` a todos los roles que lo requieren
6. Otorgar permisos sobre tablas, columnas y secuencias específicas
7. *(Fase futura)* Crear vistas y otorgar `SELECT` a `rol_reportes`

### 6.2 Gestión de contraseñas

Las contraseñas de `app_web` y `admin_datos` nunca deben estar en el código fuente ni en scripts SQL versionados. El patrón recomendado es usar variables de `psql` inyectadas desde `.env`:

```bash
# En el script de inicialización
psql -d foodstore \
  -v APP_WEB_PASSWORD="$APP_WEB_PASSWORD" \
  -v ADMIN_DATOS_PASSWORD="$ADMIN_DATOS_PASSWORD" \
  -f db/roles.sql
```

El archivo `.env` está listado en `.gitignore`. Usar `.env.example` como plantilla con valores de marcador de posición.

### 6.3 Revocación y propagación de cambios

La arquitectura de dos capas (grupos + login) simplifica la gestión:

- **Revocar un permiso puntual:** modificar el rol de grupo correspondiente. El cambio se propaga automáticamente a todos los roles de login que lo heredan.
- **Suspender un usuario de conexión:** revocar el atributo `LOGIN` del rol de login sin tocar los grupos.
- **Agregar una nueva identidad de conexión:** crear un nuevo rol de login y asignarle los grupos necesarios.

### 6.4 Auditoría de sesiones administrativas

Para trazabilidad de las operaciones realizadas con `admin_datos`, activar en `postgresql.conf`:

```
log_connections = on
log_disconnections = on
log_statement = 'ddl'  -- registra CREATE, ALTER, DROP
```

Opcionalmente, filtrar por `application_name` o usar `SET application_name = 'admin_datos'` al inicio de cada sesión de mantenimiento.

### 6.5 Extensión futura: vistas para `rol_reportes`

Cuando se implementen las vistas agregadas deben cumplir estas reglas de diseño:

- Nunca exponer `usuario.contrasena`, `usuario.celular`, `usuario.nombre`, ni `usuario.apellido`.
- Usar funciones de agregación (`SUM`, `COUNT`, `AVG`) para que el resultado sea siempre estadístico, nunca a nivel de fila individual de usuario.
- Otorgar `SELECT` sobre cada vista nueva a `rol_reportes` explícitamente en el mismo script de creación.
- El diseño de cada vista debe revisarse contra la propiedad de no exposición de columnas sensibles antes de aplicarse en producción.

---

## 7. Correctness Properties

*Una propiedad es una característica o comportamiento que debe sostenerse como verdadero en todas las ejecuciones válidas del sistema — esencialmente, un enunciado formal sobre qué debe hacer el sistema. Las propiedades sirven de puente entre especificaciones legibles por humanos y garantías de corrección verificables automáticamente.*

---

### Property 1: Denegación universal de escritura para `rol_app_lectura`

*Para cualquier* tabla operativa del esquema `public` (`categoria`, `producto`, `pedido`, `detalle_pedido`, `usuario`) y para cualquier operación de escritura (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`), `rol_app_lectura` no debe tener ese privilegio según el catálogo del sistema.

**Validates: Requirements 1.4**

---

### Property 2: Denegación de acceso a `usuario` para `rol_app_escritura`

*Para cualquier* columna de la tabla `usuario`, `rol_app_escritura` no debe tener privilegio de `SELECT`, `INSERT`, `UPDATE` ni `DELETE` sobre ella.

**Validates: Requirements 2.10**

---

### Property 3: Denegación de `TRUNCATE` para todos los roles no administradores

*Para cualquier* rol de grupo (`rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`) y para cualquier tabla del esquema `public`, ninguno de esos roles debe tener el privilegio `TRUNCATE`.

**Validates: Requirements 1.4, 2.8, 3.6, 4.5**

---

### Property 4: Denegación de columnas sensibles de `usuario` para `rol_soporte`

*Para cualquier* columna sensible en `{nombre, apellido, celular, contrasena}` de la tabla `usuario`, `rol_soporte` no debe tener privilegio de `SELECT` sobre esa columna.

**Validates: Requirements 3.5**

---

### Property 5: Denegación de escritura para `rol_soporte`

*Para cualquier* tabla operativa del esquema `public` y para cualquier operación de escritura (`INSERT`, `UPDATE`, `DELETE`), `rol_soporte` no debe tener ese privilegio.

**Validates: Requirements 3.6**

---

### Property 6: Denegación de acceso directo a tablas operativas para `rol_reportes`

*Para cualquier* tabla operativa (`categoria`, `producto`, `pedido`, `detalle_pedido`, `usuario`) y para cualquier privilegio estándar (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`), `rol_reportes` no debe tener ese privilegio sobre ninguna de esas tablas.

**Validates: Requirements 4.4, 4.5**

---

### Property 7: Las vistas accesibles por `rol_reportes` no exponen columnas sensibles

*Para cualquier* vista sobre la que `rol_reportes` tenga privilegio `SELECT`, ninguna de sus columnas en `information_schema.columns` debe llamarse `contrasena`, `celular`, `nombre` ni `apellido`.

**Validates: Requirements 4.6**

---

### Property 8: `app_web` no posee privilegios directos fuera de los heredados

*Para cualquier* privilegio de tabla o columna que no esté otorgado a `rol_app_lectura` ni a `rol_app_escritura`, `app_web` tampoco debe poseer ese privilegio de forma directa.

**Validates: Requirements 5.6**

---

## 8. Archivos relacionados

| Archivo                                          | Descripción                                          |
|--------------------------------------------------|------------------------------------------------------|
| `db/schema.sql`                                  | Esquema canónico: tablas, triggers, índices, seeds   |
| `.env.example`                                   | Variables de entorno requeridas (credenciales)       |
| `.kiro/specs/roles-y-permisos/requirements.md`   | Requisitos funcionales y de seguridad de este modelo |
| `docs/design.md`                                 | Documento de diseño previo (referencia)              |
