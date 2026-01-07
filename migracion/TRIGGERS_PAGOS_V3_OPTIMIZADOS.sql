-- =====================================================
-- TRIGGERS OPTIMIZADOS PARA pagos_v3
-- Versión: 4.0
-- Fecha: 2025-11-26
--
-- LÓGICA:
-- Saldo = Total_a_pagar - SUM(pagos)
-- Cobrado = SUM(pagos)
-- Siempre recalcula basado en pagos_v3, nunca incremental
-- =====================================================

-- =====================================================
-- PASO 1: ELIMINAR TRIGGERS EXISTENTES
-- =====================================================
DROP TRIGGER IF EXISTS trg_pagos_v3_before_insert;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_insert;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_update_prestamos;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_update_pagos;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_delete_log;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_delete_prestamos;
DROP TRIGGER IF EXISTS trg_pagos_v3_after_delete_pagos;

-- =====================================================
-- TRIGGER 1: BEFORE INSERT - Sincroniza pagos_dynamic
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_before_insert
    BEFORE INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_acumulado DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);
    DECLARE v_tipo_aux VARCHAR(16);

    IF NEW.Tipo IN ('Multa', 'Visita', 'No_pago') THEN
        SET v_tipo = NEW.Tipo;
        SET v_tipo_aux = CASE
            WHEN NEW.Tipo = 'Multa' THEN 'Multa'
            WHEN NEW.Tipo = 'Visita' THEN 'Visita'
            ELSE 'Pago'
        END;

        INSERT INTO pagos_dynamic (
            prestamo_id, monto, semana, anio, es_primer_pago, abre_con, cierra_con,
            tarifa, agencia, tipo, fecha_pago, identificador, cliente, prestamo,
            quien_pago, comentario, pago_id, lat, lng, tipo_aux, recuperado_por
        ) VALUES (
            NEW.PrestamoID, NEW.Monto, NEW.Semana, NEW.Anio, NEW.EsPrimerPago,
            NEW.AbreCon, NEW.CierraCon, NEW.Tarifa, NEW.Agente, v_tipo, NEW.Fecha_pago,
            NEW.Identificador, NEW.cliente, NEW.prestamo, NEW.quien_pago, NEW.Comentario,
            NEW.PagoID, NEW.Lat, NEW.Lng, v_tipo_aux, NEW.recuperado_por
        );
    ELSE
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            SELECT LEAST(abre_con, tarifa), monto + NEW.Monto
            INTO v_tarifa, v_monto_acumulado
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            SET v_tipo = CASE
                WHEN NEW.Tipo = 'Liquidacion' THEN 'Liquidacion'
                WHEN v_monto_acumulado = 0 THEN 'No_Pago'
                WHEN v_monto_acumulado < v_tarifa THEN 'Reducido'
                WHEN v_monto_acumulado = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            UPDATE pagos_dynamic
            SET monto = v_monto_acumulado,
                fecha_pago = NEW.Fecha_pago,
                cierra_con = cierra_con - NEW.Monto,
                tipo = v_tipo,
                recuperado_por = NEW.recuperado_por,
                tipo_aux = 'Pago'
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago';
        ELSE
            SET v_tarifa = LEAST(NEW.AbreCon, NEW.Tarifa);
            SET v_tipo = CASE
                WHEN NEW.Monto = 0 THEN 'No_pago'
                WHEN NEW.Tipo = 'Liquidacion' THEN 'Liquidacion'
                WHEN NEW.Monto < v_tarifa THEN 'Reducido'
                WHEN NEW.Monto = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            INSERT INTO pagos_dynamic (
                prestamo_id, monto, semana, anio, es_primer_pago, abre_con, cierra_con,
                tarifa, agencia, tipo, fecha_pago, identificador, cliente, prestamo,
                quien_pago, comentario, pago_id, lat, lng, tipo_aux, recuperado_por
            ) VALUES (
                NEW.PrestamoID, NEW.Monto, NEW.Semana, NEW.Anio, NEW.EsPrimerPago,
                NEW.AbreCon, NEW.CierraCon, NEW.Tarifa, NEW.Agente, v_tipo, NEW.Fecha_pago,
                NEW.Identificador, NEW.cliente, NEW.prestamo, NEW.quien_pago, NEW.Comentario,
                NEW.PagoID, NEW.Lat, NEW.Lng, 'Pago', NEW.recuperado_por
            );
        END IF;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 2: AFTER INSERT - Recalcula saldo basado en SUM(pagos)
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_insert
    AFTER INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_total_pagos DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);

    IF NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN
        -- Calcular suma de todos los pagos del préstamo
        SELECT COALESCE(SUM(Monto), 0) INTO v_total_pagos
        FROM pagos_v3
        WHERE PrestamoID = NEW.PrestamoID
          AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

        -- Obtener total a pagar
        SELECT Total_a_pagar INTO v_total_a_pagar
        FROM prestamos_v2
        WHERE PrestamoID = NEW.PrestamoID;

        -- Actualizar prestamos_dynamic
        UPDATE prestamos_dynamic
        SET saldo = v_total_a_pagar - v_total_pagos,
            cobrado = v_total_pagos
        WHERE prestamo_id = NEW.PrestamoID;

        -- Actualizar prestamos_v2
        UPDATE prestamos_v2
        SET Saldo = v_total_a_pagar - v_total_pagos,
            Cobrado = v_total_pagos
        WHERE PrestamoID = NEW.PrestamoID;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 3: AFTER UPDATE - Recalcula saldo basado en SUM(pagos)
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_update_prestamos
    AFTER UPDATE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_total_pagos DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);

    IF NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago') OR OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN
        SELECT COALESCE(SUM(Monto), 0) INTO v_total_pagos
        FROM pagos_v3
        WHERE PrestamoID = NEW.PrestamoID
          AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

        SELECT Total_a_pagar INTO v_total_a_pagar
        FROM prestamos_v2
        WHERE PrestamoID = NEW.PrestamoID;

        UPDATE prestamos_dynamic
        SET saldo = v_total_a_pagar - v_total_pagos,
            cobrado = v_total_pagos
        WHERE prestamo_id = NEW.PrestamoID;

        UPDATE prestamos_v2
        SET Saldo = v_total_a_pagar - v_total_pagos,
            Cobrado = v_total_pagos
        WHERE PrestamoID = NEW.PrestamoID;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 4: AFTER UPDATE - Actualiza pagos_dynamic
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_update_pagos
    AFTER UPDATE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_nuevo DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);

    IF NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            SELECT LEAST(abre_con, tarifa), monto + NEW.Monto - OLD.Monto
            INTO v_tarifa, v_monto_nuevo
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            SET v_tipo = CASE
                WHEN v_monto_nuevo = 0 THEN 'No_pago'
                WHEN NEW.Tipo = 'Liquidacion' THEN 'Liquidacion'
                WHEN v_monto_nuevo < v_tarifa THEN 'Reducido'
                WHEN v_monto_nuevo = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            UPDATE pagos_dynamic
            SET monto = v_monto_nuevo,
                fecha_pago = NEW.Fecha_pago,
                cierra_con = cierra_con + OLD.Monto - NEW.Monto,
                tipo = v_tipo,
                recuperado_por = NEW.recuperado_por
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago';
        END IF;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 5: AFTER DELETE - Log de pagos eliminados
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_delete_log
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    INSERT INTO pagos_eliminados_log (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio, EsPrimerPago, AbreCon,
        CierraCon, Tarifa, Cliente, Agente, Tipo, Creado_desde, Identificador,
        Fecha_pago, Lat, Lng, Comentario, Datos_migracion, Created_at, Updated_at,
        Log, quien_pago, eliminado_en
    ) VALUES (
        OLD.PagoID, OLD.PrestamoID, OLD.Prestamo, OLD.Monto, OLD.Semana, OLD.Anio,
        OLD.EsPrimerPago, OLD.AbreCon, OLD.CierraCon, OLD.Tarifa, OLD.Cliente,
        OLD.Agente, OLD.Tipo, OLD.Creado_desde, OLD.Identificador, OLD.Fecha_pago,
        OLD.Lat, OLD.Lng, OLD.Comentario, OLD.Datos_migracion, OLD.Created_at,
        OLD.Updated_at, OLD.Log, OLD.quien_pago, NOW()
    );
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 6: AFTER DELETE - Recalcula saldo basado en SUM(pagos)
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_delete_prestamos
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_total_pagos DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);

    IF OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN
        SELECT COALESCE(SUM(Monto), 0) INTO v_total_pagos
        FROM pagos_v3
        WHERE PrestamoID = OLD.PrestamoID
          AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

        SELECT Total_a_pagar INTO v_total_a_pagar
        FROM prestamos_v2
        WHERE PrestamoID = OLD.PrestamoID;

        UPDATE prestamos_dynamic
        SET saldo = v_total_a_pagar - v_total_pagos,
            cobrado = v_total_pagos
        WHERE prestamo_id = OLD.PrestamoID;

        UPDATE prestamos_v2
        SET Saldo = v_total_a_pagar - v_total_pagos,
            Cobrado = v_total_pagos
        WHERE PrestamoID = OLD.PrestamoID;
    END IF;
