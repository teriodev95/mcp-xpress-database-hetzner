-- ============================================================================
-- CALCULAR LIQUIDACIÓN DE PRÉSTAMO (VERSIÓN OPTIMIZADA v2)
-- ============================================================================
-- USA: porcentajes_liquidacion_v2 (tabla normalizada)
-- REQUISITO: Ejecutar primero porcentajes_liquidacion_v2_datos.sql
--
-- NOTA: El saldo se toma de prestamos_dynamic.saldo (más confiable)
--       NO de prestamos_v2.Saldo (puede estar desactualizado)
-- ============================================================================


-- ============================================================================
-- FUNCIÓN: fn_liquidacion(prestamo_id)
-- ============================================================================
-- Retorna solo el monto de liquidación
-- Usa el saldo más reciente de pagos_dynamic

DELIMITER //

DROP FUNCTION IF EXISTS fn_liquidacion //

CREATE FUNCTION fn_liquidacion(p_prestamo_id VARCHAR(32))
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(10,2);
    DECLARE v_plazo INT;
    DECLARE v_tipo_cliente VARCHAR(16);
    DECLARE v_anio_prestamo INT;
    DECLARE v_semana_prestamo INT;
    DECLARE v_semana_actual INT;
    DECLARE v_anio_actual INT;
    DECLARE v_semanas_transcurridas INT;
    DECLARE v_porcentaje INT DEFAULT 0;

    -- Obtener datos del préstamo
    SELECT plazo, Tipo_de_Cliente, Anio, Semana
    INTO v_plazo, v_tipo_cliente, v_anio_prestamo, v_semana_prestamo
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    -- Obtener semana actual
    SELECT semana, anio INTO v_semana_actual, v_anio_actual
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- Obtener saldo de prestamos_dynamic
    SELECT saldo INTO v_saldo
    FROM prestamos_dynamic
    WHERE prestamo_id = p_prestamo_id;

    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        RETURN NULL;
    END IF;

    -- Cuenta semanas transcurridas (NO incluye semana de entrega)
    SELECT COUNT(*) INTO v_semanas_transcurridas
    FROM calendario c
    WHERE (c.anio > v_anio_prestamo OR (c.anio = v_anio_prestamo AND c.semana > v_semana_prestamo))
      AND (c.anio < v_anio_actual OR (c.anio = v_anio_actual AND c.semana <= v_semana_actual));

    -- Obtener porcentaje
    SELECT COALESCE(porcentaje, 0) INTO v_porcentaje
    FROM porcentajes_liquidacion_v2
    WHERE plazo = v_plazo
      AND tipo_cliente = v_tipo_cliente
      AND semana = LEAST(v_semanas_transcurridas, v_plazo);

    RETURN ROUND(v_saldo * (100 - COALESCE(v_porcentaje, 0)) / 100, 2);
END //

DELIMITER ;


-- ============================================================================
-- PROCEDIMIENTO: sp_liquidacion(prestamo_id)
-- ============================================================================
-- Retorna: semana, descuento_en_dinero, descuento_en_porcentaje,
--          liquido_con, sem_transcurridas
-- Usa saldo de pagos_dynamic

DELIMITER //

DROP PROCEDURE IF EXISTS sp_liquidacion //

CREATE PROCEDURE sp_liquidacion(IN p_prestamo_id VARCHAR(32))
BEGIN
    SELECT
        c_actual.semana AS semana,
        ROUND(pdyn.saldo * COALESCE(pdl.porcentaje, 0) / 100, 2) AS descuento_en_dinero,
        COALESCE(pdl.porcentaje, 0) AS descuento_en_porcentaje,
        ROUND(pdyn.saldo * (100 - COALESCE(pdl.porcentaje, 0)) / 100, 2) AS liquido_con,
        (
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ) AS sem_transcurridas
    FROM prestamos_v2 p
    CROSS JOIN (
        SELECT semana, anio FROM calendario
        WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    ) c_actual
    -- Saldo actualizado de prestamos_dynamic
    INNER JOIN prestamos_dynamic pdyn ON pdyn.prestamo_id = p.PrestamoID
    -- Tabla de porcentajes
    LEFT JOIN porcentajes_liquidacion_v2 pdl ON
        pdl.plazo = p.plazo
        AND pdl.tipo_cliente = p.Tipo_de_Cliente
        AND pdl.semana = LEAST((
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ), p.plazo)
    WHERE p.PrestamoID = p_prestamo_id;
