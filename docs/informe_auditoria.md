# Informe de Configuración y Prueba de Auditoría (Parte B)

**Asignatura:** Base de Datos II — Unidad 5  
**Proyecto:** Food Store (`food_store_copia`)  
**Integrantes:** Máximo, Andrés y Octavio  

---

## 1. Parámetros de auditoría activados en el servidor de desarrollo (Punto B.1)

Sobre la instancia local de PostgreSQL (`C:/Program Files/PostgreSQL/18/data`), con el recolector de logs activo (`logging_collector = on`), se configuraron mediante `ALTER SYSTEM` y se aplicaron con `SELECT pg_reload_conf();` los siguientes parámetros en `postgresql.auto.conf`:

| Parámetro | Valor previo | Valor activado | Contexto en `pg_settings` | Propósito técnico |
| :--- | :---: | :---: | :---: | :--- |
| `log_connections` | `off` / vacío | **`on`** | `superuser-backend` | Registra cada intento de conexión al servidor y su autorización exitosa o fallida. |
| `log_disconnections` | `off` | **`on`** | `superuser-backend` | Registra el cierre de cada sesión junto con la duración total (`duración de sesión`). |
| `log_statement` | `none` | **`mod`** | `superuser` | Registra todas las sentencias DDL más las sentencias DML que modifican datos (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`). |
| `log_line_prefix` | `%t ` | **`%t [%p] %u@%d %h `** | `sighup` | Enriquece cada línea del log con: timestamp (`%t`), PID de proceso (`%p`), usuario (`%u`), base de datos (`%d`) y host/IP de origen (`%h`). |

> **Nota técnica sobre la recarga de parámetros (`context`):**  
> Mientras que `logging_collector` tiene contexto `postmaster` (requiere reinicio del servicio), los parámetros `log_connections` y `log_disconnections` poseen contexto `superuser-backend`. Esto significa que al ejecutar `SELECT pg_reload_conf();` (`pending_restart = f`), toda **nueva conexión** que se abre contra el servidor toma inmediatamente el valor `on` sin interrumpir las conexiones activas.

Comandos ejecutados:
```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'mod';
ALTER SYSTEM SET log_line_prefix = '%t [%p] %u@%d %h ';
SELECT pg_reload_conf();
```

---

## 2. Secuencia de prueba ejecutada y fragmento de log capturado (Punto B.2)

Se ejecutó el script `sql/auditoria_test.sql` conectando con el rol de aplicación `app_web` (que incluye `SELECT` sobre `producto`, `INSERT` en `pedido` y `detalle_pedido`, `UPDATE` en `producto` y `pedido`, e intento fallido en `fn_autenticar`), seguido de un intento de inicio de sesión fallido a nivel de motor con un rol inexistente (`usuario_inexistente_test`).

El fragmento completo capturado desde `log/postgresql-2026-11-02_000000.log` se adjunta en `docs/log_auditoria_prueba.txt`:

```text
2026-11-02 19:30:53 -03 [12028] [desconocido]@[desconocido] ::1 LOG:  conexión recibida: host=::1 port=60653
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  conexión autenticada: usuario=«app_web» método=trust (C:/Program Files/PostgreSQL/18/data/pg_hba.conf:117)
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  conexión autorizada: usuario=app_web base_de_datos=food_store_copia nombre_de_aplicación=psql
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  sentencia: INSERT INTO pedido (fecha, estado, forma_pago, usuario_id)
	VALUES (CURRENT_TIMESTAMP, 'PENDIENTE', 'TARJETA', 1);
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  sentencia: INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
	VALUES (currval(pg_get_serial_sequence('pedido', 'id')), 1, 2);
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  sentencia: UPDATE producto
	SET stock = stock - 2
	WHERE id = 1;
2026-11-02 19:30:53 -03 [12028] app_web@food_store_copia ::1 LOG:  sentencia: UPDATE pedido
	SET estado = 'CONFIRMADO'
	WHERE id = currval(pg_get_serial_sequence('pedido', 'id'));
2026-11-02 19:30:54 -03 [12028] app_web@food_store_copia ::1 WARNING:  Fallo de autenticación para el correo: usuario1@test.com
2026-11-02 19:30:54 -03 [12028] app_web@food_store_copia ::1 CONTEXTO:  función PL/pgSQL fn_autenticar(character varying,character varying) en la línea 20 en RAISE
2026-11-02 19:30:54 -03 [12028] app_web@food_store_copia ::1 LOG:  desconexión: duración de sesión: 0:00:00.857 usuario=app_web base=food_store_copia host=::1 port=60653
2026-11-02 19:30:54 -03 [35744] [desconocido]@[desconocido] ::1 LOG:  conexión recibida: host=::1 port=60654
2026-11-02 19:30:54 -03 [35744] usuario_inexistente_test@food_store_copia ::1 LOG:  conexión autenticada: usuario=«usuario_inexistente_test» método=trust (C:/Program Files/PostgreSQL/18/data/pg_hba.conf:117)
2026-11-02 19:30:54 -03 [35744] usuario_inexistente_test@food_store_copia ::1 LOG:  conexión autorizada: usuario=usuario_inexistente_test base_de_datos=food_store_copia nombre_de_aplicación=psql
2026-11-02 19:30:54 -03 [35744] usuario_inexistente_test@food_store_copia ::1 FATAL:  no existe el rol «usuario_inexistente_test»
```

---

## 3. Análisis de alcance: qué informa el log nativo y qué queda fuera frente a `pgaudit` (Punto B.3)

### Información útil presente en el fragmento (Rendición de cuentas básica):
- **Quién (`%u` y evento de conexión):** Se identifica claramente que las modificaciones fueron ejecutadas por el rol `app_web` en la sesión con PID `[12028]`, y que luego hubo un intento fallido con el rol `usuario_inexistente_test` en el PID `[35744]`, además del correo objetivo (`usuario1@test.com`) reportado por el `WARNING` de `fn_autenticar`.
- **Qué (`LOG: sentencia` / `WARNING` / `FATAL`):** Se observan las sentencias SQL exactas de inserción (`INSERT INTO pedido`, `INSERT INTO detalle_pedido`), actualización (`UPDATE producto`, `UPDATE pedido`) y los motivos de rechazo (`WARNING` de clave inválida y `FATAL` de rol inexistente).
- **Cuándo (`%t` y desconexión):** Cada evento tiene marca de tiempo con precisión de segundos y huso horario (`2026-11-02 19:30:53 -03`), más la duración exacta de la sesión (`0:00:00.857`).
- **Desde dónde (`%h`, `port` y `nombre_de_aplicación`):** Se registra la dirección IP de origen (`::1` localhost), el puerto efímero del cliente (`60653` / `60654`), la base afectada (`food_store_copia`) y el cliente utilizado (`psql`).

### Qué queda fuera del alcance de este mecanismo nativo (y por qué se requeriría `pgaudit` o triggers con `OLD`/`NEW`):
1. **Invisibilidad de las lecturas (`SELECT`) con `log_statement = 'mod'`:** Aunque `sql/auditoria_test.sql` ejecutó `SELECT id, nombre, precio, stock FROM producto WHERE id = 1;`, **esa consulta no aparece en el log** porque el nivel `'mod'` solo captura escrituras y DDL. Si se cambiara a `log_statement = 'all'` para detectar exfiltraciones (lecturas masivas de `usuario`), el log se inundaría con miles de consultas triviales del catálogo; en cambio, **`pgaudit`** permite auditar `SELECT` selectivamente sobre tablas o roles sensibles (`pgaudit.role` / object audit logging) sin degradar todo el servidor.
2. **Ausencia de detalle fila por fila y valores anteriores/posteriores (`OLD` vs `NEW`):** El log muestra el texto estático `UPDATE producto SET stock = stock - 2 WHERE id = 1;`, pero no informa cuántas filas se afectaron realmente, qué valor tenía `stock` antes del cambio, ni qué filas tocaron las funciones internas o triggers en cascada.
3. **Consultas dinámicas y objetos subyacentes:** Si un usuario consulta una vista o ejecuta una función PL/pgSQL que lee tablas internas sin `RAISE`, `log_statement` solo muestra la llamada externa, mientras que `pgaudit` desglosa los objetos y columnas efectivamente accedidos dentro del plan de ejecución.

---

## 4. Sensibilidad y permisos del archivo de log (Punto B.4)

Sí, el archivo de log es en sí mismo un **activo altamente sensible**, ya que almacena en texto plano sentencias SQL con parámetros literales (correos, nombres, montos e incluso credenciales si se ejecutaran sentencias `CREATE/ALTER ROLE ... PASSWORD` o funciones mal invocadas), además de revelar la estructura interna del esquema y patrones de acceso. Por principio de mínimo privilegio, a nivel de sistema operativo solo debe poder leerlo la cuenta de servicio del motor (`postgres`, con permisos `0600` o `0640` en el directorio `data/log/`) y los administradores de infraestructura o seguridad autorizados, mientras que a nivel de base de datos las funciones de lectura de archivos (`pg_read_file`, `pg_read_binary_file`) deben permanecer restringidas exclusivamente al superusuario o al rol `pg_read_server_files`, estando estrictamente vedadas para `app_web`, `rol_soporte` y `rol_reportes`.
