-- ============================================================================
-- TABLA OPTIMIZADA: porcentajes_liquidacion_v2
-- ============================================================================
-- REDUCCIÓN: 2,588 registros → 468 registros (82% menos)
--            26 columnas → 4 columnas (85% menos)
-- ============================================================================

DROP TABLE IF EXISTS porcentajes_liquidacion_v2;

CREATE TABLE porcentajes_liquidacion_v2 (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plazo INT NOT NULL COMMENT 'Plazo en semanas (16, 21, 26)',
    tipo_cliente VARCHAR(16) NOT NULL COMMENT 'NUEVO, LEAL, DIAMANTE, PREMIUM, VIP, NOBEL',
    semana INT NOT NULL COMMENT 'Semana transcurrida (1-26)',
    porcentaje INT NOT NULL DEFAULT 0 COMMENT 'Porcentaje de descuento',
    UNIQUE KEY idx_plazo_tipo_semana (plazo, tipo_cliente, semana),
    INDEX idx_busqueda (plazo, tipo_cliente)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ============================================================================
-- DATOS: PLAZO 16 SEMANAS
-- ============================================================================

-- DIAMANTE - 16 sem (descuento: 15→10%, luego 0 desde sem 13)
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'DIAMANTE', 1, 15), (16, 'DIAMANTE', 2, 14), (16, 'DIAMANTE', 3, 13),
(16, 'DIAMANTE', 4, 12), (16, 'DIAMANTE', 5, 11), (16, 'DIAMANTE', 6, 10),
(16, 'DIAMANTE', 7, 10), (16, 'DIAMANTE', 8, 10), (16, 'DIAMANTE', 9, 10),
(16, 'DIAMANTE', 10, 10), (16, 'DIAMANTE', 11, 10), (16, 'DIAMANTE', 12, 10),
(16, 'DIAMANTE', 13, 0), (16, 'DIAMANTE', 14, 0), (16, 'DIAMANTE', 15, 0), (16, 'DIAMANTE', 16, 0);

-- LEAL - 16 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'LEAL', 1, 16), (16, 'LEAL', 2, 15), (16, 'LEAL', 3, 14),
(16, 'LEAL', 4, 13), (16, 'LEAL', 5, 12), (16, 'LEAL', 6, 11),
(16, 'LEAL', 7, 10), (16, 'LEAL', 8, 10), (16, 'LEAL', 9, 10),
(16, 'LEAL', 10, 10), (16, 'LEAL', 11, 10), (16, 'LEAL', 12, 10),
(16, 'LEAL', 13, 0), (16, 'LEAL', 14, 0), (16, 'LEAL', 15, 0), (16, 'LEAL', 16, 0);

-- PREMIUM - 16 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'PREMIUM', 1, 17), (16, 'PREMIUM', 2, 16), (16, 'PREMIUM', 3, 15),
(16, 'PREMIUM', 4, 14), (16, 'PREMIUM', 5, 13), (16, 'PREMIUM', 6, 12),
(16, 'PREMIUM', 7, 11), (16, 'PREMIUM', 8, 10), (16, 'PREMIUM', 9, 10),
(16, 'PREMIUM', 10, 10), (16, 'PREMIUM', 11, 10), (16, 'PREMIUM', 12, 10),
(16, 'PREMIUM', 13, 0), (16, 'PREMIUM', 14, 0), (16, 'PREMIUM', 15, 0), (16, 'PREMIUM', 16, 0);

-- VIP - 16 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'VIP', 1, 18), (16, 'VIP', 2, 17), (16, 'VIP', 3, 16),
(16, 'VIP', 4, 15), (16, 'VIP', 5, 14), (16, 'VIP', 6, 13),
(16, 'VIP', 7, 12), (16, 'VIP', 8, 11), (16, 'VIP', 9, 10),
(16, 'VIP', 10, 10), (16, 'VIP', 11, 10), (16, 'VIP', 12, 10),
(16, 'VIP', 13, 0), (16, 'VIP', 14, 0), (16, 'VIP', 15, 0), (16, 'VIP', 16, 0);

-- NOBEL - 16 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'NOBEL', 1, 19), (16, 'NOBEL', 2, 18), (16, 'NOBEL', 3, 17),
(16, 'NOBEL', 4, 16), (16, 'NOBEL', 5, 15), (16, 'NOBEL', 6, 14),
(16, 'NOBEL', 7, 13), (16, 'NOBEL', 8, 12), (16, 'NOBEL', 9, 11),
(16, 'NOBEL', 10, 10), (16, 'NOBEL', 11, 10), (16, 'NOBEL', 12, 10),
(16, 'NOBEL', 13, 0), (16, 'NOBEL', 14, 0), (16, 'NOBEL', 15, 0), (16, 'NOBEL', 16, 0);

