-- =====================================================
-- Procedimiento: Historial de Préstamos por Persona (V2 - CORREGIDO)
-- =====================================================
-- Retorna todos los préstamos (activos + completados) de una persona
-- con criterios de evaluación incluyendo análisis CORRECTO de pagos reducidos
--
-- CORRECCIONES:
-- - Agrupa pagos por Semana/Año (maneja parcialidades)
-- - Excluye EsPrimerPago = 1 (primeros pagos no cuentan como reducidos)
-- - Excluye últimos pagos cuando saldo < tarifa
-- - Compara suma semanal vs tarifa
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `obtener_historial_prestamos_persona`$$

CREATE PROCEDURE `obtener_historial_prestamos_persona`(
    IN p_cliente_persona_id VARCHAR(64)
)
BEGIN
    -- Préstamos completados
    SELECT
        p.PrestamoID,
        'COMPLETADO' AS tipo_prestamo,
        p.Gerencia,
        p.Agente,
        p.Semana,
        p.Anio,
        p.plazo,
        p.Tarifa,
        p.Saldo,
        p.Cobrado,
        p.Monto_otorgado,

        -- Estadísticas de pagos
        COALESCE(pagos.total_semanas, 0) AS total_semanas_pagadas,
        COALESCE(pagos.semanas_sin_pago, 0) AS semanas_sin_pago,
        COALESCE(pagos.semanas_reducidas, 0) AS semanas_reducidas,
        COALESCE(pagos.pct_reducidos, 0.00) AS pct_reducidos,
        COALESCE(pagos.promedio_monto_reducido, 0.00) AS promedio_monto_reducido,

        -- Criterios de filtrado
        (p.Saldo < p.Tarifa * 2) AS cumple_saldo,
        (COALESCE(pagos.total_semanas, 0) <= p.plazo) AS cumple_plazo,
        (COALESCE(pagos.semanas_sin_pago, 0) = 0) AS cumple_sin_no_pagos,

        -- Criterio de reducidos
        (COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.70) AS cumple_sin_reducidos_graves,
        (COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.50) AS cumple_minimo_reducido,

        -- Resultado final
        CASE
            WHEN COALESCE(pagos.promedio_monto_reducido, p.Tarifa) < p.Tarifa * 0.50
                THEN 'NO APTO - REDUCIDO < 50%'
            WHEN (p.Saldo < p.Tarifa * 2)
                AND (COALESCE(pagos.total_semanas, 0) <= p.plazo)
                AND COALESCE(pagos.semanas_sin_pago, 0) = 0
                AND COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.70
                THEN 'CUMPLE'
            WHEN COALESCE(pagos.promedio_monto_reducido, p.Tarifa) BETWEEN p.Tarifa * 0.50 AND p.Tarifa * 0.69
                THEN 'CUMPLE CON MONTO REDUCIDO'
            ELSE 'NO CUMPLE'
        END AS resultado

    FROM prestamos_completados p
    LEFT JOIN (
        -- Agrupar pagos por semana/año
        SELECT
            semanas.PrestamoID,
            COUNT(*) AS total_semanas,

            -- Semanas sin pago (monto total = 0)
            SUM(CASE WHEN semanas.monto_semanal = 0 THEN 1 ELSE 0 END) AS semanas_sin_pago,

            -- Semanas reducidas (monto < tarifa, saldo antes > tarifa, NO primer pago)
            SUM(CASE
                WHEN semanas.monto_semanal > 0
                    AND semanas.monto_semanal < semanas.Tarifa
                    AND semanas.saldo_antes > semanas.Tarifa
                    AND semanas.es_primer_pago = 0
                THEN 1
                ELSE 0
            END) AS semanas_reducidas,

            -- Porcentaje de semanas reducidas (excluyendo primeros pagos)
            ROUND(
                (SUM(CASE
                    WHEN semanas.monto_semanal > 0
                        AND semanas.monto_semanal < semanas.Tarifa
                        AND semanas.saldo_antes > semanas.Tarifa
                        AND semanas.es_primer_pago = 0
                    THEN 1
                    ELSE 0
                END) * 100.0) / NULLIF(SUM(CASE WHEN semanas.monto_semanal > 0 AND semanas.es_primer_pago = 0 THEN 1 ELSE 0 END), 0)
            , 2) AS pct_reducidos,

            -- Promedio del monto pagado en semanas reducidas
            ROUND(AVG(CASE
                WHEN semanas.monto_semanal > 0
                    AND semanas.monto_semanal < semanas.Tarifa
                    AND semanas.saldo_antes > semanas.Tarifa
                    AND semanas.es_primer_pago = 0
                THEN semanas.monto_semanal
                ELSE NULL
            END), 2) AS promedio_monto_reducido

        FROM (
            -- Agrupar pagos por PrestamoID, Semana, Año
            SELECT
                pv.PrestamoID,
                pv.Semana,
                pv.Anio,
                pc.Tarifa,
                pc.Monto_otorgado,
                SUM(pv.Monto) AS monto_semanal,
                MAX(pv.EsPrimerPago) AS es_primer_pago,

                -- Saldo antes de los pagos de esta semana
                (pc.Monto_otorgado - (
                    SELECT COALESCE(SUM(pv2.Monto), 0)
                    FROM pagos_v3 pv2
                    WHERE pv2.PrestamoID = pv.PrestamoID
                        AND (pv2.Anio < pv.Anio
                            OR (pv2.Anio = pv.Anio AND pv2.Semana < pv.Semana))
                )) AS saldo_antes

            FROM pagos_v3 pv
            INNER JOIN prestamos_completados pc ON pv.PrestamoID = pc.PrestamoID
            GROUP BY pv.PrestamoID, pv.Semana, pv.Anio, pc.Tarifa, pc.Monto_otorgado
        ) AS semanas

        GROUP BY semanas.PrestamoID
    ) AS pagos ON p.PrestamoID = pagos.PrestamoID
    WHERE p.cliente_persona_id = p_cliente_persona_id

    UNION ALL

    -- Préstamos activos
    SELECT
        p.PrestamoID,
        'ACTIVO' AS tipo_prestamo,
        p.Gerencia,
        p.Agente,
        p.Semana,
        p.Anio,
        p.plazo,
        p.Tarifa,
        pd.saldo AS Saldo,
        pd.cobrado AS Cobrado,
        p.Monto_otorgado,

        -- Estadísticas de pagos
        COALESCE(pagos.total_semanas, 0) AS total_semanas_pagadas,
        COALESCE(pagos.semanas_sin_pago, 0) AS semanas_sin_pago,
        COALESCE(pagos.semanas_reducidas, 0) AS semanas_reducidas,
        COALESCE(pagos.pct_reducidos, 0.00) AS pct_reducidos,
        COALESCE(pagos.promedio_monto_reducido, 0.00) AS promedio_monto_reducido,

        -- Criterios de filtrado
        (pd.saldo < p.Tarifa * 2) AS cumple_saldo,
        (COALESCE(pagos.total_semanas, 0) <= p.plazo) AS cumple_plazo,
        (COALESCE(pagos.semanas_sin_pago, 0) = 0) AS cumple_sin_no_pagos,

        -- Criterio de reducidos
        (COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.70) AS cumple_sin_reducidos_graves,
        (COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.50) AS cumple_minimo_reducido,

        -- Resultado final
        CASE
            WHEN COALESCE(pagos.promedio_monto_reducido, p.Tarifa) < p.Tarifa * 0.50
                THEN 'NO APTO - REDUCIDO < 50%'
            WHEN (pd.saldo < p.Tarifa * 2)
                AND (COALESCE(pagos.total_semanas, 0) <= p.plazo)
                AND COALESCE(pagos.semanas_sin_pago, 0) = 0
                AND COALESCE(pagos.promedio_monto_reducido, p.Tarifa) >= p.Tarifa * 0.70
                THEN 'CUMPLE'
            WHEN COALESCE(pagos.promedio_monto_reducido, p.Tarifa) BETWEEN p.Tarifa * 0.50 AND p.Tarifa * 0.69
                THEN 'CUMPLE CON MONTO REDUCIDO'
            ELSE 'NO CUMPLE'
        END AS resultado

    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    LEFT JOIN (
        -- Agrupar pagos por semana/año
        SELECT
            semanas.PrestamoID,
            COUNT(*) AS total_semanas,

            -- Semanas sin pago (monto total = 0)
            SUM(CASE WHEN semanas.monto_semanal = 0 THEN 1 ELSE 0 END) AS semanas_sin_pago,

            -- Semanas reducidas (monto < tarifa, saldo antes > tarifa, NO primer pago)
            SUM(CASE
                WHEN semanas.monto_semanal > 0
                    AND semanas.monto_semanal < semanas.Tarifa
                    AND semanas.saldo_antes > semanas.Tarifa
                    AND semanas.es_primer_pago = 0
                THEN 1
                ELSE 0
            END) AS semanas_reducidas,

            -- Porcentaje de semanas reducidas (excluyendo primeros pagos)
            ROUND(
                (SUM(CASE
                    WHEN semanas.monto_semanal > 0
                        AND semanas.monto_semanal < semanas.Tarifa
                        AND semanas.saldo_antes > semanas.Tarifa
                        AND semanas.es_primer_pago = 0
                    THEN 1
                    ELSE 0
                END) * 100.0) / NULLIF(SUM(CASE WHEN semanas.monto_semanal > 0 AND semanas.es_primer_pago = 0 THEN 1 ELSE 0 END), 0)
            , 2) AS pct_reducidos,

            -- Promedio del monto pagado en semanas reducidas
            ROUND(AVG(CASE
                WHEN semanas.monto_semanal > 0
                    AND semanas.monto_semanal < semanas.Tarifa
                    AND semanas.saldo_antes > semanas.Tarifa
                    AND semanas.es_primer_pago = 0
                THEN semanas.monto_semanal
                ELSE NULL
            END), 2) AS promedio_monto_reducido

        FROM (
            -- Agrupar pagos por PrestamoID, Semana, Año
            SELECT
                pv.PrestamoID,
                pv.Semana,
                pv.Anio,
                p2.Tarifa,
                p2.Monto_otorgado,
                SUM(pv.Monto) AS monto_semanal,
                MAX(pv.EsPrimerPago) AS es_primer_pago,

                -- Saldo antes de los pagos de esta semana
                (p2.Monto_otorgado - (
                    SELECT COALESCE(SUM(pv2.Monto), 0)
                    FROM pagos_v3 pv2
                    WHERE pv2.PrestamoID = pv.PrestamoID
                        AND (pv2.Anio < pv.Anio
                            OR (pv2.Anio = pv.Anio AND pv2.Semana < pv.Semana))
                )) AS saldo_antes

            FROM pagos_v3 pv
            INNER JOIN prestamos_v2 p2 ON pv.PrestamoID = p2.PrestamoID
            GROUP BY pv.PrestamoID, pv.Semana, pv.Anio, p2.Tarifa, p2.Monto_otorgado
        ) AS semanas

        GROUP BY semanas.PrestamoID
    ) AS pagos ON p.PrestamoID = pagos.PrestamoID
    WHERE p.cliente_persona_id = p_cliente_persona_id

    ORDER BY Anio DESC, Semana DESC;

