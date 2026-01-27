-- ============================================================================
-- QUERY: LIQUIDACIONES ESPECIALES - CONSULTA POR PRESTAMO ID
-- ============================================================================
-- Descripción: Obtiene todos los datos de liquidación especial para un préstamo
-- Uso: Reemplazar 'PRESTAMO_ID_AQUI' con el ID del préstamo a consultar
-- ============================================================================
-- Campos calculados:
--   - Semanas_Transcurridas: Semanas desde el inicio del préstamo
--   - Semanas_Sin_Pagar: Semanas desde el último pago registrado
--   - Cobrado: Total cobrado al cliente
--   - Saldo: Saldo pendiente
--   - Comision_Cobranza: 10% de lo cobrado
--   - Comision_Venta: $100 por préstamo entregado
--   - Comision_Total: Suma de ambas comisiones
--   - Por_Recuperar: Monto_otorgado + Comision_Cobranza + Comision_Venta (mínimo a recuperar)
--   - Faltante: Diferencia entre Por_Recuperar y Cobrado
--   - Descuento_Disponible: Si PENDIENTE = Saldo - Faltante | Si RECUPERADO = Saldo / 2
--   - Status_Recuperacion: RECUPERADO si Cobrado >= Por_Recuperar, PENDIENTE si no
-- ============================================================================

-- QUERY OPTIMIZADA PARA MCP - Buscar por PrestamoID
-- IMPORTANTE: El PrestamoID se usa en 2 lugares para optimizar rendimiento
-- Reemplazar 'PRESTAMO_ID_AQUI' con el ID del préstamo (en ambos lugares)

SELECT
    p.PrestamoID,
    CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS Cliente,
    p.Gerencia,
    p.Agente,
    p.Semana AS Semana_Inicio,
    p.Anio AS Anio_Inicio,
    p.plazo AS Plazo_Semanas,

    -- Semanas transcurridas desde inicio del préstamo
    ((cal.semana + (cal.anio * 52)) - (p.Semana + (p.Anio * 52))) AS Semanas_Transcurridas,

    -- Datos financieros
    p.Monto_otorgado,
    p.Total_a_pagar,
    p.Tarifa,
    p.Cobrado,
    p.Saldo,

    -- Información del último pago
    COALESCE(up.ultima_semana_pago, p.Semana) AS Ultima_Semana_Pago,
    COALESCE(up.ultimo_anio_pago, p.Anio) AS Ultimo_Anio_Pago,

    -- Semanas sin pagar
    CASE
        WHEN up.ultima_semana_pago IS NOT NULL
        THEN ((cal.semana + (cal.anio * 52)) - (up.ultima_semana_pago + (up.ultimo_anio_pago * 52)))
        ELSE ((cal.semana + (cal.anio * 52)) - (p.Semana + (p.Anio * 52)))
    END AS Semanas_Sin_Pagar,

    -- Número de pagos realizados
    COALESCE(up.num_pagos, 0) AS Numero_Pagos,

    -- Comisión por cobranza: 10% de lo cobrado
    ROUND(p.Cobrado * 0.10, 2) AS Comision_Cobranza,

    -- Comisión por venta: $100 por préstamo entregado
    100.00 AS Comision_Venta,

    -- Comisión total del agente
    ROUND((p.Cobrado * 0.10) + 100, 2) AS Comision_Total,

    -- Por Recuperar: Monto otorgado + Comisión Cobranza + Comisión Venta
    -- Es lo mínimo que se debe recuperar para no perder
    ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) AS Por_Recuperar,

    -- Faltante: Lo que falta para cubrir el Por_Recuperar
    GREATEST(
        ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado,
        0
    ) AS Faltante,

    -- Descuento disponible para aplicar:
    -- Si PENDIENTE: Saldo - Faltante
    -- Si RECUPERADO: Mitad del saldo
    CASE
        WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
        ELSE GREATEST(
            p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0),
            0
        )
    END AS Descuento_Disponible,

    -- Status de recuperación: basado en Por_Recuperar
    CASE
        WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN 'RECUPERADO'
        ELSE 'PENDIENTE'
    END AS Status_Recuperacion,

    -- Simulación de liquidación con diferentes porcentajes del descuento disponible
    -- Fórmula: Saldo - (Descuento_Disponible * Porcentaje)
    ROUND(p.Saldo - (
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END * 0.10
    ), 2) AS Liquida_Con_10_Porciento,
    ROUND(p.Saldo - (
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END * 0.20
    ), 2) AS Liquida_Con_20_Porciento,
    ROUND(p.Saldo - (
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END * 0.30
    ), 2) AS Liquida_Con_30_Porciento,
    ROUND(p.Saldo - (
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END * 0.40
    ), 2) AS Liquida_Con_40_Porciento,
    ROUND(p.Saldo - (
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END * 0.50
    ), 2) AS Liquida_Con_50_Porciento

