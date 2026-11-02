BEGIN;

-- 1. Crear tabla de auditoria (regla snake_case y PK identity del steering.md)
CREATE TABLE auditoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_db VARCHAR(50) NOT NULL,
    tabla_afectada VARCHAR(50) NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 2. Crear la función del trigger
CREATE OR REPLACE FUNCTION registrar_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO auditoria (usuario_db, tabla_afectada, operacion, fecha_hora)
    VALUES (
        CURRENT_USER, 
        TG_TABLE_NAME, 
        TG_OP, 
        CURRENT_TIMESTAMP
    );
    
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. Asignar el trigger a las tablas principales
CREATE TRIGGER trg_auditoria_categoria
AFTER INSERT OR UPDATE OR DELETE ON categoria
FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_auditoria_producto
AFTER INSERT OR UPDATE OR DELETE ON producto
FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_auditoria_pedido
AFTER INSERT OR UPDATE OR DELETE ON pedido
FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

-- 4. Dar permiso al rol de escritura para que no falle al auditar
GRANT INSERT ON auditoria TO rol_app_escritura;

COMMIT;