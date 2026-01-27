-- =====================================================
-- Script: Agregar campo clientes a debitos_historial
-- Descripción: Agrega el campo clientes que no cambia durante la semana
-- =====================================================

-- Agregar columna clientes
ALTER TABLE debitos_historial
ADD COLUMN clientes SMALLINT NOT NULL DEFAULT 0 AFTER anio;

-- =====================================================
-- Actualizar SP para incluir clientes
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
    INSERT INTO debitos_historial (
        agencia,
        semana,
        anio,
        clientes,
        debito_miercoles,
        debito_jueves,
        debito_viernes,
        origen
    )
    SELECT
        d.agencia,
        p_semana as semana,
        p_anio as anio,
        COUNT(d.prestamo_id) as clientes,
        SUM(CASE WHEN d.Dia_de_pago = 'MIERCOLES' THEN d.debito ELSE 0 END) AS debito_miercoles,
        SUM(CASE WHEN d.Dia_de_pago = 'JUEVES' THEN d.debito ELSE 0 END) AS debito_jueves,
        SUM(CASE WHEN d.Dia_de_pago = 'VIERNES' THEN d.debito ELSE 0 END) AS debito_viernes,
        'sp_automatico' as origen
    FROM vw_datos_cobranza d
    WHERE d.semana = p_semana
      AND d.anio = p_anio
    GROUP BY d.agencia
    ON DUPLICATE KEY UPDATE
        clientes = VALUES(clientes),
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
-- Llenar datos históricos (si ya tienes registros)
-- =====================================================

/*
-- Actualizar registros existentes con el conteo de clientes
UPDATE debitos_historial d
INNER JOIN (
    SELECT
        agencia,
        semana,
        anio,
        COUNT(prestamo_id) as total_clientes
    FROM vw_datos_cobranza
    GROUP BY agencia, semana, anio
) vc ON d.agencia = vc.agencia AND d.semana = vc.semana AND d.anio = vc.anio
SET d.clientes = vc.total_clientes;
*/
