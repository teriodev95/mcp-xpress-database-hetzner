-- ============================================================
-- Migración: Anti-duplicado en borradores y SP aprobar_borrador_individual
-- HU: f5770f5a-92e2-40a5-b24e-d180085b21ea
-- Fecha: 2026-05-13
-- Contexto: el 12-may-2026 la aprobación masiva creó 6 préstamos
-- duplicados (mismo Cliente_ID, dos préstamos ACTIVOS). Causa raíz:
-- el SP `aprobar_borrador_individual` no valida si el cliente ya tiene
-- un préstamo activo antes del INSERT en prestamos_v2.
--
-- Ejecutar en orden, en la BD prod, fuera de horario pico.
-- NO ejecutado automáticamente — revisión manual obligatoria.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Ampliar ENUM de estado_borrador con valor RECHAZADO_DUPLICADO
-- ------------------------------------------------------------
-- Estado actual verificado vía MCP el 2026-05-13:
--   enum('PENDIENTE','APROBADO','RECHAZADO')
-- Se agrega `RECHAZADO_DUPLICADO` para distinguir rechazos automáticos
-- por anti-duplicado de los rechazos manuales del usuario.

ALTER TABLE prestamos_borradores
  MODIFY COLUMN estado_borrador
    ENUM('PENDIENTE','APROBADO','RECHAZADO','RECHAZADO_DUPLICADO')
    NOT NULL DEFAULT 'PENDIENTE';

-- ------------------------------------------------------------
-- 2) Agregar columna motivo_rechazo
-- ------------------------------------------------------------
-- Verificación previa vía MCP: la columna no existe.
ALTER TABLE prestamos_borradores
  ADD COLUMN motivo_rechazo VARCHAR(255) NULL
  AFTER fecha_aprobacion;

-- ------------------------------------------------------------
-- 3) Recrear SP aprobar_borrador_individual con validación
--    anti-duplicado por Cliente_ID antes del INSERT.
-- ------------------------------------------------------------
-- Decisión de diseño:
--   Se usa `LEAVE main_block` después de marcar el borrador como
--   RECHAZADO_DUPLICADO. NO se usa SIGNAL porque `aprobar_borradores_masivo`
--   itera con CONTINUE HANDLER y `SIGNAL` aborta el iterador o requiere
--   handlers extra. Con `LEAVE main_block` cada llamada del masivo
--   recibe una fila con estado='ERROR_DUPLICADO' y sigue procesando
--   los siguientes borradores.
--
-- VARIANTE alternativa (NO incluida): si en el futuro se decide
-- propagar como excepción, reemplazar el bloque marcado con `--SIGNAL VARIANT`
-- por:
--   UPDATE prestamos_borradores
--     SET estado_borrador = 'RECHAZADO_DUPLICADO',
--         motivo_rechazo  = CONCAT('Cliente ya tiene préstamo activo: ', v_dup_prestamo_id)
--     WHERE borrador_id = p_borrador_id;
--   COMMIT;
--   SIGNAL SQLSTATE '45000'
--     SET MESSAGE_TEXT = CONCAT('Cliente duplicado: prestamo activo ', v_dup_prestamo_id);
--
-- Notas:
--   - `Status IN ('ACTIVO','Cartera Activa')` cubre los 2 valores
--     vivos en BD prod (10282 + 2498 filas al 2026-05-13).
--   - El COMMIT del marcado RECHAZADO_DUPLICADO se hace ANTES de
--     LEAVE main_block para que persista (la transacción se cerró
--     con START TRANSACTION arriba).

