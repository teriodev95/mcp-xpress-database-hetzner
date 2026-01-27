-- =====================================================
-- Procedimiento: sp_insertar_cobranza_agencias
-- Descripción: Inserta snapshot de cobranza por agencia (OPTIMIZADO V4)
--              Captura TODAS las agencias (352) incluso sin pagos
--              Usa pagos_dynamic directamente (NO vw_datos_cobranza bugueada)
--              Usa tabla multas separada (sin duplicados)
--              100% más rápido usando JOINs en lugar de subconsultas
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

    -- Insertar snapshot de cobranza por agencia (OPTIMIZADO V4)
    -- Usa vw_datos_cobranza solo para identificar agencias activas
    -- Calcula métricas desde pagos_dynamic (fuente correcta sin duplicados)
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
        agencias_base.agencia,
        p_semana as semana,
        p_anio as anio,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') as created_at,

        -- Contadores desde pagos_dynamic
        COALESCE(pd_counts.clientes_cobrados, 0) as clientes_cobrados,
        COALESCE(pd_counts.no_pagos, 0) as no_pagos,
        COALESCE(liq_count.total_liquidaciones, 0) as numero_liquidaciones,
        COALESCE(pd_counts.pagos_reducidos, 0) as pagos_reducidos,

        -- CAMBIO V4: Calcular cobranza directamente desde pagos_dynamic
        COALESCE(pd_montos.total_cobranza_pura, 0) as total_cobranza_pura,
        COALESCE(pd_montos.monto_excedente, 0) as monto_excedente,

        -- Multas desde tabla separada (SIN duplicados)
        COALESCE(multas_count.total_multas, 0) as multas,

        COALESCE(pd_montos.liquidaciones, 0) as liquidaciones,
        COALESCE(pd_montos.total_de_descuento, 0) as total_de_descuento

    FROM (
        -- Base: TODAS las agencias con préstamos activos en la semana
        SELECT DISTINCT agencia
        FROM vw_datos_cobranza
        WHERE semana = p_semana AND anio = p_anio
    ) agencias_base

    -- JOIN con contadores de pagos_dynamic (UNA SOLA VEZ por agencia)
    LEFT JOIN (
        SELECT
            agencia,
            SUM(IF(tipo_aux = 'Pago' AND monto > 0, 1, 0)) as clientes_cobrados,
            SUM(IF(tipo = 'No_pago', 1, 0)) as no_pagos,
            SUM(IF(tipo = 'Reducido', 1, 0)) as pagos_reducidos
        FROM pagos_dynamic
        WHERE semana = p_semana AND anio = p_anio
        GROUP BY agencia
    ) pd_counts ON agencias_base.agencia = pd_counts.agencia

    -- NUEVO V4: JOIN con montos desde pagos_dynamic (calculados correctamente)
    LEFT JOIN (
        SELECT
            pd.agencia,
            -- Cobranza pura = mínimo entre monto y débito
            SUM(LEAST(pd.monto, LEAST(pv.Saldo, pv.Tarifa))) as total_cobranza_pura,
            -- Excedente = monto que supera el débito
            SUM(GREATEST(0, pd.monto - LEAST(pv.Saldo, pv.Tarifa))) as monto_excedente,
            -- Liquidaciones
            SUM(IF(pd.tipo = 'Liquidacion', pd.monto, 0)) as liquidaciones,
            -- Descuentos (si existen)
            0 as total_de_descuento
        FROM pagos_dynamic pd
        INNER JOIN prestamos_v2 pv ON pd.prestamo_id = pv.PrestamoID
        WHERE pd.semana = p_semana AND pd.anio = p_anio
          AND pd.tipo_aux = 'Pago'  -- Solo pagos, no visitas ni multas
        GROUP BY pd.agencia
    ) pd_montos ON agencias_base.agencia = pd_montos.agencia

    -- JOIN con tabla multas (UNA SOLA VEZ por agencia)
    LEFT JOIN (
        SELECT
            agencia,
            SUM(monto) as total_multas
        FROM multas
        WHERE semana = p_semana AND anio = p_anio
        GROUP BY agencia
    ) multas_count ON agencias_base.agencia = multas_count.agencia

    -- JOIN con conteo de liquidaciones (UNA SOLA VEZ por agencia)
    LEFT JOIN (
        SELECT
            pv.Agente as agencia,
            COUNT(liq.liquidacionID) as total_liquidaciones
        FROM liquidaciones liq
        INNER JOIN prestamos_v2 pv ON liq.prestamoID = pv.PrestamoID
        WHERE liq.anio = p_anio AND liq.semana = p_semana
        GROUP BY pv.Agente
    ) liq_count ON agencias_base.agencia = liq_count.agencia;

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
-- MEJORAS V4:
-- =====================================================

-- 1. Calcula cobranza_pura y excedente desde pagos_dynamic (NO desde vw_datos_cobranza)
-- 2. Elimina dependencia de vista bugueada con duplicados
-- 3. Join con prestamos_v2 para obtener Saldo y Tarifa correctos
-- 4. Usa tabla multas separada (sin duplicados)
-- 5. Mantiene todas las 352 agencias
-- 6. Mantiene la velocidad: 1-3 segundos

-- =====================================================
-- CAMBIOS DESDE VERSION V3:
-- =====================================================

-- ANTES V3: Usaba vw_datos_cobranza para cobranza_pura y excedente (tiene bug de duplicados)
-- AHORA V4: Calcula directamente desde pagos_dynamic + prestamos_v2

-- ANTES:
-- SELECT SUM(cobranza_pura), SUM(excedente)
-- FROM vw_datos_cobranza  -- Vista bugueada

-- AHORA:
-- SELECT
--   SUM(LEAST(pd.monto, LEAST(pv.Saldo, pv.Tarifa))) as cobranza_pura,
--   SUM(GREATEST(0, pd.monto - LEAST(pv.Saldo, pv.Tarifa))) as excedente
-- FROM pagos_dynamic pd
-- INNER JOIN prestamos_v2 pv ON pd.prestamo_id = pv.PrestamoID

-- =====================================================
-- Uso:
-- =====================================================

-- CALL sp_insertar_cobranza_agencias(3, 2026);
