-- ===========================================================
-- FIX: Corregir sufijo 'xx' → 'gc' para préstamos GoCash
-- y actualizar ambos SPs para incluir 'gocash'
-- ===========================================================

-- ===========================================================
-- PARTE 1: Corregir los 23 PrestamoIDs existentes (xx → gc)
-- ===========================================================

-- 1.1 prestamos_v2
UPDATE prestamos_v2
SET PrestamoID = REPLACE(PrestamoID, '01xx', '01gc')
WHERE PrestamoID LIKE '09.26-%-01xx'
  AND SucursalID = 'gocash';

-- 1.2 prestamos_dynamic (prestamo_id y prestamo)
UPDATE prestamos_dynamic
SET prestamo_id = REPLACE(prestamo_id, '01xx', '01gc')
WHERE prestamo_id LIKE '09.26-%-01xx';

-- 1.3 pagos_v3 (PrestamoID y Prestamo)
UPDATE pagos_v3
SET PrestamoID = REPLACE(PrestamoID, '01xx', '01gc'),
    Prestamo   = REPLACE(Prestamo, '01xx', '01gc')
WHERE PrestamoID LIKE '09.26-%-01xx';

-- 1.4 pagos_dynamic (prestamo_id y prestamo)
UPDATE pagos_dynamic
SET prestamo_id = REPLACE(prestamo_id, '01xx', '01gc'),
    prestamo    = REPLACE(prestamo, '01xx', '01gc')
WHERE prestamo_id LIKE '09.26-%-01xx';

-- 1.5 prestamos_borradores (PrestamoID_propuesto)
UPDATE prestamos_borradores
SET PrestamoID_propuesto = REPLACE(PrestamoID_propuesto, '01xx', '01gc')
WHERE PrestamoID_propuesto LIKE '09.26-%-01xx'
  AND SucursalID = 'gocash';


-- ===========================================================
-- PARTE 2: Actualizar SP aprobar_borrador_individual
-- ===========================================================

DROP PROCEDURE IF EXISTS aprobar_borrador_individual;

DELIMITER $$

