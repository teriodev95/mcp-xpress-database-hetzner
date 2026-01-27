-- =====================================================
-- Tabla: cobranza_historial
-- Descripción: Snapshots de cobranza por agencia capturados 3 veces al día
--              (mañana, tarde, noche) durante miércoles, jueves y viernes
-- Autor: Sistema
-- Fecha: 2026-01-20
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
-- Comentarios de campos
-- =====================================================

-- agencia: Código de la agencia (ej: AGE068, AGC001)
-- semana/anio: Semana ISO del año
-- created_at: Fecha/hora exacta de captura en zona horaria de Ciudad de México
-- clientes_cobrados: Clientes que han pagado hasta esta captura
-- no_pagos: Clientes que no han pagado (tipo = 'No_pago')
-- numero_liquidaciones: Cantidad de préstamos liquidados
-- pagos_reducidos: Cantidad de pagos reducidos
-- total_cobranza_pura: Cobranza que cubre el débito
-- monto_excedente: Pagos adicionales sobre el débito
-- multas: Multas cobradas
-- liquidaciones: Monto total de liquidaciones
-- total_de_descuento: Descuentos aplicados

-- =====================================================
-- Notas de diseño
-- =====================================================

-- 1. PRIMARY KEY (agencia, semana, anio, created_at) permite:
--    - Múltiples snapshots por día sin límite
--    - Horario exacto de cada captura
--    - Historial completo de evolución diaria

-- 2. Frecuencia de capturas:
--    - 3 veces al día (mañana ~09:00, tarde ~14:00, noche ~18:00)
--    - Solo miércoles, jueves, viernes
--    - 3 días × 3 capturas = 9 snapshots por agencia/semana

-- 3. Campos calculables (NO almacenados):
--    - cobranza_total = total_cobranza_pura + monto_excedente + multas + liquidaciones
--    - debito_faltante = debitos_historial.debito_X - total_cobranza_pura
--    - rendimiento = (total_cobranza_pura / debitos_historial.debito_X) * 100

-- 4. Estimación de datos:
--    - 352 agencias × 52 semanas × 9 snapshots = ~164,736 registros/año
--    - Tamaño estimado: ~8 MB/año (muy eficiente)

-- 5. Queries útiles:

-- Última captura del día:
-- SELECT * FROM cobranza_historial
-- WHERE agencia = 'AGC001' AND semana = 3 AND anio = 2026
-- ORDER BY created_at DESC LIMIT 1;

-- Evolución durante el día:
-- SELECT
--     TIME(created_at) as hora,
--     clientes_cobrados,
--     total_cobranza_pura
-- FROM cobranza_historial
-- WHERE agencia = 'AGC001'
--   AND DATE(created_at) = '2026-01-15'
-- ORDER BY created_at;

-- Comparar mañana vs noche:
-- SELECT
--     agencia,
--     MIN(total_cobranza_pura) as cobranza_manana,
--     MAX(total_cobranza_pura) as cobranza_noche,
--     MAX(total_cobranza_pura) - MIN(total_cobranza_pura) as incremento_dia
-- FROM cobranza_historial
-- WHERE semana = 3 AND anio = 2026 AND DATE(created_at) = '2026-01-15'
-- GROUP BY agencia;
