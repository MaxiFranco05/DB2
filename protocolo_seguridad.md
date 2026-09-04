# Protocolo de Seguridad - Operaciones sobre Base de Datos

## 1. Copia
**Regla:** Jamás se trabaja sobre la base de producción ni sobre la base que contiene los datos importantes consolidados.
**Aplicación práctica:** 
Antes de ejecutar cualquier script generado por IA, creo una base de datos clonada en PostgreSQL usando la base principal como plantilla.
Comando a utilizar en terminal (o su equivalente visual en pgAdmin):
`createdb -U postgres -T food_store food_store_trabajo`

## 2. Transacción
**Regla:** Todo script que modifique datos (`INSERT`, `UPDATE`, `DELETE`) debe probarse dentro de un bloque de transacción para inspeccionar el efecto antes de confirmarlo.
**Aplicación práctica:**
Enuncio explícitamente `BEGIN;` al inicio del script en el Query Tool. Verifico los mensajes de PostgreSQL (filas afectadas). Si todo es correcto, ejecuto `COMMIT;`. Si el resultado es inesperado o destructivo, ejecuto `ROLLBACK;`.

## 3. Respaldo
**Regla:** Se debe crear un archivo de volcado (dump) antes de aplicar un cambio estructural DDL (`ALTER`, `DROP`).
**Aplicación práctica:**
Utilizo la herramienta de copias de seguridad de PostgreSQL para guardar el estado exacto de la base de trabajo antes de alterar el esquema.
Comando a utilizar:
`pg_dump -U postgres -F c -d food_store_trabajo -f respaldo_antes_de_migracion.dump`