CREATE PROCEDURE aprobar_borrador_individual(
    IN p_borrador_id INT
)
main_block: BEGIN
    DECLARE v_fecha_actual DATETIME;
    DECLARE v_prestamo_id VARCHAR(32);
    DECLARE v_pago_id VARCHAR(64);
    DECLARE v_estado_borrador VARCHAR(20);
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_gerencia VARCHAR(16);
    DECLARE v_sucursal_id VARCHAR(16);
    DECLARE v_consecutivo INT;
    DECLARE v_sucursal_suffix VARCHAR(2);

    -- Variables para datos del borrador
    DECLARE v_cliente_id VARCHAR(255);
    DECLARE v_nombres VARCHAR(60);
    DECLARE v_apellido_paterno VARCHAR(50);
    DECLARE v_apellido_materno VARCHAR(50);
    DECLARE v_direccion VARCHAR(128);
    DECLARE v_no_exterior VARCHAR(8);
    DECLARE v_no_interior VARCHAR(8);
    DECLARE v_colonia VARCHAR(64);
    DECLARE v_codigo_postal VARCHAR(8);
    DECLARE v_municipio VARCHAR(64);
    DECLARE v_estado VARCHAR(32);
    DECLARE v_telefono_cliente VARCHAR(62);
    DECLARE v_no_contrato VARCHAR(16);
    DECLARE v_agente VARCHAR(16);
    DECLARE v_plazo INT;
    DECLARE v_monto_otorgado INT;
    DECLARE v_cargo DECIMAL(8,2);
    DECLARE v_total_a_pagar DECIMAL(10,2);
    DECLARE v_primer_pago DECIMAL(8,2);
    DECLARE v_tarifa DECIMAL(8,2);
    DECLARE v_saldo DECIMAL(10,2);
    DECLARE v_tipo_credito VARCHAR(32);
    DECLARE v_nombres_aval VARCHAR(60);
    DECLARE v_apellido_paterno_aval VARCHAR(50);
    DECLARE v_apellido_materno_aval VARCHAR(50);
    DECLARE v_direccion_aval VARCHAR(128);
    DECLARE v_no_exterior_aval VARCHAR(8);
    DECLARE v_no_interior_aval VARCHAR(8);
    DECLARE v_colonia_aval VARCHAR(64);
    DECLARE v_codigo_postal_aval VARCHAR(8);
    DECLARE v_poblacion_aval VARCHAR(64);
    DECLARE v_estado_aval VARCHAR(32);
    DECLARE v_telefono_aval VARCHAR(60);
    DECLARE v_no_servicio_aval VARCHAR(32);
    DECLARE v_dia_pago VARCHAR(16);
    DECLARE v_gerente_turno VARCHAR(32);
    DECLARE v_agente2 VARCHAR(64);
    DECLARE v_status VARCHAR(16);
    DECLARE v_capturista VARCHAR(16);
    DECLARE v_no_servicio VARCHAR(32);
    DECLARE v_tipo_cliente VARCHAR(16);
    DECLARE v_identificador VARCHAR(64);
    DECLARE v_seguridad VARCHAR(128);
    DECLARE v_folio_pagare VARCHAR(16);
    DECLARE v_cliente_persona_id VARCHAR(255);
    DECLARE v_aval_persona_id VARCHAR(255);
    DECLARE v_impacta_comision TINYINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT NULL AS prestamo_id, 'ERROR' AS estado, 'Ocurrió un error al aprobar el borrador' AS mensaje;
    END;

    -- Fecha actual en zona horaria de México
    SET v_fecha_actual = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City');

    START TRANSACTION;

    -- =========================================================
    -- PASO 1: Verificar que el borrador existe y está pendiente
    -- =========================================================
    SELECT estado_borrador INTO v_estado_borrador
    FROM prestamos_borradores
    WHERE borrador_id = p_borrador_id;

    IF v_estado_borrador IS NULL THEN
        ROLLBACK;
        SELECT NULL AS prestamo_id, 'ERROR' AS estado, 'Borrador no encontrado' AS mensaje;
        LEAVE main_block;
    END IF;

    IF v_estado_borrador != 'PENDIENTE' THEN
        ROLLBACK;
        SELECT NULL AS prestamo_id, 'ERROR' AS estado, CONCAT('Borrador ya está en estado: ', v_estado_borrador) AS mensaje;
        LEAVE main_block;
    END IF;

    -- =========================================================
    -- PASO 2: Obtener datos del borrador
    -- =========================================================
    SELECT
        Semana, Anio, Gerencia, SucursalID,
        Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
        Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
        Telefono_Cliente, No_De_Contrato, Agente, plazo,
        Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa, Saldo,
        Tipo_de_credito,
        Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
        Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
        Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
        Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
        NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad,
        Folio_de_pagare, cliente_persona_id, aval_persona_id, impacta_en_comision
    INTO
        v_semana, v_anio, v_gerencia, v_sucursal_id,
        v_cliente_id, v_nombres, v_apellido_paterno, v_apellido_materno,
        v_direccion, v_no_exterior, v_no_interior, v_colonia, v_codigo_postal, v_municipio, v_estado,
        v_telefono_cliente, v_no_contrato, v_agente, v_plazo,
        v_monto_otorgado, v_cargo, v_total_a_pagar, v_primer_pago, v_tarifa, v_saldo,
        v_tipo_credito,
        v_nombres_aval, v_apellido_paterno_aval, v_apellido_materno_aval,
        v_direccion_aval, v_no_exterior_aval, v_no_interior_aval, v_colonia_aval,
        v_codigo_postal_aval, v_poblacion_aval, v_estado_aval, v_telefono_aval, v_no_servicio_aval,
        v_dia_pago, v_gerente_turno, v_agente2, v_status, v_capturista,
        v_no_servicio, v_tipo_cliente, v_identificador, v_seguridad,
        v_folio_pagare, v_cliente_persona_id, v_aval_persona_id, v_impacta_comision
    FROM prestamos_borradores
    WHERE borrador_id = p_borrador_id;

    -- =========================================================
    -- PASO 3: Generar PrestamoID único
    -- =========================================================

    -- Obtener sufijo de sucursal
    SET v_sucursal_suffix = CASE v_sucursal_id
        WHEN 'dinero' THEN 'di'
        WHEN 'plata' THEN 'pl'
        WHEN 'moneda' THEN 'mo'
        WHEN 'efectivo' THEN 'ef'
        WHEN 'capital' THEN 'ca'
        WHEN 'dec' THEN 'dc'
        WHEN 'puebla' THEN 'pu'
        WHEN 'gocash' THEN 'gc'
        ELSE 'xx'
    END;

    -- Obtener el máximo consecutivo actual para esta semana/año/gerencia/sucursal
    SELECT COALESCE(MAX(from_base36(SUBSTRING(PrestamoID, 7, 3))), 0) + 1
    INTO v_consecutivo
    FROM prestamos_v2
    WHERE PrestamoID REGEXP '^[0-9]{2}\\.[0-9]{2}-[0-9A-Z]{3}-[0-9]{2}[a-z]{2}$'
      AND CAST(LEFT(PrestamoID, 2) AS UNSIGNED) = v_semana
      AND CAST(SUBSTRING(PrestamoID, 4, 2) AS UNSIGNED) + 2000 = v_anio
      AND SUBSTRING(PrestamoID, 11, 2) = RIGHT(v_gerencia, 2)
      AND SUBSTRING(PrestamoID, 13, 2) = v_sucursal_suffix;

    -- Generar PrestamoID
    SET v_prestamo_id = CONCAT(
        LPAD(v_semana, 2, '0'), '.',
        RIGHT(v_anio, 2), '-',
        to_base36(v_consecutivo, 3), '-',
        RIGHT(v_gerencia, 2),
        v_sucursal_suffix
    );

    -- Generar PagoID único
    SET v_pago_id = UUID();

    -- =========================================================
    -- PASO 4: Insertar en prestamos_v2
    -- =========================================================
    INSERT INTO prestamos_v2 (
        PrestamoID, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
        Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
        No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
        Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
        Saldo, Cobrado, Tipo_de_credito,
        Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
        Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
        Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
        Telefono_Cliente, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
        NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad,
        Folio_de_pagare, cliente_persona_id, aval_persona_id,
        impacta_en_comision, created_at
    ) VALUES (
        v_prestamo_id, v_cliente_id, v_nombres, v_apellido_paterno, v_apellido_materno,
        v_direccion, v_no_exterior, v_no_interior, v_colonia, v_codigo_postal, v_municipio, v_estado,
        v_no_contrato, v_agente, v_gerencia, v_sucursal_id, v_semana, v_anio, v_plazo,
        v_monto_otorgado, v_cargo, v_total_a_pagar, v_primer_pago, v_tarifa,
        v_saldo, 0, v_tipo_credito,
        v_nombres_aval, v_apellido_paterno_aval, v_apellido_materno_aval,
        v_direccion_aval, v_no_exterior_aval, v_no_interior_aval, v_colonia_aval,
        v_codigo_postal_aval, v_poblacion_aval, v_estado_aval, v_telefono_aval, v_no_servicio_aval,
        v_telefono_cliente, v_dia_pago, v_gerente_turno, v_agente2, v_status, v_capturista,
        v_no_servicio, v_tipo_cliente, v_identificador, v_seguridad,
        v_folio_pagare, v_cliente_persona_id, v_aval_persona_id,
        v_impacta_comision, v_fecha_actual
    );

    -- =========================================================
    -- PASO 5: Crear primer pago en pagos_v3
    -- =========================================================
    INSERT INTO pagos_v3 (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio,
        EsPrimerPago, AbreCon, CierraCon, Tarifa,
        Cliente, Agente, Tipo, Creado_desde, Identificador,
        Fecha_pago, Lat, Lng, Comentario, Created_at
    ) VALUES (
        v_pago_id,
        v_prestamo_id,
        v_prestamo_id,
        v_primer_pago,
        v_semana,
        v_anio,
        1,
        v_total_a_pagar,
        v_total_a_pagar - v_primer_pago,
        v_tarifa,
        CONCAT(TRIM(v_nombres), ' ', TRIM(v_apellido_paterno), ' ', TRIM(COALESCE(v_apellido_materno, ''))),
        v_agente,
        'Pago',
        'PGS',
        v_identificador,
        v_fecha_actual,
        0,
        0,
        CONCAT('Primer pago - borrador #', p_borrador_id),
        v_fecha_actual
    );

    -- =========================================================
    -- PASO 6: Marcar borrador como APROBADO
    -- =========================================================
    UPDATE prestamos_borradores
    SET estado_borrador = 'APROBADO',
        fecha_aprobacion = v_fecha_actual,
        PrestamoID_propuesto = v_prestamo_id
    WHERE borrador_id = p_borrador_id;

    COMMIT;

    -- Retornar resultado
    SELECT
        v_prestamo_id AS prestamo_id,
        'OK' AS estado,
        CONCAT('Borrador #', p_borrador_id, ' aprobado exitosamente') AS mensaje;