-- NUEVO - 16 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(16, 'NUEVO', 1, 20), (16, 'NUEVO', 2, 19), (16, 'NUEVO', 3, 18),
(16, 'NUEVO', 4, 17), (16, 'NUEVO', 5, 16), (16, 'NUEVO', 6, 15),
(16, 'NUEVO', 7, 14), (16, 'NUEVO', 8, 13), (16, 'NUEVO', 9, 12),
(16, 'NUEVO', 10, 11), (16, 'NUEVO', 11, 10), (16, 'NUEVO', 12, 10),
(16, 'NUEVO', 13, 0), (16, 'NUEVO', 14, 0), (16, 'NUEVO', 15, 0), (16, 'NUEVO', 16, 0);


-- ============================================================================
-- DATOS: PLAZO 21 SEMANAS
-- ============================================================================

-- DIAMANTE - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'DIAMANTE', 1, 16), (21, 'DIAMANTE', 2, 15), (21, 'DIAMANTE', 3, 14),
(21, 'DIAMANTE', 4, 13), (21, 'DIAMANTE', 5, 12), (21, 'DIAMANTE', 6, 11),
(21, 'DIAMANTE', 7, 10), (21, 'DIAMANTE', 8, 10), (21, 'DIAMANTE', 9, 10),
(21, 'DIAMANTE', 10, 10), (21, 'DIAMANTE', 11, 10), (21, 'DIAMANTE', 12, 10),
(21, 'DIAMANTE', 13, 10), (21, 'DIAMANTE', 14, 10), (21, 'DIAMANTE', 15, 10),
(21, 'DIAMANTE', 16, 10), (21, 'DIAMANTE', 17, 10), (21, 'DIAMANTE', 18, 0),
(21, 'DIAMANTE', 19, 0), (21, 'DIAMANTE', 20, 0), (21, 'DIAMANTE', 21, 0);

-- LEAL - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'LEAL', 1, 17), (21, 'LEAL', 2, 16), (21, 'LEAL', 3, 15),
(21, 'LEAL', 4, 14), (21, 'LEAL', 5, 13), (21, 'LEAL', 6, 12),
(21, 'LEAL', 7, 11), (21, 'LEAL', 8, 10), (21, 'LEAL', 9, 10),
(21, 'LEAL', 10, 10), (21, 'LEAL', 11, 10), (21, 'LEAL', 12, 10),
(21, 'LEAL', 13, 10), (21, 'LEAL', 14, 10), (21, 'LEAL', 15, 10),
(21, 'LEAL', 16, 10), (21, 'LEAL', 17, 10), (21, 'LEAL', 18, 0),
(21, 'LEAL', 19, 0), (21, 'LEAL', 20, 0), (21, 'LEAL', 21, 0);

-- PREMIUM - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'PREMIUM', 1, 18), (21, 'PREMIUM', 2, 17), (21, 'PREMIUM', 3, 16),
(21, 'PREMIUM', 4, 15), (21, 'PREMIUM', 5, 14), (21, 'PREMIUM', 6, 13),
(21, 'PREMIUM', 7, 12), (21, 'PREMIUM', 8, 11), (21, 'PREMIUM', 9, 10),
(21, 'PREMIUM', 10, 10), (21, 'PREMIUM', 11, 10), (21, 'PREMIUM', 12, 10),
(21, 'PREMIUM', 13, 10), (21, 'PREMIUM', 14, 10), (21, 'PREMIUM', 15, 10),
(21, 'PREMIUM', 16, 10), (21, 'PREMIUM', 17, 10), (21, 'PREMIUM', 18, 0),
(21, 'PREMIUM', 19, 0), (21, 'PREMIUM', 20, 0), (21, 'PREMIUM', 21, 0);

-- VIP - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'VIP', 1, 19), (21, 'VIP', 2, 18), (21, 'VIP', 3, 17),
(21, 'VIP', 4, 16), (21, 'VIP', 5, 15), (21, 'VIP', 6, 14),
(21, 'VIP', 7, 13), (21, 'VIP', 8, 12), (21, 'VIP', 9, 11),
(21, 'VIP', 10, 10), (21, 'VIP', 11, 10), (21, 'VIP', 12, 10),
(21, 'VIP', 13, 10), (21, 'VIP', 14, 10), (21, 'VIP', 15, 10),
(21, 'VIP', 16, 10), (21, 'VIP', 17, 10), (21, 'VIP', 18, 0),
(21, 'VIP', 19, 0), (21, 'VIP', 20, 0), (21, 'VIP', 21, 0);

