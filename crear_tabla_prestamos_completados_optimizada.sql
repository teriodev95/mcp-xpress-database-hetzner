-- =====================================================
-- Tabla de Respaldo para Préstamos Completados (OPTIMIZADA)
-- =====================================================
-- Esta tabla almacena préstamos que ya han sido pagados
-- completamente (Saldo <= 0) y sirve como respaldo histórico
-- de la tabla prestamos_v2.
--
-- OPTIMIZACIÓN: Elimina campos redundantes que ya existen
-- en la tabla personas. Solo mantiene las referencias:
-- - cliente_persona_id -> personas.id
-- - aval_persona_id -> personas.id
--
-- Los datos personales se consultan mediante JOIN con personas
-- =====================================================

CREATE TABLE IF NOT EXISTS `prestamos_completados` (
    -- ID auto-incremental (PK eficiente para 500k+ registros)
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- Identificador único del préstamo
    `PrestamoID` varchar(32) NOT NULL,
    `Cliente_ID` varchar(32) NOT NULL,

    -- Referencias a tabla personas (NO redundante)
    `cliente_xpress_id` varchar(64) DEFAULT NULL COMMENT 'Referencia a personas.xpress_id',
    `cliente_persona_id` varchar(64) DEFAULT NULL COMMENT 'Referencia a personas.id para datos del cliente',
    `aval_persona_id` varchar(64) DEFAULT NULL COMMENT 'Referencia a personas.id para datos del aval',

    -- Datos del préstamo
    `No_De_Contrato` varchar(16) DEFAULT NULL,
    `Agente` varchar(16) NOT NULL,
    `Gerencia` varchar(16) NOT NULL,
    `SucursalID` enum('dinero','plata','moneda','efectivo','capital','dec') DEFAULT NULL,
    `Semana` int(11) NOT NULL,
    `Anio` int(11) NOT NULL,
    `plazo` int(11) NOT NULL,

    -- Montos y cálculos del préstamo
    `Monto_otorgado` int(11) NOT NULL,
    `Cargo` decimal(8,2) NOT NULL,
    `Total_a_pagar` decimal(8,2) NOT NULL,
    `Primer_pago` decimal(8,2) NOT NULL,
    `Tarifa` decimal(8,2) NOT NULL,

    -- Ajustes al préstamo
    `Saldos_Migrados` varchar(30) DEFAULT NULL,
    `wk_descu` varchar(16) DEFAULT NULL,
    `Descuento` decimal(8,2) DEFAULT NULL,
    `Porcentaje` decimal(8,2) DEFAULT NULL,
    `Multas` decimal(8,2) DEFAULT NULL,
    `wk_refi` varchar(30) DEFAULT NULL,
    `Refin` varchar(30) DEFAULT NULL,
    `Externo` varchar(14) DEFAULT NULL,

    -- Saldo y cobrado (valores de prestamos_dynamic al momento de migración)
    `Saldo` decimal(8,2) NOT NULL COMMENT 'Saldo final al migrar (debería ser <= 0)',
    `Cobrado` decimal(8,2) NOT NULL COMMENT 'Total cobrado calculado de prestamos_dynamic',

    -- Tipo y estado del préstamo
    `Tipo_de_credito` varchar(32) NOT NULL,
    `Status` varchar(14) NOT NULL,
    `Tipo_de_Cliente` varchar(16) NOT NULL,
    `Aclaracion` varchar(512) DEFAULT NULL,

    -- Información operativa
    `Dia_de_pago` varchar(9) NOT NULL,
    `Gerente_en_turno` varchar(32) NOT NULL,
    `Agente2` varchar(32) NOT NULL,
    `Capturista` varchar(16) NOT NULL,
    `NoServicio` varchar(64) DEFAULT NULL,
    `Identificador_Credito` varchar(36) NOT NULL,
    `Seguridad` varchar(128) DEFAULT NULL,
    `Depuracion` varchar(124) DEFAULT NULL,
    `Folio_de_pagare` varchar(32) DEFAULT NULL,
    `excel_index` int(11) NOT NULL DEFAULT 0,
    `impacta_en_comision` tinyint(1) NOT NULL DEFAULT 1,

    -- Calificación del préstamo
    `calificacion_prestamo` JSON DEFAULT NULL COMMENT 'Calificación y métricas del préstamo (ej: puntualidad, días de retraso, etc.)',

    -- Campos de auditoría
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha cuando el préstamo fue movido a la tabla de completados',
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última actualización del registro',

    -- Clave primaria simple (óptima para inserts masivos)
    PRIMARY KEY (`id`),

    -- Índice único en PrestamoID (cada préstamo solo puede aparecer una vez)
    UNIQUE KEY `idx_unique_prestamo_id` (`PrestamoID`),

    -- Índices para consultas
    KEY `idx_cliente_persona_id` (`cliente_persona_id`),
    KEY `idx_aval_persona_id` (`aval_persona_id`),
    KEY `idx_gerencia_agencia` (`Gerencia`, `Agente`),
    KEY `idx_semana_anio` (`Semana`, `Anio`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_status` (`Status`),
    KEY `idx_tipo_credito` (`Tipo_de_credito`),

    -- Foreign keys a tabla personas
    CONSTRAINT `fk_prestamos_completados_cliente`
        FOREIGN KEY (`cliente_persona_id`) REFERENCES `personas` (`id`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_prestamos_completados_aval`
        FOREIGN KEY (`aval_persona_id`) REFERENCES `personas` (`id`)
        ON DELETE SET NULL ON UPDATE CASCADE

) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Respaldo optimizado de préstamos completados (Saldo <= 0) - datos personales en tabla personas';

-- =====================================================
-- Vista para consultar préstamos completados con datos personales
-- =====================================================
-- Esta vista facilita las consultas uniendo los datos del préstamo
-- con los datos personales del cliente y aval desde la tabla personas

CREATE OR REPLACE VIEW `prestamos_completados_view` AS
SELECT
    -- Datos del préstamo
    pc.PrestamoID,
    pc.Cliente_ID,
    pc.No_De_Contrato,
    pc.Agente,
    pc.Gerencia,
    pc.SucursalID,
    pc.Semana,
    pc.Anio,
    pc.plazo,
    pc.Monto_otorgado,
    pc.Cargo,
    pc.Total_a_pagar,
    pc.Primer_pago,
    pc.Tarifa,
    pc.Saldo,
    pc.Cobrado,
    pc.Tipo_de_credito,
    pc.Status,
    pc.Tipo_de_Cliente,
    pc.Dia_de_pago,
    pc.created_at AS fecha_migracion,
    pc.updated_at,

    -- Datos del cliente desde personas
    cliente.nombres AS Cliente_Nombres,
    cliente.apellido_paterno AS Cliente_Apellido_Paterno,
    cliente.apellido_materno AS Cliente_Apellido_Materno,
    cliente.telefono AS Cliente_Telefono,
    cliente.calle AS Cliente_Direccion,
    cliente.no_exterior AS Cliente_NoExterior,
    cliente.no_interior AS Cliente_NoInterior,
    cliente.colonia AS Cliente_Colonia,
    cliente.codigo_postal AS Cliente_Codigo_Postal,
    cliente.municipio AS Cliente_Municipio,
    cliente.estado AS Cliente_Estado,

    -- Datos del aval desde personas
    aval.nombres AS Aval_Nombres,
    aval.apellido_paterno AS Aval_Apellido_Paterno,
    aval.apellido_materno AS Aval_Apellido_Materno,
    aval.telefono AS Aval_Telefono,
    aval.calle AS Aval_Direccion,
    aval.no_exterior AS Aval_NoExterior,
    aval.no_interior AS Aval_NoInterior,
    aval.colonia AS Aval_Colonia,
    aval.codigo_postal AS Aval_Codigo_Postal,
    aval.municipio AS Aval_Municipio,
    aval.estado AS Aval_Estado

FROM prestamos_completados pc
LEFT JOIN personas cliente ON pc.cliente_persona_id = cliente.id
LEFT JOIN personas aval ON pc.aval_persona_id = aval.id;

-- =====================================================
-- Comentarios sobre el uso de la tabla optimizada
-- =====================================================
-- VENTAJAS:
-- 1. Reduce significativamente el tamaño de la tabla (menos campos redundantes)
-- 2. Mantiene un solo registro de cada persona en la tabla personas
-- 3. Actualizaciones de datos personales se reflejan automáticamente
-- 4. Facilita queries relacionales con integridad referencial
--
-- USO:
-- 1. Para consultas simples del préstamo: SELECT * FROM prestamos_completados
-- 2. Para consultas con datos personales: SELECT * FROM prestamos_completados_view
-- 3. Los datos personales siempre están actualizados desde tabla personas
--
-- MIGRACIÓN:
-- 1. Esta tabla se debe usar para archivar préstamos con Saldo <= 0
-- 2. Los campos cliente_persona_id y aval_persona_id deben estar poblados
-- 3. El campo created_at registra cuándo se archivó el préstamo
-- 4. Use prestamos_completados_view para consultas con nombres completos
-- =====================================================