END$$

DELIMITER ;

-- =====================================================
-- Uso del procedimiento
-- =====================================================
-- CALL obtener_historial_prestamos_persona('A0MV-1781-SDCH-de');
-- CALL obtener_historial_prestamos_persona('B0EH-2977-NBOB-de');
-- =====================================================

-- =====================================================
-- Campos Retornados (ACTUALIZADOS)
-- =====================================================
-- PrestamoID, tipo_prestamo (ACTIVO/COMPLETADO)
-- Gerencia, Agente, Semana, Anio, plazo
-- Tarifa, Saldo, Cobrado, Monto_otorgado
--
-- ESTADÍSTICAS DE PAGOS:
-- - total_semanas_pagadas: Total de semanas con al menos un pago
-- - semanas_sin_pago: Semanas con monto total = 0
-- - semanas_reducidas: Semanas donde suma < Tarifa (excluyendo primeras y últimas)
-- - pct_reducidos: % de semanas reducidas sobre total (ej: 25.50 = 25.50%)
-- - promedio_monto_reducido: Promedio en $ de las semanas reducidas (ej: 350.75)
--
-- CRITERIOS:
-- - cumple_saldo: Saldo < 2 tarifas
-- - cumple_plazo: total_semanas_pagadas <= plazo
-- - cumple_sin_no_pagos: semanas_sin_pago = 0
-- - cumple_sin_reducidos_graves: promedio_monto_reducido >= 70% de Tarifa
-- - cumple_minimo_reducido: promedio_monto_reducido >= 50% de Tarifa
--
-- RESULTADO:
-- - 'CUMPLE': Todos los criterios OK
-- - 'CUMPLE CON MONTO REDUCIDO': Reducidos entre 50%-70%
-- - 'NO CUMPLE': Falla algún criterio
-- - 'NO APTO - REDUCIDO < 50%': Pagos muy bajos
--
-- EXCLUSIONES EN CÁLCULO DE REDUCIDOS:
-- - NO se cuentan primeros pagos (EsPrimerPago = 1)
-- - NO se cuentan últimas semanas donde saldo < tarifa
-- - SÍ maneja parcialidades (suma por semana/año)
-- =====================================================
