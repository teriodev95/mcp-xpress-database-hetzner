-- =====================================================
-- PASO 1: Crear tabla cobranza_historial
-- =====================================================
-- Ejecutar ANTES de crear el procedimiento almacenado
-- =====================================================

CREATE TABLE IF NOT EXISTS cobranza_historial (
    -- Identificadores (PRIMARY KEY compuesto)
    agencia VARCHAR(32) NOT NULL,
    semana TINYINT NOT NULL,
    anio YEAR NOT NULL,
    created_at DATETIME NOT NULL DEFAULT (CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')),

    -- Contadores (cambian cada captura)
    clientes_cobrados SMALLINT NOT NULL DEFAULT 0,
    no_pagos SMALLINT NOT NULL DEFAULT 0,
    numero_liquidaciones SMALLINT NOT NULL DEFAULT 0,
    pagos_reducidos SMALLINT NOT NULL DEFAULT 0,

    -- Cobranza acumulada hasta esta captura
    total_cobranza_pura DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    monto_excedente DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    multas DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    liquidaciones DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_de_descuento DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    -- Índices
    PRIMARY KEY (agencia, semana, anio, created_at),
    INDEX idx_semana_anio (semana, anio),
    INDEX idx_created_at (created_at)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_general_ci
  COMMENT='Cobranza histórica capturada 3 veces al día (mañana, tarde, noche)';

-- =====================================================
-- Verificar que la tabla se creó correctamente
-- =====================================================

SHOW CREATE TABLE cobranza_historial;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

-- 1. Esta tabla se llena con el SP: sp_insertar_cobranza_agencias
-- 2. Se ejecuta 3 veces al día: mañana (~09:00), tarde (~14:00), noche (~18:00)
-- 3. Solo en días: miércoles, jueves, viernes
-- 4. PRIMARY KEY (agencia, semana, anio, created_at) permite múltiples snapshots por día
-- 5. Los datos coinciden 100% con Dashboard V2 API

-- =====================================================
-- Estimación de datos:
-- =====================================================

-- - 352 agencias
-- - 52 semanas/año
-- - 3 días (mié, jue, vie)
-- - 3 capturas/día
-- = 352 × 52 × 3 × 3 = ~164,736 registros/año
-- Tamaño estimado: ~8-10 MB/año (muy eficiente)
