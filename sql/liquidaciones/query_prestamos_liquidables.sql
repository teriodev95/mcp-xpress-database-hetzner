-- ============================================================================
-- PRÉSTAMOS LIQUIDABLES: Con tarifa cubierta y descuento disponible
-- ============================================================================
-- Muestra préstamos que:
-- 1. Ya cubrieron su tarifa semanal (pago >= débito)
-- 2. Aún pueden obtener descuento por liquidación anticipada
-- ============================================================================


-- ============================================================================
-- QUERY PRINCIPAL: Préstamos con tarifa cubierta esta semana + liquidación
-- ============================================================================

SELECT
    p.PrestamoID,
    pd.cliente,
    p.Agente,
    pd.agencia,
    -- Info del préstamo
    p.Monto_otorgado,
    p.plazo AS plazo_semanas,
    p.Tipo_de_Cliente,
    -- Fechas
    p.Semana AS sem_entrega,
    p.Anio AS anio_entrega,
    c_actual.semana AS sem_actual,
    c_actual.anio AS anio_actual,
    -- Semanas transcurridas (NO incluye semana de entrega)
    (
        SELECT COUNT(*)
        FROM calendario c
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
          AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
    ) AS sem_transcurridas,
    -- Pago de esta semana
    ROUND(pd.abre_con, 2) AS saldo_inicio_semana,
    ROUND(pd.monto, 2) AS pago_realizado,
    ROUND(LEAST(pd.abre_con, pd.tarifa), 2) AS debito_esperado,
    CASE
        WHEN pd.monto >= LEAST(pd.abre_con, pd.tarifa) THEN 'CUBIERTO'
        ELSE 'PARCIAL'
    END AS status_pago,
    -- Liquidación
    ROUND(pd.cierra_con, 2) AS saldo_actual,
    COALESCE(pdl.porcentaje, 0) AS descuento_porcentaje,
    ROUND(pd.cierra_con * COALESCE(pdl.porcentaje, 0) / 100, 2) AS descuento_dinero,
    ROUND(pd.cierra_con * (100 - COALESCE(pdl.porcentaje, 0)) / 100, 2) AS liquida_con,
    -- Estado de liquidación
    CASE
        WHEN pd.cierra_con <= 0 THEN 'YA LIQUIDADO'
        WHEN pdl.porcentaje IS NULL THEN 'SIN TABLA DESCUENTO'
        WHEN pdl.porcentaje = 0 THEN 'SIN DESCUENTO (VENCIDO)'
        ELSE 'DESCUENTO DISPONIBLE'
    END AS estado_liquidacion
FROM prestamos_v2 p
-- Semana actual
CROSS JOIN (
    SELECT semana, anio FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
) c_actual
-- Pago de esta semana
INNER JOIN pagos_dynamic pd ON
    pd.prestamo_id = p.PrestamoID
    AND pd.semana = c_actual.semana
    AND pd.anio = c_actual.anio
    AND pd.tipo_aux = 'Pago'
-- Tabla de porcentajes de liquidación
LEFT JOIN porcentajes_liquidacion_v2 pdl ON
    pdl.plazo = p.plazo
    AND pdl.tipo_cliente = p.Tipo_de_Cliente
    AND pdl.semana = LEAST((
        SELECT COUNT(*)
        FROM calendario c
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
          AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
    ), p.plazo)
WHERE
    p.Saldo > 0
    -- Solo los que cubrieron su tarifa
    AND pd.monto >= LEAST(pd.abre_con, pd.tarifa)
    -- Solo los que tienen descuento disponible
    AND COALESCE(pdl.porcentaje, 0) > 0
ORDER BY
    pdl.porcentaje DESC,  -- Mayor descuento primero
    pd.cierra_con DESC;   -- Mayor saldo después


-- ============================================================================
-- QUERY: TODOS los préstamos con pago esta semana (cubiertos o no)
-- ============================================================================

