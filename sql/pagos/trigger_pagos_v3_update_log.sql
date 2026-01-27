-- =====================================================
-- TRIGGER DE AUDITORÍA PARA MODIFICACIONES EN pagos_v3
-- Estructura minimalista: solo campos clave + OLD/NEW
-- =====================================================

-- 1. CREAR TABLA DE LOG (minimalista)
-- Solo guarda los campos que típicamente cambian

CREATE TABLE IF NOT EXISTS pagos_modificados_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    PagoID VARCHAR(64) NOT NULL,
    PrestamoID VARCHAR(32),
    Semana INT,
    Anio INT,

    -- Valores anteriores (campos críticos)
    old_Monto DECIMAL(10,2),
    old_AbreCon DECIMAL(10,2),
    old_CierraCon DECIMAL(10,2),
    old_Tipo ENUM('Multa','No_pago','Visita','Reducido','Pago','Excedente','Liquidacion'),

    -- Valores nuevos
    new_Monto DECIMAL(10,2),
    new_AbreCon DECIMAL(10,2),
    new_CierraCon DECIMAL(10,2),
    new_Tipo ENUM('Multa','No_pago','Visita','Reducido','Pago','Excedente','Liquidacion'),

    -- Metadata
    modificado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_pago (PagoID),
    INDEX idx_prestamo (PrestamoID),
    INDEX idx_fecha (modificado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- 2. CREAR TRIGGER AFTER UPDATE

DELIMITER //

CREATE TRIGGER trg_pagos_v3_after_update_log
AFTER UPDATE ON pagos_v3
FOR EACH ROW
BEGIN
    -- Solo registrar si cambió algún campo crítico
    IF OLD.Monto != NEW.Monto
       OR OLD.AbreCon != NEW.AbreCon
       OR OLD.CierraCon != NEW.CierraCon
       OR OLD.Tipo != NEW.Tipo THEN

        INSERT INTO pagos_modificados_log (
            PagoID, PrestamoID, Semana, Anio,
            old_Monto, old_AbreCon, old_CierraCon, old_Tipo,
            new_Monto, new_AbreCon, new_CierraCon, new_Tipo,
            modificado_en
        ) VALUES (
            NEW.PagoID, NEW.PrestamoID, NEW.Semana, NEW.Anio,
            OLD.Monto, OLD.AbreCon, OLD.CierraCon, OLD.Tipo,
            NEW.Monto, NEW.AbreCon, NEW.CierraCon, NEW.Tipo,
            CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
        );
    END IF;
END //

DELIMITER ;


-- =====================================================
-- SIMULACIÓN DE EJEMPLO
-- =====================================================

-- Así se vería un registro en la tabla después de una modificación:

/*
+----+------------------+------------+--------+------+-----------+------------+-------------+----------+-----------+------------+-------------+----------+---------------------+
| id | PagoID           | PrestamoID | Semana | Anio | old_Monto | old_AbreCon| old_CierraCon| old_Tipo | new_Monto | new_AbreCon| new_CierraCon| new_Tipo | modificado_en       |
+----+------------------+------------+--------+------+-----------+------------+-------------+----------+-----------+------------+-------------+----------+---------------------+
|  1 | PAG-2025-001234  | PRE-00567  |     52 | 2025 |    150.00 |    1500.00 |     1350.00 | Pago     |    200.00 |    1500.00 |     1300.00 | Pago     | 2025-12-28 14:30:00 |
|  2 | PAG-2025-001235  | PRE-00568  |     52 | 2025 |    100.00 |     800.00 |      700.00 | Pago     |    800.00 |     800.00 |        0.00 | Liquidacion | 2025-12-28 15:45:00 |
+----+------------------+------------+--------+------+-----------+------------+-------------+----------+-----------+------------+-------------+----------+---------------------+

Ejemplo 1: Se corrigió el monto de 150 a 200, actualizando CierraCon
Ejemplo 2: Pago convertido a Liquidación, monto ajustado al saldo completo
*/


-- =====================================================
-- QUERIES ÚTILES PARA CONSULTAR EL LOG
-- =====================================================

-- Ver todas las modificaciones de hoy
-- SELECT * FROM pagos_modificados_log
-- WHERE DATE(modificado_en) = CURDATE()
-- ORDER BY modificado_en DESC;

-- Ver cambios de un préstamo específico
-- SELECT * FROM pagos_modificados_log
-- WHERE PrestamoID = 'PRE-00567'
-- ORDER BY modificado_en DESC;

-- Ver solo cambios de tipo (Pago -> Liquidacion, etc)
-- SELECT * FROM pagos_modificados_log
-- WHERE old_Tipo != new_Tipo
-- ORDER BY modificado_en DESC;

-- Resumen de modificaciones por día
-- SELECT DATE(modificado_en) as fecha, COUNT(*) as total_cambios
-- FROM pagos_modificados_log
-- GROUP BY DATE(modificado_en)
-- ORDER BY fecha DESC;
