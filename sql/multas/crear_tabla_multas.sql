-- =====================================================
-- Tabla: multas
-- Descripción: Almacena multas (penalizaciones) aplicadas a préstamos
--              NO impactan el saldo del préstamo
--              Separadas de pagos_dynamic para evitar duplicados
-- Fecha: 2026-01-20
-- =====================================================

CREATE TABLE IF NOT EXISTS multas (
    -- Identificador único (mismo que pagoID de pagos_v3)
    multa_id VARCHAR(36) NOT NULL PRIMARY KEY,

    -- Relación con préstamo
    prestamo_id VARCHAR(32) NOT NULL,

    -- Datos de la multa
    monto DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    semana TINYINT NOT NULL,
    anio YEAR NOT NULL,

    -- Información de agencia
    agencia VARCHAR(32) NOT NULL,

    -- Fecha de aplicación
    fecha_multa DATETIME NOT NULL,

    -- Metadata
    created_at DATETIME NOT NULL DEFAULT (CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')),

    -- Índices
    INDEX idx_prestamo (prestamo_id),
    INDEX idx_semana_anio (semana, anio),
    INDEX idx_agencia (agencia),
    INDEX idx_fecha_multa (fecha_multa)

) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_general_ci
  COMMENT='Multas (penalizaciones) - NO impactan saldo del préstamo';

-- =====================================================
-- Notas de diseño
-- =====================================================

-- 1. Multas son penalizaciones que NO modifican el saldo del préstamo
-- 2. Se extraen automáticamente de pagos_v3 mediante triggers
-- 3. Se eliminan automáticamente de pagos_dynamic (evita duplicados)
-- 4. Solo campos esenciales: monto, préstamo, agencia, semana, fecha
-- 5. Estimación: ~100-200 multas/año (muy pocas)
