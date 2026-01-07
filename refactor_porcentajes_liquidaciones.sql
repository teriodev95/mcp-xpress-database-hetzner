-- ============================================================================
-- REFACTORIZACIÓN: porcentajes_descuento_liquidaciones
-- ============================================================================
-- ANTES: 2,588 registros × 26 columnas (mucha redundancia)
-- DESPUÉS: 18 registros × 4 columnas (sin redundancia)
--
-- DESCUBRIMIENTOS:
-- - El MONTO no afecta los porcentajes (todos iguales por plazo/tipo)
-- - El AÑO no afecta los porcentajes (2023-2026 son idénticos)
-- - Solo importan: PLAZO (3) × TIPO_CLIENTE (6) = 18 combinaciones
-- ============================================================================

-- ============================================================================
-- PASO 1: CREAR NUEVA TABLA NORMALIZADA
-- ============================================================================

CREATE TABLE IF NOT EXISTS porcentajes_liquidacion_v2 (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plazo INT NOT NULL COMMENT 'Plazo en semanas (16, 21, 26)',
    tipo_cliente VARCHAR(16) NOT NULL COMMENT 'Tipo de cliente (NUEVO, LEAL, DIAMANTE, PREMIUM, VIP, NOBEL)',
    semana INT NOT NULL COMMENT 'Número de semana transcurrida (1-26)',
    porcentaje INT NOT NULL DEFAULT 0 COMMENT 'Porcentaje de descuento para liquidación',

    -- Índice único para evitar duplicados
    UNIQUE KEY idx_plazo_tipo_semana (plazo, tipo_cliente, semana),

    -- Índices para búsquedas rápidas
    INDEX idx_plazo_tipo (plazo, tipo_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Porcentajes de descuento para liquidación de préstamos (normalizada)';


-- ============================================================================
-- PASO 2: MIGRAR DATOS (extraer valores únicos de tabla actual)
-- ============================================================================

INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje)
-- Plazo 16 semanas
SELECT DISTINCT
    16 as plazo,
    CASE
        WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE'
        WHEN id LIKE '%LEAL%' THEN 'LEAL'
        WHEN id LIKE '%NOBEL%' THEN 'NOBEL'
        WHEN id LIKE '%NUEVO%' THEN 'NUEVO'
        WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM'
        WHEN id LIKE '%VIP%' THEN 'VIP'
    END as tipo_cliente,
    1 as semana,
    semana1 as porcentaje
FROM porcentajes_descuento_liquidaciones
WHERE id LIKE '%-a_16_sem.-%_2025'
GROUP BY tipo_cliente

UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 2, semana2 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 3, semana3 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 4, semana4 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 5, semana5 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 6, semana6 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 7, semana7 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 8, semana8 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 9, semana9 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 10, semana10 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 11, semana11 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 12, semana12 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 13, semana13 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 14, semana14 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 15, semana15 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 16, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 16, semana16 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_16_sem.-%_2025' GROUP BY 2

-- Plazo 21 semanas
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 1, semana1 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 2, semana2 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 3, semana3 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 4, semana4 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 5, semana5 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 6, semana6 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 7, semana7 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 8, semana8 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 9, semana9 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 10, semana10 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 11, semana11 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 12, semana12 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 13, semana13 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 14, semana14 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 15, semana15 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 16, semana16 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 17, semana17 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 18, semana18 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 19, semana19 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 20, semana20 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 21, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 21, semana21 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_21_sem.-%_2025' GROUP BY 2

-- Plazo 26 semanas
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 1, semana1 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 2, semana2 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 3, semana3 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 4, semana4 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 5, semana5 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 6, semana6 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 7, semana7 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 8, semana8 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 9, semana9 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 10, semana10 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 11, semana11 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 12, semana12 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 13, semana13 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 14, semana14 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 15, semana15 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 16, semana16 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 17, semana17 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 18, semana18 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 19, semana19 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 20, semana20 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 21, semana21 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 22, semana22 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 23, semana23 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 24, semana24 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 25, semana25 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2
UNION ALL SELECT DISTINCT 26, CASE WHEN id LIKE '%DIAMANTE%' THEN 'DIAMANTE' WHEN id LIKE '%LEAL%' THEN 'LEAL' WHEN id LIKE '%NOBEL%' THEN 'NOBEL' WHEN id LIKE '%NUEVO%' THEN 'NUEVO' WHEN id LIKE '%PREMIUM%' THEN 'PREMIUM' WHEN id LIKE '%VIP%' THEN 'VIP' END, 26, 0 FROM porcentajes_descuento_liquidaciones WHERE id LIKE '%-a_26_sem.-%_2025' GROUP BY 2;


-- ============================================================================
-- PASO 3: FUNCIÓN SIMPLIFICADA PARA OBTENER LIQUIDACIÓN
-- ============================================================================

DELIMITER //

DROP FUNCTION IF EXISTS fn_obtener_liquidacion_v2 //

CREATE FUNCTION fn_obtener_liquidacion_v2(p_prestamo_id VARCHAR(32))
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(10,2);
    DECLARE v_plazo INT;
    DECLARE v_tipo_cliente VARCHAR(16);
    DECLARE v_anio_prestamo INT;
    DECLARE v_semana_prestamo INT;
    DECLARE v_semana_actual INT;
    DECLARE v_anio_actual INT;
    DECLARE v_semanas_transcurridas INT;
    DECLARE v_porcentaje INT DEFAULT 0;

    -- Obtener datos del préstamo
    SELECT Saldo, plazo, Tipo_de_Cliente, Anio, Semana
    INTO v_saldo, v_plazo, v_tipo_cliente, v_anio_prestamo, v_semana_prestamo
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        RETURN NULL;
    END IF;

    -- Obtener semana actual
    SELECT semana, anio INTO v_semana_actual, v_anio_actual
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- Calcular semanas transcurridas
    SELECT COUNT(*) INTO v_semanas_transcurridas
    FROM calendario c
    WHERE (c.anio > v_anio_prestamo OR (c.anio = v_anio_prestamo AND c.semana >= v_semana_prestamo))
      AND (c.anio < v_anio_actual OR (c.anio = v_anio_actual AND c.semana <= v_semana_actual));

    -- Obtener porcentaje de la tabla normalizada (MUCHO MÁS SIMPLE)
    SELECT COALESCE(porcentaje, 0) INTO v_porcentaje
    FROM porcentajes_liquidacion_v2
    WHERE plazo = v_plazo
      AND tipo_cliente = v_tipo_cliente
      AND semana = LEAST(v_semanas_transcurridas, 26);

    RETURN ROUND(v_saldo - (v_saldo * COALESCE(v_porcentaje, 0) / 100), 2);
END //

DELIMITER ;


-- ============================================================================
-- PASO 4: PROCEDIMIENTO SIMPLIFICADO
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_calcular_liquidacion_v2 //

CREATE PROCEDURE sp_calcular_liquidacion_v2(IN p_prestamo_id VARCHAR(32))
BEGIN
    SELECT
        p.PrestamoID,
        CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) as cliente,
        p.Monto_otorgado,
        p.Total_a_pagar,
        p.plazo as plazo_semanas,
        p.Tipo_de_Cliente,
        p.Saldo as saldo_actual,
        p.Semana as semana_inicio,
        p.Anio as anio_inicio,
        c_actual.semana as semana_actual,
        c_actual.anio as anio_actual,
        (
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ) as semanas_transcurridas,
        COALESCE(pdl.porcentaje, 0) as porcentaje_descuento,
        ROUND(p.Saldo * COALESCE(pdl.porcentaje, 0) / 100, 2) as monto_descuento,
        ROUND(p.Saldo - (p.Saldo * COALESCE(pdl.porcentaje, 0) / 100), 2) as monto_liquidacion,
        CASE
            WHEN p.Saldo <= 0 THEN 'Préstamo ya liquidado'
            WHEN pdl.porcentaje IS NULL THEN 'Sin descuento disponible'
            WHEN pdl.porcentaje = 0 THEN 'Fuera de periodo de descuento'
            ELSE 'Liquidación disponible'
        END as estado
    FROM prestamos_v2 p
    CROSS JOIN (
        SELECT semana, anio FROM calendario
        WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    ) c_actual
    LEFT JOIN porcentajes_liquidacion_v2 pdl ON
        pdl.plazo = p.plazo
        AND pdl.tipo_cliente = p.Tipo_de_Cliente
        AND pdl.semana = LEAST((
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ), 26)
    WHERE p.PrestamoID = p_prestamo_id;
