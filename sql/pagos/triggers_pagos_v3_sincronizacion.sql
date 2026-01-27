-- =====================================================
-- TRIGGERS SINCRONIZACIÓN: pagos_v3 -> pagos_dynamic
-- =====================================================
--
-- OBJETIVO:
-- Mantener pagos_dynamic sincronizado con pagos_v3
-- Calcular AbreCon y CierraCon correctamente
--
-- FÓRMULA CLAVE:
-- - AbreCon = Total_a_pagar - SUM(pagos de semanas anteriores)
-- - CierraCon = AbreCon - SUM(pagos de la semana actual)
--
-- REFERENCIA: prestamos_view.saldo_al_iniciar_semana
-- =====================================================

-- =====================================================
-- ÍNDICES REQUERIDOS
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_pagos_dynamic_prestamo_semana
ON pagos_dynamic (prestamo_id, anio, semana);

CREATE INDEX IF NOT EXISTS idx_pagos_v3_prestamo_anio_semana
ON pagos_v3 (PrestamoID, Anio, Semana, PagoID);

-- =====================================================
-- TRIGGER BEFORE INSERT
-- =====================================================
-- Calcula AbreCon correctamente usando la fórmula:
-- Total_a_pagar - SUM(pagos anteriores a esta semana)

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
    DECLARE v_total_a_pagar DECIMAL(10, 2);
    DECLARE v_suma_pagos_anteriores DECIMAL(10, 2);
    DECLARE v_abre_con_existente DECIMAL(10, 2);

    -- =====================================================
    -- CALCULAR AbreCon CORRECTO
    -- Fórmula: Total_a_pagar - SUM(pagos de semanas anteriores)
    -- Esta es la misma fórmula que usa prestamos_view.saldo_al_iniciar_semana
    -- =====================================================

    -- Obtener Total_a_pagar del préstamo
    SELECT Total_a_pagar INTO v_total_a_pagar
    FROM prestamos_v2
    WHERE PrestamoID = NEW.PrestamoID
    LIMIT 1;

    -- Calcular suma de pagos de semanas ANTERIORES a esta
    SELECT COALESCE(SUM(pg.Monto), 0) INTO v_suma_pagos_anteriores
    FROM pagos_v3 pg
    JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
    JOIN calendario cal_nueva ON NEW.Semana = cal_nueva.semana AND NEW.Anio = cal_nueva.anio
    WHERE pg.PrestamoID = NEW.PrestamoID
      AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
      AND cal_pago.hasta < cal_nueva.desde;

    -- AbreCon = Total_a_pagar - pagos anteriores
    IF v_total_a_pagar IS NOT NULL THEN
        SET v_abre_con_calculado = v_total_a_pagar - v_suma_pagos_anteriores;
        SET NEW.AbreCon = v_abre_con_calculado;
    END IF;

    -- CierraCon = AbreCon - Monto del pago actual
    SET NEW.CierraCon = NEW.AbreCon - NEW.Monto;

    -- =====================================================
    -- MANEJO DE TIPOS ESPECIALES (Multa, Visita, No_pago)
    -- =====================================================
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
        -- =====================================================
        -- PAGOS NORMALES - Verificar si ya existe registro esta semana
        -- =====================================================
        SELECT prestamo_id, abre_con INTO v_existe_pago, v_abre_con_existente
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            -- Ya existe: ACUMULAR monto y recalcular cierra_con
            SELECT monto + NEW.Monto INTO v_monto_acumulado
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago'
            LIMIT 1;

            -- Usar el AbreCon existente (es el correcto para el inicio de semana)
            SET v_tarifa = LEAST(v_abre_con_existente, NEW.Tarifa);

            -- Determinar tipo de pago basado en monto ACUMULADO
            SET v_tipo = CASE
                WHEN NEW.Tipo = 'Liquidacion' THEN 'Liquidacion'
                WHEN v_monto_acumulado = 0 THEN 'No_Pago'
                WHEN v_monto_acumulado < v_tarifa THEN 'Reducido'
                WHEN v_monto_acumulado = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            -- IMPORTANTE: cierra_con = abre_con - monto_acumulado (NO cierra_con - monto)
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
            -- No existe: INSERTAR nuevo registro
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
-- TRIGGER AFTER UPDATE
-- =====================================================
-- Recalcula AbreCon y sincroniza cambios en pagos_dynamic

