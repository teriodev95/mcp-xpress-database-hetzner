-- ============================================================================
-- PROCEDIMIENTO: sp_liquidacion_especial
-- ============================================================================
-- Descripción: Registra una liquidación especial para préstamos morosos
--              Permite aplicar un descuento personalizado (hasta el máximo calculado)
-- ============================================================================
-- Parámetros:
--   p_prestamo_id    : ID del préstamo a liquidar
--   p_descuento      : Descuento a aplicar (debe ser <= Descuento_Disponible)
--   p_recuperado_por : Quién recuperó el pago ('agente', 'gerente', 'seguridad')
--   p_comentario     : Comentario/observaciones de la liquidación
-- ============================================================================

DELIMITER //

DROP PROCEDURE IF EXISTS sp_liquidacion_especial //

CREATE PROCEDURE sp_liquidacion_especial(
    IN p_prestamo_id VARCHAR(32),
    IN p_descuento DECIMAL(10, 2),
    IN p_recuperado_por ENUM ('agente', 'gerente', 'seguridad'),
    IN p_comentario TEXT
)
BEGIN
    DECLARE v_pago_id VARCHAR(64);
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_saldo DECIMAL(10, 2);
    DECLARE v_cobrado DECIMAL(10, 2);
    DECLARE v_monto_otorgado DECIMAL(10, 2);
    DECLARE v_tarifa DECIMAL(10, 2);
    DECLARE v_cliente TEXT;
    DECLARE v_identificador VARCHAR(32);
    DECLARE v_prestamo VARCHAR(32);
    DECLARE v_agente VARCHAR(32);
    DECLARE v_sem_entrega INT;
    DECLARE v_anio_entrega INT;
    DECLARE v_sem_transcurridas INT;

    -- Variables para cálculos de liquidación especial
    DECLARE v_comision_cobranza DECIMAL(10, 2);
    DECLARE v_comision_venta DECIMAL(10, 2) DEFAULT 100.00;
    DECLARE v_comision_total DECIMAL(10, 2);
    DECLARE v_por_recuperar DECIMAL(10, 2);
    DECLARE v_faltante_monto DECIMAL(10, 2);
    DECLARE v_descuento_disponible DECIMAL(10, 2);
    DECLARE v_liquida_con DECIMAL(10, 2);
    DECLARE v_descuento_porcentaje DECIMAL(5, 2);

    -- Validar préstamo existe
    IF NOT EXISTS (SELECT 1 FROM prestamos_v2 WHERE PrestamoID = p_prestamo_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo no encontrado';
    END IF;

    -- Obtener semana actual
    SELECT semana, anio
    INTO v_semana, v_anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- Obtener datos del préstamo
    SELECT
        PrestamoID,
        Identificador_Credito,
        Tarifa,
        Agente,
        CONCAT(Nombres, ' ', Apellido_Paterno, ' ', COALESCE(Apellido_Materno, '')),
        Semana,
        Anio,
        Saldo,
        Cobrado,
        Monto_otorgado
    INTO
        v_prestamo, v_identificador, v_tarifa, v_agente,
        v_cliente, v_sem_entrega, v_anio_entrega,
        v_saldo, v_cobrado, v_monto_otorgado
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    -- Validar que hay saldo
    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Préstamo ya liquidado o sin saldo';
    END IF;

    -- Calcular comisiones
    SET v_comision_cobranza = ROUND(v_cobrado * 0.10, 2);
    SET v_comision_total = v_comision_cobranza + v_comision_venta;

    -- Calcular Por_Recuperar: Monto otorgado + Comisión Cobranza + Comisión Venta
    -- Es lo mínimo que se debe recuperar para no perder
    SET v_por_recuperar = ROUND(v_monto_otorgado + v_comision_cobranza + v_comision_venta, 2);

    -- Calcular faltante: diferencia entre Por_Recuperar y lo Cobrado
    SET v_faltante_monto = GREATEST(v_por_recuperar - v_cobrado, 0);

    -- Calcular descuento disponible
    -- Si RECUPERADO (Cobrado >= Por_Recuperar): Saldo / 2
    -- Si PENDIENTE: Saldo - Faltante
    IF v_cobrado >= v_por_recuperar THEN
        SET v_descuento_disponible = ROUND(v_saldo / 2, 2);
    ELSE
        SET v_descuento_disponible = GREATEST(v_saldo - v_faltante_monto, 0);
    END IF;

    -- Validar que el descuento solicitado no exceda el disponible
    IF p_descuento > v_descuento_disponible THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Descuento excede el disponible. Disponible: ', v_descuento_disponible);
    END IF;

    -- Validar que el descuento no sea negativo
    IF p_descuento < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El descuento no puede ser negativo';
    END IF;

    -- Calcular monto de liquidación
    SET v_liquida_con = v_saldo - p_descuento;

    -- Calcular porcentaje de descuento
    SET v_descuento_porcentaje = ROUND((p_descuento / v_saldo) * 100, 2);

    -- Calcular semanas transcurridas
    SELECT COUNT(*)
    INTO v_sem_transcurridas
    FROM calendario c
    WHERE (c.anio > v_anio_entrega OR (c.anio = v_anio_entrega AND c.semana > v_sem_entrega))
      AND (c.anio < v_anio OR (c.anio = v_anio AND c.semana <= v_semana));

    -- Generar PagoID único para liquidación especial
    SET v_pago_id = CONCAT('LIQESP-', p_prestamo_id, '-', v_anio, '-', v_semana, '-',
                           UNIX_TIMESTAMP(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')));

    -- Insertar en pagos_v3
    INSERT INTO pagos_v3 (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio,
        EsPrimerPago, AbreCon, CierraCon, Tarifa, Cliente, Agente,
        Tipo, Creado_desde, Identificador, Fecha_pago,
        Comentario, quien_pago, recuperado_por
    )
    VALUES (
        v_pago_id, p_prestamo_id, v_prestamo, v_liquida_con, v_semana, v_anio,
        0, v_saldo, 0, v_tarifa, v_cliente, v_agente,
        'Liquidacion', 'PGS', v_identificador,
        CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
        CONCAT('LIQUIDACIÓN ESPECIAL - ', COALESCE(p_comentario, '')),
        'Cliente', p_recuperado_por
    );

    -- Insertar en liquidaciones
    INSERT INTO liquidaciones (
        prestamoID, pagoID, anio, semana,
        descuento_en_dinero, descuento_en_porcentaje,
        liquido_con, sem_transcurridas
    )
    VALUES (
        p_prestamo_id, v_pago_id, v_anio, v_semana,
        p_descuento, v_descuento_porcentaje,
        v_liquida_con, v_sem_transcurridas
    );

    -- Retornar resumen completo
    SELECT
        p_prestamo_id           AS prestamo_id,
        v_cliente               AS cliente,
        v_agente                AS agente,
        v_monto_otorgado        AS monto_otorgado,
        v_cobrado               AS cobrado_previo,
        v_saldo                 AS saldo_anterior,
        v_comision_cobranza     AS comision_cobranza,
        v_comision_venta        AS comision_venta,
        v_comision_total        AS comision_total,
        v_faltante_monto        AS faltante_monto_otorgado,
        v_descuento_disponible  AS descuento_disponible,
        p_descuento             AS descuento_aplicado,
        v_descuento_porcentaje  AS descuento_porcentaje,
        v_liquida_con           AS monto_liquidado,
        v_sem_transcurridas     AS semanas_transcurridas,
        v_pago_id               AS pago_id,
        v_semana                AS semana_liquidacion,
        v_anio                  AS anio_liquidacion,
        'OK'                    AS estado,
        'Liquidación especial registrada correctamente' AS mensaje;

END //

DELIMITER ;


-- ============================================================================
-- FUNCIÓN: fn_preview_liquidacion_especial
-- ============================================================================
-- Descripción: Muestra una vista previa de la liquidación especial sin ejecutarla
--              Útil para mostrar al usuario los datos antes de confirmar
-- ============================================================================

DELIMITER //

DROP FUNCTION IF EXISTS fn_preview_liquidacion_especial //

-- Nota: Las funciones no pueden retornar múltiples columnas,
-- por lo que usamos un procedimiento para la vista previa

DROP PROCEDURE IF EXISTS sp_preview_liquidacion_especial //

CREATE PROCEDURE sp_preview_liquidacion_especial(
    IN p_prestamo_id VARCHAR(32),
    IN p_descuento_propuesto DECIMAL(10, 2)
)
BEGIN
    DECLARE v_semana INT;
    DECLARE v_anio INT;

    -- Obtener semana actual
    SELECT semana, anio
    INTO v_semana, v_anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    SELECT
        p.PrestamoID,
        CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS Cliente,
        p.Gerencia,
        p.Agente,
        p.Semana AS Semana_Inicio,
        p.Anio AS Anio_Inicio,
        p.plazo AS Plazo_Semanas,
        ((v_semana + (v_anio * 52)) - (p.Semana + (p.Anio * 52))) AS Semanas_Transcurridas,
        p.Monto_otorgado,
        p.Total_a_pagar,
        p.Tarifa,
        p.Cobrado,
        p.Saldo,

        -- Comisiones
        ROUND(p.Cobrado * 0.10, 2) AS Comision_Cobranza,
        100.00 AS Comision_Venta,
        ROUND((p.Cobrado * 0.10) + 100, 2) AS Comision_Total,

        -- Por Recuperar: Monto otorgado + Comisión Cobranza + Comisión Venta
        ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) AS Por_Recuperar,

        -- Faltante: diferencia entre Por_Recuperar y Cobrado
        GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0) AS Faltante,

        -- Descuento disponible: Saldo/2 si RECUPERADO, Saldo-Faltante si PENDIENTE
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
            ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
        END AS Descuento_Disponible,

        -- Descuento propuesto y validación
        p_descuento_propuesto AS Descuento_Propuesto,
        CASE
            WHEN p_descuento_propuesto > (
                CASE
                    WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
                    ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
                END
            ) THEN 'EXCEDE MÁXIMO'
            WHEN p_descuento_propuesto < 0 THEN 'NEGATIVO NO PERMITIDO'
            ELSE 'VÁLIDO'
        END AS Descuento_Status,

        -- Monto a liquidar
        (p.Saldo - LEAST(
            p_descuento_propuesto,
            CASE
                WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
                ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
            END
        )) AS Monto_A_Liquidar,

        -- Porcentaje de descuento
        ROUND((LEAST(
            p_descuento_propuesto,
            CASE
                WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN ROUND(p.Saldo / 2, 2)
                ELSE GREATEST(p.Saldo - GREATEST(ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) - p.Cobrado, 0), 0)
            END
        ) / p.Saldo) * 100, 2) AS Descuento_Porcentaje,

        -- Status de recuperación basado en Por_Recuperar
        CASE
            WHEN p.Cobrado >= ROUND(p.Monto_otorgado + (p.Cobrado * 0.10) + 100, 2) THEN 'RECUPERADO'
            ELSE 'PENDIENTE'
        END AS Status_Recuperacion

    FROM prestamos_v2 p
    WHERE p.PrestamoID = p_prestamo_id;

END //

DELIMITER ;


-- ============================================================================
-- EJEMPLO DE USO
-- ============================================================================
/*
-- 1. Primero obtener datos del préstamo y verificar descuento máximo:
CALL sp_preview_liquidacion_especial('D-2395-ef', 5000.00);

-- 2. Si el descuento es válido, ejecutar la liquidación:
CALL sp_liquidacion_especial(
    'D-2395-ef',           -- prestamo_id
    5000.00,               -- descuento a aplicar
    'gerente',             -- recuperado_por
    'Liquidación especial por mora prolongada - cliente sin pagar 5 semanas'
);

-- 3. Para aplicar el descuento máximo permitido:
-- Primero consultar el descuento máximo con la query de liquidaciones especiales
-- y luego usar ese valor en el procedimiento
*/
