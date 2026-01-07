-- =====================================================
-- QUERIES CORREGIDAS: Dashboard Agencia y Gerencia
-- =====================================================
-- Cambios principales:
--   1. Usa pagos_dynamic como tabla principal (no prestamos_v2)
--   2. Calcula débito con LEAST(abre_con, tarifa) de pagos_dynamic
--   3. Usa UPPER() para Dia_de_pago (maneja inconsistencias de mayúsculas)
--   4. Incluye préstamos liquidados (que ya no están en prestamos_v2 con Saldo > 0)
-- =====================================================

-- =====================================================
-- QUERY DASHBOARD AGENCIA (CORREGIDA)
-- =====================================================
-- Parámetros: agencia, anio, semana (repetidos según subconsultas)

SELECT
    agenc.GerenciaID as gerencia,
    ? as agencia,
    ? as anio,
    ? as semana,

    -- CONTEOS
    COUNT(pag_dyn.prestamo_id) as clientes,
    SUM(IF(pag_dyn.tipo_aux = 'Pago' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados,
    SUM(IF(pag_dyn.tipo = 'No_pago', 1, 0)) as no_pagos,
    SUM(IF(pag_dyn.tipo = 'Liquidacion', 1, 0)) as numero_liquidaciones,
    SUM(IF(pag_dyn.tipo = 'Reducido', 1, 0)) as pagos_reducidos,

    -- DÉBITOS (CORREGIDO: usa pagos_dynamic.abre_con, no prestamos_v2.Saldo)
    SUM(IF(UPPER(p.Dia_de_pago) = 'MIERCOLES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles,
    SUM(IF(UPPER(p.Dia_de_pago) = 'JUEVES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves,
    SUM(IF(UPPER(p.Dia_de_pago) = 'VIERNES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes,
    SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total,

    -- RENDIMIENTO (CORREGIDO: cobranza_pura / debito_total)
    ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 /
        NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento,

    -- COBRANZA
    SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.abre_con - pag_dyn.monto, 0)) as total_de_descuento,
    SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura,
    (SUM(IF(pag_dyn.monto > LEAST(pag_dyn.abre_con, pag_dyn.tarifa),
        pag_dyn.monto - LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) -
        SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.monto - pag_dyn.tarifa, 0))) as monto_excedente,
    SUM(IF(pag_dyn.tipo = 'Multa', pag_dyn.monto, 0)) as multas,
    SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.monto - pag_dyn.tarifa, 0)) as liquidaciones,
    SUM(COALESCE(pag_dyn.monto, 0)) as cobranza_total,
    (SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) -
        SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa)))) as monto_de_debito_faltante,

    -- ASIGNACIONES (subconsultas)
    (SELECT COUNT(asign.id)
        FROM asignaciones_v2 asign
        WHERE asign.agencia = agenc.AgenciaID
        AND asign.anio = ?
        AND asign.semana = ?) as numero_asignaciones,
    (SELECT COALESCE(SUM(asign.monto), 0)
        FROM asignaciones_v2 asign
        WHERE asign.agencia = agenc.AgenciaID
        AND asign.anio = ?
        AND asign.semana = ?) as asignaciones,

    -- CIERRE
    IF(EXISTS (
        SELECT 1 FROM cierres_semanales_consolidados_v2
        WHERE agencia = agenc.AgenciaID AND anio = ? AND semana = ?
    ), 1, 0) AS agenciaCerrada,

    -- EFECTIVO EN CAMPO
    IF(EXISTS (
        SELECT 1 FROM cierres_semanales_consolidados_v2
        WHERE agencia = agenc.AgenciaID AND anio = ? AND semana = ?
    ), 0, (SUM(COALESCE(pag_dyn.monto, 0)) - (SELECT COALESCE(SUM(asign.monto), 0)
        FROM asignaciones_v2 asign
        WHERE asign.agencia = agenc.AgenciaID
        AND asign.anio = ?
        AND asign.semana = ?))) as efectivo_en_campo,

    agenc.Status as status_agencia,

    -- VENTAS (subconsultas)
    (SELECT COUNT(vent.id)
        FROM ventas vent
        WHERE vent.agencia = agenc.AgenciaID
        AND vent.anio = ?
        AND vent.Semana = ?) as numero_ventas,
    (SELECT COALESCE(SUM(vent.monto), 0)
        FROM ventas vent
        WHERE vent.agencia = agenc.AgenciaID
        AND vent.anio = ?
        AND vent.Semana = ?) as ventas

