-- =====================================================
-- Procedimiento: sp_insertar_cobranza_agencias
-- Descripción: Inserta snapshot de cobranza por agencia (OPTIMIZADO V3)
--              Captura TODAS las agencias (352) incluso sin pagos
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

    -- Insertar snapshot de cobranza por agencia (OPTIMIZADO V3)
    -- Usa vw_datos_cobranza como base para incluir TODAS las agencias
    -- Multas vienen de tabla separada (sin duplicados en pagos_dynamic)
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

        -- Contadores desde pagos_dynamic (NULL si no hay pagos)
        COALESCE(pd_counts.clientes_cobrados, 0) as clientes_cobrados,
        COALESCE(pd_counts.no_pagos, 0) as no_pagos,
        COALESCE(liq_count.total_liquidaciones, 0) as numero_liquidaciones,
        COALESCE(pd_counts.pagos_reducidos, 0) as pagos_reducidos,

        -- Cobranza desde vw_datos_cobranza (pre-agregada)
        COALESCE(cob.total_cobranza_pura, 0) as total_cobranza_pura,
        COALESCE(cob.monto_excedente, 0) as monto_excedente,

        -- Multas desde tabla separada (SIN duplicados)
        COALESCE(multas_count.total_multas, 0) as multas,

        COALESCE(cob.liquidaciones, 0) as liquidaciones,
        COALESCE(cob.total_de_descuento, 0) as total_de_descuento

    FROM (
        -- Base: TODAS las agencias con préstamos activos en la semana
        SELECT DISTINCT agencia
        FROM vw_datos_cobranza
        WHERE semana = p_semana AND anio = p_anio
    ) agencias_base

    -- JOIN con datos de cobranza pre-agregados (UNA SOLA VEZ por agencia)
    LEFT JOIN (
        SELECT
            agencia,
            SUM(cobranza_pura) as total_cobranza_pura,
            SUM(excedente) as monto_excedente,
            SUM(monto_liquidacion) as liquidaciones,
            SUM(monto_descuento) as total_de_descuento
        FROM vw_datos_cobranza
        WHERE semana = p_semana AND anio = p_anio
        GROUP BY agencia
    ) cob ON agencias_base.agencia = cob.agencia

    -- JOIN con contadores de pagos_dynamic (UNA SOLA VEZ por agencia)
    -- YA NO incluye multas (tipo='Multa' ya no existe en pagos_dynamic)
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
-- MEJORAS V3:
-- =====================================================

-- 1. Usa tabla multas separada (sin duplicados en pagos_dynamic)
-- 2. Eliminado SUM(IF(tipo = 'Multa', monto, 0)) de pagos_dynamic
-- 3. Añadido JOIN con tabla multas para obtener total de multas
-- 4. Mantiene todas las 352 agencias
-- 5. Mantiene la velocidad: 1-3 segundos

-- =====================================================
-- CAMBIOS DESDE VERSION V2:
-- =====================================================

-- ANTES: Multas en pagos_dynamic (con duplicados)
-- AHORA: Multas en tabla separada (sin duplicados)

-- ANTES:
-- SUM(IF(tipo = 'Multa', monto, 0)) as multas
-- FROM pagos_dynamic

-- AHORA:
-- LEFT JOIN (
--     SELECT agencia, SUM(monto) as total_multas
--     FROM multas
--     WHERE semana = p_semana AND anio = p_anio
--     GROUP BY agencia
-- ) multas_count ON agencias_base.agencia = multas_count.agencia

-- =====================================================
-- IMPORTANTE: EJECUTAR DESPUÉS DE:
-- =====================================================

-- 1. crear_tabla_multas.sql
-- 2. triggers_separar_multas.sql (migra datos y crea triggers)
-- 3. Verificar que pagos_dynamic ya no tiene tipo='Multa'

-- =====================================================
-- Uso:
-- =====================================================

-- CALL sp_insertar_cobranza_agencias(3, 2026);