-- NOBEL - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'NOBEL', 1, 20), (21, 'NOBEL', 2, 19), (21, 'NOBEL', 3, 18),
(21, 'NOBEL', 4, 17), (21, 'NOBEL', 5, 16), (21, 'NOBEL', 6, 15),
(21, 'NOBEL', 7, 14), (21, 'NOBEL', 8, 13), (21, 'NOBEL', 9, 12),
(21, 'NOBEL', 10, 11), (21, 'NOBEL', 11, 10), (21, 'NOBEL', 12, 10),
(21, 'NOBEL', 13, 10), (21, 'NOBEL', 14, 10), (21, 'NOBEL', 15, 10),
(21, 'NOBEL', 16, 10), (21, 'NOBEL', 17, 10), (21, 'NOBEL', 18, 0),
(21, 'NOBEL', 19, 0), (21, 'NOBEL', 20, 0), (21, 'NOBEL', 21, 0);

-- NUEVO - 21 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(21, 'NUEVO', 1, 21), (21, 'NUEVO', 2, 20), (21, 'NUEVO', 3, 19),
(21, 'NUEVO', 4, 18), (21, 'NUEVO', 5, 17), (21, 'NUEVO', 6, 16),
(21, 'NUEVO', 7, 15), (21, 'NUEVO', 8, 14), (21, 'NUEVO', 9, 13),
(21, 'NUEVO', 10, 12), (21, 'NUEVO', 11, 11), (21, 'NUEVO', 12, 10),
(21, 'NUEVO', 13, 10), (21, 'NUEVO', 14, 10), (21, 'NUEVO', 15, 10),
(21, 'NUEVO', 16, 10), (21, 'NUEVO', 17, 10), (21, 'NUEVO', 18, 0),
(21, 'NUEVO', 19, 0), (21, 'NUEVO', 20, 0), (21, 'NUEVO', 21, 0);


-- ============================================================================
-- DATOS: PLAZO 26 SEMANAS
-- ============================================================================

-- DIAMANTE - 26 sem (descuento baja de 2 en 2)
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'DIAMANTE', 1, 18), (26, 'DIAMANTE', 2, 18), (26, 'DIAMANTE', 3, 17),
(26, 'DIAMANTE', 4, 17), (26, 'DIAMANTE', 5, 16), (26, 'DIAMANTE', 6, 16),
(26, 'DIAMANTE', 7, 15), (26, 'DIAMANTE', 8, 15), (26, 'DIAMANTE', 9, 14),
(26, 'DIAMANTE', 10, 14), (26, 'DIAMANTE', 11, 13), (26, 'DIAMANTE', 12, 13),
(26, 'DIAMANTE', 13, 12), (26, 'DIAMANTE', 14, 12), (26, 'DIAMANTE', 15, 11),
(26, 'DIAMANTE', 16, 11), (26, 'DIAMANTE', 17, 10), (26, 'DIAMANTE', 18, 10),
(26, 'DIAMANTE', 19, 10), (26, 'DIAMANTE', 20, 10), (26, 'DIAMANTE', 21, 10),
(26, 'DIAMANTE', 22, 10), (26, 'DIAMANTE', 23, 0), (26, 'DIAMANTE', 24, 0),
(26, 'DIAMANTE', 25, 0), (26, 'DIAMANTE', 26, 0);

-- LEAL - 26 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'LEAL', 1, 19), (26, 'LEAL', 2, 19), (26, 'LEAL', 3, 18),
(26, 'LEAL', 4, 18), (26, 'LEAL', 5, 17), (26, 'LEAL', 6, 17),
(26, 'LEAL', 7, 16), (26, 'LEAL', 8, 16), (26, 'LEAL', 9, 15),
(26, 'LEAL', 10, 15), (26, 'LEAL', 11, 14), (26, 'LEAL', 12, 14),
(26, 'LEAL', 13, 13), (26, 'LEAL', 14, 13), (26, 'LEAL', 15, 12),
(26, 'LEAL', 16, 12), (26, 'LEAL', 17, 11), (26, 'LEAL', 18, 11),
(26, 'LEAL', 19, 10), (26, 'LEAL', 20, 10), (26, 'LEAL', 21, 10),
(26, 'LEAL', 22, 10), (26, 'LEAL', 23, 0), (26, 'LEAL', 24, 0),
(26, 'LEAL', 25, 0), (26, 'LEAL', 26, 0);

