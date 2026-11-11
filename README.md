# FoodStore — Sistema de Base de Datos Relacional (PostgreSQL)

> [!IMPORTANT]
> **División de Repositorios (Unidades 7 y 8):**  
> Por consigna académica y separación arquitectónica de tecnologías, los módulos de **NoSQL (MongoDB - Unidad 7)** y **Persistencia Móvil Desconectada (SQLite STRICT - Unidad 8)** se encuentran en su repositorio oficial dedicado:  
> 🔗 **[https://github.com/MaxiFranco05/DB2-NoSQL](https://github.com/MaxiFranco05/DB2-NoSQL)**  
> Este repositorio (`DB2`) contiene la **Capa de Verdad Central Relacional en PostgreSQL 16+** (Unidades 1 a 6).

---

### Integrantes del Equipo (Comisión C3 · Prof. Sergio Neira):
* **Máximo Franco**
* **Andrés Novello**
* **Octavio Fiore**

---

## 📑 Informe Técnico Integrador — Segunda Entrega (Unidades 4 a 8)

El informe técnico unificado que acredita el cumplimiento de los **14 objetivos** y responde a los **5 puntos obligatorios** de la consigna oficial se encuentra disponible en:
* 📄 **Versión PDF:** [`docs/informe_tecnico_segunda_entrega.pdf`](docs/informe_tecnico_segunda_entrega.pdf)
* 📝 **Versión Markdown:** [`docs/informe_tecnico_segunda_entrega.md`](docs/informe_tecnico_segunda_entrega.md)

---

## 🎤 Guión de Defensa Oral (Presentación ante la Cátedra)

| Rol / Integrante | Eje Temático a Defender | Conceptos Clave y Respuestas a Preguntas Típicas |
| :--- | :--- | :--- |
| **Máximo Franco** | **Arquitectura Global y Ecosistema Multi-Motor** | • Explica la coexistencia de los tres motores y la separación de responsabilidades.<br>• Defiende la regla de oro: *"El móvil propone, el servidor dispone"*.<br>• Justifica la refactorización a FNBC en logística (U4) para eliminar anomalías de actualización de responsables de depósito, y la desnormalización controlada con triggers. |
| **Andrés Novello** | **Seguridad, Mantenimiento y Recuperación ante Desastres** | • Defiende el esquema RBAC de 6 roles bajo mínimo privilegio (U5) y cómo se contuvo el simulacro de acceso indebido de `app_web` (`GRANT` y `DROP TABLE` denegados).<br>• Expone el simulacro de desastre (U6): **RTO medido de 6,95 segundos** (frente a SLA < 300 s) y RPO de 332 s con 100% de paridad.<br>• Explica por qué se descartó `VACUUM FULL` (bloqueo exclusivo) en favor de `VACUUM ANALYZE`. |
| **Octavio Fiore** | **Persistencia Móvil (SQLite) y Almacén NoSQL (MongoDB)** | • Demuestra la base de la tablet (U8): modo `STRICT`, dinero en centavos enteros (`INTEGER`) para evitar redondeos IEEE 754, y el snapshot con `fecha_copia`.<br>• Explica el orden del semáforo: **Rechazo (stock/baja lógica) > Conflicto de precio (C2) > Aprobado**.<br>• Defiende el modelo documental en MongoDB (U7): importes en `Decimal128` (`NumberDecimal`), validador `$jsonSchema` e inmutabilidad de precios embebidos. |

---

## 🛠️ Guía de Reproducción de la Tablet desde Cero (Paso a Paso)

Para reproducir la capa móvil desconectada de forma autónoma en una terminal:

```bash
# 1. Exportar la instantánea desde PostgreSQL con fecha_copia
psql -d foodstore -f movil/10_snapshot_catalogo.sql

# 2. Inicializar la base SQLite en modo STRICT con sus 5 tablas
sqlite3 movil/foodstore_movil.db < movil/schema_sqlite.sql

# 3. Importar el CSV hacia snapshot_servidor y poblar producto_cache
sqlite3 movil/foodstore_movil.db <<EOF
.mode csv
.import movil/servidor_snapshot.csv snapshot_servidor
EOF
sqlite3 movil/foodstore_movil.db < movil/import_snapshot.sql

# 4. Ejecutar la batería de simulación completa (C2 a C6) de forma 100% automatizada
sqlite3 movil/foodstore_movil.db < movil/casos_simulacion.sql

# 5. Comprobar el aislamiento en PostgreSQL (0 pedidos nuevos creados en central)
psql -d foodstore -f postgresql/consulta_final.sql
```

---

## 🏛️ Ecosistema Multi-Motor y Fuentes de Verdad

1. **PostgreSQL 16+ (`DB2` - Repositorio Principal):**
   * **Fuente de Verdad Canónica:** Precios oficiales, stock real, pedidos firmes, auditoría y control de acceso RBAC.
   * **Scripts:** Carpeta `/sql` (esquema, restricciones, triggers de integridad, roles, vistas materializadas y planes de mantenimiento).

2. **MongoDB 7+ (`DB2-NoSQL`):**
   * **Almacén Documental Histórico:** Colección desnormalizada de pedidos con embedding completo de ítems, importes en `Decimal128` y validador `$jsonSchema`.
   * **Repositorio:** [github.com/MaxiFranco05/DB2-NoSQL](https://github.com/MaxiFranco05/DB2-NoSQL)

3. **SQLite 3.37+ (`DB2-NoSQL/food-store`):**
   * **Capa Móvil Offline:** Base de datos embebida con modo `STRICT` y dinero en centavos enteros para food trucks y ferias.
   * **Repositorio:** [github.com/MaxiFranco05/DB2-NoSQL/tree/main/food-store](https://github.com/MaxiFranco05/DB2-NoSQL/tree/main/food-store)
