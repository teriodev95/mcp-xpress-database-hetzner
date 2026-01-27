-- =====================================================
-- Procedimiento: sp_insertar_multa
-- Descripción: Inserta una multa DIRECTAMENTE en tabla multas
--              Evita pasar por pagos_v3
-- Uso: CALL sp_insertar_multa(params...)
-- =====================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_insertar_multa$$

CREATE PROCEDURE sp_insertar_multa(
    IN p_prestamo_id VARCHAR(32),
    IN p_monto DECIMAL(10,2),
    IN p_semana TINYINT,
    IN p_anio INT,
    IN p_agencia VARCHAR(32),
    IN p_fecha_multa DATETIME,
    OUT p_multa_id VARCHAR(36)
)
BEGIN
    DECLARE v_multa_id VARCHAR(36);

    -- Generar UUID para la multa
    SET v_multa_id = UUID();

    -- Insertar directamente en tabla multas (sin pasar por pagos_v3)
    INSERT INTO multas (
        multa_id,
        prestamo_id,
        monto,
        semana,
        anio,
        agencia,
        fecha_multa,
        created_at
    )
    VALUES (
        v_multa_id,
        p_prestamo_id,
        p_monto,
        p_semana,
        p_anio,
        p_agencia,
        COALESCE(p_fecha_multa, CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')),
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
    );

    -- Retornar el ID generado
    SET p_multa_id = v_multa_id;

    SELECT v_multa_id as multa_id, 'Multa insertada exitosamente' as mensaje;
END$$

DELIMITER ;

-- =====================================================
-- Ejemplo de uso:
-- =====================================================
-- CALL sp_insertar_multa(
--     '2924-pl',              -- prestamo_id
--     50.00,                  -- monto
--     3,                      -- semana
--     2026,                   -- anio
--     'AGP011',               -- agencia
--     NOW(),                  -- fecha_multa
--     @multa_id               -- OUT: ID generado
-- );
-- SELECT @multa_id;
-- =====================================================
