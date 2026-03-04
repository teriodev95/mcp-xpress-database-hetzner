-- Vista: vw_cobranza_snapshots_reportes_generales
-- Toma débitos desglosados desde debitos_historial (fallback a cobranza_snapshots.debito).
-- Rendimientos por día (acumulativos):
--   rendimiento_miercoles = cobranza_pura vs debito_miercoles
--   rendimiento_jueves    = cobranza_pura vs (debito_mie + debito_jue)
--   rendimiento_viernes   = cobranza_pura vs (debito_mie + debito_jue + debito_vie)
--   rendimiento           = cobranza_pura vs debito total (general)
-- Adelantos (cobranza que excede el débito acumulado del día):
--   adelanto_miercoles    = cobranza_pura - debito_miercoles (cuando > 0)
--   adelanto_jueves       = cobranza_pura - (debito_mie + debito_jue) (cuando > 0)

CREATE OR REPLACE VIEW vw_cobranza_snapshots_reportes_generales AS
SELECT
    t.id,
    t.created_at,
    t.created_at_mx,
    t.fecha_mx,
    t.anio,
    t.semana,
    t.hora,
    t.agencia,
    t.gerencia,
    t.sucursal,
    t.clientes,
    t.no_pagos,

    -- Débitos
    t.debito,
    t.debito_miercoles,
    t.debito_jueves,
    t.debito_viernes,

    -- Cobranza
    t.cobranza_pura,
    t.excedente,
    t.liquidaciones,
    t.cobranza_total,

    -- Rendimientos por día (acumulativos)
    t.rendimiento_miercoles,
    t.rendimiento_jueves,
    t.rendimiento_viernes,

    -- Rendimiento general
    t.rendimiento,

    -- Faltantes por día (acumulativos)
    t.faltante_miercoles,
    t.faltante_jueves,
    t.faltante_viernes,
    t.faltante,

    -- Adelantos por día (cobranza que excede el débito acumulado)
    t.adelanto_miercoles,
    t.adelanto_jueves,

    t.ventas_cantidad,
    t.ventas_monto,
    ELT(WEEKDAY(t.fecha_mx) + 1,
        'Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo'
    ) AS dia_semana_es,

    -- Día en que este snapshot se reporta (siguiente día hábil de reporte)
    CASE ELT(WEEKDAY(t.fecha_mx) + 1,
             'Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo')
        WHEN 'Miercoles' THEN 'Jueves'
        WHEN 'Jueves'    THEN 'Viernes'
        WHEN 'Viernes'   THEN 'Sabado'
        WHEN 'Sabado'    THEN 'Lunes'
        WHEN 'Domingo'   THEN 'Lunes'
        WHEN 'Lunes'     THEN 'Martes'
        WHEN 'Martes'    THEN 'Martes'
    END AS a_reportar_en,

    -- Snapshot de reporte: el más reciente del día (max hora disponible),
    -- solo para días que alimentan el reporte (excluye Sábado y Lunes
    -- porque Domingo y Martes son más recientes para Lunes/Martes resp.)
    IF(
        t.hora = t.max_hora_del_dia
        AND ELT(WEEKDAY(t.fecha_mx) + 1,
                'Lunes','Martes','Miercoles','Jueves','Viernes','Sabado','Domingo')
            NOT IN ('Sabado', 'Lunes'),
        1, 0
    ) AS es_reporte_del_dia
