-- =====================================================
-- CORRECCIÓN: prestamos_view - Bug en saldo_al_iniciar_semana
-- =====================================================
--
-- PROBLEMA ENCONTRADO:
-- --------------------
-- La vista usa CONVERT_TZ(current_timestamp(),'UTC','America/Mexico_City')
-- para comparar con calendario.desde y calendario.hasta (tipo DATE).
--
-- Esto FALLA después del mediodía porque:
-- - CONVERT_TZ retorna DATETIME: '2025-12-02 21:02:07'
-- - calendario.hasta es DATE: '2025-12-02' (equivale a '2025-12-02 00:00:00')
-- - La comparación BETWEEN falla porque 21:02 > 00:00
--
-- RESULTADO:
-- - saldo_al_iniciar_semana = total_a_pagar (ignora todos los pagos)
-- - Después del mediodía, la subconsulta no encuentra la semana actual
--   y retorna NULL, haciendo que COALESCE devuelva 0
--
-- SOLUCIÓN:
-- ---------
-- Usar DATE(CONVERT_TZ(...)) para comparar DATE con DATE
--
-- =====================================================

-- Primero verificar el problema actual:
-- SELECT prestamo_id, saldo_al_iniciar_semana, saldo, total_a_pagar
-- FROM prestamos_view WHERE prestamo_id = '14164-ca';
-- Esperado: saldo_al_iniciar_semana = 1650.00
-- Actual (bug): saldo_al_iniciar_semana = 4410.00

-- =====================================================
-- VISTA CORREGIDA
-- =====================================================

CREATE OR REPLACE
ALGORITHM=UNDEFINED
DEFINER=`xpress_admin`@`%`
SQL SECURITY DEFINER
VIEW `prestamos_view` AS
SELECT
    `pr`.`prestamoid` AS `prestamo_id`,
    `pr`.`cliente_id` AS `cliente_id`,
    `pr`.`nombres` AS `nombres`,
    `pr`.`apellido_paterno` AS `apellido_paterno`,
    `pr`.`apellido_materno` AS `apellido_materno`,
    `pr`.`direccion` AS `direccion`,
    `pr`.`noexterior` AS `no_exterior`,
    `pr`.`nointerior` AS `no_interior`,
    `pr`.`colonia` AS `colonia`,
    `pr`.`codigo_postal` AS `codigo_postal`,
    `pr`.`municipio` AS `municipio`,
    `pr`.`estado` AS `estado`,
    `pr`.`no_de_contrato` AS `no_de_contrato`,
    `pr`.`agente` AS `agencia`,
    `pr`.`gerencia` AS `gerencia`,
    `pr`.`sucursalid` AS `sucursal`,
    `pr`.`semana` AS `semana`,
    `pr`.`anio` AS `anio`,
    `pr`.`plazo` AS `plazo`,
    `pr`.`monto_otorgado` AS `monto_otorgado`,
    `pr`.`cargo` AS `cargo`,
    `pr`.`total_a_pagar` AS `total_a_pagar`,
    `pr`.`primer_pago` AS `primer_pago`,
    `pr`.`tarifa` AS `tarifa`,
    `pr`.`saldos_migrados` AS `saldos_migrados`,
    `pr`.`wk_descu` AS `wk_descu`,
    `pr`.`descuento` AS `descuento`,
    `pr`.`porcentaje` AS `porcentaje`,
    `pr`.`multas` AS `multas`,
    `pr`.`wk_refi` AS `wk_refi`,
    `pr`.`refin` AS `refin`,
    `pr`.`externo` AS `externo`,
    `prdyn`.`saldo` AS `saldo`,
    `prdyn`.`cobrado` AS `cobrado`,
    `pr`.`tipo_de_credito` AS `tipo_de_credito`,
    `pr`.`aclaracion` AS `aclaracion`,
    `pr`.`nombres_aval` AS `nombres_aval`,
    `pr`.`apellido_paterno_aval` AS `apellido_paterno_aval`,
    `pr`.`apellido_materno_aval` AS `apellido_materno_aval`,
    `pr`.`direccion_aval` AS `direccion_aval`,
    `pr`.`no_exterior_aval` AS `no_exterior_aval`,
    `pr`.`no_interior_aval` AS `no_interior_aval`,
    `pr`.`colonia_aval` AS `colonia_aval`,
    `pr`.`codigo_postal_aval` AS `codigo_postal_aval`,
    `pr`.`poblacion_aval` AS `poblacion_aval`,
    `pr`.`estado_aval` AS `estado_aval`,
    `pr`.`telefono_aval` AS `telefono_aval`,
    `pr`.`telefono_cliente` AS `telefono_cliente`,
    `pr`.`dia_de_pago` AS `dia_de_pago`,
    `pr`.`gerente_en_turno` AS `gerente_en_turno`,
    `pr`.`agente2` AS `agente`,
    `pr`.`status` AS `status`,
    `pr`.`capturista` AS `capturista`,
    `pr`.`noServicio` AS `no_servicio`,
    `pr`.`tipo_de_cliente` AS `tipo_de_cliente`,
    `pr`.`identificador_credito` AS `identificador_credito`,
    `pr`.`seguridad` AS `seguridad`,
    `pr`.`depuracion` AS `depuracion`,
    `pr`.`folio_de_pagare` AS `folio_de_pagare`,
    -- =====================================================
    -- CORRECCIÓN: Usar DATE() para comparar correctamente
    -- =====================================================
    `pr`.`total_a_pagar` - COALESCE(
        (SELECT SUM(`pg`.`Monto`)
         FROM ((`pagos_v3` `pg`
                JOIN `calendario` `cal_pago`
                    ON (`pg`.`Semana` = `cal_pago`.`semana`
                        AND `pg`.`Anio` = `cal_pago`.`anio`))
               JOIN `calendario` `cal_actual`
                    -- CAMBIO: DATE() agregado aquí
                    ON (DATE(CONVERT_TZ(CURRENT_TIMESTAMP(), 'UTC', 'America/Mexico_City'))
                        BETWEEN `cal_actual`.`desde` AND `cal_actual`.`hasta`))
         WHERE `pg`.`PrestamoID` = `pr`.`prestamoid`
           AND `pg`.`Tipo` NOT IN ('Multa', 'Visita', 'No_pago')
           AND `cal_pago`.`hasta` < `cal_actual`.`desde`),
        0
    ) AS `saldo_al_iniciar_semana`,
    `pr`.`excel_index` AS `excel_index`,
    `pr`.`cliente_persona_id` AS `cliente_persona_id`,
    `pr`.`aval_persona_id` AS `aval_persona_id`