END //

DELIMITER ;


-- ============================================================================
-- PROCEDIMIENTO: sp_liquidacion_detalle(prestamo_id)
-- ============================================================================
-- Retorna información completa del préstamo + liquidación
-- Usa saldo de pagos_dynamic (más confiable)

DELIMITER //

DROP PROCEDURE IF EXISTS sp_liquidacion_detalle //

CREATE PROCEDURE sp_liquidacion_detalle(IN p_prestamo_id VARCHAR(32))
BEGIN
    SELECT
        p.PrestamoID,
        CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS cliente,
        p.Monto_otorgado,
        p.Total_a_pagar,
        p.plazo AS plazo_semanas,
        p.Tipo_de_Cliente,
        -- Saldo desde prestamos_dynamic (más confiable)
        ROUND(pdyn.saldo, 2) AS saldo_actual,
        -- Fecha de entrega del préstamo
        p.Semana AS semana_entrega,
        p.Anio AS anio_entrega,
        -- Semana actual
        c_actual.semana AS semana_actual,
        c_actual.anio AS anio_actual,
        -- Semanas transcurridas (NO incluye semana de entrega)
        (
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ) AS sem_transcurridas,
        -- Liquidación
        COALESCE(pdl.porcentaje, 0) AS descuento_en_porcentaje,
        ROUND(pdyn.saldo * COALESCE(pdl.porcentaje, 0) / 100, 2) AS descuento_en_dinero,
        ROUND(pdyn.saldo * (100 - COALESCE(pdl.porcentaje, 0)) / 100, 2) AS liquido_con,
        -- Estado
        CASE
            WHEN pdyn.saldo <= 0 THEN 'YA LIQUIDADO'
            WHEN pdl.porcentaje IS NULL THEN 'SIN DESCUENTO'
            WHEN pdl.porcentaje = 0 THEN 'FUERA DE PERIODO'
            ELSE 'DISPONIBLE'
        END AS estado
    FROM prestamos_v2 p
    CROSS JOIN (
        SELECT semana, anio FROM calendario
        WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    ) c_actual
    -- Saldo actualizado de prestamos_dynamic
    INNER JOIN prestamos_dynamic pdyn ON pdyn.prestamo_id = p.PrestamoID
    -- Tabla de porcentajes
    LEFT JOIN porcentajes_liquidacion_v2 pdl ON
        pdl.plazo = p.plazo
        AND pdl.tipo_cliente = p.Tipo_de_Cliente
        AND pdl.semana = LEAST((
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana > p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ), p.plazo)
    WHERE p.PrestamoID = p_prestamo_id;
END //

DELIMITER ;


-- ============================================================================
-- EJEMPLOS DE USO
-- ============================================================================

-- Función (solo monto de liquidación):
-- SELECT fn_liquidacion('N-2199-pl') AS monto_liquidacion;

-- Procedimiento simple (5 columnas):
-- CALL sp_liquidacion('N-2199-pl');

-- Procedimiento con detalle completo:
-- CALL sp_liquidacion_detalle('N-2199-pl');

-- Comparar saldos:
-- SELECT p.PrestamoID, p.Saldo as saldo_prestamos_v2, pdyn.saldo as saldo_prestamos_dynamic
-- FROM prestamos_v2 p
-- LEFT JOIN prestamos_dynamic pdyn ON pdyn.prestamo_id = p.PrestamoID
-- WHERE p.PrestamoID = 'N-2199-pl';
