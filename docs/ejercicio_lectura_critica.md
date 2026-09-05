# 6.3. Ejercicio de Lectura Crítica

---

## Análisis y Corrección de Scripts Generados por IA

### Script 1
---
```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

* Filas que afectaría realmente: Afectaría a todas las filas de la tabla funcion sin excepción.

* Por qué no coincide con la consigna: El script carece de una cláusula WHERE, por lo que cambia la columna activa a FALSE en absolutamente todas las funciones registradas, provocando la baja masiva de funciones que continúan vigentes o en cartelera.

```sql
--Versión corregida:

UPDATE funcion
SET activa = FALSE
WHERE fecha_fin < CURRENT_DATE;
```

### Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

* Filas que afectaría realmente: Ninguna fila (0 filas eliminadas) en caso de que exista al menos un registro en la tabla producto donde categoria_id sea NULL.

* Por qué no coincide con la consigna: En SQL, el operador NOT IN evalúa mediante la lógica trivaluada (Three-Valued Logic). Si la subconsulta SELECT categoria_id FROM producto devuelve al menos un valor NULL, cualquier comparación id NOT IN (..., NULL) resulta en UNKNOWN / FALSE para todos los registros. Como consecuencia, el script falla silenciosamente y no elimina ninguna categoría sin productos.

```sql
Versión corregida (Opción recomendada con NOT EXISTS):

DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 
    FROM producto p 
    WHERE p.categoria_id = c.id
);

```
```sql
(Opción alternativa filtrando los valores NULL en la subconsulta):

DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id 
    FROM producto 
    WHERE categoria_id IS NOT NULL
);
```