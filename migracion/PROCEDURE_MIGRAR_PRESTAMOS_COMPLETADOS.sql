-- =====================================================
-- Migración de Préstamos Completados
-- Versión: 4.0 (Sin FK de visitas)
-- =====================================================

-- =====================================================
-- PASO PREVIO: Eliminar FK de visitas (ejecutar una vez)
-- =====================================================
-- ALTER TABLE visitas DROP FOREIGN KEY visitas_prestamos_v2_PrestamoID_fk;

-- =====================================================
-- CONSULTAS DE VERIFICACIÓN
-- =====================================================

-- Total a migrar
SELECT COUNT(*) AS total_a_migrar
FROM prestamos_v2 pv
INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
WHERE pd.saldo <= 0;

-- Resumen por gerencia
SELECT
    pv.Gerencia,
    COUNT(*) AS cantidad,
    SUM(pd.cobrado) AS total_cobrado
FROM prestamos_v2 pv
INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
WHERE pd.saldo <= 0
GROUP BY pv.Gerencia
ORDER BY cantidad DESC;

-- =====================================================
-- PROCEDIMIENTO DE MIGRACIÓN
-- =====================================================
DROP PROCEDURE IF EXISTS sp_migrar_prestamos_completados;

DELIMITER $$
CREATE PROCEDURE sp_migrar_prestamos_completados()
BEGIN
    DECLARE v_migrados INT DEFAULT 0;

    -- 1. Insertar en prestamos_completados
    INSERT INTO prestamos_completados (
        PrestamoID, Cliente_ID, cliente_xpress_id, cliente_persona_id, aval_persona_id,
        No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
        Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
        Saldos_Migrados, wk_descu, Descuento, Porcentaje, Multas, wk_refi, Refin, Externo,
        Saldo, Cobrado,
        Tipo_de_credito, Status, Tipo_de_Cliente, Aclaracion, Dia_de_pago,
        Gerente_en_turno, Agente2, Capturista, NoServicio, Identificador_Credito,
        Seguridad, Depuracion, Folio_de_pagare, excel_index, impacta_en_comision
    )
    SELECT
        pv.PrestamoID, pv.Cliente_ID, pv.cliente_xpress_id, pv.cliente_persona_id, pv.aval_persona_id,
        pv.No_De_Contrato, pv.Agente, pv.Gerencia, pv.SucursalID, pv.Semana, pv.Anio, pv.plazo,
        pv.Monto_otorgado, pv.Cargo, pv.Total_a_pagar, pv.Primer_pago, pv.Tarifa,
        pv.Saldos_Migrados, pv.wk_descu, pv.Descuento, pv.Porcentaje, pv.Multas, pv.wk_refi, pv.Refin, pv.Externo,
        pd.saldo, pd.cobrado,
        pv.Tipo_de_credito, 'COMPLETADO', pv.Tipo_de_Cliente, pv.Aclaracion, pv.Dia_de_pago,
        pv.Gerente_en_turno, pv.Agente2, pv.Capturista, pv.NoServicio, pv.Identificador_Credito,
        pv.Seguridad, pv.Depuracion, pv.Folio_de_pagare, pv.excel_index, pv.impacta_en_comision
    FROM prestamos_v2 pv
    INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
    WHERE pd.saldo <= 0
      AND pv.PrestamoID NOT IN (SELECT PrestamoID FROM prestamos_completados);

    SET v_migrados = ROW_COUNT();

    -- 2. Eliminar de prestamos_v2 (trigger limpia prestamos_dynamic)
    DELETE pv FROM prestamos_v2 pv
    INNER JOIN prestamos_completados pc ON pv.PrestamoID = pc.PrestamoID;

    -- 3. Resultado
    SELECT
        v_migrados AS migrados,
        (SELECT COUNT(*) FROM prestamos_v2) AS activos,
        (SELECT COUNT(*) FROM prestamos_completados) AS completados;
END$$
DELIMITER ;

-- =====================================================
-- USO: CALL sp_migrar_prestamos_completados();
-- =====================================================