FROM prestamos_v2 p

-- Obtener semana/año actual desde calendario
-- NOTA: Usamos DATE() para comparar solo fechas sin hora
CROSS JOIN (
    SELECT semana, anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN DATE(desde) AND DATE(hasta)
    LIMIT 1
) cal

-- Subquery OPTIMIZADA: filtra por PrestamoID para evitar escaneo completo
LEFT JOIN (
    SELECT
        PrestamoID,
        MAX(CASE WHEN Tipo IN ('Pago', 'Excedente', 'Liquidacion', 'Reducido') THEN Semana END) AS ultima_semana_pago,
        MAX(CASE WHEN Tipo IN ('Pago', 'Excedente', 'Liquidacion', 'Reducido') THEN Anio END) AS ultimo_anio_pago,
        COUNT(CASE WHEN Tipo IN ('Pago', 'Excedente', 'Liquidacion', 'Reducido') THEN 1 END) AS num_pagos
    FROM pagos_v3
    WHERE PrestamoID = 'PRESTAMO_ID_AQUI'  -- <<<< IMPORTANTE: mismo ID aquí
        AND Anio > 0
    GROUP BY PrestamoID
) up ON p.PrestamoID = up.PrestamoID

WHERE p.PrestamoID = 'PRESTAMO_ID_AQUI';  -- <<<< Y aquí


-- ============================================================================
-- EJEMPLO DE USO CON CURL PARA MCP (tiempo de respuesta: <1 segundo)
-- ============================================================================
/*
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT p.PrestamoID, CONCAT(p.Nombres, '\'' '\'', p.Apellido_Paterno, '\'' '\'', COALESCE(p.Apellido_Materno, '\'''\'')) AS Cliente, p.Gerencia, p.Agente, p.Semana AS Semana_Inicio, p.Anio AS Anio_Inicio, p.plazo AS Plazo_Semanas, ((cal.semana + (cal.anio * 52)) - (p.Semana + (p.Anio * 52))) AS Semanas_Transcurridas, p.Monto_otorgado, p.Total_a_pagar, p.Tarifa, p.Cobrado, p.Saldo, COALESCE(up.ultima_semana_pago, p.Semana) AS Ultima_Semana_Pago, COALESCE(up.ultimo_anio_pago, p.Anio) AS Ultimo_Anio_Pago, CASE WHEN up.ultima_semana_pago IS NOT NULL THEN ((cal.semana + (cal.anio * 52)) - (up.ultima_semana_pago + (up.ultimo_anio_pago * 52))) ELSE ((cal.semana + (cal.anio * 52)) - (p.Semana + (p.Anio * 52))) END AS Semanas_Sin_Pagar, COALESCE(up.num_pagos, 0) AS Numero_Pagos, ROUND(p.Cobrado * 0.10, 2) AS Comision_Cobranza, 100.00 AS Comision_Venta, ROUND((p.Cobrado * 0.10) + 100, 2) AS Comision_Total, GREATEST(p.Monto_otorgado - p.Cobrado, 0) AS Faltante_Monto_Otorgado, CASE WHEN p.Cobrado >= p.Monto_otorgado THEN ROUND(p.Saldo / 2, 2) ELSE GREATEST(p.Saldo - GREATEST(p.Monto_otorgado - p.Cobrado, 0) - (ROUND(p.Cobrado * 0.10, 2) + 100), 0) END AS Descuento_Maximo, CASE WHEN p.Cobrado >= p.Monto_otorgado THEN '\''RECUPERADO'\'' ELSE '\''PENDIENTE'\'' END AS Status_Recuperacion FROM prestamos_v2 p CROSS JOIN (SELECT semana, anio FROM calendario WHERE CONVERT_TZ(NOW(), '\''UTC'\'', '\''America/Mexico_City'\'') BETWEEN desde AND hasta LIMIT 1) cal LEFT JOIN (SELECT PrestamoID, MAX(CASE WHEN Tipo IN ('\''Pago'\'', '\''Excedente'\'', '\''Liquidacion'\'', '\''Reducido'\'') THEN Semana END) AS ultima_semana_pago, MAX(CASE WHEN Tipo IN ('\''Pago'\'', '\''Excedente'\'', '\''Liquidacion'\'', '\''Reducido'\'') THEN Anio END) AS ultimo_anio_pago, COUNT(CASE WHEN Tipo IN ('\''Pago'\'', '\''Excedente'\'', '\''Liquidacion'\'', '\''Reducido'\'') THEN 1 END) AS num_pagos FROM pagos_v3 WHERE PrestamoID = '\''D-2395-ef'\'' AND Anio > 0 GROUP BY PrestamoID) up ON p.PrestamoID = up.PrestamoID WHERE p.PrestamoID = '\''D-2395-ef'\''"}'
*/
