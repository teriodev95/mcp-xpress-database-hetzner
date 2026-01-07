-- ============================================================================
-- CALCULAR LIQUIDACIÓN DE PRÉSTAMO
-- ============================================================================
-- Este script contiene:
-- 1. Una QUERY parametrizable para consultar liquidación de un préstamo
-- 2. Una FUNCIÓN almacenada que retorna el monto de liquidación
-- 3. Un PROCEDIMIENTO almacenado con información detallada
-- ============================================================================

-- ============================================================================
-- OPCIÓN 1: QUERY PARAMETRIZABLE
-- ============================================================================
-- Reemplazar 'PRESTAMO_ID_AQUI' con el PrestamoID deseado
-- Ejemplo: ' L-1505-pl'

SELECT
    datos.PrestamoID,
    datos.Nombres,
    datos.Apellido_Paterno,
    datos.Apellido_Materno,
    datos.Monto_otorgado,
    datos.Total_a_pagar,
    datos.plazo,
    datos.Tipo_de_Cliente,
    datos.Saldo,
    datos.semana_inicio,
    datos.anio_inicio,
    datos.semana_actual,
    datos.anio_actual,
    datos.semanas_transcurridas,
    CASE
        WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
        WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
        WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
        WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
        WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
        WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
        WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
        WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
        WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
        WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
        WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
        WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
        WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
        WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
        WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
        WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
        WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
        WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
        WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
        WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
        WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
        WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
        WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
        WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
        WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
        ELSE 0
    END as porcentaje_descuento,
    ROUND(datos.Saldo * CASE
        WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
        WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
        WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
        WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
        WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
        WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
        WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
        WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
        WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
        WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
        WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
        WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
        WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
        WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
        WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
        WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
        WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
        WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
        WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
        WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
        WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
        WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
        WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
        WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
        WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
        ELSE 0
    END / 100, 2) as monto_descuento,
    ROUND(datos.Saldo - (datos.Saldo * CASE
        WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
        WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
        WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
        WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
        WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
        WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
        WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
        WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
        WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
        WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
        WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
        WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
        WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
        WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
        WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
        WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
        WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
        WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
        WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
        WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
        WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
        WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
        WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
        WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
        WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
        ELSE 0
    END / 100), 2) as monto_liquidacion
FROM (
    SELECT
        p.PrestamoID,
        p.Nombres,
        p.Apellido_Paterno,
        p.Apellido_Materno,
        p.Monto_otorgado,
        p.Total_a_pagar,
        p.plazo,
        p.Tipo_de_Cliente,
        p.Anio,
        p.Semana as semana_inicio,
        p.Anio as anio_inicio,
        p.Saldo,
        c_actual.semana as semana_actual,
        c_actual.anio as anio_actual,
        (
            SELECT COUNT(*)
            FROM calendario c
            WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
              AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
        ) as semanas_transcurridas,
        CONCAT(p.Monto_otorgado, '-a_', p.plazo, '_sem.-', p.Tipo_de_Cliente, '_', p.Anio) as id_porcentaje
    FROM prestamos_v2 p,
         (SELECT semana, anio FROM calendario
          WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta) c_actual
    WHERE p.PrestamoID = 'PRESTAMO_ID_AQUI'  -- <-- REEMPLAZAR AQUÍ
) datos
LEFT JOIN porcentajes_descuento_liquidaciones pdl ON pdl.id = datos.id_porcentaje;


-- ============================================================================
-- OPCIÓN 2: FUNCIÓN ALMACENADA - fn_obtener_liquidacion
-- ============================================================================
-- Retorna solo el monto de liquidación para un préstamo dado
-- Uso: SELECT fn_obtener_liquidacion('L-1505-pl');

DELIMITER //

DROP FUNCTION IF EXISTS fn_obtener_liquidacion //

