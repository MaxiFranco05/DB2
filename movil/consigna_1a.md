# Consigna 1.a — Qué datos viajan a la tablet

## Tabla comparativa de datos que viajan y que no viajan

| Origen en el servidor (PostgreSQL) | ¿Viaja a la tablet (`producto_cache` en SQLite)? | Columnas involucradas | Motivo técnico y de seguridad |
| :--- | :---: | :--- | :--- |
| **Tabla `producto`** (datos operativos de catálogo) | **Sí** | `id`, `nombre`, `precio_centavos` (derivado de `precio * 100`), `stock_visto` (`stock`), `disponible` (`activo` y stock), `eliminado` (lápida/baja lógica) y `fecha_copia` | La tablet necesita mostrar el catálogo offline en la feria y congelar el precio visto al armar cada borrador. |
| **Tabla `producto`** (atributos no esenciales para el borrador) | **No** | `descripcion`, `categoria_id` | No son necesarios para validar ni construir borradores offline, reduciendo la huella de almacenamiento local. |
| **Tabla `usuario`** y credenciales/datos personales | **No** | `nombre`, `apellido`, `mail`, `celular`, `contrasena`, `rol_usuario` | Por privacidad y seguridad (protección de datos personales y principio de mínimo privilegio), ningún dato sensible ni hash de contraseña puede almacenarse en un dispositivo móvil expuesto a pérdida o robo en la feria. |

## Justificación y fuente de verdad

Hacia la tablet viajan únicamente las columnas operativas de `producto` necesarias para exhibir el catálogo sin señal y armar borradores (`id`, `nombre`, `precio_centavos`, `stock_visto`, `disponible`, `eliminado` y `fecha_copia`), mientras que se excluyen atributos descriptivos innecesarios y la totalidad de la tabla `usuario` (mails, celulares, nombres reales y hashes de contraseñas) para evitar exponer datos personales sensibles en un dispositivo físico vulnerable fuera del servidor. Esta separación responde a la regla de oro de la arquitectura ("el móvil propone, el servidor dispone"): la tablet solo consulta su caché local y encola borradores, mientras que **PostgreSQL es la única fuente de verdad** que decide el precio vigente, descuenta el stock real y confirma las ventas.
