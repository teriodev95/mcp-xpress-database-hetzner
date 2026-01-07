-- =====================================================
-- Procedure: revertir_migracion_prestamo (CORREGIDO)
-- Descripción: Revierte un préstamo de prestamos_completados
--              a prestamos_v2, obteniendo los datos personales
--              del cliente y aval desde la tabla personas.
-- Fecha: 2025-12-08
-- =====================================================

DELIMITER //

DROP PROCEDURE IF EXISTS revertir_migracion_prestamo//

CREATE PROCEDURE revertir_migracion_prestamo(
    IN p_prestamo_id VARCHAR(32)
)
proc_body: BEGIN
    DECLARE v_existe_completado INT DEFAULT 0;
    DECLARE v_ya_existe_v2 INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(500);

    -- Manejador de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SELECT
            'ERROR' AS status,
            p_prestamo_id AS prestamo_id,
            v_error_msg AS mensaje;
    END;

    -- Validar que se proporcionó un ID
    IF p_prestamo_id IS NULL OR TRIM(p_prestamo_id) = '' THEN
        SELECT
            'ERROR' AS status,
            NULL AS prestamo_id,
            'Debe proporcionar un PrestamoID válido' AS mensaje;
        LEAVE proc_body;
    END IF;

    -- Verificar si el préstamo existe en prestamos_completados
    SELECT COUNT(*) INTO v_existe_completado
    FROM prestamos_completados
    WHERE PrestamoID = p_prestamo_id;

    IF v_existe_completado = 0 THEN
        SELECT
            'ERROR' AS status,
            p_prestamo_id AS prestamo_id,
            'El préstamo no existe en prestamos_completados' AS mensaje;
        LEAVE proc_body;
    END IF;

    -- Verificar que NO exista ya en prestamos_v2 (evitar duplicados)
    SELECT COUNT(*) INTO v_ya_existe_v2
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    IF v_ya_existe_v2 > 0 THEN
        SELECT
            'ERROR' AS status,
            p_prestamo_id AS prestamo_id,
            'El préstamo ya existe en prestamos_v2. No se puede revertir.' AS mensaje;
        LEAVE proc_body;
    END IF;

    START TRANSACTION;

    -- Paso 1: Insertar de vuelta en prestamos_v2 con datos de personas
    INSERT INTO prestamos_v2 (
        PrestamoID, Cliente_ID, cliente_xpress_id, cliente_persona_id, aval_persona_id,
        -- Datos del cliente desde tabla personas
        Nombres, Apellido_Paterno, Apellido_Materno,
        Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
        Telefono_Cliente,
        -- Datos del aval desde tabla personas
        Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
        Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
        Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval,
        -- Resto de campos del préstamo
        No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo, Monto_otorgado,
        Cargo, Total_a_pagar, Primer_pago, Tarifa, Saldos_Migrados, wk_descu, Descuento,
        Porcentaje, Multas, wk_refi, Refin, Externo, Saldo, Cobrado, Tipo_de_credito,
        Aclaracion, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista, NoServicio,
        Tipo_de_Cliente, Identificador_Credito, Seguridad, Depuracion, Folio_de_pagare,
        excel_index, impacta_en_comision
    )
    SELECT
        pc.PrestamoID, pc.Cliente_ID, pc.cliente_xpress_id, pc.cliente_persona_id, pc.aval_persona_id,
        -- Datos del cliente desde tabla personas (con valores por defecto si no existe)
        COALESCE(cli.nombres, 'SIN DATOS') AS Nombres,
        COALESCE(cli.apellido_paterno, '') AS Apellido_Paterno,
        COALESCE(cli.apellido_materno, '') AS Apellido_Materno,
        COALESCE(cli.calle, 'SIN DIRECCION') AS Direccion,
        cli.no_exterior AS NoExterior,
        cli.no_interior AS NoInterior,
        COALESCE(cli.colonia, 'SIN COLONIA') AS Colonia,
        COALESCE(cli.codigo_postal, '00000') AS Codigo_postal,
        cli.municipio AS Municipio,
        COALESCE(cli.estado, 'SIN ESTADO') AS Estado,
        cli.telefono AS Telefono_Cliente,
        -- Datos del aval desde tabla personas (con valores por defecto si no existe)
        COALESCE(aval.nombres, 'SIN AVAL') AS Nombres_Aval,
        aval.apellido_paterno AS Apellido_Paterno_Aval,
        aval.apellido_materno AS Apellido_Materno_Aval,
        COALESCE(aval.calle, 'SIN DIRECCION') AS Direccion_Aval,
        aval.no_exterior AS No_Exterior_Aval,
        aval.no_interior AS No_Interior_Aval,
        aval.colonia AS Colonia_Aval,
        aval.codigo_postal AS Codigo_Postal_Aval,
        COALESCE(aval.municipio, 'SIN POBLACION') AS Poblacion_Aval,
        COALESCE(aval.estado, 'SIN ESTADO') AS Estado_Aval,
        aval.telefono AS Telefono_Aval,
        -- Resto de campos del préstamo
        pc.No_De_Contrato, pc.Agente, pc.Gerencia, pc.SucursalID, pc.Semana, pc.Anio, pc.plazo, pc.Monto_otorgado,
        pc.Cargo, pc.Total_a_pagar, pc.Primer_pago, pc.Tarifa, pc.Saldos_Migrados, pc.wk_descu, pc.Descuento,
        pc.Porcentaje, pc.Multas, pc.wk_refi, pc.Refin, pc.Externo, pc.Saldo, pc.Cobrado, pc.Tipo_de_credito,
        pc.Aclaracion, pc.Dia_de_pago, pc.Gerente_en_turno, pc.Agente2, pc.Status, pc.Capturista, pc.NoServicio,
        pc.Tipo_de_Cliente, pc.Identificador_Credito, pc.Seguridad, pc.Depuracion, pc.Folio_de_pagare,
        pc.excel_index, pc.impacta_en_comision
    FROM prestamos_completados pc
    LEFT JOIN personas cli ON pc.cliente_persona_id = cli.id
    LEFT JOIN personas aval ON pc.aval_persona_id = aval.id
    WHERE pc.PrestamoID = p_prestamo_id;

    -- Validar que el INSERT fue exitoso
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SELECT
            'ERROR' AS status,
            p_prestamo_id AS prestamo_id,
            'No se pudo insertar en prestamos_v2. Operación cancelada.' AS mensaje;
        LEAVE proc_body;
    END IF;

    -- Paso 2: Recrear registro en prestamos_dynamic calculando saldo/cobrado desde pagos_v3
    INSERT INTO prestamos_dynamic (prestamo_id, saldo, cobrado)
    SELECT
        p.PrestamoID,
        p.Total_a_pagar - COALESCE(SUM(pg.Monto), 0) AS saldo,
        COALESCE(SUM(pg.Monto), 0) AS cobrado
    FROM prestamos_v2 p
    LEFT JOIN pagos_v3 pg ON p.PrestamoID = pg.PrestamoID
        AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
    WHERE p.PrestamoID = p_prestamo_id
    GROUP BY p.PrestamoID, p.Total_a_pagar
    ON DUPLICATE KEY UPDATE
        saldo = VALUES(saldo),
        cobrado = VALUES(cobrado);

    -- Paso 3: Eliminar de prestamos_completados
    DELETE FROM prestamos_completados
    WHERE PrestamoID = p_prestamo_id;

    -- Validar que el DELETE fue exitoso
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SELECT
            'ERROR' AS status,
            p_prestamo_id AS prestamo_id,
            'No se pudo eliminar de prestamos_completados. Operación cancelada.' AS mensaje;
        LEAVE proc_body;
    END IF;

    COMMIT;

    -- Resultado exitoso con valores calculados desde pagos_v3
    SELECT
        'SUCCESS' AS status,
        p_prestamo_id AS prestamo_id,
        pd.saldo AS saldo_calculado,
        pd.cobrado AS cobrado_calculado,
        CONCAT('Préstamo ', p_prestamo_id, ' revertido exitosamente a prestamos_v2') AS mensaje,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') AS fecha_reversion
    FROM prestamos_dynamic pd
    WHERE pd.prestamo_id = p_prestamo_id;

END//

DELIMITER ;

-- =====================================================
-- Uso:
-- CALL revertir_migracion_prestamo('L-12345-di');
-- =====================================================