CREATE FUNCTION fn_obtener_liquidacion(p_prestamo_id VARCHAR(32))
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_saldo DECIMAL(10,2);
    DECLARE v_monto_otorgado INT;
    DECLARE v_plazo INT;
    DECLARE v_tipo_cliente VARCHAR(16);
    DECLARE v_anio_prestamo INT;
    DECLARE v_semana_prestamo INT;
    DECLARE v_semana_actual INT;
    DECLARE v_anio_actual INT;
    DECLARE v_semanas_transcurridas INT;
    DECLARE v_id_porcentaje VARCHAR(64);
    DECLARE v_porcentaje INT DEFAULT 0;
    DECLARE v_monto_liquidacion DECIMAL(10,2);

    -- Obtener datos del préstamo
    SELECT Saldo, Monto_otorgado, plazo, Tipo_de_Cliente, Anio, Semana
    INTO v_saldo, v_monto_otorgado, v_plazo, v_tipo_cliente, v_anio_prestamo, v_semana_prestamo
    FROM prestamos_v2
    WHERE PrestamoID = p_prestamo_id;

    -- Si no existe el préstamo o saldo es 0, retornar NULL
    IF v_saldo IS NULL OR v_saldo <= 0 THEN
        RETURN NULL;
    END IF;

    -- Obtener semana y año actual
    SELECT semana, anio
    INTO v_semana_actual, v_anio_actual
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    -- Calcular semanas transcurridas
    SELECT COUNT(*)
    INTO v_semanas_transcurridas
    FROM calendario c
    WHERE (c.anio > v_anio_prestamo OR (c.anio = v_anio_prestamo AND c.semana >= v_semana_prestamo))
      AND (c.anio < v_anio_actual OR (c.anio = v_anio_actual AND c.semana <= v_semana_actual));

    -- Construir ID de porcentaje
    SET v_id_porcentaje = CONCAT(v_monto_otorgado, '-a_', v_plazo, '_sem.-', v_tipo_cliente, '_', v_anio_prestamo);

    -- Obtener porcentaje según semana transcurrida
    SELECT
        CASE
            WHEN v_semanas_transcurridas = 1 THEN semana1
            WHEN v_semanas_transcurridas = 2 THEN semana2
            WHEN v_semanas_transcurridas = 3 THEN semana3
            WHEN v_semanas_transcurridas = 4 THEN semana4
            WHEN v_semanas_transcurridas = 5 THEN semana5
            WHEN v_semanas_transcurridas = 6 THEN semana6
            WHEN v_semanas_transcurridas = 7 THEN semana7
            WHEN v_semanas_transcurridas = 8 THEN semana8
            WHEN v_semanas_transcurridas = 9 THEN semana9
            WHEN v_semanas_transcurridas = 10 THEN semana10
            WHEN v_semanas_transcurridas = 11 THEN semana11
            WHEN v_semanas_transcurridas = 12 THEN semana12
            WHEN v_semanas_transcurridas = 13 THEN semana13
            WHEN v_semanas_transcurridas = 14 THEN semana14
            WHEN v_semanas_transcurridas = 15 THEN semana15
            WHEN v_semanas_transcurridas = 16 THEN semana16
            WHEN v_semanas_transcurridas = 17 THEN semana17
            WHEN v_semanas_transcurridas = 18 THEN semana18
            WHEN v_semanas_transcurridas = 19 THEN semana19
            WHEN v_semanas_transcurridas = 20 THEN semana20
            WHEN v_semanas_transcurridas = 21 THEN semana21
            WHEN v_semanas_transcurridas = 22 THEN semana22
            WHEN v_semanas_transcurridas = 23 THEN semana23
            WHEN v_semanas_transcurridas = 24 THEN semana24
            WHEN v_semanas_transcurridas >= 25 THEN semana25
            ELSE 0
        END
    INTO v_porcentaje
    FROM porcentajes_descuento_liquidaciones
    WHERE id = v_id_porcentaje;

    -- Si no hay porcentaje definido, usar 0
    IF v_porcentaje IS NULL THEN
        SET v_porcentaje = 0;
    END IF;

    -- Calcular monto de liquidación
    SET v_monto_liquidacion = ROUND(v_saldo - (v_saldo * v_porcentaje / 100), 2);

    RETURN v_monto_liquidacion;
END //

DELIMITER ;


-- ============================================================================
-- OPCIÓN 3: PROCEDIMIENTO ALMACENADO - sp_calcular_liquidacion
-- ============================================================================
-- Retorna información completa de la liquidación
-- Uso: CALL sp_calcular_liquidacion('L-1505-pl');

DELIMITER //

DROP PROCEDURE IF EXISTS sp_calcular_liquidacion //

