-- =====================================================
-- Triggers: Separar multas de pagos_v3 y pagos_dynamic
-- Descripción: Mueve automáticamente registros tipo='Multa'
--              a la tabla multas y los elimina de pagos_dynamic
-- Fecha: 2026-01-20
-- =====================================================

DELIMITER $$

-- =====================================================
-- TRIGGER 1: pagos_v3 AFTER INSERT
-- Cuando se inserta una multa en pagos_v3, crear registro en tabla multas
-- =====================================================

DROP TRIGGER IF EXISTS trg_pagos_v3_multas_after_insert$$

CREATE TRIGGER trg_pagos_v3_multas_after_insert
AFTER INSERT ON pagos_v3
FOR EACH ROW
BEGIN
    -- Solo procesar si es una multa
    IF NEW.Tipo = 'Multa' THEN
        -- Insertar en tabla multas (campos simplificados)
        INSERT INTO multas (
            multa_id,
            prestamo_id,
            monto,
            semana,
            anio,
            agencia,
            fecha_multa,
            created_at
        )
        VALUES (
            NEW.pagoID,
            NEW.PrestamoID,
            NEW.Monto,
            NEW.Semana,
            NEW.Anio,
            NEW.Agente,
            NEW.Fecha_pago,
            CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
        )
        ON DUPLICATE KEY UPDATE
            monto = NEW.Monto,
            fecha_multa = NEW.Fecha_pago;
    END IF;
END$$

-- =====================================================
-- TRIGGER 2: pagos_dynamic AFTER INSERT
-- Cuando se inserta una multa en pagos_dynamic, eliminarla
-- =====================================================

DROP TRIGGER IF EXISTS trg_pagos_dynamic_multas_after_insert$$

CREATE TRIGGER trg_pagos_dynamic_multas_after_insert
AFTER INSERT ON pagos_dynamic
FOR EACH ROW
BEGIN
    -- Solo procesar si es una multa
    IF NEW.tipo = 'Multa' THEN
        -- Eliminar el registro recién insertado
        DELETE FROM pagos_dynamic
        WHERE prestamo_id = NEW.prestamo_id
          AND semana = NEW.semana
          AND anio = NEW.anio
          AND tipo = 'Multa';
    END IF;
END$$


