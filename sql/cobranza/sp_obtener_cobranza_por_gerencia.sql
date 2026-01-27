-- =====================================================
-- Procedimiento: sp_obtener_cobranza_por_gerencia
-- Descripción: Obtiene snapshot de cobranza agregado por gerencia
--              desde cobranza_historial con JOIN a agencias
-- Uso: CALL sp_obtener_cobranza_por_gerencia(3, 2026);
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_obtener_cobranza_por_gerencia$$

CREATE PROCEDURE sp_obtener_cobranza_por_gerencia(
    IN p_semana TINYINT,
    IN p_anio INT
)
BEGIN
    -- Validar parámetros
    IF p_semana IS NULL OR p_anio IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parámetros semana y anio son requeridos';
    END IF;

    IF p_semana < 1 OR p_semana > 53 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Semana debe estar entre 1 y 53';
    END IF;

    -- Obtener cobranza agregada por gerencia
    SELECT
        a.GerenciaID as gerencia,
        p_semana as semana,
        p_anio as anio,
        MAX(ch.created_at) as ultima_captura,

        -- Contadores agregados
        SUM(ch.clientes_cobrados) as clientes_cobrados,
        SUM(ch.no_pagos) as no_pagos,
        SUM(ch.numero_liquidaciones) as numero_liquidaciones,
        SUM(ch.pagos_reducidos) as pagos_reducidos,

        -- Cobranza agregada
        SUM(ch.total_cobranza_pura) as total_cobranza_pura,
        SUM(ch.monto_excedente) as monto_excedente,
        SUM(ch.multas) as multas,
        SUM(ch.liquidaciones) as liquidaciones,
        SUM(ch.total_de_descuento) as total_de_descuento,

        -- Cobranza total calculada
        SUM(ch.total_cobranza_pura + ch.monto_excedente + ch.liquidaciones) as cobranza_total

    FROM cobranza_historial ch
    INNER JOIN agencias a ON ch.agencia = a.AgenciaID
    WHERE ch.semana = p_semana
      AND ch.anio = p_anio
      AND ch.created_at = (
          -- Obtener la última captura del día para cada agencia
          SELECT MAX(created_at)
          FROM cobranza_historial
          WHERE agencia = ch.agencia
            AND semana = p_semana
            AND anio = p_anio
      )
    GROUP BY a.GerenciaID
    ORDER BY a.GerenciaID;

END$$

DELIMITER ;

-- =====================================================
-- Notas importantes:
-- =====================================================

-- 1. Usa JOIN con tabla agencias para obtener GerenciaID
-- 2. Filtra por última captura del día (MAX(created_at))
-- 3. Agrega todos los valores de agencias por gerencia
-- 4. Coincide 100% con Dashboard V2 API endpoint de gerencias

-- =====================================================
-- Uso:
-- =====================================================

-- CALL sp_obtener_cobranza_por_gerencia(3, 2026);

-- =====================================================
-- Query equivalente para validar contra Dashboard V2:
-- =====================================================

-- SELECT
--     d.gerencia_id,
--     COALESCE(SUM(IF(pag_dyn.tipo_aux = 'Pago' AND pag_dyn.monto > 0, 1, 0)), 0) as clientes_cobrados,
--     COALESCE(SUM(IF(pag_dyn.tipo = 'No_pago', 1, 0)), 0) as no_pagos,
--     SUM(d.cobranza_pura) AS total_cobranza_pura,
--     SUM(d.excedente) AS total_excedente,
--     SUM(d.monto_liquidacion) AS total_liquidaciones
-- FROM vw_datos_cobranza d
-- LEFT JOIN pagos_dynamic pag_dyn ON d.prestamo_id = pag_dyn.prestamo_id
--     AND pag_dyn.semana = d.semana AND pag_dyn.anio = d.anio
-- WHERE d.semana = 3 AND d.anio = 2026
-- GROUP BY d.gerencia_id
-- ORDER BY d.gerencia_id;