CREATE PROCEDURE sp_calcular_liquidacion(IN p_prestamo_id VARCHAR(32))
BEGIN
    SELECT
        datos.PrestamoID,
        datos.Nombres,
        datos.Apellido_Paterno,
        datos.Apellido_Materno,
        datos.Monto_otorgado,
        datos.Total_a_pagar,
        datos.plazo as plazo_semanas,
        datos.Tipo_de_Cliente,
        datos.Saldo as saldo_actual,
        datos.semana_inicio,
        datos.anio_inicio,
        datos.semana_actual,
        datos.anio_actual,
        datos.semanas_transcurridas,
        COALESCE(CASE
            WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
            WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
            WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
            WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
            WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
            WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
            WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
            WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
            WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
            WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
            WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
            WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
            WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
            WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
            WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
            WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
            WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
            WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
            WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
            WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
            WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
            WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
            WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
            WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
            WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
            ELSE 0
        END, 0) as porcentaje_descuento,
        ROUND(datos.Saldo * COALESCE(CASE
            WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
            WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
            WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
            WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
            WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
            WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
            WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
            WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
            WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
            WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
            WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
            WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
            WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
            WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
            WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
            WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
            WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
            WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
            WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
            WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
            WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
            WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
            WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
            WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
            WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
            ELSE 0
        END, 0) / 100, 2) as monto_descuento,
        ROUND(datos.Saldo - (datos.Saldo * COALESCE(CASE
            WHEN datos.semanas_transcurridas = 1 THEN pdl.semana1
            WHEN datos.semanas_transcurridas = 2 THEN pdl.semana2
            WHEN datos.semanas_transcurridas = 3 THEN pdl.semana3
            WHEN datos.semanas_transcurridas = 4 THEN pdl.semana4
            WHEN datos.semanas_transcurridas = 5 THEN pdl.semana5
            WHEN datos.semanas_transcurridas = 6 THEN pdl.semana6
            WHEN datos.semanas_transcurridas = 7 THEN pdl.semana7
            WHEN datos.semanas_transcurridas = 8 THEN pdl.semana8
            WHEN datos.semanas_transcurridas = 9 THEN pdl.semana9
            WHEN datos.semanas_transcurridas = 10 THEN pdl.semana10
            WHEN datos.semanas_transcurridas = 11 THEN pdl.semana11
            WHEN datos.semanas_transcurridas = 12 THEN pdl.semana12
            WHEN datos.semanas_transcurridas = 13 THEN pdl.semana13
            WHEN datos.semanas_transcurridas = 14 THEN pdl.semana14
            WHEN datos.semanas_transcurridas = 15 THEN pdl.semana15
            WHEN datos.semanas_transcurridas = 16 THEN pdl.semana16
            WHEN datos.semanas_transcurridas = 17 THEN pdl.semana17
            WHEN datos.semanas_transcurridas = 18 THEN pdl.semana18
            WHEN datos.semanas_transcurridas = 19 THEN pdl.semana19
            WHEN datos.semanas_transcurridas = 20 THEN pdl.semana20
            WHEN datos.semanas_transcurridas = 21 THEN pdl.semana21
            WHEN datos.semanas_transcurridas = 22 THEN pdl.semana22
            WHEN datos.semanas_transcurridas = 23 THEN pdl.semana23
            WHEN datos.semanas_transcurridas = 24 THEN pdl.semana24
            WHEN datos.semanas_transcurridas >= 25 THEN pdl.semana25
            ELSE 0
        END, 0) / 100), 2) as monto_liquidacion,
        CASE
            WHEN pdl.id IS NULL THEN 'No existe tabla de porcentajes para este préstamo'
            WHEN datos.semanas_transcurridas > datos.plazo THEN 'Préstamo vencido - sin descuento disponible'
            ELSE 'Liquidación disponible'
        END as estado
    FROM (
        SELECT
            p.PrestamoID,
            p.Nombres,
            p.Apellido_Paterno,
            p.Apellido_Materno,
            p.Monto_otorgado,
            p.Total_a_pagar,
            p.plazo,
            p.Tipo_de_Cliente,
            p.Anio,
            p.Semana as semana_inicio,
            p.Anio as anio_inicio,
            p.Saldo,
            c_actual.semana as semana_actual,
            c_actual.anio as anio_actual,
            (
                SELECT COUNT(*)
                FROM calendario c
                WHERE (c.anio > p.Anio OR (c.anio = p.Anio AND c.semana >= p.Semana))
                  AND (c.anio < c_actual.anio OR (c.anio = c_actual.anio AND c.semana <= c_actual.semana))
            ) as semanas_transcurridas,
            CONCAT(p.Monto_otorgado, '-a_', p.plazo, '_sem.-', p.Tipo_de_Cliente, '_', p.Anio) as id_porcentaje
        FROM prestamos_v2 p,
             (SELECT semana, anio FROM calendario
              WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta) c_actual
        WHERE p.PrestamoID = p_prestamo_id
    ) datos
    LEFT JOIN porcentajes_descuento_liquidaciones pdl ON pdl.id = datos.id_porcentaje;
END //

DELIMITER ;


-- ============================================================================
-- EJEMPLOS DE USO
-- ============================================================================

-- Usando la función (retorna solo el monto):
-- SELECT fn_obtener_liquidacion(' L-1505-pl') as monto_liquidacion;

-- Usando el procedimiento (retorna información completa):
-- CALL sp_calcular_liquidacion(' L-1505-pl');

-- Consulta masiva de todos los préstamos con su liquidación:
-- SELECT PrestamoID, Saldo, fn_obtener_liquidacion(PrestamoID) as liquidacion
-- FROM prestamos_v2
-- WHERE Saldo > 0
-- LIMIT 100;
