-- =====================================================
-- SISTEMA DE LOGS PARA PRESTAMOS_V2
-- =====================================================
-- Fecha: 2026-01-26
--
-- Este script crea 3 tablas de auditoría:
-- 1. prestamos_v2_create_log - Registra altas (INSERT)
-- 2. prestamos_v2_delete_log - Registra bajas con respaldo completo (DELETE)
-- 3. prestamos_v2_update_log - Registra cambios en formato JSON (UPDATE)
-- =====================================================


-- =====================================================
-- 1. TABLA: prestamos_v2_create_log (Altas - ligera)
-- =====================================================
CREATE TABLE IF NOT EXISTS prestamos_v2_create_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha TIMESTAMP DEFAULT (CONVERT_TZ(CURRENT_TIMESTAMP, 'UTC', 'America/Mexico_City')),
    usuario_db VARCHAR(100),

    prestamo_id VARCHAR(32) NOT NULL,
    cliente_persona_id VARCHAR(64),
    cliente_nombre VARCHAR(200),
    agente VARCHAR(16),
    gerencia VARCHAR(16),
    monto_otorgado INT,
    total_a_pagar DECIMAL(10,2),

    INDEX idx_fecha (fecha),
    INDEX idx_prestamo (prestamo_id),
    INDEX idx_cliente (cliente_persona_id),
    INDEX idx_agente (agente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================
-- 2. TABLA: prestamos_v2_delete_log (Bajas - respaldo completo)
-- =====================================================
CREATE TABLE IF NOT EXISTS prestamos_v2_delete_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha TIMESTAMP DEFAULT (CONVERT_TZ(CURRENT_TIMESTAMP, 'UTC', 'America/Mexico_City')),
    usuario_db VARCHAR(100),

    -- Copia completa de prestamos_v2 (71 campos)
    PrestamoID VARCHAR(32),
    Cliente_ID VARCHAR(32),
    Nombres VARCHAR(32),
    Apellido_Paterno VARCHAR(64),
    Apellido_Materno VARCHAR(64),
    Direccion VARCHAR(128),
    NoExterior VARCHAR(64),
    NoInterior VARCHAR(64),
    Colonia VARCHAR(64),
    Codigo_postal VARCHAR(32),
    Municipio VARCHAR(64),
    Estado VARCHAR(32),
    No_De_Contrato VARCHAR(16),
    Agente VARCHAR(16),
    Gerencia VARCHAR(16),
    SucursalID VARCHAR(8),
    Semana INT,
    Anio INT,
    plazo INT,
    Monto_otorgado INT,
    Cargo DECIMAL(10,2),
    Total_a_pagar DECIMAL(10,2),
    Primer_pago DECIMAL(10,2),
    Tarifa DECIMAL(10,2),
    Saldos_Migrados VARCHAR(30),
    wk_descu VARCHAR(16),
    Descuento DECIMAL(10,2),
    Porcentaje DECIMAL(10,2),
    Multas DECIMAL(10,2),
    wk_refi VARCHAR(30),
    Refin VARCHAR(30),
    Externo VARCHAR(14),
    Saldo DECIMAL(10,2),
    Cobrado DECIMAL(10,2),
    Tipo_de_credito VARCHAR(32),
    Aclaracion VARCHAR(512),
    Nombres_Aval VARCHAR(32),
    Apellido_Paterno_Aval VARCHAR(64),
    Apellido_Materno_Aval VARCHAR(64),
    Direccion_Aval VARCHAR(128),
    No_Exterior_Aval VARCHAR(64),
    No_Interior_Aval VARCHAR(64),
    Colonia_Aval VARCHAR(64),
    Codigo_Postal_Aval VARCHAR(32),
    Poblacion_Aval VARCHAR(64),
    Estado_Aval VARCHAR(64),
    Telefono_Aval VARCHAR(60),
    NoServicio_Aval VARCHAR(128),
    Telefono_Cliente VARCHAR(62),
    Dia_de_pago VARCHAR(10),
    Gerente_en_turno VARCHAR(32),
    Agente2 VARCHAR(64),
    Status VARCHAR(14),
    Capturista VARCHAR(16),
    NoServicio VARCHAR(64),
    Tipo_de_Cliente VARCHAR(16),
    Identificador_Credito VARCHAR(36),
    Seguridad VARCHAR(128),
    Depuracion VARCHAR(124),
    Folio_de_pagare VARCHAR(32),
    excel_index INT,
    cliente_xpress_id VARCHAR(64),
    cliente_persona_id VARCHAR(64),
    aval_persona_id VARCHAR(64),
    impacta_en_comision TINYINT,
    referencia_nombre VARCHAR(128),
    referencia_telefono VARCHAR(20),
    tipo_servicio VARCHAR(32),
    regional_en_venta TINYINT,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,

    INDEX idx_fecha (fecha),
    INDEX idx_prestamo (PrestamoID),
    INDEX idx_cliente (cliente_persona_id),
    INDEX idx_agente (Agente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================
-- 3. TABLA: prestamos_v2_update_log (Cambios - JSON)
-- =====================================================
CREATE TABLE IF NOT EXISTS prestamos_v2_update_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    fecha TIMESTAMP DEFAULT (CONVERT_TZ(CURRENT_TIMESTAMP, 'UTC', 'America/Mexico_City')),
    usuario_db VARCHAR(100),

    prestamo_id VARCHAR(32) NOT NULL,
    cambios JSON NOT NULL,

    INDEX idx_fecha (fecha),
    INDEX idx_prestamo (prestamo_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =====================================================
-- TRIGGER: CREATE (INSERT)
-- =====================================================
DROP TRIGGER IF EXISTS trg_prestamos_v2_create_log;

DELIMITER //
CREATE TRIGGER trg_prestamos_v2_create_log
AFTER INSERT ON prestamos_v2
FOR EACH ROW
BEGIN
    INSERT INTO prestamos_v2_create_log (
        usuario_db, prestamo_id, cliente_persona_id, cliente_nombre,
        agente, gerencia, monto_otorgado, total_a_pagar
    ) VALUES (
        USER(),
        NEW.PrestamoID,
        NEW.cliente_persona_id,
        CONCAT_WS(' ', NEW.Nombres, NEW.Apellido_Paterno, NEW.Apellido_Materno),
        NEW.Agente,
        NEW.Gerencia,
        NEW.Monto_otorgado,
        NEW.Total_a_pagar
    );
END //
DELIMITER ;


-- =====================================================
-- TRIGGER: DELETE
-- =====================================================
DROP TRIGGER IF EXISTS trg_prestamos_v2_delete_log;

DELIMITER //
CREATE TRIGGER trg_prestamos_v2_delete_log
AFTER DELETE ON prestamos_v2
FOR EACH ROW
BEGIN
    INSERT INTO prestamos_v2_delete_log (
        usuario_db,
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
        impacta_en_comision, referencia_nombre, referencia_telefono, tipo_servicio,
        regional_en_venta, created_at, updated_at
    ) VALUES (
        USER(),
        OLD.PrestamoID, OLD.Cliente_ID, OLD.Nombres, OLD.Apellido_Paterno, OLD.Apellido_Materno,
        OLD.Direccion, OLD.NoExterior, OLD.NoInterior, OLD.Colonia, OLD.Codigo_postal, OLD.Municipio, OLD.Estado,
        OLD.No_De_Contrato, OLD.Agente, OLD.Gerencia, OLD.SucursalID, OLD.Semana, OLD.Anio, OLD.plazo,
        OLD.Monto_otorgado, OLD.Cargo, OLD.Total_a_pagar, OLD.Primer_pago, OLD.Tarifa,
        OLD.Saldos_Migrados, OLD.wk_descu, OLD.Descuento, OLD.Porcentaje, OLD.Multas, OLD.wk_refi, OLD.Refin, OLD.Externo,
        OLD.Saldo, OLD.Cobrado, OLD.Tipo_de_credito, OLD.Aclaracion,
        OLD.Nombres_Aval, OLD.Apellido_Paterno_Aval, OLD.Apellido_Materno_Aval,
        OLD.Direccion_Aval, OLD.No_Exterior_Aval, OLD.No_Interior_Aval, OLD.Colonia_Aval,
        OLD.Codigo_Postal_Aval, OLD.Poblacion_Aval, OLD.Estado_Aval, OLD.Telefono_Aval, OLD.NoServicio_Aval,
        OLD.Telefono_Cliente, OLD.Dia_de_pago, OLD.Gerente_en_turno, OLD.Agente2, OLD.Status, OLD.Capturista,
        OLD.NoServicio, OLD.Tipo_de_Cliente, OLD.Identificador_Credito, OLD.Seguridad, OLD.Depuracion,
        OLD.Folio_de_pagare, OLD.excel_index, OLD.cliente_xpress_id, OLD.cliente_persona_id, OLD.aval_persona_id,
        OLD.impacta_en_comision, OLD.referencia_nombre, OLD.referencia_telefono, OLD.tipo_servicio,
        OLD.regional_en_venta, OLD.created_at, OLD.updated_at
    );
END //
DELIMITER ;


-- =====================================================
-- TRIGGER: UPDATE (JSON)
-- =====================================================
DROP TRIGGER IF EXISTS trg_prestamos_v2_update_log;

DELIMITER //
CREATE TRIGGER trg_prestamos_v2_update_log
AFTER UPDATE ON prestamos_v2
FOR EACH ROW
BEGIN
    DECLARE v_cambios JSON DEFAULT JSON_OBJECT();

    IF NOT (OLD.PrestamoID <=> NEW.PrestamoID) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.PrestamoID', JSON_OBJECT('antes', OLD.PrestamoID, 'despues', NEW.PrestamoID));
    END IF;

    IF NOT (OLD.Cliente_ID <=> NEW.Cliente_ID) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Cliente_ID', JSON_OBJECT('antes', OLD.Cliente_ID, 'despues', NEW.Cliente_ID));
    END IF;

    IF NOT (OLD.Nombres <=> NEW.Nombres) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Nombres', JSON_OBJECT('antes', OLD.Nombres, 'despues', NEW.Nombres));
    END IF;

    IF NOT (OLD.Apellido_Paterno <=> NEW.Apellido_Paterno) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Apellido_Paterno', JSON_OBJECT('antes', OLD.Apellido_Paterno, 'despues', NEW.Apellido_Paterno));
    END IF;

    IF NOT (OLD.Apellido_Materno <=> NEW.Apellido_Materno) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Apellido_Materno', JSON_OBJECT('antes', OLD.Apellido_Materno, 'despues', NEW.Apellido_Materno));
    END IF;

    IF NOT (OLD.Direccion <=> NEW.Direccion) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Direccion', JSON_OBJECT('antes', OLD.Direccion, 'despues', NEW.Direccion));
    END IF;

    IF NOT (OLD.NoExterior <=> NEW.NoExterior) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.NoExterior', JSON_OBJECT('antes', OLD.NoExterior, 'despues', NEW.NoExterior));
    END IF;

    IF NOT (OLD.NoInterior <=> NEW.NoInterior) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.NoInterior', JSON_OBJECT('antes', OLD.NoInterior, 'despues', NEW.NoInterior));
    END IF;

    IF NOT (OLD.Colonia <=> NEW.Colonia) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Colonia', JSON_OBJECT('antes', OLD.Colonia, 'despues', NEW.Colonia));
    END IF;

    IF NOT (OLD.Codigo_postal <=> NEW.Codigo_postal) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Codigo_postal', JSON_OBJECT('antes', OLD.Codigo_postal, 'despues', NEW.Codigo_postal));
    END IF;

    IF NOT (OLD.Municipio <=> NEW.Municipio) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Municipio', JSON_OBJECT('antes', OLD.Municipio, 'despues', NEW.Municipio));
    END IF;

    IF NOT (OLD.Estado <=> NEW.Estado) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Estado', JSON_OBJECT('antes', OLD.Estado, 'despues', NEW.Estado));
    END IF;

    IF NOT (OLD.No_De_Contrato <=> NEW.No_De_Contrato) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.No_De_Contrato', JSON_OBJECT('antes', OLD.No_De_Contrato, 'despues', NEW.No_De_Contrato));
    END IF;

    IF NOT (OLD.Agente <=> NEW.Agente) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Agente', JSON_OBJECT('antes', OLD.Agente, 'despues', NEW.Agente));
    END IF;

    IF NOT (OLD.Gerencia <=> NEW.Gerencia) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Gerencia', JSON_OBJECT('antes', OLD.Gerencia, 'despues', NEW.Gerencia));
    END IF;

    IF NOT (OLD.SucursalID <=> NEW.SucursalID) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.SucursalID', JSON_OBJECT('antes', OLD.SucursalID, 'despues', NEW.SucursalID));
    END IF;

    IF NOT (OLD.Semana <=> NEW.Semana) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Semana', JSON_OBJECT('antes', OLD.Semana, 'despues', NEW.Semana));
    END IF;

    IF NOT (OLD.Anio <=> NEW.Anio) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Anio', JSON_OBJECT('antes', OLD.Anio, 'despues', NEW.Anio));
    END IF;

    IF NOT (OLD.plazo <=> NEW.plazo) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.plazo', JSON_OBJECT('antes', OLD.plazo, 'despues', NEW.plazo));
    END IF;

    IF NOT (OLD.Monto_otorgado <=> NEW.Monto_otorgado) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Monto_otorgado', JSON_OBJECT('antes', OLD.Monto_otorgado, 'despues', NEW.Monto_otorgado));
    END IF;

    IF NOT (OLD.Cargo <=> NEW.Cargo) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Cargo', JSON_OBJECT('antes', OLD.Cargo, 'despues', NEW.Cargo));
    END IF;

    IF NOT (OLD.Total_a_pagar <=> NEW.Total_a_pagar) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Total_a_pagar', JSON_OBJECT('antes', OLD.Total_a_pagar, 'despues', NEW.Total_a_pagar));
    END IF;

    IF NOT (OLD.Primer_pago <=> NEW.Primer_pago) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Primer_pago', JSON_OBJECT('antes', OLD.Primer_pago, 'despues', NEW.Primer_pago));
    END IF;

    IF NOT (OLD.Tarifa <=> NEW.Tarifa) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Tarifa', JSON_OBJECT('antes', OLD.Tarifa, 'despues', NEW.Tarifa));
    END IF;

    IF NOT (OLD.Saldos_Migrados <=> NEW.Saldos_Migrados) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Saldos_Migrados', JSON_OBJECT('antes', OLD.Saldos_Migrados, 'despues', NEW.Saldos_Migrados));
    END IF;

    IF NOT (OLD.wk_descu <=> NEW.wk_descu) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.wk_descu', JSON_OBJECT('antes', OLD.wk_descu, 'despues', NEW.wk_descu));
    END IF;

    IF NOT (OLD.Descuento <=> NEW.Descuento) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Descuento', JSON_OBJECT('antes', OLD.Descuento, 'despues', NEW.Descuento));
    END IF;

    IF NOT (OLD.Porcentaje <=> NEW.Porcentaje) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Porcentaje', JSON_OBJECT('antes', OLD.Porcentaje, 'despues', NEW.Porcentaje));
    END IF;

    IF NOT (OLD.Multas <=> NEW.Multas) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Multas', JSON_OBJECT('antes', OLD.Multas, 'despues', NEW.Multas));
    END IF;

    IF NOT (OLD.wk_refi <=> NEW.wk_refi) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.wk_refi', JSON_OBJECT('antes', OLD.wk_refi, 'despues', NEW.wk_refi));
    END IF;

    IF NOT (OLD.Refin <=> NEW.Refin) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Refin', JSON_OBJECT('antes', OLD.Refin, 'despues', NEW.Refin));
    END IF;

    IF NOT (OLD.Externo <=> NEW.Externo) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Externo', JSON_OBJECT('antes', OLD.Externo, 'despues', NEW.Externo));
    END IF;

    IF NOT (OLD.Saldo <=> NEW.Saldo) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Saldo', JSON_OBJECT('antes', OLD.Saldo, 'despues', NEW.Saldo));
    END IF;

    IF NOT (OLD.Cobrado <=> NEW.Cobrado) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Cobrado', JSON_OBJECT('antes', OLD.Cobrado, 'despues', NEW.Cobrado));
    END IF;

    IF NOT (OLD.Tipo_de_credito <=> NEW.Tipo_de_credito) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Tipo_de_credito', JSON_OBJECT('antes', OLD.Tipo_de_credito, 'despues', NEW.Tipo_de_credito));
    END IF;

    IF NOT (OLD.Aclaracion <=> NEW.Aclaracion) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Aclaracion', JSON_OBJECT('antes', OLD.Aclaracion, 'despues', NEW.Aclaracion));
    END IF;

    IF NOT (OLD.Nombres_Aval <=> NEW.Nombres_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Nombres_Aval', JSON_OBJECT('antes', OLD.Nombres_Aval, 'despues', NEW.Nombres_Aval));
    END IF;

    IF NOT (OLD.Apellido_Paterno_Aval <=> NEW.Apellido_Paterno_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Apellido_Paterno_Aval', JSON_OBJECT('antes', OLD.Apellido_Paterno_Aval, 'despues', NEW.Apellido_Paterno_Aval));
    END IF;

    IF NOT (OLD.Apellido_Materno_Aval <=> NEW.Apellido_Materno_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Apellido_Materno_Aval', JSON_OBJECT('antes', OLD.Apellido_Materno_Aval, 'despues', NEW.Apellido_Materno_Aval));
    END IF;

    IF NOT (OLD.Direccion_Aval <=> NEW.Direccion_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Direccion_Aval', JSON_OBJECT('antes', OLD.Direccion_Aval, 'despues', NEW.Direccion_Aval));
    END IF;

    IF NOT (OLD.No_Exterior_Aval <=> NEW.No_Exterior_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.No_Exterior_Aval', JSON_OBJECT('antes', OLD.No_Exterior_Aval, 'despues', NEW.No_Exterior_Aval));
    END IF;

    IF NOT (OLD.No_Interior_Aval <=> NEW.No_Interior_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.No_Interior_Aval', JSON_OBJECT('antes', OLD.No_Interior_Aval, 'despues', NEW.No_Interior_Aval));
    END IF;

    IF NOT (OLD.Colonia_Aval <=> NEW.Colonia_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Colonia_Aval', JSON_OBJECT('antes', OLD.Colonia_Aval, 'despues', NEW.Colonia_Aval));
    END IF;

    IF NOT (OLD.Codigo_Postal_Aval <=> NEW.Codigo_Postal_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Codigo_Postal_Aval', JSON_OBJECT('antes', OLD.Codigo_Postal_Aval, 'despues', NEW.Codigo_Postal_Aval));
    END IF;

    IF NOT (OLD.Poblacion_Aval <=> NEW.Poblacion_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Poblacion_Aval', JSON_OBJECT('antes', OLD.Poblacion_Aval, 'despues', NEW.Poblacion_Aval));
    END IF;

    IF NOT (OLD.Estado_Aval <=> NEW.Estado_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Estado_Aval', JSON_OBJECT('antes', OLD.Estado_Aval, 'despues', NEW.Estado_Aval));
    END IF;

    IF NOT (OLD.Telefono_Aval <=> NEW.Telefono_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Telefono_Aval', JSON_OBJECT('antes', OLD.Telefono_Aval, 'despues', NEW.Telefono_Aval));
    END IF;

    IF NOT (OLD.NoServicio_Aval <=> NEW.NoServicio_Aval) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.NoServicio_Aval', JSON_OBJECT('antes', OLD.NoServicio_Aval, 'despues', NEW.NoServicio_Aval));
    END IF;

    IF NOT (OLD.Telefono_Cliente <=> NEW.Telefono_Cliente) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Telefono_Cliente', JSON_OBJECT('antes', OLD.Telefono_Cliente, 'despues', NEW.Telefono_Cliente));
    END IF;

    IF NOT (OLD.Dia_de_pago <=> NEW.Dia_de_pago) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Dia_de_pago', JSON_OBJECT('antes', OLD.Dia_de_pago, 'despues', NEW.Dia_de_pago));
    END IF;

    IF NOT (OLD.Gerente_en_turno <=> NEW.Gerente_en_turno) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Gerente_en_turno', JSON_OBJECT('antes', OLD.Gerente_en_turno, 'despues', NEW.Gerente_en_turno));
    END IF;

    IF NOT (OLD.Agente2 <=> NEW.Agente2) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Agente2', JSON_OBJECT('antes', OLD.Agente2, 'despues', NEW.Agente2));
    END IF;

    IF NOT (OLD.Status <=> NEW.Status) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Status', JSON_OBJECT('antes', OLD.Status, 'despues', NEW.Status));
    END IF;

    IF NOT (OLD.Capturista <=> NEW.Capturista) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Capturista', JSON_OBJECT('antes', OLD.Capturista, 'despues', NEW.Capturista));
    END IF;

    IF NOT (OLD.NoServicio <=> NEW.NoServicio) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.NoServicio', JSON_OBJECT('antes', OLD.NoServicio, 'despues', NEW.NoServicio));
    END IF;

    IF NOT (OLD.Tipo_de_Cliente <=> NEW.Tipo_de_Cliente) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Tipo_de_Cliente', JSON_OBJECT('antes', OLD.Tipo_de_Cliente, 'despues', NEW.Tipo_de_Cliente));
    END IF;

    IF NOT (OLD.Identificador_Credito <=> NEW.Identificador_Credito) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Identificador_Credito', JSON_OBJECT('antes', OLD.Identificador_Credito, 'despues', NEW.Identificador_Credito));
    END IF;

    IF NOT (OLD.Seguridad <=> NEW.Seguridad) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Seguridad', JSON_OBJECT('antes', OLD.Seguridad, 'despues', NEW.Seguridad));
    END IF;

    IF NOT (OLD.Depuracion <=> NEW.Depuracion) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Depuracion', JSON_OBJECT('antes', OLD.Depuracion, 'despues', NEW.Depuracion));
    END IF;

    IF NOT (OLD.Folio_de_pagare <=> NEW.Folio_de_pagare) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.Folio_de_pagare', JSON_OBJECT('antes', OLD.Folio_de_pagare, 'despues', NEW.Folio_de_pagare));
    END IF;

    IF NOT (OLD.excel_index <=> NEW.excel_index) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.excel_index', JSON_OBJECT('antes', OLD.excel_index, 'despues', NEW.excel_index));
    END IF;

    IF NOT (OLD.cliente_xpress_id <=> NEW.cliente_xpress_id) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.cliente_xpress_id', JSON_OBJECT('antes', OLD.cliente_xpress_id, 'despues', NEW.cliente_xpress_id));
    END IF;

    IF NOT (OLD.cliente_persona_id <=> NEW.cliente_persona_id) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.cliente_persona_id', JSON_OBJECT('antes', OLD.cliente_persona_id, 'despues', NEW.cliente_persona_id));
    END IF;

    IF NOT (OLD.aval_persona_id <=> NEW.aval_persona_id) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.aval_persona_id', JSON_OBJECT('antes', OLD.aval_persona_id, 'despues', NEW.aval_persona_id));
    END IF;

    IF NOT (OLD.impacta_en_comision <=> NEW.impacta_en_comision) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.impacta_en_comision', JSON_OBJECT('antes', OLD.impacta_en_comision, 'despues', NEW.impacta_en_comision));
    END IF;

    IF NOT (OLD.referencia_nombre <=> NEW.referencia_nombre) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.referencia_nombre', JSON_OBJECT('antes', OLD.referencia_nombre, 'despues', NEW.referencia_nombre));
    END IF;

    IF NOT (OLD.referencia_telefono <=> NEW.referencia_telefono) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.referencia_telefono', JSON_OBJECT('antes', OLD.referencia_telefono, 'despues', NEW.referencia_telefono));
    END IF;

    IF NOT (OLD.tipo_servicio <=> NEW.tipo_servicio) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.tipo_servicio', JSON_OBJECT('antes', OLD.tipo_servicio, 'despues', NEW.tipo_servicio));
    END IF;

    IF NOT (OLD.regional_en_venta <=> NEW.regional_en_venta) THEN
        SET v_cambios = JSON_SET(v_cambios, '$.regional_en_venta', JSON_OBJECT('antes', OLD.regional_en_venta, 'despues', NEW.regional_en_venta));
    END IF;

    -- Solo insertar si hubo cambios
    IF JSON_LENGTH(v_cambios) > 0 THEN
        INSERT INTO prestamos_v2_update_log (prestamo_id, cambios, usuario_db)
        VALUES (NEW.PrestamoID, v_cambios, USER());
    END IF;

END //
DELIMITER ;


-- =====================================================
-- VERIFICAR CREACION
-- =====================================================
SELECT 'Tablas creadas:' AS mensaje;
SHOW TABLES LIKE 'prestamos_v2_%_log';

SELECT 'Triggers creados:' AS mensaje;
SHOW TRIGGERS WHERE `Table` = 'prestamos_v2' AND `Trigger` LIKE '%log%';
