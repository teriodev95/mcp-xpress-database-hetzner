-- ============================================================
-- VISTA: detalle_prestamos_semana
-- Descripción: Detalle de préstamos activos con pagos por semana/año
-- Permite consultar el estado de préstamos y agrupar por agencia
-- ============================================================

-- ============================================================
-- NOTA: Esta vista requiere CROSS JOIN con calendario para
-- generar una fila por préstamo por semana. Se debe filtrar
-- SIEMPRE por semana y anio al consultar.
-- ============================================================

CREATE OR REPLACE VIEW vw_datos_cobranza AS
SELECT
    g.GerenciaID AS gerencia_id,
    p.Agente AS agencia,
    p.PrestamoID AS prestamo_id,
    CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS cliente,
    p.Tarifa AS tarifa_prestamo,
    COALESCE(LEAST(p.Tarifa, p.Saldo), 0) AS tarifa_en_semana,
    p.Saldo AS saldo_al_iniciar_semana,
    p.Dia_de_pago,
    pag_dyn.cierra_con,
    LEAST(p.Saldo, p.Tarifa) AS debito,
    COALESCE(pag_dyn.monto, 0) AS monto_pagado,
    COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0) AS cobranza_pura,
    CASE
        WHEN liq.liquidacionID IS NOT NULL THEN 0
        ELSE COALESCE(pag_dyn.monto - LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
    END AS excedente,
    ROUND(COALESCE(liq.liquido_con, 0), 2) AS monto_liquidacion,
    ROUND(COALESCE(liq.descuento_en_dinero, 0), 2) AS monto_descuento,
    -- cobranza_total = cobranza_pura + excedente + liquidaciones
    ROUND(
        COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0) +
        CASE
            WHEN liq.liquidacionID IS NOT NULL THEN 0
            ELSE COALESCE(pag_dyn.monto - LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
        END +
        COALESCE(liq.liquido_con, 0)
    , 2) AS cobranza_total,
    -- debito_faltante = debito - cobranza_pura
    ROUND(
        LEAST(p.Saldo, p.Tarifa) - COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
    , 2) AS debito_faltante,
    COALESCE(pag_dyn.tipo, 'Sin Pago') AS tipo,
    CASE WHEN pag_dyn.prestamo_id IS NULL AND liq.liquidacionID IS NULL THEN 'NO' ELSE 'SI' END AS pago_semana,
    cal.Semana AS semana,
    cal.Anio AS anio
FROM prestamos_v2 p
INNER JOIN gerencias g
    ON p.Gerencia = g.deprecated_name
    AND p.SucursalID = g.sucursal
CROSS JOIN (
    SELECT DISTINCT Semana, Anio FROM calendario WHERE Anio >= 2024
) cal
LEFT JOIN pagos_dynamic pag_dyn
    ON p.PrestamoID = pag_dyn.prestamo_id
    AND pag_dyn.semana = cal.Semana
    AND pag_dyn.anio = cal.Anio
LEFT JOIN liquidaciones liq
    ON p.PrestamoID = liq.prestamoID
    AND liq.anio = cal.Anio
    AND liq.semana = cal.Semana
WHERE p.Saldo > 0;


-- ============================================================
-- VISTA: vw_resumen_cobranza_agencias
-- Descripción: Resumen de cobranza agrupado por agencia con agente y no_pagos
-- ============================================================

CREATE OR REPLACE VIEW vw_resumen_cobranza_agencias AS
SELECT
    d.gerencia_id,
    d.agencia,
    asa.Agente AS nombre_agente,
    d.semana,
    d.anio,
    COUNT(d.prestamo_id) AS clientes,
    SUM(d.debito) AS total_debito,
    SUM(d.monto_pagado) AS total_pagado,
    SUM(d.cobranza_pura) AS total_cobranza_pura,
    SUM(d.excedente) AS total_excedente,
    SUM(d.monto_liquidacion) AS total_liquidaciones,
    SUM(d.monto_descuento) AS total_descuentos,
    SUM(d.cobranza_total) AS total_cobranza,
    SUM(d.debito_faltante) AS total_debito_faltante,
    SUM(CASE WHEN d.pago_semana = 'SI' THEN 1 ELSE 0 END) AS prestamos_con_pago,
    SUM(CASE WHEN d.pago_semana = 'NO' THEN 1 ELSE 0 END) AS prestamos_sin_pago,
    COALESCE(np.total_no_pagos, 0) AS total_no_pagos,
    ROUND(SUM(d.cobranza_pura) / NULLIF(SUM(d.debito), 0) * 100, 2) AS porcentaje_cobranza
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT
        agencia,
        semana,
        anio,
        COUNT(*) AS total_no_pagos
    FROM pagos_dynamic
    WHERE tipo = 'No_pago'
    GROUP BY agencia, semana, anio
) np ON d.agencia = np.agencia AND d.semana = np.semana AND d.anio = np.anio
GROUP BY  d.agencia;


-- ============================================================
-- EJEMPLOS DE USO
-- ============================================================

-- 1. Detalle de préstamos de una gerencia en una semana específica
/*
SELECT *
FROM detalle_prestamos_semana
WHERE gerencia_id = 'GERD009'
    AND semana = 49
    AND anio = 2025
ORDER BY agencia, prestamo_id;
*/

-- 2. Resumen agrupado por agencia con nombre del agente y no_pagos
/*
SELECT
    d.agencia,
    asa.Agente AS nombre_agente,
    COUNT(d.prestamo_id) AS total_prestamos,
    SUM(d.debito) AS total_debito,
    SUM(d.monto_pagado) AS total_pagado,
    SUM(d.cobranza_pura) AS total_cobranza_pura,
    SUM(d.excedente) AS total_excedente,
    SUM(d.monto_liquidacion) AS total_liquidaciones,
    SUM(d.monto_descuento) AS total_descuentos,
    SUM(d.cobranza_total) AS total_cobranza,
    SUM(d.debito_faltante) AS total_debito_faltante,
    SUM(CASE WHEN d.pago_semana = 'SI' THEN 1 ELSE 0 END) AS prestamos_con_pago,
    SUM(CASE WHEN d.pago_semana = 'NO' THEN 1 ELSE 0 END) AS prestamos_sin_pago,
    COALESCE(np.total_no_pagos, 0) AS total_no_pagos,
    ROUND(SUM(d.cobranza_pura) / NULLIF(SUM(d.debito), 0) * 100, 2) AS porcentaje_cobranza
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT
        agencia,
        semana,
        anio,
        COUNT(*) AS total_no_pagos
    FROM pagos_dynamic
    WHERE tipo = 'No_pago'
    GROUP BY agencia, semana, anio
) np ON d.agencia = np.agencia AND d.semana = np.semana AND d.anio = np.anio
WHERE d.gerencia_id = 'GERD009'
    AND d.semana = 49
    AND d.anio = 2025
GROUP BY d.agencia, asa.Agente, np.total_no_pagos
ORDER BY d.agencia;
*/

-- 3. Resumen por gerencia (todas las agencias)
/*
SELECT
    gerencia_id,
    COUNT(DISTINCT agencia) AS total_agencias,
    COUNT(prestamo_id) AS total_prestamos,
    SUM(debito) AS total_debito,
    SUM(monto_pagado) AS total_pagado,
    SUM(cobranza_pura) AS total_cobranza_pura,
    ROUND(SUM(cobranza_pura) / NULLIF(SUM(debito), 0) * 100, 2) AS porcentaje_cobranza
FROM detalle_prestamos_semana
WHERE semana = 49
    AND anio = 2025
GROUP BY gerencia_id
ORDER BY gerencia_id;
*/
