# Implementation Plan: Roles y Permisos — FoodStore

## Overview

Plan de implementación del modelo de seguridad de roles para la base de datos `foodstore`. Se crean cuatro roles de grupo (sin login) y dos roles de login mediante scripts SQL puros, siguiendo el principio de mínimo privilegio. Los permisos se verifican contra el catálogo del sistema de PostgreSQL usando consultas con `EXCEPT` para validar propiedades de corrección.

## Tasks

- [ ] 1. Preparar estructura de archivos y variables de entorno
  - [ ] 1.1 Crear el archivo `db/roles.sql` vacío con cabecera de documentación
    - Incluir comentario con descripción del script, fecha y autor
    - Agregar bloque `\set ON_ERROR_STOP on` al inicio para abortar ante errores
    - _Requirements: 7.6_

  - [ ] 1.2 Agregar variables de contraseña en `.env.example`
    - Añadir las claves `APP_WEB_PASSWORD` y `ADMIN_DATOS_PASSWORD` con valores de marcador de posición
    - Verificar que `.env` esté listado en `.gitignore`
    - _Requirements: 5.1, 6.1_

- [ ] 2. Crear roles de grupo sin login
  - [ ] 2.1 Escribir sentencias SQL para crear `rol_app_lectura`
    - `CREATE ROLE rol_app_lectura NOLOGIN NOINHERIT;`
    - `GRANT USAGE ON SCHEMA public TO rol_app_lectura;`
    - `GRANT SELECT ON TABLE categoria, producto, pedido, detalle_pedido, usuario TO rol_app_lectura;`
    - _Requirements: 1.1, 1.2, 1.3, 7.1, 7.2, 7.3_

  - [ ] 2.2 Escribir sentencias SQL para crear `rol_app_escritura`
    - `CREATE ROLE rol_app_escritura NOLOGIN NOINHERIT;`
    - `GRANT USAGE ON SCHEMA public TO rol_app_escritura;`
    - `GRANT INSERT ON TABLE pedido, detalle_pedido TO rol_app_escritura;`
    - `GRANT UPDATE (stock) ON TABLE producto TO rol_app_escritura;`
    - `GRANT UPDATE (estado) ON TABLE pedido TO rol_app_escritura;`
    - `GRANT DELETE ON TABLE detalle_pedido TO rol_app_escritura;`
    - `GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq, detalle_pedido_pedido_id_seq TO rol_app_escritura;`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 7.1, 7.2, 7.3_

  - [ ] 2.3 Escribir sentencias SQL para crear `rol_soporte`
    - `CREATE ROLE rol_soporte NOLOGIN NOINHERIT;`
    - `GRANT USAGE ON SCHEMA public TO rol_soporte;`
    - `GRANT SELECT (id, mail) ON TABLE usuario TO rol_soporte;`
    - `GRANT SELECT ON TABLE pedido, detalle_pedido TO rol_soporte;`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 7.1, 7.2, 7.3_

  - [ ] 2.4 Escribir sentencias SQL para crear `rol_reportes`
    - `CREATE ROLE rol_reportes NOLOGIN NOINHERIT;`
    - `GRANT USAGE ON SCHEMA public TO rol_reportes;`
    - Incluir comentario indicando que los `GRANT SELECT ON VIEW` se añaden al crear cada vista
    - _Requirements: 4.1, 4.2, 4.3, 7.1, 7.2, 7.3_

- [ ] 3. Checkpoint — verificar creación de roles de grupo
  - Aplicar el script parcial con `psql -d foodstore -f db/roles.sql` y confirmar que los cuatro roles aparecen en `\du`.
  - Asegurarse de que ningún rol de grupo tiene el atributo `Login`.
  - Preguntar al usuario si hay dudas antes de continuar.