FROM agencias agenc
-- CAMBIO PRINCIPAL: pagos_dynamic es la tabla base (incluye préstamos liquidados)
INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID
    AND pag_dyn.anio = ?
    AND pag_dyn.semana = ?
    AND pag_dyn.tipo_aux = 'Pago'
-- LEFT JOIN a prestamos_v2 solo para obtener Dia_de_pago
LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID
WHERE agenc.AgenciaID = ?
GROUP BY agenc.GerenciaID, agenc.AgenciaID, agenc.Status;


-- =====================================================
-- QUERY DASHBOARD GERENCIA (CORREGIDA)
-- =====================================================
-- Parámetros: anio, semana, (subconsultas), gerencia

SELECT
    ger.GerenciaID as gerencia,
    ? as anio,
    ? as semana,

    -- CONTEOS
    COUNT(pag_dyn.prestamo_id) as clientes,
    SUM(IF(pag_dyn.tipo_aux = 'Pago' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados,
    SUM(IF(pag_dyn.tipo = 'No_pago', 1, 0)) as no_pagos,
    SUM(IF(pag_dyn.tipo = 'Liquidacion', 1, 0)) as numero_liquidaciones,
    SUM(IF(pag_dyn.tipo = 'Reducido', 1, 0)) as pagos_reducidos,

    -- DÉBITOS (CORREGIDO: usa pagos_dynamic.abre_con)
    SUM(IF(UPPER(p.Dia_de_pago) = 'MIERCOLES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles,
    SUM(IF(UPPER(p.Dia_de_pago) = 'JUEVES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves,
    SUM(IF(UPPER(p.Dia_de_pago) = 'VIERNES', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes,
    SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total,

    -- RENDIMIENTO
    ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 /
        NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento,

    -- COBRANZA
    SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.abre_con - pag_dyn.monto, 0)) as total_descuento,
    SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura,
    (SUM(IF(pag_dyn.monto > LEAST(pag_dyn.abre_con, pag_dyn.tarifa),
        pag_dyn.monto - LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) -
        SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.monto - pag_dyn.tarifa, 0))) as monto_excedente,
    SUM(IF(pag_dyn.tipo = 'Multa', pag_dyn.monto, 0)) as multas,
    SUM(IF(pag_dyn.tipo = 'Liquidacion', pag_dyn.monto - pag_dyn.tarifa, 0)) as liquidaciones,
    SUM(pag_dyn.monto) as cobranza_total,
    (SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) -
        SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa)))) as debito_faltante,

    -- VENTAS (subconsultas)
    (SELECT COUNT(vent.id)
        FROM ventas vent
        INNER JOIN agencias ag ON vent.agencia = ag.AgenciaID
        WHERE ag.GerenciaID = ger.GerenciaID
        AND vent.anio = ?
        AND vent.Semana = ?) as numero_ventas,
    (SELECT COALESCE(SUM(vent.monto), 0)
        FROM ventas vent
        INNER JOIN agencias ag ON vent.agencia = ag.AgenciaID
        WHERE ag.GerenciaID = ger.GerenciaID
        AND vent.anio = ?
        AND vent.Semana = ?) as ventas,

    -- ASIGNACIONES
    (SELECT COALESCE(SUM(asign.monto), 0)
        FROM asignaciones_v2 asign
        INNER JOIN agencias ag ON asign.agencia = ag.AgenciaID
        WHERE ag.GerenciaID = ger.GerenciaID
        AND asign.anio = ?
        AND asign.semana = ?
        AND asign.agencia != '') as suma_asignaciones,

    -- EFECTIVO EN CAMPO
    (SUM(pag_dyn.monto) -
        (SELECT COALESCE(SUM(asign.monto), 0)
            FROM asignaciones_v2 asign
            INNER JOIN agencias ag ON asign.agencia = ag.AgenciaID
            WHERE ag.GerenciaID = ger.GerenciaID
            AND asign.anio = ?
            AND asign.semana = ?
            AND asign.agencia != '')) as efectivo_en_campo

FROM gerencias ger
-- CAMBIO: Usar agencias -> pagos_dynamic como ruta principal
INNER JOIN agencias agenc ON agenc.GerenciaID = ger.GerenciaID
INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID
    AND pag_dyn.anio = ?
    AND pag_dyn.semana = ?
    AND pag_dyn.tipo_aux = 'Pago'
-- LEFT JOIN a prestamos_v2 solo para Dia_de_pago
LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID
WHERE ger.GerenciaID = ?
GROUP BY ger.GerenciaID;
