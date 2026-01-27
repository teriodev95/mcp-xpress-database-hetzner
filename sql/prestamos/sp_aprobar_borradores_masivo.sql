-- =====================================================
-- Procedimiento: aprobar_borradores_masivo
--
-- Migra préstamos PENDIENTES de prestamos_borradores a prestamos_v2
-- y genera su primer pago en pagos_v3.
--
-- Los triggers existentes se encargan de:
--   - insert_prestamos_dynamic: crea registro en prestamos_dynamic
--   - trg_pagos_v3_before_insert: inserta en pagos_dynamic
--   - trg_pagos_v3_after_insert: actualiza saldo en prestamos_dynamic
--
-- Uso: CALL aprobar_borradores_masivo();
-- =====================================================

DROP PROCEDURE IF EXISTS aprobar_borradores_masivo;

CREATE PROCEDURE aprobar_borradores_masivo()
BEGIN
    DECLARE v_fecha_actual DATETIME;
    DECLARE v_total_procesados INT DEFAULT 0;

    -- Fecha actual en zona horaria de México
    SET v_fecha_actual = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City');

    -- =========================================================
    -- PASO 1: Generar PrestamoID único para cada borrador
    -- =========================================================
    -- Formato PrestamoID: SS.AA-CCC-GGXX
    -- SS = semana (2 dígitos)
    -- AA = año (2 dígitos)
    -- CCC = consecutivo en base 36 (3 dígitos: 001-ZZZ = hasta 46,655)
    -- GG = últimos 2 dígitos de gerencia (Ger001 -> 01)
    -- XX = sufijo sucursal (dinero->di, plata->pl, etc.)

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
        -- Máximo consecutivo buscando por prefijo del PrestamoID (SS.AA-CCC-GGXX)
        -- Usa from_base36 para convertir el consecutivo de base 36 a entero
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
        impacta_en_comision, created_at
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
        impacta_en_comision, v_fecha_actual
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

END;


-- Ejemplo de PrestamoID generado: 02.26-001-09dc
-- Formato: SS.AA-CCC-GGXX
--   SS = semana (02)
--   AA = año (26)
--   CCC = consecutivo en base 36 (001-ZZZ = hasta 46,655)
--   GG = últimos 2 dígitos gerencia (09 = Ger009)
--   XX = sufijo sucursal (dc = dec)
--
-- Ejemplos de consecutivo base 36:
--   001 = 1, 00A = 10, 00Z = 35, 010 = 36, 0RR = 999, ZZZ = 46655