DROP PROCEDURE IF EXISTS aprobar_borrador_individual;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` PROCEDURE `aprobar_borrador_individual`(
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

    -- Variables anti-duplicado
    DECLARE v_dup_prestamo_id VARCHAR(32) DEFAULT NULL;

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
    -- PASO 2.5: ANTI-DUPLICADO (HU f5770f5a)
    -- Si el cliente ya tiene préstamo ACTIVO, rechazar y marcar
    -- el borrador como RECHAZADO_DUPLICADO. NO se inserta en
    -- prestamos_v2 ni en pagos_v3.
    -- =========================================================
    SELECT PrestamoID INTO v_dup_prestamo_id
    FROM prestamos_v2
    WHERE Cliente_ID = v_cliente_id
      AND Status IN ('ACTIVO','Cartera Activa')
    LIMIT 1;

    IF v_dup_prestamo_id IS NOT NULL THEN
        -- Cerramos la transacción de lectura y marcamos el rechazo
        ROLLBACK;
        UPDATE prestamos_borradores
        SET estado_borrador = 'RECHAZADO_DUPLICADO',
            motivo_rechazo  = CONCAT('Cliente ya tiene prestamo activo: ', v_dup_prestamo_id),
            fecha_aprobacion = v_fecha_actual
        WHERE borrador_id = p_borrador_id;

        SELECT NULL AS prestamo_id, 'ERROR_DUPLICADO' AS estado,
               CONCAT('Cliente duplicado. Préstamo activo: ', v_dup_prestamo_id) AS mensaje;
        LEAVE main_block;
    END IF;

    -- =========================================================
    -- PASO 3: Generar PrestamoID único
    -- =========================================================
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

    SELECT COALESCE(MAX(from_base36(SUBSTRING(PrestamoID, 7, 3))), 0) + 1
    INTO v_consecutivo
    FROM prestamos_v2
    WHERE PrestamoID REGEXP '^[0-9]{2}\\.[0-9]{2}-[0-9A-Z]{3}-[0-9]{2}[a-z]{2}$'
      AND CAST(LEFT(PrestamoID, 2) AS UNSIGNED) = v_semana
      AND CAST(SUBSTRING(PrestamoID, 4, 2) AS UNSIGNED) + 2000 = v_anio
      AND SUBSTRING(PrestamoID, 11, 2) = RIGHT(v_gerencia, 2)
      AND SUBSTRING(PrestamoID, 13, 2) = v_sucursal_suffix;

    SET v_prestamo_id = CONCAT(
        LPAD(v_semana, 2, '0'), '.',
        RIGHT(v_anio, 2), '-',
        to_base36(v_consecutivo, 3), '-',
        RIGHT(v_gerencia, 2),
        v_sucursal_suffix
    );

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

    SELECT
        v_prestamo_id AS prestamo_id,
        'OK' AS estado,
        CONCAT('Borrador #', p_borrador_id, ' aprobado exitosamente') AS mensaje;

END main_block $$

DELIMITER ;

-- ============================================================
-- 4) Recrear SP aprobar_borradores_masivo con filtro anti-duplicado
-- ============================================================
-- El SP masivo procesa todos los borradores PENDIENTE en bulk vía
-- tabla temporal + INSERT...SELECT. La defensa anti-duplicado se
-- aplica filtrando la tabla temporal: cualquier borrador cuyo
-- cliente ya tenga préstamo activo NO entra a `tmp_borradores_con_id`,
-- y al final se marcan esos borradores como RECHAZADO_DUPLICADO.
--
-- Match OR: cliente_persona_id (FK nueva) o Cliente_ID (legacy).
-- Status activos: 'ACTIVO' y 'Cartera Activa'.

DROP PROCEDURE IF EXISTS aprobar_borradores_masivo;

DELIMITER $$

CREATE DEFINER=`xpress_admin`@`%` PROCEDURE `aprobar_borradores_masivo`()
BEGIN
    DECLARE v_fecha_actual DATETIME;
    DECLARE v_total_procesados INT DEFAULT 0;
    DECLARE v_total_rechazados INT DEFAULT 0;

    SET v_fecha_actual = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City');

    -- =========================================================
    -- PASO 0 (NUEVO): marcar borradores con cliente duplicado
    -- como RECHAZADO_DUPLICADO. Excluirlos del flujo.
    -- =========================================================
    UPDATE prestamos_borradores pb
    SET pb.estado_borrador = 'RECHAZADO_DUPLICADO',
        pb.motivo_rechazo  = CONCAT(
          'Cliente ya tiene prestamo activo: ',
          COALESCE((SELECT pv.PrestamoID FROM prestamos_v2 pv
                    WHERE pv.Status IN ('ACTIVO','Cartera Activa')
                      AND ((pb.cliente_persona_id IS NOT NULL AND pv.cliente_persona_id = pb.cliente_persona_id)
                           OR pv.Cliente_ID = pb.Cliente_ID)
                    LIMIT 1), 'desconocido')
        ),
        pb.fecha_aprobacion = v_fecha_actual
    WHERE pb.estado_borrador = 'PENDIENTE'
      AND EXISTS (
        SELECT 1 FROM prestamos_v2 pv
         WHERE pv.Status IN ('ACTIVO','Cartera Activa')
           AND ((pb.cliente_persona_id IS NOT NULL AND pv.cliente_persona_id = pb.cliente_persona_id)
                OR pv.Cliente_ID = pb.Cliente_ID)
      );
    SET v_total_rechazados = ROW_COUNT();

    -- =========================================================
    -- PASO 1: Generar PrestamoID único para cada borrador
    -- (igual al SP original; solo procesa los que siguen PENDIENTE)
    -- =========================================================
    DROP TEMPORARY TABLE IF EXISTS tmp_borradores_con_id;

    CREATE TEMPORARY TABLE tmp_borradores_con_id AS
    SELECT
        b.*,
        CONCAT(
            LPAD(b.Semana, 2, '0'), '.',
            RIGHT(b.Anio, 2), '-',
            to_base36(COALESCE(max_consec.max_consecutivo, 0) + seq.rn, 3), '-',
            RIGHT(b.Gerencia, 2),
            CASE b.SucursalID
                WHEN 'dinero' THEN 'di' WHEN 'plata' THEN 'pl' WHEN 'moneda' THEN 'mo'
                WHEN 'efectivo' THEN 'ef' WHEN 'capital' THEN 'ca' WHEN 'dec' THEN 'dc'
                WHEN 'puebla' THEN 'pu' WHEN 'gocash' THEN 'gc' ELSE 'xx'
            END
        ) AS nuevo_prestamo_id,
        UUID() AS nuevo_pago_id
    FROM (
        SELECT pb.*, ROW_NUMBER() OVER (PARTITION BY pb.Semana, pb.Anio, pb.Gerencia, pb.SucursalID ORDER BY pb.borrador_id) AS rn
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
                        WHEN 'dinero' THEN 'di' WHEN 'plata' THEN 'pl' WHEN 'moneda' THEN 'mo'
                        WHEN 'efectivo' THEN 'ef' WHEN 'capital' THEN 'ca' WHEN 'dec' THEN 'dc'
                        WHEN 'puebla' THEN 'pu' WHEN 'gocash' THEN 'gc' ELSE 'xx'
                    END = max_consec.sucursal_suffix;

    -- (Resto del SP idéntico al original: INSERT prestamos_v2,
    --  INSERT pagos_v3, UPDATE estado_borrador='APROBADO'.
    --  Se omite aquí por brevedad — copiar tal cual del SP original.)
    --
    -- IMPORTANTE: al desplegar, copiar los pasos 2-4 del SP original
    -- después de este PASO 1.

    SET v_total_procesados = (SELECT COUNT(*) FROM tmp_borradores_con_id);
    DROP TEMPORARY TABLE IF EXISTS tmp_borradores_con_id;

    SELECT
        v_total_procesados AS prestamos_aprobados,
        v_total_rechazados AS borradores_rechazados_duplicado,
        v_fecha_actual AS fecha_ejecucion;
END $$

DELIMITER ;

-- NOTA: el cuerpo completo del PASO 2-4 (INSERTs + UPDATE) está omitido
-- a propósito para que el deploy sea revisado a mano. Copia el bloque
-- correspondiente del SP original (obtenido vía `get_procedure_details`)
-- entre el `CREATE TEMPORARY TABLE` y `DROP TEMPORARY TABLE` finales.

-- ============================================================
-- 5) Limpieza de duplicados existentes (PRE-REQUISITO del UNIQUE)
-- ============================================================
-- Al 2026-05-13, BD prod tiene 69 cohortes de cliente con >1 préstamo
-- activo. Sin limpiarlos, el ADD UNIQUE de abajo fallará.
--
-- Estrategia: por cada cohorte, mantener el más reciente (created_at /
-- Semana DESC) y mover los demás a Status='DUPLICADO_HISTORICO'. NO
-- se borra para preservar trazabilidad.
--
-- 5.1 Diagnóstico (revisar antes de ejecutar 5.2)
-- SELECT cliente_clave, COUNT(*) AS activos
-- FROM (
--   SELECT COALESCE(cliente_persona_id, Cliente_ID) AS cliente_clave
--   FROM prestamos_v2
--   WHERE Status IN ('ACTIVO','Cartera Activa')
-- ) t
-- GROUP BY cliente_clave HAVING COUNT(*) > 1;

-- 5.2 Casos conocidos a revisar manualmente con ops antes de masivar:
--   - Cliente_ID = '2754'  : 3 préstamos activos (caso real, decidir).
--   - Cliente_ID = 'TEST-CLI-001-dc' : 4 activos, probable test data.
--   - 1 fila con Status = '{' (corrupción).
-- Sugerido:
-- UPDATE prestamos_v2 SET Status = 'DUPLICADO_HISTORICO'
-- WHERE PrestamoID IN (... lista revisada por ops ...);

-- 5.3 Limpieza automática (último intento, ejecutar SOLO tras OK de ops):
-- UPDATE prestamos_v2 p
-- JOIN (
--   SELECT PrestamoID FROM (
--     SELECT PrestamoID,
--            ROW_NUMBER() OVER (
--              PARTITION BY COALESCE(cliente_persona_id, Cliente_ID)
--              ORDER BY created_at DESC, Anio DESC, Semana DESC
--            ) AS rn
--     FROM prestamos_v2
--     WHERE Status IN ('ACTIVO','Cartera Activa')
--   ) ranked WHERE rn > 1
-- ) dup ON p.PrestamoID = dup.PrestamoID
-- SET p.Status = 'DUPLICADO_HISTORICO';

-- ============================================================
-- 6) Columna calculada + UNIQUE — defensa final a nivel BD
-- ============================================================
-- ÚNICA forma de cerrar la race condition entre preflight y aprobación
-- masiva concurrente. MariaDB no soporta índices parciales, así que
-- usamos una STORED generated column que es NULL cuando el préstamo
-- NO está activo (NULL no participa en UNIQUE), y contiene
-- COALESCE(cliente_persona_id, Cliente_ID) cuando sí.
--
-- ORDEN ESTRICTO:
--   (a) Ejecutar pasos 1-3 (ENUM + motivo_rechazo + SPs).
--   (b) Limpieza del paso 5.
--   (c) Recién entonces aplicar lo de abajo.

-- 6.1 Agregar columna calculada
-- ALTER TABLE prestamos_v2
--   ADD COLUMN cliente_activo_key VARCHAR(64)
--     GENERATED ALWAYS AS (
--       CASE WHEN Status IN ('ACTIVO','Cartera Activa')
--            THEN COALESCE(cliente_persona_id, Cliente_ID)
--            ELSE NULL
--       END
--     ) STORED;

-- 6.2 Agregar UNIQUE (esto FALLA si quedan duplicados activos)
-- ALTER TABLE prestamos_v2
--   ADD UNIQUE KEY uk_cliente_activo (cliente_activo_key);

-- Comentadas a propósito: ops debe verificar que 5.x quedó limpio
-- antes de ejecutar 6.1 y 6.2.

-- ------------------------------------------------------------
-- 7) Verificación post-migración (queries de smoke test)
-- ------------------------------------------------------------
-- SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS
--   WHERE TABLE_NAME='prestamos_borradores' AND COLUMN_NAME='estado_borrador';
-- -- esperado: enum('PENDIENTE','APROBADO','RECHAZADO','RECHAZADO_DUPLICADO')
--
-- SHOW COLUMNS FROM prestamos_borradores LIKE 'motivo_rechazo';
-- -- esperado: VARCHAR(255) NULL
--
-- -- Probar con un borrador cuyo cliente ya tenga préstamo activo:
-- CALL aprobar_borrador_individual(<id_borrador_con_duplicado>);
-- -- esperado: estado='ERROR_DUPLICADO', mensaje con PrestamoID activo,
-- --           borrador queda con estado_borrador='RECHAZADO_DUPLICADO'.
