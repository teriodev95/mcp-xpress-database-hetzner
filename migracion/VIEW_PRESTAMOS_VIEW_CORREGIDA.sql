-- =====================================================
-- Vista prestamos_view corregida
-- saldo_al_iniciar_semana calculado dinámicamente
-- usando tabla calendario para semana actual
-- =====================================================

CREATE OR REPLACE VIEW prestamos_view AS
SELECT
    pr.prestamoid AS prestamo_id,
    pr.cliente_id AS cliente_id,
    pr.nombres AS nombres,
    pr.apellido_paterno AS apellido_paterno,
    pr.apellido_materno AS apellido_materno,
    pr.direccion AS direccion,
    pr.noexterior AS no_exterior,
    pr.nointerior AS no_interior,
    pr.colonia AS colonia,
    pr.codigo_postal AS codigo_postal,
    pr.municipio AS municipio,
    pr.estado AS estado,
    pr.no_de_contrato AS no_de_contrato,
    pr.agente AS agencia,
    pr.gerencia AS gerencia,
    pr.sucursalid AS sucursal,
    pr.semana AS semana,
    pr.anio AS anio,
    pr.plazo AS plazo,
    pr.monto_otorgado AS monto_otorgado,
    pr.cargo AS cargo,
    pr.total_a_pagar AS total_a_pagar,
    pr.primer_pago AS primer_pago,
    pr.tarifa AS tarifa,
    pr.saldos_migrados AS saldos_migrados,
    pr.wk_descu AS wk_descu,
    pr.descuento AS descuento,
    pr.porcentaje AS porcentaje,
    pr.multas AS multas,
    pr.wk_refi AS wk_refi,
    pr.refin AS refin,
    pr.externo AS externo,
    prdyn.saldo AS saldo,
    prdyn.cobrado AS cobrado,
    pr.tipo_de_credito AS tipo_de_credito,
    pr.aclaracion AS aclaracion,
    pr.nombres_aval AS nombres_aval,
    pr.apellido_paterno_aval AS apellido_paterno_aval,
    pr.apellido_materno_aval AS apellido_materno_aval,
    pr.direccion_aval AS direccion_aval,
    pr.no_exterior_aval AS no_exterior_aval,
    pr.no_interior_aval AS no_interior_aval,
    pr.colonia_aval AS colonia_aval,
    pr.codigo_postal_aval AS codigo_postal_aval,
    pr.poblacion_aval AS poblacion_aval,
    pr.estado_aval AS estado_aval,
    pr.telefono_aval AS telefono_aval,
    pr.telefono_cliente AS telefono_cliente,
    pr.dia_de_pago AS dia_de_pago,
    pr.gerente_en_turno AS gerente_en_turno,
    pr.agente2 AS agente,
    pr.status AS status,
    pr.capturista AS capturista,
    pr.noServicio AS no_servicio,
    pr.tipo_de_cliente AS tipo_de_cliente,
    pr.identificador_credito AS identificador_credito,
    pr.seguridad AS seguridad,
    pr.depuracion AS depuracion,
    pr.folio_de_pagare AS folio_de_pagare,
    -- Saldo al iniciar semana = Total - pagos de semanas anteriores a la actual
    pr.total_a_pagar - COALESCE((
        SELECT SUM(pg.Monto)
        FROM pagos_v3 pg
        INNER JOIN calendario cal_pago ON pg.Semana = cal_pago.semana AND pg.Anio = cal_pago.anio
        INNER JOIN calendario cal_actual ON CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') BETWEEN cal_actual.desde AND cal_actual.hasta
        WHERE pg.PrestamoID = pr.prestamoid
          AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
          AND cal_pago.hasta < cal_actual.desde
    ), 0) AS saldo_al_iniciar_semana,
    pr.excel_index AS excel_index,
    pr.cliente_persona_id AS cliente_persona_id,
    pr.aval_persona_id AS aval_persona_id
FROM prestamos_v2_view pr
INNER JOIN prestamos_dynamic prdyn ON pr.prestamoid = prdyn.prestamo_id;