-- PREMIUM - 26 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'PREMIUM', 1, 20), (26, 'PREMIUM', 2, 20), (26, 'PREMIUM', 3, 19),
(26, 'PREMIUM', 4, 19), (26, 'PREMIUM', 5, 18), (26, 'PREMIUM', 6, 18),
(26, 'PREMIUM', 7, 17), (26, 'PREMIUM', 8, 17), (26, 'PREMIUM', 9, 16),
(26, 'PREMIUM', 10, 16), (26, 'PREMIUM', 11, 15), (26, 'PREMIUM', 12, 15),
(26, 'PREMIUM', 13, 14), (26, 'PREMIUM', 14, 14), (26, 'PREMIUM', 15, 13),
(26, 'PREMIUM', 16, 13), (26, 'PREMIUM', 17, 12), (26, 'PREMIUM', 18, 12),
(26, 'PREMIUM', 19, 11), (26, 'PREMIUM', 20, 11), (26, 'PREMIUM', 21, 10),
(26, 'PREMIUM', 22, 10), (26, 'PREMIUM', 23, 0), (26, 'PREMIUM', 24, 0),
(26, 'PREMIUM', 25, 0), (26, 'PREMIUM', 26, 0);

-- VIP - 26 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'VIP', 1, 21), (26, 'VIP', 2, 21), (26, 'VIP', 3, 20),
(26, 'VIP', 4, 20), (26, 'VIP', 5, 19), (26, 'VIP', 6, 19),
(26, 'VIP', 7, 18), (26, 'VIP', 8, 18), (26, 'VIP', 9, 17),
(26, 'VIP', 10, 17), (26, 'VIP', 11, 16), (26, 'VIP', 12, 16),
(26, 'VIP', 13, 15), (26, 'VIP', 14, 15), (26, 'VIP', 15, 14),
(26, 'VIP', 16, 14), (26, 'VIP', 17, 13), (26, 'VIP', 18, 13),
(26, 'VIP', 19, 12), (26, 'VIP', 20, 12), (26, 'VIP', 21, 11),
(26, 'VIP', 22, 11), (26, 'VIP', 23, 0), (26, 'VIP', 24, 0),
(26, 'VIP', 25, 0), (26, 'VIP', 26, 0);

-- NOBEL - 26 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'NOBEL', 1, 21), (26, 'NOBEL', 2, 21), (26, 'NOBEL', 3, 20),
(26, 'NOBEL', 4, 20), (26, 'NOBEL', 5, 19), (26, 'NOBEL', 6, 19),
(26, 'NOBEL', 7, 18), (26, 'NOBEL', 8, 18), (26, 'NOBEL', 9, 17),
(26, 'NOBEL', 10, 17), (26, 'NOBEL', 11, 16), (26, 'NOBEL', 12, 16),
(26, 'NOBEL', 13, 15), (26, 'NOBEL', 14, 15), (26, 'NOBEL', 15, 14),
(26, 'NOBEL', 16, 14), (26, 'NOBEL', 17, 13), (26, 'NOBEL', 18, 13),
(26, 'NOBEL', 19, 12), (26, 'NOBEL', 20, 12), (26, 'NOBEL', 21, 11),
(26, 'NOBEL', 22, 11), (26, 'NOBEL', 23, 0), (26, 'NOBEL', 24, 0),
(26, 'NOBEL', 25, 0), (26, 'NOBEL', 26, 0);

-- NUEVO - 26 sem
INSERT INTO porcentajes_liquidacion_v2 (plazo, tipo_cliente, semana, porcentaje) VALUES
(26, 'NUEVO', 1, 22), (26, 'NUEVO', 2, 22), (26, 'NUEVO', 3, 21),
(26, 'NUEVO', 4, 21), (26, 'NUEVO', 5, 20), (26, 'NUEVO', 6, 20),
(26, 'NUEVO', 7, 19), (26, 'NUEVO', 8, 19), (26, 'NUEVO', 9, 18),
(26, 'NUEVO', 10, 18), (26, 'NUEVO', 11, 17), (26, 'NUEVO', 12, 17),
(26, 'NUEVO', 13, 16), (26, 'NUEVO', 14, 16), (26, 'NUEVO', 15, 15),
(26, 'NUEVO', 16, 15), (26, 'NUEVO', 17, 14), (26, 'NUEVO', 18, 14),
(26, 'NUEVO', 19, 13), (26, 'NUEVO', 20, 13), (26, 'NUEVO', 21, 12),
(26, 'NUEVO', 22, 12), (26, 'NUEVO', 23, 0), (26, 'NUEVO', 24, 0),
(26, 'NUEVO', 25, 0), (26, 'NUEVO', 26, 0);


-- ============================================================================
-- VERIFICAR DATOS INSERTADOS
-- ============================================================================
-- SELECT plazo, tipo_cliente, COUNT(*) as semanas FROM porcentajes_liquidacion_v2 GROUP BY plazo, tipo_cliente;
-- SELECT COUNT(*) as total FROM porcentajes_liquidacion_v2;  -- Debería ser 384 (16*6 + 21*6 + 26*6)
