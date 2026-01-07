-- =====================================================
-- Procedimiento para Migrar Préstamos Completados
-- =====================================================
-- Migra automáticamente préstamos con saldo <= 0 desde
-- prestamos_v2 a prestamos_completados
--
-- Fuente de verdad: prestamos_dynamic (saldo calculado
-- dinámicamente desde pagos_dynamic)
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `migrar_prestamos_completados`$$

CREATE PROCEDURE `migrar_prestamos_completados`()
BEGIN
    -- Variables
    DECLARE v_registros_migrados INT DEFAULT 0;
    DECLARE v_registros_eliminados INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(500);

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SELECT
            'ERROR' AS status,
            v_error_msg AS mensaje,
            0 AS registros_migrados;
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Migrar préstamos completados
    INSERT INTO prestamos_completados (
        PrestamoID,
        Cliente_ID,
        cliente_xpress_id,
        cliente_persona_id,
        aval_persona_id,
        No_De_Contrato,
        Agente,
        Gerencia,
        SucursalID,
        Semana,
        Anio,
        plazo,
        Monto_otorgado,
        Cargo,
        Total_a_pagar,
        Primer_pago,
        Tarifa,
        Saldos_Migrados,
        wk_descu,
        Descuento,
        Porcentaje,
        Multas,
        wk_refi,
        Refin,
        Externo,
        Saldo,
        Cobrado,
        Tipo_de_credito,
        Aclaracion,
        Dia_de_pago,
        Gerente_en_turno,
        Agente2,
        Status,
        Capturista,
        NoServicio,
        Tipo_de_Cliente,
        Identificador_Credito,
        Seguridad,
        Depuracion,
        Folio_de_pagare,
        excel_index,
        impacta_en_comision
    )
    SELECT
        p.PrestamoID,
        p.Cliente_ID,
        p.cliente_xpress_id,
        p.cliente_persona_id,
        p.aval_persona_id,
        p.No_De_Contrato,
        p.Agente,
        p.Gerencia,
        p.SucursalID,
        p.Semana,
        p.Anio,
        p.plazo,
        p.Monto_otorgado,
        p.Cargo,
        p.Total_a_pagar,
        p.Primer_pago,
        p.Tarifa,
        p.Saldos_Migrados,
        p.wk_descu,
        p.Descuento,
        p.Porcentaje,
        p.Multas,
        p.wk_refi,
        p.Refin,
        p.Externo,
        pd.saldo,
        pd.cobrado,
        p.Tipo_de_credito,
        p.Aclaracion,
        p.Dia_de_pago,
        p.Gerente_en_turno,
        p.Agente2,
        p.Status,
        p.Capturista,
        p.NoServicio,
        p.Tipo_de_Cliente,
        p.Identificador_Credito,
        p.Seguridad,
        p.Depuracion,
        p.Folio_de_pagare,
        p.excel_index,
        p.impacta_en_comision
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE pd.saldo <= 0 OR pd.saldo IS NULL
    ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;

    SET v_registros_migrados = ROW_COUNT();

    -- Eliminar de prestamos_v2
    DELETE p
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE pd.saldo <= 0 OR pd.saldo IS NULL;

    SET v_registros_eliminados = ROW_COUNT();

    COMMIT;

    -- Retornar resultado
    SELECT
        'SUCCESS' AS status,
        v_registros_migrados AS registros_migrados,
        v_registros_eliminados AS registros_eliminados,
        CONCAT('Migración exitosa: ', v_registros_migrados, ' registros') AS mensaje,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') AS fecha_migracion;

END$$

DELIMITER ;

-- =====================================================
-- Procedimiento para Verificar Préstamos Completados
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS `verificar_prestamos_completados`$$

CREATE PROCEDURE `verificar_prestamos_completados`()
BEGIN
    -- Resumen general
    SELECT
        COUNT(*) AS total_listos_migrar,
        SUM(pd.cobrado) AS total_cobrado,
        MIN(p.Semana) AS semana_min,
        MIN(p.Anio) AS anio_min,
        MAX(p.Semana) AS semana_max,
        MAX(p.Anio) AS anio_max
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE pd.saldo <= 0 OR pd.saldo IS NULL;

    -- Por gerencia
    SELECT
        p.Gerencia,
        COUNT(*) AS total,
        SUM(pd.cobrado) AS cobrado,
        AVG(pd.cobrado) AS promedio
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE pd.saldo <= 0 OR pd.saldo IS NULL
    GROUP BY p.Gerencia
    ORDER BY total DESC;

    -- Discrepancias
    SELECT
        COUNT(*) AS total_discrepancias,
        SUM(CASE WHEN p.Saldo = 0 AND pd.saldo > 0 THEN 1 ELSE 0 END) AS v2_cero_dynamic_pendiente,
        SUM(CASE WHEN p.Saldo > 0 AND pd.saldo = 0 THEN 1 ELSE 0 END) AS v2_pendiente_dynamic_cero
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE p.Saldo != pd.saldo;

END$$

DELIMITER ;

-- =====================================================
-- Uso
-- =====================================================
-- 1. Verificar: CALL verificar_prestamos_completados();
-- 2. Migrar: CALL migrar_prestamos_completados();
-- 3. Validar: SELECT COUNT(*) FROM prestamos_completados;
-- =====================================================