END //

DELIMITER ;


-- ============================================================================
-- VERIFICACIÓN Y VALIDACIÓN
-- ============================================================================

-- Ver la nueva tabla (debería tener ~468 registros: 18 combinaciones × 26 semanas)
-- SELECT COUNT(*) as total_registros FROM porcentajes_liquidacion_v2;

-- Ver estructura por plazo y tipo
-- SELECT plazo, tipo_cliente, COUNT(*) as semanas
-- FROM porcentajes_liquidacion_v2
-- GROUP BY plazo, tipo_cliente
-- ORDER BY plazo, tipo_cliente;

-- Ejemplo de consulta simple
-- SELECT * FROM porcentajes_liquidacion_v2
-- WHERE plazo = 21 AND tipo_cliente = 'LEAL'
-- ORDER BY semana;

-- Probar la función
-- SELECT fn_obtener_liquidacion_v2(' L-1505-pl') as monto_liquidacion;

-- Probar el procedimiento
-- CALL sp_calcular_liquidacion_v2(' L-1505-pl');


-- ============================================================================
-- PASO 5: RENOMBRAR TABLAS (EJECUTAR DESPUÉS DE VALIDAR)
-- ============================================================================

-- Una vez validado que todo funciona:
-- RENAME TABLE porcentajes_descuento_liquidaciones TO porcentajes_descuento_liquidaciones_OLD;
-- RENAME TABLE porcentajes_liquidacion_v2 TO porcentajes_liquidacion;

-- Para eliminar la tabla vieja (SOLO después de confirmar):
-- DROP TABLE porcentajes_descuento_liquidaciones_OLD;