END$$
DELIMITER ;

-- =====================================================
-- TRIGGER 7: AFTER DELETE - Actualiza pagos_dynamic
-- =====================================================
DELIMITER $$
CREATE TRIGGER trg_pagos_v3_after_delete_pagos
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_nuevo DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);

    IF OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = OLD.PrestamoID
          AND anio = OLD.Anio
          AND semana = OLD.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            SELECT LEAST(abre_con, tarifa), monto - OLD.Monto
            INTO v_tarifa, v_monto_nuevo
            FROM pagos_dynamic
            WHERE prestamo_id = OLD.PrestamoID
              AND anio = OLD.Anio
              AND semana = OLD.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            SET v_tipo = CASE
                WHEN v_monto_nuevo <= 0 THEN 'No_pago'
                WHEN v_monto_nuevo < v_tarifa THEN 'Reducido'
                WHEN v_monto_nuevo = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            UPDATE pagos_dynamic
            SET monto = GREATEST(v_monto_nuevo, 0),
                cierra_con = cierra_con + OLD.Monto,
                tipo = v_tipo
            WHERE prestamo_id = OLD.PrestamoID
              AND anio = OLD.Anio
              AND semana = OLD.Semana
              AND tipo_aux = 'Pago';
        END IF;
    END IF;
END$$
DELIMITER ;