DROP TRIGGER IF EXISTS trg_pagos_v3_after_update_pagos;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` TRIGGER trg_pagos_v3_after_update_pagos
    AFTER UPDATE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_total DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);
    DECLARE v_abre_con_correcto DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);
    DECLARE v_suma_pagos_anteriores DECIMAL(10, 2);

    -- Solo procesar pagos normales
    IF NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN

        -- Verificar si existe registro en pagos_dynamic
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = NEW.PrestamoID
          AND anio = NEW.Anio
          AND semana = NEW.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            -- Calcular AbreCon correcto
            SELECT Total_a_pagar INTO v_total_a_pagar
            FROM prestamos_v2
            WHERE PrestamoID = NEW.PrestamoID
            LIMIT 1;

            SELECT COALESCE(SUM(pg.Monto), 0) INTO v_suma_pagos_anteriores
            FROM pagos_v3 pg
            JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
            JOIN calendario cal_actual ON NEW.Semana = cal_actual.semana AND NEW.Anio = cal_actual.anio
            WHERE pg.PrestamoID = NEW.PrestamoID
              AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
              AND cal_pago.hasta < cal_actual.desde;

            SET v_abre_con_correcto = v_total_a_pagar - v_suma_pagos_anteriores;

            -- Calcular monto total de TODOS los pagos de esta semana
            SELECT COALESCE(SUM(Monto), 0) INTO v_monto_total
            FROM pagos_v3
            WHERE PrestamoID = NEW.PrestamoID
              AND Anio = NEW.Anio
              AND Semana = NEW.Semana
              AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

            SET v_tarifa = LEAST(v_abre_con_correcto, NEW.Tarifa);

            -- Determinar tipo
            SET v_tipo = CASE
                WHEN v_monto_total = 0 THEN 'No_pago'
                WHEN NEW.Tipo = 'Liquidacion' THEN 'Liquidacion'
                WHEN v_monto_total < v_tarifa THEN 'Reducido'
                WHEN v_monto_total = v_tarifa THEN 'Pago'
                ELSE 'Excedente'
            END;

            -- Actualizar pagos_dynamic
            UPDATE pagos_dynamic
            SET monto = v_monto_total,
                fecha_pago = NEW.Fecha_pago,
                abre_con = v_abre_con_correcto,
                cierra_con = v_abre_con_correcto - v_monto_total,
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
-- TRIGGER AFTER DELETE
-- =====================================================
-- Recalcula cuando se elimina un pago

DROP TRIGGER IF EXISTS trg_pagos_v3_after_delete_pagos;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` TRIGGER trg_pagos_v3_after_delete_pagos
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE v_existe_pago VARCHAR(64);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_monto_total DECIMAL(10, 2);
    DECLARE v_tipo VARCHAR(16);
    DECLARE v_abre_con_correcto DECIMAL(10, 2);
    DECLARE v_total_a_pagar DECIMAL(10, 2);
    DECLARE v_suma_pagos_anteriores DECIMAL(10, 2);
    DECLARE v_count_pagos INT;

    -- Solo procesar pagos normales
    IF OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago') THEN

        -- Verificar si existe registro en pagos_dynamic
        SELECT prestamo_id INTO v_existe_pago
        FROM pagos_dynamic
        WHERE prestamo_id = OLD.PrestamoID
          AND anio = OLD.Anio
          AND semana = OLD.Semana
          AND tipo_aux = 'Pago'
        LIMIT 1;

        IF v_existe_pago IS NOT NULL THEN
            -- Contar cuántos pagos quedan en esta semana
            SELECT COUNT(*) INTO v_count_pagos
            FROM pagos_v3
            WHERE PrestamoID = OLD.PrestamoID
              AND Anio = OLD.Anio
              AND Semana = OLD.Semana
              AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

            IF v_count_pagos = 0 THEN
                -- No quedan pagos: eliminar registro de pagos_dynamic
                DELETE FROM pagos_dynamic
                WHERE prestamo_id = OLD.PrestamoID
                  AND anio = OLD.Anio
                  AND semana = OLD.Semana
                  AND tipo_aux = 'Pago';
            ELSE
                -- Quedan pagos: recalcular
                SELECT Total_a_pagar INTO v_total_a_pagar
                FROM prestamos_v2
                WHERE PrestamoID = OLD.PrestamoID
                LIMIT 1;

                SELECT COALESCE(SUM(pg.Monto), 0) INTO v_suma_pagos_anteriores
                FROM pagos_v3 pg
                JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
                JOIN calendario cal_old ON OLD.Semana = cal_old.semana AND OLD.Anio = cal_old.anio
                WHERE pg.PrestamoID = OLD.PrestamoID
                  AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
                  AND cal_pago.hasta < cal_old.desde;

                SET v_abre_con_correcto = v_total_a_pagar - v_suma_pagos_anteriores;

                -- Calcular monto total restante
                SELECT COALESCE(SUM(Monto), 0) INTO v_monto_total
                FROM pagos_v3
                WHERE PrestamoID = OLD.PrestamoID
                  AND Anio = OLD.Anio
                  AND Semana = OLD.Semana
                  AND Tipo NOT IN ('Multa', 'Visita', 'No_pago');

                SET v_tarifa = LEAST(v_abre_con_correcto, OLD.Tarifa);

                -- Determinar tipo
                SET v_tipo = CASE
                    WHEN v_monto_total = 0 THEN 'No_pago'
                    WHEN v_monto_total < v_tarifa THEN 'Reducido'
                    WHEN v_monto_total = v_tarifa THEN 'Pago'
                    ELSE 'Excedente'
                END;

                -- Actualizar pagos_dynamic
                UPDATE pagos_dynamic
                SET monto = v_monto_total,
                    abre_con = v_abre_con_correcto,
                    cierra_con = v_abre_con_correcto - v_monto_total,
                    tipo = v_tipo
                WHERE prestamo_id = OLD.PrestamoID
                  AND anio = OLD.Anio
                  AND semana = OLD.Semana
                  AND tipo_aux = 'Pago';
            END IF;
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- PROCEDIMIENTO: Corregir pagos_dynamic de últimas N semanas
-- =====================================================
-- Uso: CALL corregir_pagos_dynamic_ultimas_semanas(4);
-- Ejecutar de madrugada o manualmente cuando sea necesario

