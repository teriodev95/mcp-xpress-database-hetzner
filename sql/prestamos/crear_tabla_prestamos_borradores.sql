-- ============================================================================
-- SISTEMA DE PRÉSTAMOS EN BORRADOR
-- ============================================================================
-- Este script crea la estructura para manejar préstamos en estado "borrador"
-- sin modificar la tabla prestamos_v2 que ya está en producción.
--
-- Flujo:
-- 1. Se crea un registro en prestamos_borradores (estado: PENDIENTE)
-- 2. Se puede editar/revisar el borrador
-- 3. Al aprobar, se ejecuta el procedimiento que lo mueve a prestamos_v2
-- ============================================================================

-- ============================================================================
-- TABLA: prestamos_borradores
-- ============================================================================
-- Estructura idéntica a prestamos_v2 + campos de control de borrador

CREATE TABLE IF NOT EXISTS prestamos_borradores (
    -- ========================================================================
    -- CAMPOS DE CONTROL DEL BORRADOR (nuevos)
    -- ========================================================================
    borrador_id INT AUTO_INCREMENT PRIMARY KEY,
    estado_borrador ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO') NOT NULL DEFAULT 'PENDIENTE',
    creado_por VARCHAR(64) NOT NULL COMMENT 'Usuario que creó el borrador',
    aprobado_por VARCHAR(64) NULL COMMENT 'Usuario que aprobó/rechazó',
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_aprobacion TIMESTAMP NULL,
    motivo_rechazo VARCHAR(512) NULL COMMENT 'Razón si fue rechazado',

    -- ========================================================================
    -- CAMPOS IDÉNTICOS A prestamos_v2
    -- ========================================================================
    -- Identificadores (PrestamoID se genera al aprobar)
    PrestamoID_propuesto VARCHAR(32) NULL COMMENT 'ID propuesto, se valida al aprobar',
    Cliente_ID VARCHAR(32) NOT NULL,

    -- Datos del cliente
    Nombres VARCHAR(32) NULL,
    Apellido_Paterno VARCHAR(64) NULL,
    Apellido_Materno VARCHAR(64) NULL,
    Direccion VARCHAR(128) NOT NULL,
    NoExterior VARCHAR(64) NULL,
    NoInterior VARCHAR(64) NULL,
    Colonia VARCHAR(64) NOT NULL,
    Codigo_postal VARCHAR(32) NOT NULL,
    Municipio VARCHAR(64) NULL,
    Estado VARCHAR(32) NOT NULL,
    Telefono_Cliente VARCHAR(62) NULL,

    -- Datos del préstamo
    No_De_Contrato VARCHAR(16) NULL,
    Agente VARCHAR(16) NOT NULL,
    Gerencia VARCHAR(16) NOT NULL,
    SucursalID ENUM('dinero','plata','moneda','efectivo','capital','dec') NULL,
    Semana INT NOT NULL COMMENT 'Semana de otorgamiento',
    Anio INT NOT NULL COMMENT 'Año de otorgamiento',
    plazo INT NOT NULL,
    Monto_otorgado INT NOT NULL,
    Cargo DECIMAL(8,2) NOT NULL,
    Total_a_pagar DECIMAL(8,2) NOT NULL,
    Primer_pago DECIMAL(8,2) NOT NULL,
    Tarifa DECIMAL(8,2) NOT NULL,

    -- Campos opcionales de préstamo
    Saldos_Migrados VARCHAR(30) NULL,
    wk_descu VARCHAR(16) NULL,
    Descuento DECIMAL(8,2) NULL,
    Porcentaje DECIMAL(8,2) NULL,
    Multas DECIMAL(8,2) NULL,
    wk_refi VARCHAR(30) NULL,
    Refin VARCHAR(30) NULL,
    Externo VARCHAR(14) NULL,

    -- Saldo y Cobrado (iniciales, normalmente Saldo = Total_a_pagar, Cobrado = 0)
    Saldo DECIMAL(8,2) NOT NULL,
    Cobrado DECIMAL(8,2) NOT NULL DEFAULT 0,

    -- Tipo y clasificación
    Tipo_de_credito VARCHAR(32) NOT NULL,
    Aclaracion VARCHAR(512) NULL,

    -- Datos del aval
    Nombres_Aval VARCHAR(32) NOT NULL,
    Apellido_Paterno_Aval VARCHAR(64) NULL,
    Apellido_Materno_Aval VARCHAR(64) NULL,
    Direccion_Aval VARCHAR(128) NOT NULL,
    No_Exterior_Aval VARCHAR(64) NULL,
    No_Interior_Aval VARCHAR(64) NULL,
    Colonia_Aval VARCHAR(64) NULL,
    Codigo_Postal_Aval VARCHAR(32) NULL,
    Poblacion_Aval VARCHAR(64) NOT NULL,
    Estado_Aval VARCHAR(64) NOT NULL,
    Telefono_Aval VARCHAR(60) NULL,
    NoServicio_Aval VARCHAR(128) NULL,

    -- Campos operativos
    Dia_de_pago ENUM('MIERCOLES','JUEVES','VIERNES','SABADO','LUNES','MARTES') NOT NULL DEFAULT 'MIERCOLES',
    Gerente_en_turno VARCHAR(32) NOT NULL,
    Agente2 VARCHAR(32) NOT NULL DEFAULT '',
    Status VARCHAR(14) NOT NULL DEFAULT 'ACTIVO',
    Capturista VARCHAR(16) NOT NULL,
    NoServicio VARCHAR(64) NULL,
    Tipo_de_Cliente VARCHAR(16) NOT NULL,
    Identificador_Credito VARCHAR(36) NOT NULL,
    Seguridad VARCHAR(128) NULL,
    Depuracion VARCHAR(124) NULL,
    Folio_de_pagare VARCHAR(32) NULL,
    excel_index INT NOT NULL DEFAULT 0,

    -- Referencias a personas
    cliente_xpress_id VARCHAR(64) NULL,
    cliente_persona_id VARCHAR(64) NULL,
    aval_persona_id VARCHAR(64) NULL,

    -- Control
    impacta_en_comision TINYINT(1) NOT NULL DEFAULT 1,

    -- ========================================================================
    -- ÍNDICES
    -- ========================================================================
    INDEX idx_estado_borrador (estado_borrador),
    INDEX idx_gerencia (Gerencia),
    INDEX idx_agente (Agente),
    INDEX idx_fecha_creacion (fecha_creacion),
    INDEX idx_creado_por (creado_por),
    INDEX idx_cliente_persona_id (cliente_persona_id)

) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='Préstamos en estado borrador pendientes de aprobación';


