-- =====================================================
-- TRIGGER MODIFICADO: trg_pagos_v3_before_insert
-- =====================================================
-- Cambios:
--   1. Calcula AbreCon basado en CierraCon de la semana anterior
--   2. Recalcula CierraCon basado en AbreCon correcto
--   3. Si no hay pago anterior, calcula saldo inicial = Total_a_pagar - SUM(pagos anteriores)
-- =====================================================

DROP TRIGGER IF EXISTS trg_pagos_v3_before_insert;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` TRIGGER trg_pagos_v3_before_insert
    BEFORE INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_acumulado DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);
    DECLARE v_tipo_aux VARCHAR(16);
    DECLARE v_abre_con_calculado DECIMAL(10, 2);
    DECLARE v_cierra_con_calculado DECIMAL(10, 2);

    -- =====================================================
    -- NUEVO: Calcular AbreCon correcto
    -- =====================================================
    -- Buscar el MIN(CierraCon) de la semana anterior (saldo final después de todos los pagos)
    SELECT MIN(CierraCon) INTO v_abre_con_calculado
    FROM pagos_v3
    WHERE PrestamoID = NEW.PrestamoID
      AND (Anio < NEW.Anio OR (Anio = NEW.Anio AND Semana < NEW.Semana))
      AND CONCAT(Anio, LPAD(Semana, 2, '0')) = (
          SELECT MAX(CONCAT(Anio, LPAD(Semana, 2, '0')))
          FROM pagos_v3
          WHERE PrestamoID = NEW.PrestamoID
            AND (Anio < NEW.Anio OR (Anio = NEW.Anio AND Semana < NEW.Semana))
      );

    -- Si no hay pago anterior, calcular saldo inicial = Total_a_pagar - SUM(pagos anteriores)
    IF v_abre_con_calculado IS NULL THEN
        SELECT p.Total_a_pagar - COALESCE(SUM(pv.Monto), 0) INTO v_abre_con_calculado
        FROM prestamos_v2 p
        LEFT JOIN pagos_v3 pv ON p.PrestamoID = pv.PrestamoID
            AND pv.Tipo NOT IN ('Multa', 'Visita')
        WHERE p.PrestamoID = NEW.PrestamoID
        GROUP BY p.Total_a_pagar;
    END IF;

    -- Si encontramos un valor, actualizar NEW.AbreCon
    IF v_abre_con_calculado IS NOT NULL THEN
        SET NEW.AbreCon = v_abre_con_calculado;
    END IF;

    -- Recalcular CierraCon basado en AbreCon correcto
    SET NEW.CierraCon = NEW.AbreCon - NEW.Monto;
    -- =====================================================

    -- Ignorar tipos especiales que no afectan el flujo principal
    IF NEW.Tipo IN ('Multa', 'Visita', 'No_pago') THEN
        -- Para estos tipos, solo insertar en pagos_dynamic sin lógica adicional
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
        -- Verificar si ya existe un registro de pago para esta semana/año
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            -- Ya existe: actualizar el registro existente
            SELECT
                LEAST(abre_con, tarifa),
                monto + NEW.Monto
            INTO v_tarifa, v_monto_acumulado
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            -- Determinar tipo de pago
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
            -- No existe: insertar nuevo registro
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
