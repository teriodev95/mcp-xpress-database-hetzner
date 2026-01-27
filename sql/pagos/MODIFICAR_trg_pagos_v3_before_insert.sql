-- =====================================================
-- MODIFICACIÓN: trg_pagos_v3_before_insert
-- Cambio: NO insertar multas en pagos_dynamic
-- Solo insertar Visitas y No_pago
-- Las multas van directamente a tabla multas (trigger separado)
-- =====================================================

DELIMITER $$

DROP TRIGGER IF EXISTS trg_pagos_v3_before_insert$$

CREATE TRIGGER trg_pagos_v3_before_insert
    BEFORE INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_acumulado DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);
    DECLARE v_tipo_aux VARCHAR(16);
    DECLARE v_abre_con_calculado DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);
    DECLARE v_suma_pagos_anteriores DECIMAL(10, 2);
    DECLARE v_abre_con_existente DECIMAL(10, 2);

    -- =====================================================
    -- CALCULAR AbreCon CORRECTO
    -- =====================================================

    SELECT Total_a_pagar INTO v_total_a_pagar
    FROM prestamos_v2
    WHERE PrestamoID = NEW.PrestamoID
    LIMIT 1;

    SELECT COALESCE(SUM(pg.Monto), 0) INTO v_suma_pagos_anteriores
    FROM pagos_v3 pg
    JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
    JOIN calendario cal_nueva ON NEW.Semana = cal_nueva.semana AND NEW.Anio = cal_nueva.anio
    WHERE pg.PrestamoID = NEW.PrestamoID
      AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
      AND cal_pago.hasta < cal_nueva.desde;

    IF v_total_a_pagar IS NOT NULL THEN
        SET v_abre_con_calculado = v_total_a_pagar - v_suma_pagos_anteriores;
        SET NEW.AbreCon = v_abre_con_calculado;
    END IF;

    SET NEW.CierraCon = NEW.AbreCon - NEW.Monto;

    -- =====================================================
    -- CAMBIO: Solo procesar Visitas y No_pago (NO Multas)
    -- Las multas se manejan en trigger separado (trg_pagos_v3_multas_after_insert)
    -- =====================================================
    IF NEW.Tipo IN ('Visita', 'No_pago') THEN
        SET v_tipo = NEW.Tipo;
        SET v_tipo_aux = CASE
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
    -- =====================================================
    -- NOTA: Multas ya NO se insertan aquí
    -- Se manejan automáticamente por trg_pagos_v3_multas_after_insert → tabla multas
    -- =====================================================
    ELSEIF NEW.Tipo = 'Multa' THEN
        -- No hacer nada, el trigger AFTER INSERT se encarga de copiar a tabla multas
        SET v_tipo = NULL;
    ELSE
        -- =====================================================
        -- PAGOS NORMALES
        -- =====================================================
        SELECT prestamo_id, abre_con INTO v_existe_pago, v_abre_con_existente
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            -- Ya existe: ACUMULAR
            SELECT monto + NEW.Monto INTO v_monto_acumulado
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            SET v_tarifa = LEAST(v_abre_con_existente, NEW.Tarifa);

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
                cierra_con = v_abre_con_existente - v_monto_acumulado,
                tipo = v_tipo,
                recuperado_por = NEW.recuperado_por
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago';
        ELSE
            -- No existe: INSERTAR
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
-- VERIFICACIÓN
-- =====================================================
SELECT 'Trigger modificado exitosamente' as resultado;
SELECT 'Ahora las multas NO se insertan en pagos_dynamic' as nota;
SELECT 'Las multas van directo a tabla multas via trg_pagos_v3_multas_after_insert' as nota2;