-- ============================================================================
-- PROCEDIMIENTO: aprobar_borrador
-- ============================================================================
-- Convierte un borrador aprobado en un préstamo activo en prestamos_v2
--
-- Parámetros:
--   p_borrador_id: ID del borrador a aprobar
--   p_aprobado_por: Usuario que aprueba
--   p_prestamo_id: (OPCIONAL) ID específico para el préstamo. Si es NULL, se genera automáticamente
--
-- Retorna:
--   Resultado con el PrestamoID generado o mensaje de error
-- ============================================================================

DELIMITER //

CREATE PROCEDURE aprobar_borrador(
    IN p_borrador_id INT,
    IN p_aprobado_por VARCHAR(64),
    IN p_prestamo_id VARCHAR(32)
)
BEGIN
    DECLARE v_estado VARCHAR(20);
    DECLARE v_prestamo_id VARCHAR(32);
    DECLARE v_existe INT DEFAULT 0;
    DECLARE v_gerencia VARCHAR(16);
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_consecutivo INT;

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR' AS resultado, 'Error al procesar el borrador' AS mensaje;
    END;

    -- Verificar que el borrador existe y está PENDIENTE
    SELECT estado_borrador, Gerencia, Semana, Anio
    INTO v_estado, v_gerencia, v_semana, v_anio
    FROM prestamos_borradores
    WHERE borrador_id = p_borrador_id;

    IF v_estado IS NULL THEN
        SELECT 'ERROR' AS resultado, 'Borrador no encontrado' AS mensaje;
    ELSEIF v_estado != 'PENDIENTE' THEN
        SELECT 'ERROR' AS resultado, CONCAT('El borrador ya fue procesado. Estado: ', v_estado) AS mensaje;
    ELSE
        -- Generar PrestamoID si no se proporcionó
        IF p_prestamo_id IS NULL OR p_prestamo_id = '' THEN
            -- Formato: GERXXX-SSAA-NNNN (Gerencia-SemanaAño-Consecutivo)
            SELECT COALESCE(MAX(
                CAST(SUBSTRING_INDEX(PrestamoID, '-', -1) AS UNSIGNED)
            ), 0) + 1
            INTO v_consecutivo
            FROM prestamos_v2
            WHERE Gerencia = v_gerencia
              AND Semana = v_semana
              AND Anio = v_anio;

            SET v_prestamo_id = CONCAT(
                v_gerencia, '-',
                LPAD(v_semana, 2, '0'), SUBSTRING(v_anio, 3, 2), '-',
                LPAD(v_consecutivo, 4, '0')
            );
        ELSE
            SET v_prestamo_id = p_prestamo_id;
        END IF;

        -- Verificar que el PrestamoID no exista
        SELECT COUNT(*) INTO v_existe FROM prestamos_v2 WHERE PrestamoID = v_prestamo_id;

        IF v_existe > 0 THEN
            SELECT 'ERROR' AS resultado, CONCAT('El PrestamoID ya existe: ', v_prestamo_id) AS mensaje;
        ELSE
            START TRANSACTION;

            -- Insertar en prestamos_v2
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
                v_prestamo_id, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
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
                impacta_en_comision, CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
            FROM prestamos_borradores
            WHERE borrador_id = p_borrador_id;

            -- Insertar en prestamos_dynamic
            INSERT INTO prestamos_dynamic (prestamo_id, saldo, cobrado)
            SELECT v_prestamo_id, Saldo, Cobrado
            FROM prestamos_borradores
            WHERE borrador_id = p_borrador_id;

            -- Actualizar estado del borrador
            UPDATE prestamos_borradores
            SET estado_borrador = 'APROBADO',
                aprobado_por = p_aprobado_por,
                fecha_aprobacion = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
                PrestamoID_propuesto = v_prestamo_id
            WHERE borrador_id = p_borrador_id;

            COMMIT;

            SELECT 'OK' AS resultado,
                   v_prestamo_id AS prestamo_id,
                   'Préstamo creado exitosamente' AS mensaje;
        END IF;
    END IF;
