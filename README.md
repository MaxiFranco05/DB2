# TP8 - Kiro - Implementación de Bases de Datos

## Instrucciones de Despliegue (Setup)
Para inicializar el ecosistema de bases de datos desde cero, ejecutar en el siguiente orden:

1. **PostgreSQL (Capa de Verdad Central):**
   Ejecutar los scripts ubicados en la carpeta `/sql` (esquema, restricciones, triggers y roles).
2. **MongoDB (Capa Histórica Documental):**
   Ejecutar el script `consultas_mongodb.js` mediante `mongosh` para generar las proyecciones de pedidos.
3. **SQLite (Capa Móvil Offline):**
   Ejecutar el script `movil/semaforo.sql`, crear el esquema `STRICT` y cargar los datos cacheados en `producto_cache`.