END main_block$$

DELIMITER ;


-- ===========================================================
-- PARTE 3: Actualizar SP aprobar_borradores_masivo
-- ===========================================================

DROP PROCEDURE IF EXISTS aprobar_borradores_masivo;

DELIMITER $$

CREATE PROCEDURE aprobar_borradores_masivo()
BEGIN
    DECLARE v_fecha_actual DATETIME;
    DECLARE v_total_procesados INT DEFAULT 0;

    -- Fecha actual en zona horaria de México
    SET v_fecha_actual = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City');

    -- =========================================================
    -- PASO 1: Generar PrestamoID único para cada borrador
    -- =========================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_borradores_con_id;

    CREATE TEMPORARY TABLE tmp_borradores_con_id AS
    SELECT
        b.*,
        CONCAT(
            LPAD(b.Semana, 2, '0'), '.',
            RIGHT(b.Anio, 2), '-',
            to_base36(COALESCE(max_consec.max_consecutivo, 0) + seq.rn, 3),
            '-',
            RIGHT(b.Gerencia, 2),
            CASE b.SucursalID
                WHEN 'dinero' THEN 'di'
                WHEN 'plata' THEN 'pl'
                WHEN 'moneda' THEN 'mo'
                WHEN 'efectivo' THEN 'ef'
                WHEN 'capital' THEN 'ca'
                WHEN 'dec' THEN 'dc'
                WHEN 'puebla' THEN 'pu'
                WHEN 'gocash' THEN 'gc'
                ELSE 'xx'
            END
        ) AS nuevo_prestamo_id,
        UUID() AS nuevo_pago_id
    FROM (
        SELECT
            pb.*,
            ROW_NUMBER() OVER (PARTITION BY pb.Semana, pb.Anio, pb.Gerencia, pb.SucursalID ORDER BY pb.borrador_id) AS rn
        FROM prestamos_borradores pb
        WHERE pb.estado_borrador = 'PENDIENTE'
    ) seq
    JOIN prestamos_borradores b ON seq.borrador_id = b.borrador_id
    LEFT JOIN (
        SELECT
            CAST(LEFT(PrestamoID, 2) AS UNSIGNED) AS semana_id,
            CAST(SUBSTRING(PrestamoID, 4, 2) AS UNSIGNED) + 2000 AS anio_id,
            SUBSTRING(PrestamoID, 11, 2) AS gerencia_suffix,
            SUBSTRING(PrestamoID, 13, 2) AS sucursal_suffix,
            MAX(from_base36(SUBSTRING(PrestamoID, 7, 3))) AS max_consecutivo
        FROM prestamos_v2
        WHERE PrestamoID REGEXP '^[0-9]{2}\\.[0-9]{2}-[0-9A-Z]{3}-[0-9]{2}[a-z]{2}$'
        GROUP BY LEFT(PrestamoID, 2), SUBSTRING(PrestamoID, 4, 2), SUBSTRING(PrestamoID, 11, 2), SUBSTRING(PrestamoID, 13, 2)
    ) max_consec ON b.Semana = max_consec.semana_id
                AND b.Anio = max_consec.anio_id
                AND RIGHT(b.Gerencia, 2) = max_consec.gerencia_suffix
                AND CASE b.SucursalID
                        WHEN 'dinero' THEN 'di'
                        WHEN 'plata' THEN 'pl'
                        WHEN 'moneda' THEN 'mo'
                        WHEN 'efectivo' THEN 'ef'
                        WHEN 'capital' THEN 'ca'
                        WHEN 'dec' THEN 'dc'
                        WHEN 'puebla' THEN 'pu'
                        WHEN 'gocash' THEN 'gc'
                        ELSE 'xx'
                    END = max_consec.sucursal_suffix;

    -- =========================================================
    -- PASO 2: Insertar en prestamos_v2
    -- =========================================================
    INSERT INTO prestamos_v2 (
        PrestamoID, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
        Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
        No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
        Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
        Saldos_Migrados, wk_descu, Descuento, Porcentaje, Multas, wk_refi, Refin, Externo,
        Saldo, Cobrado, Tipo_de_credito, Aclaracion,
        Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
        Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
        Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
        Telefono_Cliente, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
        NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad, Depuracion,
        Folio_de_pagare, excel_index, cliente_xpress_id, cliente_persona_id, aval_persona_id,
        impacta_en_comision,
        referencia_nombre, referencia_telefono, tipo_servicio, regional_en_venta,
        created_at
    )
    SELECT
        nuevo_prestamo_id, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
        Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
        No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
        Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
        Saldos_Migrados, wk_descu, Descuento, Porcentaje, Multas, wk_refi, Refin, Externo,
        Saldo, Cobrado, Tipo_de_credito, Aclaracion,
        Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
        Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
        Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
        Telefono_Cliente, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
        NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad, Depuracion,
        Folio_de_pagare, excel_index, cliente_xpress_id, cliente_persona_id, aval_persona_id,
        impacta_en_comision,
        referencia_nombre, referencia_telefono, tipo_servicio, regional_en_venta,
        v_fecha_actual
    FROM tmp_borradores_con_id;

    SET v_total_procesados = ROW_COUNT();

    -- =========================================================
    -- PASO 3: Crear primer pago en pagos_v3
    -- =========================================================
    INSERT INTO pagos_v3 (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio,
        EsPrimerPago, AbreCon, CierraCon, Tarifa,
        Cliente, Agente, Tipo, Creado_desde, Identificador,
        Fecha_pago, Lat, Lng, Comentario, Created_at
    )
    SELECT
        nuevo_pago_id,
        nuevo_prestamo_id,
        nuevo_prestamo_id,
        Primer_pago,
        Semana,
        Anio,
        1,
        Total_a_pagar,
        Total_a_pagar - Primer_pago,
        Tarifa,
        CONCAT(TRIM(Nombres), ' ', TRIM(Apellido_Paterno), ' ', TRIM(COALESCE(Apellido_Materno, ''))),
        Agente,
        'Pago',
        'PGS',
        Identificador_Credito,
        v_fecha_actual,
        0,
        0,
        CONCAT('Primer pago - borrador #', borrador_id),
        v_fecha_actual
    FROM tmp_borradores_con_id;

    -- =========================================================
    -- PASO 4: Marcar borradores como APROBADO
    -- =========================================================
    UPDATE prestamos_borradores pb
    INNER JOIN tmp_borradores_con_id tmp ON pb.borrador_id = tmp.borrador_id
    SET
        pb.estado_borrador = 'APROBADO',
        pb.fecha_aprobacion = v_fecha_actual,
        pb.PrestamoID_propuesto = tmp.nuevo_prestamo_id;

    -- Limpiar
    DROP TEMPORARY TABLE IF EXISTS tmp_borradores_con_id;

    -- Resultado
    SELECT
        v_total_procesados AS prestamos_aprobados,
        v_fecha_actual AS fecha_ejecucion;

END$$

DELIMITER ;
