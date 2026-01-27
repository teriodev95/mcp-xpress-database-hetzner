-- ============================================================================
-- PROCEDIMIENTO: sp_registrar_liquidacion_especial
-- ============================================================================
-- Descripción: Registra una liquidación especial en la base de datos
--              Solo inserta registros - la lógica de cálculo está en Java
-- ============================================================================
-- Parámetros:
--   p_prestamo_id          : ID del préstamo
--   p_descuento_dinero     : Monto del descuento aplicado
--   p_descuento_porcentaje : Porcentaje del descuento
--   p_liquida_con          : Monto con el que se liquida
--   p_sem_transcurridas    : Semanas transcurridas desde inicio
--   p_recuperado_por       : Quién recuperó ('agente', 'gerente', 'seguridad')
--   p_status_recuperacion  : 'RECUPERADO' o 'PENDIENTE'
--   p_comentario           : Comentario/observaciones
-- ============================================================================

DELIMITER //

CREATE PROCEDURE sp_registrar_liquidacion_especial(
    IN p_prestamo_id VARCHAR(32),
    IN p_descuento_dinero DECIMAL(10, 2),
    IN p_descuento_porcentaje DECIMAL(5, 2),
    IN p_liquida_con DECIMAL(10, 2),
    IN p_sem_transcurridas INT,
    IN p_recuperado_por ENUM ('agente', 'gerente', 'seguridad'),
    IN p_status_recuperacion VARCHAR(20),
    IN p_comentario TEXT
)
BEGIN
    DECLARE v_pago_id VARCHAR(64);
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_saldo DECIMAL(10, 2);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_cliente TEXT;
    DECLARE v_identificador VARCHAR(32);
    DECLARE v_prestamo VARCHAR(32);
    DECLARE v_agente VARCHAR(32);

    -- Validar préstamo existe
    IF NOT EXISTS (SELECT 1 FROM prestamos_v2 WHERE PrestamoID = p_prestamo_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo no encontrado';
    END IF;

    -- Obtener semana actual
    SELECT semana, anio
    INTO v_semana, v_anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN DATE(desde) AND DATE(hasta)
    LIMIT 1;

    -- Obtener datos del préstamo necesarios para pagos_v3
    SELECT PrestamoID,
           Identificador_Credito,
           Tarifa,
           Agente,
           CONCAT(Nombres, ' ', Apellido_Paterno, ' ', COALESCE(Apellido_Materno, ''))
    INTO v_prestamo, v_identificador, v_tarifa, v_agente, v_cliente
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    -- Obtener saldo actual de prestamos_dynamic
    SELECT saldo
    INTO v_saldo
    FROM prestamos_dynamic
    WHERE prestamo_id = p_prestamo_id;

    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo ya liquidado o sin saldo';
    END IF;

    -- Generar PagoID único
    SET v_pago_id = CONCAT('LIQESP-', p_prestamo_id, '-', v_anio, '-', v_semana);

    -- Insertar en pagos_v3
    INSERT INTO pagos_v3 (PagoID, PrestamoID, Prestamo, Monto, Semana, Anio,
                          EsPrimerPago, AbreCon, CierraCon, Tarifa, Cliente, Agente,
                          Tipo, Creado_desde, Identificador, Fecha_pago,
                          Comentario, quien_pago, recuperado_por)
    VALUES (v_pago_id, p_prestamo_id, v_prestamo, p_liquida_con, v_semana, v_anio,
            0, v_saldo, 0, v_tarifa, v_cliente, v_agente,
            'Liquidacion', 'LIQESP', v_identificador,
            CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
            CONCAT('[ESPECIAL-', p_status_recuperacion, '] ', COALESCE(p_comentario, '')),
            'Cliente', p_recuperado_por);

    -- Insertar en liquidaciones con tipo ESPECIAL
    INSERT INTO liquidaciones (prestamoID, pagoID, anio, semana,
                               descuento_en_dinero, descuento_en_porcentaje,
                               liquido_con, tipo, sem_transcurridas)
    VALUES (p_prestamo_id, v_pago_id, v_anio, v_semana,
            p_descuento_dinero, p_descuento_porcentaje,
            p_liquida_con, 'ESPECIAL', p_sem_transcurridas);

    -- Retornar confirmación
    SELECT p_prestamo_id AS prestamo,
           v_saldo       AS saldo_anterior,
           p_liquida_con AS monto_liquidado,
           v_pago_id     AS pago_id,
           v_semana      AS semana,
           v_anio        AS anio,
           'OK'          AS estado;

END //

DELIMITER ;


-- ============================================================================
-- EJEMPLO DE USO DESDE JAVA
-- ============================================================================
/*
// En tu clase Java, después de obtener los datos con LiquidacionEspecialService:

LiquidacionEspecial info = service.obtenerLiquidacionEspecial(prestamoId).orElseThrow();

// Calcular el descuento a aplicar (ejemplo: 30% del disponible)
double descuentoAplicar = info.getDescuentoDisponible() * 0.30;
double liquidaCon = info.getSaldo() - descuentoAplicar;
double porcentaje = (descuentoAplicar / info.getSaldo()) * 100;

// Llamar al SP
CallableStatement cs = conn.prepareCall("{CALL sp_registrar_liquidacion_especial(?, ?, ?, ?, ?, ?, ?, ?)}");
cs.setString(1, prestamoId);                          // p_prestamo_id
cs.setDouble(2, descuentoAplicar);                    // p_descuento_dinero
cs.setDouble(3, porcentaje);                          // p_descuento_porcentaje
cs.setDouble(4, liquidaCon);                          // p_liquida_con
cs.setInt(5, info.getSemanasTranscurridas());         // p_sem_transcurridas
cs.setString(6, "gerente");                           // p_recuperado_por
cs.setString(7, info.getStatusRecuperacion());        // p_status_recuperacion
cs.setString(8, "Cliente contactado por cobranza");   // p_comentario
cs.execute();
*/
