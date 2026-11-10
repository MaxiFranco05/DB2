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

## 🏛️ Ecosistema Multi-Motor y Fuentes de Verdad

1. **PostgreSQL 16+ (`DB2` - Repositorio Principal):**
   * **Fuente de Verdad Canónica:** Precios oficiales, stock real, pedidos firmes, auditoría y control de acceso RBAC.
   * **Scripts:** Carpeta `/sql` (esquema, restricciones, triggers de integridad, roles, vistas materializadas y planes de mantenimiento).

2. **MongoDB 7+ (`DB2-NoSQL`):**
   * **Almacén Documental Histórico:** Colección desnormalizada de pedidos con embedding completo de ítems para lectura rápida sin `JOIN`s.
   * **Repositorio:** [github.com/MaxiFranco05/DB2-NoSQL](https://github.com/MaxiFranco05/DB2-NoSQL)

3. **SQLite 3.37+ (`DB2-NoSQL/food-store`):**
   * **Capa Móvil Offline:** Base de datos embebida con modo `STRICT` y dinero en centavos enteros para food trucks y ferias.
   * Regla de Oro: *"El móvil propone, el servidor dispone"* (0 ventas automáticas en PostgreSQL sin sincronización formal).
   * **Repositorio:** [github.com/MaxiFranco05/DB2-NoSQL/tree/main/food-store](https://github.com/MaxiFranco05/DB2-NoSQL/tree/main/food-store)

---

## 📁 Estructura del Proyecto

```text
FoodStore/
├── sql/                     # Scripts SQL canónicos (esquema, restricciones, roles, auditoría)
├── db/                      # Pruebas y backups
├── docs/                    # Informes técnicos de cada unidad, DUIA y bitácoras
│   ├── informe_tecnico_segunda_entrega.pdf   # Informe integrador oficial (Unidades 4 a 8)
│   ├── informe_u6.pdf                        # Informe post-incidente y RTO de la Unidad 6
│   └── informe_u7.pdf                        # Informe técnico de modelado NoSQL (Unidad 7)
├── movil/                   # Copia local de scripts SQLite y snapshot
├── .env.example             # Variables de entorno template (sin credenciales)
└── .kiro/                   # Especificaciones de ingeniería dirigida por especificaciones (SDD)
```

---

## 🚀 Despliegue y Base de Datos (PostgreSQL)

```bash
# Copiar variables de entorno
cp .env.example .env

# Aplicar esquema base
psql -d foodstore -f sql/schema.sql

# Aplicar restricciones y triggers de integridad
psql -d foodstore -f sql/restricciones.sql

# Aplicar roles y permisos (RBAC)
psql -d foodstore -f sql/roles.sql

# Backup
pg_dump -Fc -d foodstore > db/backups/backup_$(date +%Y%m%d).dump

# Restore
pg_restore -d foodstore db/backups/backup_YYYYMMDD.dump
```
