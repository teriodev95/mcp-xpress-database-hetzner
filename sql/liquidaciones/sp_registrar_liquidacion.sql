-- ============================================================================
-- PROCEDIMIENTO: sp_registrar_liquidacion
-- ============================================================================
-- Registra una liquidación anticipada de préstamo.
-- Inserta en pagos_v3 (tipo='Liquidacion') y en liquidaciones.
--
-- Uso: CALL sp_registrar_liquidacion('N-2199-pl', 'AGE001', 'agente', 'Cliente pagó en efectivo');
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_registrar_liquidacion //

CREATE PROCEDURE sp_registrar_liquidacion(
    IN p_prestamo_id VARCHAR(32),
    IN p_recuperado_por ENUM('agente', 'gerente', 'seguridad'),
    IN p_comentario TEXT
)
BEGIN
    DECLARE v_pago_id VARCHAR(64);
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_saldo DECIMAL(10,2);
    DECLARE v_tarifa DECIMAL(10,2);
    DECLARE v_cliente TEXT;
    DECLARE v_identificador VARCHAR(32);
    DECLARE v_prestamo VARCHAR(32);
    DECLARE v_agente VARCHAR(32);
    DECLARE v_sem_entrega INT;
    DECLARE v_anio_entrega INT;
    DECLARE v_plazo INT;
    DECLARE v_tipo_cliente VARCHAR(32);
    DECLARE v_sem_transcurridas INT;
    DECLARE v_porcentaje DECIMAL(5,2);
    DECLARE v_descuento_dinero DECIMAL(10,2);
    DECLARE v_liquida_con DECIMAL(10,2);

    -- Validar préstamo existe
    IF NOT EXISTS (SELECT 1 FROM prestamos_v2 WHERE PrestamoID = p_prestamo_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo no encontrado';
    END IF;

    -- Obtener semana actual
    SELECT semana, anio INTO v_semana, v_anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- Obtener datos del préstamo
    SELECT
        Prestamo, Identificador_Credito, Tarifa, Agente,
        CONCAT(Nombres, ' ', Apellido_Paterno, ' ', COALESCE(Apellido_Materno, '')),
        Semana, Anio, plazo, Tipo_de_Cliente
    INTO
        v_prestamo, v_identificador, v_tarifa, v_agente,
        v_cliente, v_sem_entrega, v_anio_entrega, v_plazo, v_tipo_cliente
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    -- Obtener saldo actual de prestamos_dynamic
    SELECT saldo INTO v_saldo
    FROM prestamos_dynamic
    WHERE prestamo_id = p_prestamo_id;

    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo ya liquidado o sin saldo';
    END IF;

    -- Calcular semanas transcurridas
    SELECT COUNT(*) INTO v_sem_transcurridas
    FROM calendario c
    WHERE (c.anio > v_anio_entrega OR (c.anio = v_anio_entrega AND c.semana > v_sem_entrega))
      AND (c.anio < v_anio OR (c.anio = v_anio AND c.semana <= v_semana));

    -- Obtener porcentaje de descuento
    SELECT COALESCE(porcentaje, 0) INTO v_porcentaje
    FROM porcentajes_liquidacion_v2
    WHERE plazo = v_plazo
      AND tipo_cliente = v_tipo_cliente
      AND semana = LEAST(v_sem_transcurridas, v_plazo)
    LIMIT 1;

    IF v_porcentaje IS NULL THEN
        SET v_porcentaje = 0;
    END IF;

    -- Calcular liquidación
    SET v_descuento_dinero = ROUND(v_saldo * v_porcentaje / 100, 2);
    SET v_liquida_con = ROUND(v_saldo - v_descuento_dinero, 2);

    -- Generar PagoID
    SET v_pago_id = CONCAT('LIQ-', p_prestamo_id, '-', v_anio, '-', v_semana);

    -- Insertar en pagos_v3
    INSERT INTO pagos_v3 (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio,
        EsPrimerPago, AbreCon, CierraCon, Tarifa, Cliente, Agente,
        Tipo, Creado_desde, Identificador, Fecha_pago,
        Comentario, quien_pago, recuperado_por
    ) VALUES (
        v_pago_id, p_prestamo_id, v_prestamo, v_liquida_con, v_semana, v_anio,
        0, v_saldo, 0, v_tarifa, v_cliente, v_agente,
        'Liquidacion', 'PGS', v_identificador, CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
        p_comentario, 'Cliente', p_recuperado_por
    );

    -- Insertar en liquidaciones
    INSERT INTO liquidaciones (
        prestamoID, pagoID, anio, semana,
        descuento_en_dinero, descuento_en_porcentaje, liquido_con, sem_transcurridas
    ) VALUES (
        p_prestamo_id, v_pago_id, v_anio, v_semana,
        v_descuento_dinero, v_porcentaje, v_liquida_con, v_sem_transcurridas
    );

    -- Retornar resumen
    SELECT
        p_prestamo_id AS prestamo,
        v_saldo AS saldo_anterior,
        v_sem_transcurridas AS semanas_transcurridas,
        v_porcentaje AS descuento_porcentaje,
        v_descuento_dinero AS descuento_dinero,
        v_liquida_con AS monto_liquidado,
        v_pago_id AS pago_id,
        'OK' AS estado;

END //

-- ============================================================================
-- PROCEDIMIENTO: sp_eliminar_liquidacion
-- ============================================================================
-- Elimina una liquidación y su pago asociado.
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_eliminar_liquidacion //

CREATE PROCEDURE sp_eliminar_liquidacion(IN p_liquidacion_id INT)
BEGIN
    DECLARE v_pago_id VARCHAR(64);
    DECLARE v_prestamo_id VARCHAR(32);

    -- Buscar liquidación
    SELECT pagoID, prestamoID INTO v_pago_id, v_prestamo_id
    FROM liquidaciones
    WHERE liquidacionID = p_liquidacion_id;

    IF v_pago_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Liquidación no encontrada';
    END IF;

    -- Eliminar de liquidaciones
    DELETE FROM liquidaciones WHERE liquidacionID = p_liquidacion_id;

    -- Eliminar de pagos_v3
    DELETE FROM pagos_v3 WHERE PagoID = v_pago_id;

    -- Confirmar
    SELECT
        v_prestamo_id AS prestamo,
        p_liquidacion_id AS liquidacion_eliminada,
        v_pago_id AS pago_eliminado,
        'ELIMINADO' AS estado;

END //

DELIMITER ;

-- ============================================================================
-- EJEMPLOS DE USO
-- ============================================================================
-- Registrar:
-- CALL sp_registrar_liquidacion('N-2199-pl', 'agente', 'Liquidación anticipada');
--
-- Eliminar (por ID de liquidación):
-- CALL sp_eliminar_liquidacion(15);
