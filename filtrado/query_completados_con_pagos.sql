-- =====================================================
-- Query para Préstamos Completados con Análisis de Pagos
-- =====================================================
-- Incluye conteo y análisis de pagos desde pagos_v3
-- =====================================================

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    p.Saldo,
    p.Cobrado,

    -- Criterios simplificados
    (p.Saldo < p.Tarifa * 2) AS cumple_saldo,
    (((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo) AS cumple_plazo,

    -- Conteo de pagos optimizado
    COALESCE(pagos.total_pagos, 0) AS total_pagos,
    COALESCE(pagos.no_pagos, 0) AS no_pagos,
    (COALESCE(pagos.no_pagos, 0) = 0) AS cumple_sin_no_pagos,

    -- Resultado final
    CASE
        WHEN (p.Saldo < p.Tarifa * 2)
            AND (((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo)
            AND COALESCE(pagos.no_pagos, 0) = 0
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado

FROM prestamos_completados p

-- JOIN optimizado: solo cuenta no_pagos (Monto = 0)
LEFT JOIN (
    SELECT
        PrestamoID,
        COUNT(*) AS total_pagos,
        SUM(CASE WHEN Monto = 0 THEN 1 ELSE 0 END) AS no_pagos
    FROM pagos_v3
    GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID

WHERE p.PrestamoID = 'ID_DEL_PRESTAMO';


-- =====================================================
-- Query para LISTAR TODOS los Completados que Cumplen
-- =====================================================

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    p.Saldo,
    p.Cobrado,
    (p.Saldo / p.Tarifa) AS tarifas_restantes,

    -- Pagos
    COALESCE(pagos.total_pagos, 0) AS total_pagos,
    COALESCE(pagos.no_pagos, 0) AS no_pagos,
    COALESCE(pagos.total_monto_pagado, 0) AS monto_pagado,

    -- Semanas
    ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) AS semanas_transcurridas

FROM prestamos_completados p

LEFT JOIN (
    SELECT
        PrestamoID,
        COUNT(*) AS total_pagos,
        SUM(CASE WHEN Tipo = 'No_pago' THEN 1 ELSE 0 END) AS no_pagos,
        SUM(Monto) AS total_monto_pagado
    FROM pagos_v3
    GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID

WHERE
    -- Criterio 1: Saldo menor a 2 tarifas
    p.Saldo < (p.Tarifa * 2)

    -- Criterio 2: Dentro del plazo
    AND ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo

    -- Criterio 3: Sin "No_pago"
    AND COALESCE(pagos.no_pagos, 0) = 0

ORDER BY p.Gerencia, p.Agente
LIMIT 100;


-- =====================================================
-- Query con ANÁLISIS DETALLADO por Tipo de Pago
-- =====================================================

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Tarifa,
    p.Saldo,
    p.Cobrado,
    p.plazo,

    -- Estadísticas de pagos
    COALESCE(pagos.total_pagos, 0) AS total_pagos,
    COALESCE(pagos.pagos_normales, 0) AS pagos_normales,
    COALESCE(pagos.no_pagos, 0) AS no_pagos,
    COALESCE(pagos.visitas, 0) AS visitas,
    COALESCE(pagos.multas, 0) AS multas,
    COALESCE(pagos.liquidaciones, 0) AS liquidaciones,
    COALESCE(pagos.excedentes, 0) AS excedentes,

    -- Montos
    COALESCE(pagos.total_monto_pagado, 0) AS monto_pagado,
    COALESCE(pagos.monto_pagos_normales, 0) AS monto_pagos_normales,
    COALESCE(pagos.monto_multas, 0) AS monto_multas,
    COALESCE(pagos.monto_excedentes, 0) AS monto_excedentes,

    -- Análisis
    CASE
        WHEN COALESCE(pagos.total_pagos, 0) = 0 THEN 'SIN PAGOS REGISTRADOS'
        WHEN COALESCE(pagos.no_pagos, 0) = 0 THEN 'TODOS LOS PAGOS REALIZADOS'
        ELSE CONCAT('CON ', COALESCE(pagos.no_pagos, 0), ' NO PAGOS')
    END AS analisis_pagos,

    -- Tasa de cumplimiento
    CASE
        WHEN COALESCE(pagos.total_pagos, 0) > 0
        THEN ROUND((COALESCE(pagos.pagos_normales, 0) * 100.0 / pagos.total_pagos), 2)
        ELSE 0
    END AS porcentaje_cumplimiento

FROM prestamos_completados p

LEFT JOIN (
    SELECT
        PrestamoID,
        COUNT(*) AS total_pagos,
        SUM(CASE WHEN Tipo = 'Pago' THEN 1 ELSE 0 END) AS pagos_normales,
        SUM(CASE WHEN Tipo = 'No_pago' THEN 1 ELSE 0 END) AS no_pagos,
        SUM(CASE WHEN Tipo = 'Visita' THEN 1 ELSE 0 END) AS visitas,
        SUM(CASE WHEN Tipo = 'Multa' THEN 1 ELSE 0 END) AS multas,
        SUM(CASE WHEN Tipo = 'Liquidacion' THEN 1 ELSE 0 END) AS liquidaciones,
        SUM(CASE WHEN Tipo = 'Excedente' THEN 1 ELSE 0 END) AS excedentes,
        SUM(Monto) AS total_monto_pagado,
        SUM(CASE WHEN Tipo = 'Pago' THEN Monto ELSE 0 END) AS monto_pagos_normales,
        SUM(CASE WHEN Tipo = 'Multa' THEN Monto ELSE 0 END) AS monto_multas,
        SUM(CASE WHEN Tipo = 'Excedente' THEN Monto ELSE 0 END) AS monto_excedentes
    FROM pagos_v3
    GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID

WHERE p.PrestamoID = 'ID_DEL_PRESTAMO'
ORDER BY p.Gerencia, p.Agente;


-- =====================================================
-- RESUMEN POR GERENCIA con Pagos
-- =====================================================

SELECT
    p.Gerencia,
    COUNT(*) AS total_prestamos_completados,
    SUM(p.Cobrado) AS total_cobrado,

    -- Estadísticas de pagos
    AVG(COALESCE(pagos.total_pagos, 0)) AS promedio_pagos,
    SUM(COALESCE(pagos.no_pagos, 0)) AS total_no_pagos,

    -- Préstamos que cumplen criterios
    SUM(
        CASE
            WHEN p.Saldo < (p.Tarifa * 2)
                AND ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo
                AND COALESCE(pagos.no_pagos, 0) = 0
            THEN 1
            ELSE 0
        END
    ) AS cumplen_criterios

FROM prestamos_completados p

LEFT JOIN (
    SELECT
        PrestamoID,
        COUNT(*) AS total_pagos,
        SUM(CASE WHEN Tipo = 'No_pago' THEN 1 ELSE 0 END) AS no_pagos
    FROM pagos_v3
    GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID

GROUP BY p.Gerencia
ORDER BY total_prestamos_completados DESC;