FROM (`prestamos_v2_view` `pr`
      JOIN `prestamos_dynamic` `prdyn`
          ON (`pr`.`prestamoid` = `prdyn`.`prestamo_id`));

-- =====================================================
-- VERIFICACIÓN POST-CORRECCIÓN
-- =====================================================
-- Ejecutar estas queries para validar:

-- 1. Verificar que la vista retorna valores correctos:
-- SELECT prestamo_id, saldo_al_iniciar_semana, saldo, total_a_pagar
-- FROM prestamos_view WHERE prestamo_id = '14164-ca';
-- Esperado: saldo_al_iniciar_semana = 1650.00 (NO 4410.00)

-- 2. Comparar con cálculo manual:
-- SELECT
--     pv.prestamo_id,
--     pv.saldo_al_iniciar_semana as desde_vista,
--     pd.abre_con as desde_pagos_dynamic,
--     pv.saldo_al_iniciar_semana - pd.abre_con as diferencia
-- FROM prestamos_view pv
-- JOIN pagos_dynamic pd ON pv.prestamo_id = pd.prestamo_id
--     AND pd.semana = 48 AND pd.anio = 2025 AND pd.tipo_aux = 'Pago'
-- WHERE pv.prestamo_id = '14164-ca';
-- Esperado: diferencia = 0

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
--
-- 1. Este bug afecta a TODOS los préstamos después del mediodía
--    (hora Ciudad de México)
--
-- 2. La corrección es retroactiva - una vez aplicada, todas las
--    consultas retornarán valores correctos
--
-- 3. El campo saldo_al_iniciar_semana debe coincidir con el
--    AbreCon de pagos_dynamic para la semana actual
--
-- =====================================================