DROP PROCEDURE IF EXISTS corregir_pagos_dynamic_ultimas_semanas;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` PROCEDURE corregir_pagos_dynamic_ultimas_semanas(
    IN p_num_semanas INT
)
BEGIN
    DECLARE v_semana_actual INT;
    DECLARE v_anio_actual INT;
    DECLARE v_registros_corregidos INT DEFAULT 0;
    DECLARE v_inicio DATETIME;

    SET v_inicio = NOW();

    -- Obtener semana/año actual
    SELECT semana, anio INTO v_semana_actual, v_anio_actual
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- =====================================================
    -- Actualizar pagos_dynamic con AbreCon y CierraCon correctos
    -- Solo registros de las últimas N semanas
    -- =====================================================
    UPDATE pagos_dynamic pd
    JOIN (
        SELECT
            pd2.prestamo_id,
            pd2.semana,
            pd2.anio,
            pr.Total_a_pagar - COALESCE(
                (SELECT SUM(pg.Monto)
                 FROM pagos_v3 pg
                 JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
                 JOIN calendario cal_pd ON pd2.semana = cal_pd.semana AND pd2.anio = cal_pd.anio
                 WHERE pg.PrestamoID = pd2.prestamo_id
                   AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
                   AND cal_pago.hasta < cal_pd.desde), 0
            ) as abre_con_correcto,
            (SELECT COALESCE(SUM(pg.Monto), 0)
             FROM pagos_v3 pg
             WHERE pg.PrestamoID = pd2.prestamo_id
               AND pg.Semana = pd2.semana
               AND pg.Anio = pd2.anio
               AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
            ) as monto_total
        FROM pagos_dynamic pd2
        JOIN prestamos_v2 pr ON pd2.prestamo_id = pr.PrestamoID
        JOIN calendario cal ON pd2.semana = cal.semana AND pd2.anio = cal.anio
        JOIN calendario cal_actual ON DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'))
            BETWEEN cal_actual.desde AND cal_actual.hasta
        WHERE pd2.tipo_aux = 'Pago'
          -- Solo últimas N semanas (basado en fechas del calendario)
          AND cal.desde >= DATE_SUB(cal_actual.desde, INTERVAL (p_num_semanas * 7) DAY)
    ) calc ON pd.prestamo_id = calc.prestamo_id
          AND pd.semana = calc.semana
          AND pd.anio = calc.anio
    SET pd.abre_con = calc.abre_con_correcto,
        pd.monto = calc.monto_total,
        pd.cierra_con = calc.abre_con_correcto - calc.monto_total
    WHERE pd.tipo_aux = 'Pago'
      -- Solo actualizar si hay diferencia
      AND (pd.abre_con != calc.abre_con_correcto
           OR pd.monto != calc.monto_total
           OR pd.cierra_con != calc.abre_con_correcto - calc.monto_total);

    SET v_registros_corregidos = ROW_COUNT();

    -- Retornar resumen
    SELECT
        'Corrección completada' as status,
        p_num_semanas as semanas_procesadas,
        v_semana_actual as semana_actual,
        v_anio_actual as anio_actual,
        v_registros_corregidos as registros_corregidos,
        TIMEDIFF(NOW(), v_inicio) as tiempo_ejecucion;
END$$

DELIMITER ;

-- =====================================================
-- PROCEDIMIENTO: Corregir un préstamo específico
-- =====================================================
-- Uso: CALL corregir_pagos_dynamic_prestamo('L-11952-di');

DROP PROCEDURE IF EXISTS corregir_pagos_dynamic_prestamo;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` PROCEDURE corregir_pagos_dynamic_prestamo(
    IN p_prestamo_id VARCHAR(64)
)
BEGIN
    DECLARE v_total_a_pagar DECIMAL(10, 2);
    DECLARE v_registros_actualizados INT DEFAULT 0;

    -- Obtener total_a_pagar
    SELECT Total_a_pagar INTO v_total_a_pagar
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id
    LIMIT 1;

    IF v_total_a_pagar IS NULL THEN
        SELECT 'Préstamo no encontrado' as status, p_prestamo_id as prestamo_id;
    ELSE
        -- Actualizar cada registro en pagos_dynamic
        UPDATE pagos_dynamic pd
        JOIN (
            SELECT
                pd2.prestamo_id,
                pd2.semana,
                pd2.anio,
                v_total_a_pagar - COALESCE(
                    (SELECT SUM(pg.Monto)
                     FROM pagos_v3 pg
                     JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
                     JOIN calendario cal_pd ON pd2.semana = cal_pd.semana AND pd2.anio = cal_pd.anio
                     WHERE pg.PrestamoID = pd2.prestamo_id
                       AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
                       AND cal_pago.hasta < cal_pd.desde), 0
                ) as abre_con_correcto,
                (SELECT COALESCE(SUM(pg.Monto), 0)
                 FROM pagos_v3 pg
                 WHERE pg.PrestamoID = pd2.prestamo_id
                   AND pg.Semana = pd2.semana
                   AND pg.Anio = pd2.anio
                   AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
                ) as monto_total
            FROM pagos_dynamic pd2
            WHERE pd2.prestamo_id = p_prestamo_id
              AND pd2.tipo_aux = 'Pago'
        ) calc ON pd.prestamo_id = calc.prestamo_id
              AND pd.semana = calc.semana
              AND pd.anio = calc.anio
        SET pd.abre_con = calc.abre_con_correcto,
            pd.monto = calc.monto_total,
            pd.cierra_con = calc.abre_con_correcto - calc.monto_total
        WHERE pd.tipo_aux = 'Pago';

        SET v_registros_actualizados = ROW_COUNT();

        SELECT
            'Préstamo corregido' as status,
            p_prestamo_id as prestamo_id,
            v_registros_actualizados as registros_actualizados;
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- PROCEDIMIENTO: Corregir una semana específica
-- =====================================================
-- Uso: CALL corregir_pagos_dynamic_semana(48, 2025);