- [ ] 4. Crear roles de login
  - [ ] 4.1 Escribir sentencias SQL para crear `app_web`
    - `CREATE ROLE app_web LOGIN PASSWORD :'APP_WEB_PASSWORD' NOSUPERUSER NOCREATEROLE NOCREATEDB;`
    - `GRANT CONNECT ON DATABASE foodstore TO app_web;`
    - `GRANT rol_app_lectura TO app_web;`
    - `GRANT rol_app_escritura TO app_web;`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 7.4_

  - [ ] 4.2 Escribir sentencias SQL para crear `admin_datos`
    - `CREATE ROLE admin_datos LOGIN PASSWORD :'ADMIN_DATOS_PASSWORD' NOSUPERUSER CREATEROLE NOCREATEDB;`
    - `GRANT CONNECT ON DATABASE foodstore TO admin_datos;`
    - `GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_datos;`
    - `GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;`
    - `GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.4_

- [ ] 5. Crear script de verificación `db/verify_roles.sql`
  - [ ] 5.1 Escribir consultas de verificación para `rol_app_lectura` (Property 1)
    - Consulta que lista los privilegios de escritura (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`) sobre tablas operativas otorgados a `rol_app_lectura` usando `information_schema.role_table_grants`
    - El resultado esperado es cero filas; usar `EXCEPT` para comparar contra el conjunto vacío
    - **Property 1: Denegación universal de escritura para `rol_app_lectura`**
    - **Validates: Requirements 1.4**

  - [ ]* 5.2 Escribir consulta de verificación para `rol_app_escritura` — acceso a `usuario` (Property 2)
    - Consulta que lista cualquier privilegio (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) de `rol_app_escritura` sobre cualquier columna de `usuario`
    - El resultado esperado es cero filas; verificar con `EXCEPT`
    - **Property 2: Denegación de acceso a `usuario` para `rol_app_escritura`**
    - **Validates: Requirements 2.10**

  - [ ]* 5.3 Escribir consulta de verificación de `TRUNCATE` para todos los roles de grupo (Property 3)
    - Consulta que lista filas con `privilege_type = 'TRUNCATE'` otorgadas a cualquiera de los cuatro roles de grupo
    - El resultado esperado es cero filas; verificar con `EXCEPT`
    - **Property 3: Denegación de `TRUNCATE` para todos los roles no administradores**
    - **Validates: Requirements 1.4, 2.8, 3.6, 4.5**

  - [ ]* 5.4 Escribir consulta de verificación de columnas sensibles para `rol_soporte` (Property 4)
    - Consulta que lista cualquier privilegio `SELECT` de `rol_soporte` sobre columnas `nombre`, `apellido`, `celular`, `contrasena` de `usuario`
    - El resultado esperado es cero filas; verificar con `EXCEPT`
    - **Property 4: Denegación de columnas sensibles de `usuario` para `rol_soporte`**
    - **Validates: Requirements 3.5**

  - [ ]* 5.5 Escribir consulta de verificación de escritura para `rol_soporte` (Property 5)
    - Consulta que lista privilegios `INSERT`, `UPDATE`, `DELETE` de `rol_soporte` sobre cualquier tabla operativa
    - El resultado esperado es cero filas; verificar con `EXCEPT`
    - **Property 5: Denegación de escritura para `rol_soporte`**
    - **Validates: Requirements 3.6**

  - [ ]* 5.6 Escribir consulta de verificación de acceso directo a tablas para `rol_reportes` (Property 6)
    - Consulta que lista cualquier privilegio estándar de `rol_reportes` sobre las tablas operativas
    - El resultado esperado es cero filas; verificar con `EXCEPT`
    - **Property 6: Denegación de acceso directo a tablas operativas para `rol_reportes`**
    - **Validates: Requirements 4.4, 4.5**

  - [ ]* 5.7 Escribir consulta de verificación de atributos de seguridad para `app_web` y `admin_datos` (Property 8)
    - Consulta sobre `pg_roles` que verifica que `app_web` no tenga `rolsuper`, `rolcreaterole` ni `rolcreatedb`
    - Consulta que verifica que `admin_datos` no tenga `rolsuper`
    - El resultado esperado muestra únicamente los atributos permitidos; verificar con `EXCEPT`
    - **Property 8: `app_web` no posee privilegios directos fuera de los heredados**
    - **Validates: Requirements 5.5, 5.6, 6.5**

- [ ] 6. Checkpoint final — ejecutar todas las verificaciones
  - Aplicar el script completo: `psql -d foodstore -v APP_WEB_PASSWORD="$APP_WEB_PASSWORD" -v ADMIN_DATOS_PASSWORD="$ADMIN_DATOS_PASSWORD" -f db/roles.sql`
  - Ejecutar `psql -d foodstore -f db/verify_roles.sql` y confirmar que todas las consultas retornan cero filas
  - Verificar con `\du` que los atributos de `app_web` y `admin_datos` son los esperados
  - Asegurarse de que todos los tests pasan; preguntar al usuario si surgen dudas.

## Notes

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido
- Cada tarea referencia requisitos específicos para trazabilidad
- El script `db/roles.sql` debe ejecutarse con variables de entorno inyectadas desde `.env` (nunca valores literales en el script)
- Las propiedades se verifican mediante consultas SQL al catálogo del sistema (`information_schema`, `pg_roles`, `pg_class`) usando `EXCEPT` para comparar el estado real contra el estado esperado (conjunto vacío)
- Property 7 (vistas sin columnas sensibles) no tiene tarea asignada porque las vistas son trabajo futuro; se implementará junto a cada vista cuando se cree
- Los checkpoints asumen que la base `foodstore` ya existe y que el schema está aplicado desde `db/schema.sql`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["4.1", "4.2"] },
    { "id": 3, "tasks": ["5.1"] },
    { "id": 4, "tasks": ["5.2", "5.3", "5.4", "5.5", "5.6", "5.7"] }
  ]
}
```