FROM (
    SELECT
        cs.id,
        cs.created_at,
        CONVERT_TZ(cs.created_at, 'UTC', 'America/Mexico_City') AS created_at_mx,
        CAST(CONVERT_TZ(cs.created_at, 'UTC', 'America/Mexico_City') AS DATE) AS fecha_mx,
        cs.anio,
        cs.semana,
        cs.hora_real AS hora,
        cs.agencia,
        a.GerenciaID AS gerencia,
        g.sucursal,
        cs.clientes,
        cs.no_pagos,

        -- Débito total: preferir historial, fallback a snapshot
        COALESCE(
            dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes,
            cs.debito
        ) AS debito,

        -- Débitos desglosados por día
        COALESCE(dh.debito_miercoles, 0) AS debito_miercoles,
        COALESCE(dh.debito_jueves, 0)    AS debito_jueves,
        COALESCE(dh.debito_viernes, 0)   AS debito_viernes,

        cs.cobranza_pura,
        cs.excedente,
        cs.liquidaciones,
        ROUND(cs.cobranza_pura + cs.excedente + cs.liquidaciones, 2) AS cobranza_total,

        -- Rendimiento miércoles: cobranza vs solo débito miércoles
        ROUND(
            cs.cobranza_pura / NULLIF(COALESCE(dh.debito_miercoles, 0), 0) * 100, 2
        ) AS rendimiento_miercoles,

        -- Rendimiento jueves: cobranza vs débito miércoles + jueves
        ROUND(
            cs.cobranza_pura / NULLIF(
                COALESCE(dh.debito_miercoles, 0) + COALESCE(dh.debito_jueves, 0),
                0
            ) * 100, 2
        ) AS rendimiento_jueves,

        -- Rendimiento viernes: cobranza vs débito mié + jue + vie (= total)
        ROUND(
            cs.cobranza_pura / NULLIF(
                COALESCE(dh.debito_miercoles, 0) + COALESCE(dh.debito_jueves, 0) + COALESCE(dh.debito_viernes, 0),
                0
            ) * 100, 2
        ) AS rendimiento_viernes,

        -- Rendimiento general (mismo que viernes, con fallback a cs.debito)
        ROUND(
            cs.cobranza_pura / NULLIF(
                COALESCE(
                    dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes,
                    cs.debito
                ), 0
            ) * 100, 2
        ) AS rendimiento,

        -- Faltante miércoles: lo que falta para cubrir solo débito miércoles
        GREATEST(
            COALESCE(dh.debito_miercoles, 0) - cs.cobranza_pura,
            0
        ) AS faltante_miercoles,

        -- Faltante jueves: lo que falta para cubrir débito mié + jue
        GREATEST(
            COALESCE(dh.debito_miercoles, 0) + COALESCE(dh.debito_jueves, 0) - cs.cobranza_pura,
            0
        ) AS faltante_jueves,

        -- Faltante viernes: lo que falta para cubrir débito mié + jue + vie
        GREATEST(
            COALESCE(dh.debito_miercoles, 0) + COALESCE(dh.debito_jueves, 0) + COALESCE(dh.debito_viernes, 0) - cs.cobranza_pura,
            0
        ) AS faltante_viernes,

        -- Faltante general (mismo que viernes, con fallback)
        GREATEST(
            COALESCE(
                dh.debito_miercoles + dh.debito_jueves + dh.debito_viernes,
                cs.debito
            ) - cs.cobranza_pura,
            0
        ) AS faltante,

        -- Adelanto miércoles: cobranza que excede el débito del miércoles
        GREATEST(
            cs.cobranza_pura - COALESCE(dh.debito_miercoles, 0),
            0
        ) AS adelanto_miercoles,

        -- Adelanto jueves: cobranza que excede el débito mié + jue
        GREATEST(
            cs.cobranza_pura - (COALESCE(dh.debito_miercoles, 0) + COALESCE(dh.debito_jueves, 0)),
            0
        ) AS adelanto_jueves,

        cs.ventas_cantidad,
        cs.ventas_monto,

        -- Hora máxima disponible por agencia+día (para marcar el snapshot más reciente)
        ultimo.max_hora AS max_hora_del_dia

    FROM cobranza_snapshots cs
    LEFT JOIN agencias a
        ON a.AgenciaID = cs.agencia
    LEFT JOIN gerencias g
        ON g.GerenciaID = a.GerenciaID
    LEFT JOIN debitos_historial dh
        ON dh.agencia COLLATE utf8mb4_general_ci = cs.agencia
        AND dh.semana = cs.semana
        AND dh.anio = cs.anio
    LEFT JOIN (
        SELECT agencia, semana, anio,
               CAST(CONVERT_TZ(created_at, 'UTC', 'America/Mexico_City') AS DATE) AS fecha,
               MAX(hora_real) AS max_hora
        FROM cobranza_snapshots
        GROUP BY agencia, semana, anio, fecha
    ) ultimo
        ON ultimo.agencia = cs.agencia
        AND ultimo.semana  = cs.semana
        AND ultimo.anio    = cs.anio
        AND ultimo.fecha   = CAST(CONVERT_TZ(cs.created_at, 'UTC', 'America/Mexico_City') AS DATE)
) t;