DROP PROCEDURE IF EXISTS corregir_pagos_dynamic_semana;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` PROCEDURE corregir_pagos_dynamic_semana(
    IN p_semana INT,
    IN p_anio INT
)
BEGIN
    DECLARE v_registros_corregidos INT DEFAULT 0;
    DECLARE v_inicio DATETIME;

    SET v_inicio = NOW();

    -- Actualizar todos los registros de la semana
    UPDATE pagos_dynamic pd
    JOIN (
        SELECT
            pd2.prestamo_id,
            pd2.semana,
            pd2.anio,
            pr.Total_a_pagar - COALESCE(
                (SELECT SUM(pg.Monto)
                 FROM pagos_v3 pg
                 JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
                 JOIN calendario cal_pd ON pd2.semana = cal_pd.semana AND pd2.anio = cal_pd.anio
                 WHERE pg.PrestamoID = pd2.prestamo_id
                   AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
                   AND cal_pago.hasta < cal_pd.desde), 0
            ) as abre_con_correcto,
            (SELECT COALESCE(SUM(pg.Monto), 0)
             FROM pagos_v3 pg
             WHERE pg.PrestamoID = pd2.prestamo_id
               AND pg.Semana = pd2.semana
               AND pg.Anio = pd2.anio
               AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
            ) as monto_total
        FROM pagos_dynamic pd2
        JOIN prestamos_v2 pr ON pd2.prestamo_id = pr.PrestamoID
        WHERE pd2.semana = p_semana
          AND pd2.anio = p_anio
          AND pd2.tipo_aux = 'Pago'
    ) calc ON pd.prestamo_id = calc.prestamo_id
          AND pd.semana = calc.semana
          AND pd.anio = calc.anio
    SET pd.abre_con = calc.abre_con_correcto,
        pd.monto = calc.monto_total,
        pd.cierra_con = calc.abre_con_correcto - calc.monto_total
    WHERE pd.tipo_aux = 'Pago';

    SET v_registros_corregidos = ROW_COUNT();

    SELECT
        'Semana corregida' as status,
        p_semana as semana,
        p_anio as anio,
        v_registros_corregidos as registros_corregidos,
        TIMEDIFF(NOW(), v_inicio) as tiempo_ejecucion;
END$$

DELIMITER ;

-- =====================================================
-- EVENT: Ejecutar corrección automáticamente a las 3 AM
-- =====================================================
-- Requiere: SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_corregir_pagos_dynamic_nocturno;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` EVENT evt_corregir_pagos_dynamic_nocturno
ON SCHEDULE EVERY 1 DAY
STARTS CONCAT(CURDATE() + INTERVAL 1 DAY, ' 03:00:00')
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Corrige AbreCon/CierraCon de pagos_dynamic para últimas 4 semanas'
DO
BEGIN
    CALL corregir_pagos_dynamic_ultimas_semanas(4);
END$$

DELIMITER ;

-- =====================================================
-- VERIFICACIÓN Y USO
-- =====================================================
--
-- 1. Verificar que los procedimientos existen:
-- SHOW PROCEDURE STATUS WHERE Db = DATABASE() AND Name LIKE 'corregir_pagos%';
--
-- 2. Corregir últimas 4 semanas manualmente:
-- CALL corregir_pagos_dynamic_ultimas_semanas(4);
--
-- 3. Corregir un préstamo específico:
-- CALL corregir_pagos_dynamic_prestamo('L-11952-di');
--
-- 4. Corregir una semana específica:
-- CALL corregir_pagos_dynamic_semana(48, 2025);
--
-- 5. Verificar el event scheduler:
-- SHOW VARIABLES LIKE 'event_scheduler';
-- SHOW EVENTS WHERE Name = 'evt_corregir_pagos_dynamic_nocturno';
--
-- 6. Habilitar event scheduler (si no está):
-- SET GLOBAL event_scheduler = ON;
--
-- =====================================================