/*
SELECT
    p.PrestamoID,
    pd.cliente,
    pd.agencia,
    p.Tipo_de_Cliente,
    p.Semana AS sem_entrega,
    p.Anio AS anio_entrega,
    (
        SELECT COUNT(*)
        FROM calendario c, (SELECT semana, anio FROM calendario WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta) ca
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
          AND (c.anio < ca.anio OR (c.anio = ca.anio AND c.semana <= ca.semana))
    ) AS sem_transcurridas,
    ROUND(pd.abre_con, 2) AS saldo_inicio,
    ROUND(pd.monto, 2) AS pago,
    ROUND(LEAST(pd.abre_con, pd.tarifa), 2) AS debito,
    CASE
        WHEN pd.monto >= LEAST(pd.abre_con, pd.tarifa) THEN 'CUBIERTO'
        WHEN pd.monto > 0 THEN 'PARCIAL'
        ELSE 'SIN PAGO'
    END AS status_pago,
    ROUND(pd.cierra_con, 2) AS saldo_actual,
    COALESCE(pdl.porcentaje, 0) AS descuento_pct,
    ROUND(pd.cierra_con * (100 - COALESCE(pdl.porcentaje, 0)) / 100, 2) AS liquida_con
FROM prestamos_v2 p
CROSS JOIN (
    SELECT semana, anio FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
) c_actual
INNER JOIN pagos_dynamic pd ON
    pd.prestamo_id = p.PrestamoID
    AND pd.semana = c_actual.semana
    AND pd.anio = c_actual.anio
    AND pd.tipo_aux = 'Pago'
LEFT JOIN porcentajes_liquidacion_v2 pdl ON
    pdl.plazo = p.plazo
    AND pdl.tipo_cliente = p.Tipo_de_Cliente
    AND pdl.semana = LEAST((
        SELECT COUNT(*)
        FROM calendario c
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
          AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
    ), p.plazo)
WHERE p.Saldo > 0
ORDER BY status_pago, pdl.porcentaje DESC;
*/


-- ============================================================================
-- QUERY: Préstamos SIN pago esta semana pero con descuento disponible
-- ============================================================================

/*
SELECT
    p.PrestamoID,
    CONCAT(p.Nombres, ' ', p.Apellido_Paterno) AS cliente,
    p.Agente,
    p.Tipo_de_Cliente,
    p.Semana AS sem_entrega,
    p.Anio AS anio_entrega,
    (
        SELECT COUNT(*)
        FROM calendario c, (SELECT semana, anio FROM calendario WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta) ca
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
          AND (c.anio < ca.anio OR (c.anio = ca.anio AND c.semana <= ca.semana))
    ) AS sem_transcurridas,
    ROUND(p.Saldo, 2) AS saldo_actual,
    COALESCE(pdl.porcentaje, 0) AS descuento_pct,
    ROUND(p.Saldo * COALESCE(pdl.porcentaje, 0) / 100, 2) AS descuento_dinero,
    ROUND(p.Saldo * (100 - COALESCE(pdl.porcentaje, 0)) / 100, 2) AS liquida_con,
    'PENDIENTE PAGO' AS status
FROM prestamos_v2 p
CROSS JOIN (
    SELECT semana, anio FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
) c_actual
LEFT JOIN pagos_dynamic pd ON
    pd.prestamo_id = p.PrestamoID
    AND pd.semana = c_actual.semana
    AND pd.anio = c_actual.anio
    AND pd.tipo_aux = 'Pago'
LEFT JOIN porcentajes_liquidacion_v2 pdl ON
    pdl.plazo = p.plazo
    AND pdl.tipo_cliente = p.Tipo_de_Cliente
    AND pdl.semana = LEAST((
        SELECT COUNT(*)
        FROM calendario c
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
          AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
    ), p.plazo)
WHERE
    p.Saldo > 0
    AND pd.prestamo_id IS NULL  -- Sin pago esta semana
    AND COALESCE(pdl.porcentaje, 0) > 0  -- Con descuento disponible
ORDER BY pdl.porcentaje DESC;
*/


-- ============================================================================
-- RESUMEN: Conteo por estado de pago y liquidación
-- ============================================================================

/*
SELECT
    CASE
        WHEN pd.monto >= LEAST(pd.abre_con, pd.tarifa) THEN 'TARIFA CUBIERTA'
        WHEN pd.monto > 0 THEN 'PAGO PARCIAL'
        ELSE 'SIN PAGO'
    END AS status_pago,
    CASE
        WHEN COALESCE(pdl.porcentaje, 0) > 0 THEN 'CON DESCUENTO'
        ELSE 'SIN DESCUENTO'
    END AS status_liquidacion,
    COUNT(*) AS cantidad,
    SUM(pd.cierra_con) AS saldo_total,
    SUM(pd.cierra_con * (100 - COALESCE(pdl.porcentaje, 0)) / 100) AS liquidacion_total
FROM prestamos_v2 p
CROSS JOIN (
    SELECT semana, anio FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
) c_actual
INNER JOIN pagos_dynamic pd ON
    pd.prestamo_id = p.PrestamoID
    AND pd.semana = c_actual.semana
    AND pd.anio = c_actual.anio
    AND pd.tipo_aux = 'Pago'
LEFT JOIN porcentajes_liquidacion_v2 pdl ON
    pdl.plazo = p.plazo
    AND pdl.tipo_cliente = p.Tipo_de_Cliente
    AND pdl.semana = LEAST((
        SELECT COUNT(*)
        FROM calendario c
        WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
          AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
    ), p.plazo)
WHERE p.Saldo > 0
GROUP BY status_pago, status_liquidacion;
*/
