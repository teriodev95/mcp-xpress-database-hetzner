-- =====================================================
-- Procedimiento: sp_insertar_debitos_agencias
-- Descripción: Inserta débitos por agencia para una semana/año específica
--              Calcula débitos desde vw_datos_cobranza
-- Uso: CALL sp_insertar_debitos_agencias(2, 2026);
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_insertar_debitos_agencias$$

CREATE PROCEDURE sp_insertar_debitos_agencias(
    IN p_semana TINYINT,
    IN p_anio INT
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    -- Validar parámetros
    IF p_semana IS NULL OR p_anio IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Parámetros semana y anio son requeridos';
    END IF;

    IF p_semana < 1 OR p_semana > 53 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Semana debe estar entre 1 y 53';
    END IF;

    -- Insertar o actualizar débitos por agencia
    INSERT INTO debitos (
        agencia,
        semana,
        anio,
        debito_miercoles,
        debito_jueves,
        debito_viernes,
        origen
    )
    SELECT
        d.agencia,
        p_semana as semana,
        p_anio as anio,
        SUM(CASE WHEN d.Dia_de_pago = 'MIERCOLES' THEN d.debito ELSE 0 END) AS debito_miercoles,
        SUM(CASE WHEN d.Dia_de_pago = 'JUEVES' THEN d.debito ELSE 0 END) AS debito_jueves,
        SUM(CASE WHEN d.Dia_de_pago = 'VIERNES' THEN d.debito ELSE 0 END) AS debito_viernes,
        'sp_automatico' as origen
    FROM vw_datos_cobranza d
    WHERE d.semana = p_semana
      AND d.anio = p_anio
    GROUP BY d.agencia
    ON DUPLICATE KEY UPDATE
        debito_miercoles = VALUES(debito_miercoles),
        debito_jueves = VALUES(debito_jueves),
        debito_viernes = VALUES(debito_viernes);

    -- Contar registros insertados/actualizados
    SET v_count = ROW_COUNT();

    -- Mensaje de resultado
    SELECT
        v_count as registros_afectados,
        p_semana as semana,
        p_anio as anio,
        'Débitos insertados/actualizados correctamente' as mensaje;

END$$

DELIMITER ;

-- =====================================================
-- Ejemplos de uso:
-- =====================================================

-- Insertar débitos de la semana 2 de 2026
-- CALL sp_insertar_debitos_agencias(2, 2026);

-- Insertar débitos de la semana 3 de 2026
-- CALL sp_insertar_debitos_agencias(3, 2026);

-- Insertar débitos de la semana actual
-- CALL sp_insertar_debitos_agencias(
--     (SELECT DISTINCT Semana FROM calendario WHERE CURDATE() BETWEEN Fecha_Inicio AND Fecha_Fin LIMIT 1),
--     YEAR(CURDATE())
-- );

-- =====================================================
-- Notas:
-- =====================================================
-- 1. El procedimiento usa ON DUPLICATE KEY UPDATE para actualizar
--    si ya existe un registro para esa agencia/semana/año
-- 2. Los débitos se calculan desde vw_datos_cobranza que usa prestamos_v2
-- 3. Solo incluye agencias con préstamos activos (Saldo > 0)
-- 4. created_at se establece automáticamente al insertar
-- 5. updated_at se actualiza automáticamente al hacer UPDATE