END //

DELIMITER ;


-- ============================================================================
-- PROCEDIMIENTO: rechazar_borrador
-- ============================================================================
-- Marca un borrador como rechazado con motivo

DELIMITER //

CREATE PROCEDURE rechazar_borrador(
    IN p_borrador_id INT,
    IN p_rechazado_por VARCHAR(64),
    IN p_motivo VARCHAR(512)
)
BEGIN
    DECLARE v_estado VARCHAR(20);

    SELECT estado_borrador INTO v_estado
    FROM prestamos_borradores
    WHERE borrador_id = p_borrador_id;

    IF v_estado IS NULL THEN
        SELECT 'ERROR' AS resultado, 'Borrador no encontrado' AS mensaje;
    ELSEIF v_estado != 'PENDIENTE' THEN
        SELECT 'ERROR' AS resultado, CONCAT('El borrador ya fue procesado. Estado: ', v_estado) AS mensaje;
    ELSE
        UPDATE prestamos_borradores
        SET estado_borrador = 'RECHAZADO',
            aprobado_por = p_rechazado_por,
            fecha_aprobacion = CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
            motivo_rechazo = p_motivo
        WHERE borrador_id = p_borrador_id;

        SELECT 'OK' AS resultado, 'Borrador rechazado' AS mensaje;
    END IF;
END //

DELIMITER ;


-- ============================================================================
-- PROCEDIMIENTO: listar_borradores_pendientes
-- ============================================================================
-- Lista borradores pendientes de aprobación, opcionalmente filtrados

DELIMITER //

CREATE PROCEDURE listar_borradores_pendientes(
    IN p_gerencia VARCHAR(16),
    IN p_agente VARCHAR(16)
)
BEGIN
    SELECT
        borrador_id,
        PrestamoID_propuesto,
        Nombres,
        Apellido_Paterno,
        Apellido_Materno,
        Gerencia,
        Agente,
        Monto_otorgado,
        Total_a_pagar,
        Tarifa,
        plazo,
        Semana,
        Anio,
        creado_por,
        fecha_creacion
    FROM prestamos_borradores
    WHERE estado_borrador = 'PENDIENTE'
      AND (p_gerencia IS NULL OR Gerencia = p_gerencia)
      AND (p_agente IS NULL OR Agente = p_agente)
    ORDER BY fecha_creacion DESC;
END //

DELIMITER ;


-- ============================================================================
-- EJEMPLO DE USO
-- ============================================================================
/*
-- 1. Crear un borrador
INSERT INTO prestamos_borradores (
    creado_por, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
    Direccion, Colonia, Codigo_postal, Estado,
    Agente, Gerencia, SucursalID, Semana, Anio, plazo,
    Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
    Saldo, Cobrado, Tipo_de_credito,
    Nombres_Aval, Direccion_Aval, Poblacion_Aval, Estado_Aval,
    Dia_de_pago, Gerente_en_turno, Capturista, Tipo_de_Cliente, Identificador_Credito
)
VALUES (
    'usuario_capturista', 'CLI001', 'JUAN', 'PEREZ', 'LOPEZ',
    'CALLE PRINCIPAL 123', 'CENTRO', '12345', 'CIUDAD DE MEXICO',
    'AGM001', 'GERM001', 'dinero', 2, 2026, 20,
    5000, 2500.00, 7500.00, 375.00, 375.00,
    7500.00, 0, 'NUEVO',
    'MARIA', 'CALLE SECUNDARIA 456', 'CENTRO', 'CIUDAD DE MEXICO',
    'MIERCOLES', 'GERENTE001', 'CAPTURISTA001', 'NUEVO', UUID()
);

-- 2. Listar borradores pendientes
CALL listar_borradores_pendientes(NULL, NULL);  -- Todos
CALL listar_borradores_pendientes('GERM001', NULL);  -- Por gerencia

-- 3. Aprobar un borrador (genera PrestamoID automático)
CALL aprobar_borrador(1, 'supervisor_aprueba', NULL);

-- 4. Aprobar con PrestamoID específico
CALL aprobar_borrador(2, 'supervisor_aprueba', 'GERM001-0226-0001');

-- 5. Rechazar un borrador
CALL rechazar_borrador(3, 'supervisor_rechaza', 'Datos del aval incompletos');
*/
