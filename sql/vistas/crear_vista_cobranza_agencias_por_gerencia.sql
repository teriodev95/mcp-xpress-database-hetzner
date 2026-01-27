-- =====================================================
-- Vista: vw_cobranza_agencias_por_gerencia
-- Descripción: Combina débitos y cobranza por agencia dentro de gerencias
--              Usa debitos_historial y cobranza_historial
--              Incluye métricas calculadas (rendimiento %, débito faltante)
-- Fecha: 2026-01-20
-- =====================================================

CREATE OR REPLACE VIEW vw_cobranza_agencias_por_gerencia AS
SELECT
    -- Identificación
    a.GerenciaID as gerencia_id,
    g.deprecated_name as gerencia_nombre,
    ch.agencia,
    asa.Agente as nombre_agente,
    ch.semana,
    ch.anio,

    -- Débitos (desde debitos_historial)
    COALESCE(dh.clientes, 0) as total_clientes,
    COALESCE(dh.debito_miercoles, 0) as debito_miercoles,
    COALESCE(dh.debito_jueves, 0) as debito_jueves,
    COALESCE(dh.debito_viernes, 0) as debito_viernes,
    COALESCE(dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes, 0) as debito_total,

    -- Cobranza (desde cobranza_historial)
    ch.clientes_cobrados,
    ch.no_pagos,
    ch.numero_liquidaciones,
    ch.pagos_reducidos,
    ch.total_cobranza_pura,
    ch.monto_excedente,
    ch.multas,
    ch.liquidaciones,
    ch.total_de_descuento,

    -- Cobranza total calculada
    (ch.total_cobranza_pura + ch.monto_excedente + ch.liquidaciones) as cobranza_total,

    -- Débito faltante
    COALESCE(
        (dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes) - ch.total_cobranza_pura,
        0
    ) as debito_faltante,

    -- Rendimiento (%)
    ROUND(
        (ch.total_cobranza_pura / NULLIF(dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes, 0)) * 100,
        2
    ) as rendimiento_porcentaje,

    -- Metadata
    ch.created_at as fecha_captura

FROM cobranza_historial ch

-- JOIN con agencias para obtener GerenciaID
INNER JOIN agencias a ON ch.agencia = a.AgenciaID

-- JOIN con gerencias para obtener nombre
INNER JOIN gerencias g ON a.GerenciaID = g.GerenciaID

-- JOIN con agencias_status_auxilar para obtener nombre del agente
INNER JOIN agencias_status_auxilar asa ON ch.agencia = asa.Agencia

-- LEFT JOIN con debitos_historial (puede no existir para todas las semanas)
LEFT JOIN debitos_historial dh
    ON ch.agencia = dh.agencia
    AND ch.semana = dh.semana
    AND ch.anio = dh.anio;

-- =====================================================
-- Comentarios de la vista
-- =====================================================

ALTER VIEW vw_cobranza_agencias_por_gerencia
COMMENT = 'Vista combinada de débitos y cobranza por agencia dentro de gerencias';

-- =====================================================
-- Ejemplos de uso:
-- =====================================================

-- 1. Ver todas las agencias de una gerencia específica
-- SELECT * FROM vw_cobranza_agencias_por_gerencia
-- WHERE gerencia_id = 'GERM009' AND semana = 3 AND anio = 2026
-- ORDER BY agencia;

-- 2. Resumen por gerencia (agregado)
-- SELECT
--     gerencia_id,
--     gerencia_nombre,
--     COUNT(DISTINCT agencia) as total_agencias,
--     SUM(total_clientes) as total_clientes,
--     SUM(debito_total) as debito_total,
--     SUM(total_cobranza_pura) as cobranza_pura,
--     SUM(cobranza_total) as cobranza_total,
--     ROUND(SUM(total_cobranza_pura) / NULLIF(SUM(debito_total), 0) * 100, 2) as rendimiento
-- FROM vw_cobranza_agencias_por_gerencia
-- WHERE semana = 3 AND anio = 2026
-- GROUP BY gerencia_id, gerencia_nombre
-- ORDER BY gerencia_id;

-- 3. Top 10 agencias con mejor rendimiento
-- SELECT
--     gerencia_nombre,
--     agencia,
--     nombre_agente,
--     rendimiento_porcentaje,
--     total_cobranza_pura,
--     debito_total
-- FROM vw_cobranza_agencias_por_gerencia
-- WHERE semana = 3 AND anio = 2026
-- ORDER BY rendimiento_porcentaje DESC
-- LIMIT 10;

-- 4. Agencias con débito faltante mayor a $1000
-- SELECT
--     gerencia_nombre,
--     agencia,
--     nombre_agente,
--     debito_total,
--     total_cobranza_pura,
--     debito_faltante,
--     rendimiento_porcentaje
-- FROM vw_cobranza_agencias_por_gerencia
-- WHERE semana = 3 AND anio = 2026
--   AND debito_faltante > 1000
-- ORDER BY debito_faltante DESC;

-- 5. Comparar miércoles vs jueves vs viernes
-- SELECT
--     gerencia_nombre,
--     agencia,
--     debito_miercoles,
--     debito_jueves,
--     debito_viernes,
--     total_cobranza_pura,
--     CASE
--         WHEN debito_miercoles > debito_jueves AND debito_miercoles > debito_viernes THEN 'Miércoles'
--         WHEN debito_jueves > debito_miercoles AND debito_jueves > debito_viernes THEN 'Jueves'
--         ELSE 'Viernes'
--     END as dia_mayor_debito
-- FROM vw_cobranza_agencias_por_gerencia
-- WHERE semana = 3 AND anio = 2026
-- ORDER BY gerencia_id, agencia;

-- =====================================================
-- Notas:
-- =====================================================

-- 1. Esta vista combina datos de:
--    - cobranza_historial (snapshot de cobranza)
--    - debitos_historial (snapshot de débitos)
--    - agencias (relación con gerencias)
--    - gerencias (nombres)
--    - agencias_status_auxilar (nombres de agentes)

-- 2. Si debitos_historial no tiene datos para una semana,
--    los campos de débito mostrarán 0

-- 3. El rendimiento_porcentaje se calcula como:
--    (cobranza_pura / debito_total) * 100

-- 4. El debito_faltante se calcula como:
--    debito_total - cobranza_pura

-- 5. La vista es READ-ONLY, no se puede hacer INSERT/UPDATE/DELETE
