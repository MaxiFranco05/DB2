# Verificación de Roles y Permisos de Mínimo Privilegio (Parte A.3)

**Asignatura:** Base de Datos II — Unidad 5  
**Proyecto:** Food Store (`food_store` / `food_store_copia`)  
**Integrantes:** Máximo, Andrés y Octavio  

Este documento contiene la salida verificable de las consultas al catálogo de PostgreSQL (`\du`, `information_schema.role_table_grants`, `information_schema.role_column_grants`, `\ddp` y pruebas formales con `EXCEPT`) tras la ejecución de `sql/roles.sql`, demostrando que cada rol posee **exactamente** los privilegios especificados en Kiro (`docs/kiro_roles_spec/`) —ni más, ni menos—.

---

## 1. Verificación de Roles, Atributos y Membresías (`\du` y `pg_auth_members`)

Comando ejecutado:
```sql
\du
```

Salida obtenida del motor PostgreSQL:
```text
                               Listado de roles
   Nombre de rol   |                         Atributos                         
-------------------+-----------------------------------------------------------
 admin_datos       | Crear rol
 app_web           | 
 postgres          | Superusuario, Crear rol, Crear BD, Replicación, Ignora RLS
 rol_app_escritura | No puede conectarse
 rol_app_lectura   | No puede conectarse
 rol_reportes      | No puede conectarse
 rol_soporte       | No puede conectarse
```

Verificación de herencia de grupos para `app_web`:
```sql
SELECT r.rolname AS rol_login, m.rolname AS rol_grupo_heredado
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.member
JOIN pg_roles m ON m.oid = am.roleid
WHERE r.rolname IN ('app_web', 'admin_datos')
ORDER BY 1, 2;
```
```text
 rol_login | rol_grupo_heredado 
-----------+--------------------
 app_web   | rol_app_escritura
 app_web   | rol_app_lectura
(2 filas)
```

---

## 2. Verificación de Privilegios a Nivel de Tabla (`information_schema.role_table_grants`)

Consulta ejecutada:
```sql
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'app_web')
ORDER BY grantee, table_name, privilege_type;
```

Salida obtenida:
```text
      grantee      |        table_name        | privilege_type 
-------------------+--------------------------+----------------
 rol_app_escritura | auditoria                | INSERT
 rol_app_escritura | detalle_pedido           | DELETE
 rol_app_escritura | detalle_pedido           | INSERT
 rol_app_escritura | pedido                   | INSERT
 rol_app_escritura | ventas_diarias_categoria | INSERT
 rol_app_escritura | ventas_diarias_categoria | SELECT
 rol_app_escritura | ventas_diarias_categoria | UPDATE
 rol_app_lectura   | categoria                | SELECT
 rol_app_lectura   | detalle_pedido           | SELECT
 rol_app_lectura   | pedido                   | SELECT
 rol_app_lectura   | producto                 | SELECT
 rol_app_lectura   | usuario                  | SELECT
 rol_reportes      | v_ventas_por_categoria   | SELECT
 rol_soporte       | detalle_pedido           | SELECT
 rol_soporte       | pedido                   | SELECT
(15 filas)
```
*(Nota: `admin_datos` posee los 7 privilegios `ALL PRIVILEGES` sobre todas las tablas y vistas del esquema `public`, y `app_web` no posee ningún privilegio directo sobre tablas, sino que hereda limpiamente de `rol_app_lectura` y `rol_app_escritura`).*

---

## 3. Verificación de Privilegios a Nivel de Columna (`information_schema.role_column_grants`)

Consulta ejecutada para verificar los permisos puntuales de columna (`rol_soporte` sobre `usuario(id, mail)` y `rol_app_escritura` sobre `producto(stock)` y `pedido(estado)`):
```sql
SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.role_column_grants
WHERE (grantee = 'rol_soporte' AND table_name = 'usuario')
   OR (grantee = 'rol_app_escritura' AND privilege_type = 'UPDATE' AND table_name IN ('producto', 'pedido'))
ORDER BY grantee, table_name, column_name;
```

Salida obtenida:
```text
      grantee      | table_name | column_name | privilege_type 
-------------------+------------+-------------+----------------
 rol_app_escritura | pedido     | estado      | UPDATE
 rol_app_escritura | producto   | stock       | UPDATE
 rol_soporte       | usuario    | id          | SELECT
 rol_soporte       | usuario    | mail        | SELECT
(4 filas)
```

---

## 4. Verificación de `ALTER DEFAULT PRIVILEGES` para Tablas Futuras (`\ddp`)

Comando ejecutado:
```sql
\ddp
```

Salida obtenida:
```text
                Privilegios de acceso por omisión
   Dueño   | Esquema |   Tipo    |          Privilegios          
-----------+---------+-----------+-------------------------------
 postgres  | public  | secuencia | admin_datos=rwU/postgres
 postgres  | public  | tabla     | rol_app_lectura=r/postgres   +
           |         |           | admin_datos=arwdDxtm/postgres
(2 filas)
```

---

## 5. Verificación Formal de Propiedades de Seguridad con `EXCEPT`

Siguiendo la especificación de Kiro (`docs/kiro_roles_spec/design.md` y `tasks.md`), se validó que la diferencia simétrica (`EXCEPT`) entre los permisos otorgados a los roles sobre las 5 tablas operativas principales (`categoria`, `producto`, `pedido`, `detalle_pedido`, `usuario`) y la matriz de diseño sea exactamente **0 filas**:

```sql
WITH esperado (grantee, table_name, privilege_type) AS (
    VALUES
        ('rol_app_lectura', 'categoria',      'SELECT'),
        ('rol_app_lectura', 'producto',       'SELECT'),
        ('rol_app_lectura', 'pedido',         'SELECT'),
        ('rol_app_lectura', 'detalle_pedido', 'SELECT'),
        ('rol_app_lectura', 'usuario',        'SELECT'),
        ('rol_app_escritura', 'pedido',         'INSERT'),
        ('rol_app_escritura', 'detalle_pedido', 'INSERT'),
        ('rol_app_escritura', 'detalle_pedido', 'DELETE'),
        ('rol_soporte', 'pedido',         'SELECT'),
        ('rol_soporte', 'detalle_pedido', 'SELECT')
),
actual AS (
    SELECT grantee::text, table_name::text, privilege_type::text
    FROM information_schema.role_table_grants
    WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'app_web')
      AND table_name IN ('categoria', 'producto', 'pedido', 'detalle_pedido', 'usuario')
)
(SELECT * FROM actual EXCEPT SELECT * FROM esperado)
UNION ALL
(SELECT * FROM esperado EXCEPT SELECT * FROM actual);
```

Resultado en motor:
```text
 grantee | table_name | privilege_type 
---------+------------+----------------
(0 filas)
```

Verificación con `EXCEPT` para columnas de `usuario` en `rol_soporte` (garantizando la no exposición de `nombre`, `apellido`, `celular` ni `contrasena`):
```sql
(
    SELECT column_name::text, privilege_type::text
    FROM information_schema.role_column_grants
    WHERE grantee = 'rol_soporte' AND table_name = 'usuario'
    EXCEPT
    VALUES ('id', 'SELECT'), ('mail', 'SELECT')
)
UNION ALL
(
    VALUES ('id', 'SELECT'), ('mail', 'SELECT')
    EXCEPT
    SELECT column_name::text, privilege_type::text
    FROM information_schema.role_column_grants
    WHERE grantee = 'rol_soporte' AND table_name = 'usuario'
);
```

Resultado en motor:
```text
 column_name | privilege_type 
-------------+----------------
(0 filas)
```
