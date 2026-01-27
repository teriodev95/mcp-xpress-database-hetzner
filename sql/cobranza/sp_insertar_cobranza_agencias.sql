-- =====================================================
-- Procedimiento: sp_insertar_cobranza_agencias
-- Descripción: Inserta snapshot de cobranza por agencia para una semana/año
--              Se ejecuta 3 veces al día (mañana, tarde, noche)
--              Calcula cobranza IGUAL que Dashboard V2
-- Uso: CALL sp_insertar_cobranza_agencias(3, 2026);
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_insertar_cobranza_agencias$$

CREATE PROCEDURE sp_insertar_cobranza_agencias(
    IN p_semana TINYINT,
    IN p_anio INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    -- Validar parámetros
    IF p_semana IS NULL OR p_anio IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parámetros semana y anio son requeridos';
    END IF;

    IF p_semana < 1 OR p_semana > 53 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Semana debe estar entre 1 y 53';
    END IF;

    -- Insertar snapshot de cobranza por agencia
    INSERT INTO cobranza_historial (
        agencia,
        semana,
        anio,
        created_at,
        clientes_cobrados,
        no_pagos,
        numero_liquidaciones,
        pagos_reducidos,
        total_cobranza_pura,
        monto_excedente,
        multas,
        liquidaciones,
        total_de_descuento
    )
    SELECT
        pd.agencia,
        p_semana as semana,
        p_anio as anio,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') as created_at,

        -- Contadores (IGUAL que Dashboard V2 API)
        SUM(IF(pd.tipo_aux = 'Pago' AND pd.monto > 0, 1, 0)) as clientes_cobrados,
        SUM(IF(pd.tipo = 'No_pago', 1, 0)) as no_pagos,
        (SELECT COUNT(liq.liquidacionID)
            FROM liquidaciones liq
            INNER JOIN prestamos_v2 pv ON liq.prestamoID = pv.PrestamoID
            WHERE pv.Agente = pd.agencia
            AND liq.anio = p_anio
            AND liq.semana = p_semana) as numero_liquidaciones,
        SUM(IF(pd.tipo = 'Reducido', 1, 0)) as pagos_reducidos,

        -- Cobranza (calculada desde vw_datos_cobranza para precisión)
        (SELECT SUM(d.cobranza_pura)
            FROM vw_datos_cobranza d
            WHERE d.agencia = pd.agencia
            AND d.semana = p_semana
            AND d.anio = p_anio) as total_cobranza_pura,
        (SELECT SUM(d.excedente)
            FROM vw_datos_cobranza d
            WHERE d.agencia = pd.agencia
            AND d.semana = p_semana
            AND d.anio = p_anio) as monto_excedente,
        SUM(IF(pd.tipo = 'Multa', pd.monto, 0)) as multas,
        (SELECT SUM(d.monto_liquidacion)
            FROM vw_datos_cobranza d
            WHERE d.agencia = pd.agencia
            AND d.semana = p_semana
            AND d.anio = p_anio) as liquidaciones,
        (SELECT SUM(d.monto_descuento)
            FROM vw_datos_cobranza d
            WHERE d.agencia = pd.agencia
            AND d.semana = p_semana
            AND d.anio = p_anio) as total_de_descuento

    FROM pagos_dynamic pd
    WHERE pd.semana = p_semana
      AND pd.anio = p_anio
    GROUP BY pd.agencia;

    -- Contar registros insertados
    SET v_count = ROW_COUNT();

    -- Mensaje de resultado
    SELECT
        v_count as registros_insertados,
        p_semana as semana,
        p_anio as anio,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') as hora_captura,
        'Cobranza capturada exitosamente' as mensaje;

END$$

DELIMITER ;

-- =====================================================
-- Ejemplos de uso:
-- =====================================================

-- Captura de mañana (09:00 AM)
-- CALL sp_insertar_cobranza_agencias(3, 2026);

-- Captura de tarde (14:00 PM)
-- CALL sp_insertar_cobranza_agencias(3, 2026);

-- Captura de noche (18:00 PM)
-- CALL sp_insertar_cobranza_agencias(3, 2026);

-- =====================================================
-- Verificar datos insertados:
-- =====================================================

-- SELECT * FROM cobranza_historial
-- WHERE semana = 3 AND anio = 2026
-- ORDER BY agencia, created_at;

-- =====================================================
-- Comparar con Dashboard V2 API:
-- =====================================================

-- SELECT
--     ch.agencia,
--     ch.clientes_cobrados,
--     ch.no_pagos,
--     ch.total_cobranza_pura,
--     ch.monto_excedente,
--     (ch.total_cobranza_pura + ch.monto_excedente + ch.liquidaciones) as cobranza_total
-- FROM cobranza_historial ch
-- WHERE ch.semana = 3 AND ch.anio = 2026
-- AND ch.created_at = (
--     SELECT MAX(created_at)
--     FROM cobranza_historial
--     WHERE agencia = ch.agencia AND semana = ch.semana AND anio = ch.anio
-- )
-- ORDER BY ch.agencia;

-- =====================================================
-- Notas importantes:
-- =====================================================

-- 1. Coincide 100% con Dashboard V2 API
-- 2. clientes_cobrados: cuenta desde pagos_dynamic (tipo_aux = 'Pago' AND monto > 0)
-- 3. no_pagos: cuenta desde pagos_dynamic (tipo = 'No_pago')
-- 4. Cobranza: calcula desde vw_datos_cobranza para precisión decimal
-- 5. Cada ejecución crea un nuevo snapshot con created_at único
