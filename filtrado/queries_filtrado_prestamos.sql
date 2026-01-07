-- =====================================================
-- Queries de Filtrado de Préstamos
-- =====================================================
-- Criterios de filtrado:
-- 1. Saldo < 2 tarifas (Saldo < Tarifa * 2)
-- 2. Plazo sin exceder (aún está dentro del plazo)
-- 3. Sin "No_pago" (cuenta de Tipo = 'No_pago' en pagos_v3 = 0)
-- =====================================================

-- =====================================================
-- 1. QUERY PARA UN PRÉSTAMO ESPECÍFICO (Por PrestamoID)
-- =====================================================
-- Retorna si el préstamo cumple con los criterios de filtrado

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana AS semana_inicio,
    p.Anio AS anio_inicio,
    p.plazo,
    p.Tarifa,
    pd.saldo AS saldo_actual,
    pd.cobrado AS cobrado_actual,

    -- Cálculos
    (p.Tarifa * 2) AS dos_tarifas,
    (pd.saldo < p.Tarifa * 2) AS cumple_saldo_menor_dos_tarifas,

    -- Calcular semanas transcurridas desde el inicio del préstamo
    DATEDIFF(CURDATE(),
        (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
    ) / 7 AS semanas_transcurridas,

    (DATEDIFF(CURDATE(),
        (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
    ) / 7 <= p.plazo) AS cumple_dentro_plazo,

    -- Contar "No_pago" en pagos_v3
    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') AS total_no_pagos,
    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0 AS cumple_sin_no_pagos,

    -- Resultado final
    CASE
        WHEN (pd.saldo < p.Tarifa * 2)
            AND (DATEDIFF(CURDATE(),
                (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
            ) / 7 <= p.plazo)
            AND (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado_filtro,

    'ACTIVO' AS tipo_prestamo

FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE p.PrestamoID = 'ID_DEL_PRESTAMO'  -- Reemplazar con el PrestamoID a buscar

UNION ALL

-- Buscar también en préstamos completados
SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana AS semana_inicio,
    p.Anio AS anio_inicio,
    p.plazo,
    p.Tarifa,
    p.Saldo AS saldo_actual,
    p.Cobrado AS cobrado_actual,

    -- Cálculos
    (p.Tarifa * 2) AS dos_tarifas,
    (p.Saldo < p.Tarifa * 2) AS cumple_saldo_menor_dos_tarifas,

    -- Calcular semanas transcurridas
    DATEDIFF(CURDATE(),
        (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
    ) / 7 AS semanas_transcurridas,

    (DATEDIFF(CURDATE(),
        (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
    ) / 7 <= p.plazo) AS cumple_dentro_plazo,

    -- Contar "No_pago"
    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') AS total_no_pagos,
    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0 AS cumple_sin_no_pagos,

    -- Resultado final
    CASE
        WHEN (p.Saldo < p.Tarifa * 2)
            AND (DATEDIFF(CURDATE(),
                (SELECT desde FROM calendario WHERE semana = p.Semana AND anio = p.Anio LIMIT 1)
            ) / 7 <= p.plazo)
            AND (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado_filtro,

    'COMPLETADO' AS tipo_prestamo

FROM prestamos_completados p
WHERE p.PrestamoID = 'ID_DEL_PRESTAMO';  -- Reemplazar con el PrestamoID a buscar


-- =====================================================
-- 2. QUERY SIMPLIFICADA (Sin calendario, usando conteo de semanas)
-- =====================================================
-- Versión más simple si no tienes acceso a la tabla calendario

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    pd.saldo,
    pd.cobrado,

    -- Criterios
    (pd.saldo < p.Tarifa * 2) AS saldo_menor_dos_tarifas,

    -- Calcular semanas transcurridas (aproximado: año y semana actual - año y semana inicio)
    ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) AS semanas_aprox,
    (((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo) AS dentro_plazo,

    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') AS no_pagos,
    ((SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0) AS sin_no_pagos,

    -- Resultado
    CASE
        WHEN (pd.saldo < p.Tarifa * 2)
            AND (((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo)
            AND ((SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') = 0)
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado

FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE p.PrestamoID = 'ID_DEL_PRESTAMO';


-- =====================================================
-- 3. QUERY PARA MÚLTIPLES PRÉSTAMOS (Filtrar todos los activos)
-- =====================================================
-- Retorna todos los préstamos activos que cumplen los criterios

SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    pd.saldo,
    pd.cobrado,
    (pd.saldo / p.Tarifa) AS tarifas_restantes,

    -- Semanas transcurridas
    ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) AS semanas_transcurridas,

    -- Total de no pagos
    (SELECT COUNT(*) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID AND Tipo = 'No_pago') AS no_pagos

FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE
    -- Criterio 1: Saldo menor a 2 tarifas
    pd.saldo < (p.Tarifa * 2)

    -- Criterio 2: Dentro del plazo
    AND ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo

    -- Criterio 3: Sin "No_pago"
    AND NOT EXISTS (
        SELECT 1 FROM pagos_v3
        WHERE PrestamoID = p.PrestamoID
        AND Tipo = 'No_pago'
    )

ORDER BY p.Gerencia, p.Agente;


-- =====================================================
-- 4. QUERY CON RESUMEN POR GERENCIA
-- =====================================================
-- Cuenta cuántos préstamos cumplen los criterios por gerencia

SELECT
    p.Gerencia,
    COUNT(*) AS total_cumplen_criterios,
    SUM(pd.saldo) AS saldo_total,
    AVG(pd.saldo) AS saldo_promedio,
    AVG(p.Tarifa) AS tarifa_promedio

FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE
    pd.saldo < (p.Tarifa * 2)
    AND ((YEAR(CURDATE()) - p.Anio) * 52 + (WEEK(CURDATE()) - p.Semana)) <= p.plazo
    AND NOT EXISTS (
        SELECT 1 FROM pagos_v3
        WHERE PrestamoID = p.PrestamoID
        AND Tipo = 'No_pago'
    )

GROUP BY p.Gerencia
ORDER BY total_cumplen_criterios DESC;


-- =====================================================
-- 5. FUNCIÓN PARA VERIFICAR UN PRÉSTAMO (Opción avanzada)
-- =====================================================

DELIMITER $$

DROP FUNCTION IF EXISTS `cumple_criterios_filtrado`$$

CREATE FUNCTION `cumple_criterios_filtrado`(p_prestamo_id VARCHAR(32))
RETURNS VARCHAR(10)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_cumple VARCHAR(10);
    DECLARE v_saldo DECIMAL(8,2);
    DECLARE v_tarifa DECIMAL(8,2);
    DECLARE v_plazo INT;
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_no_pagos INT;
    DECLARE v_semanas_transcurridas INT;

    -- Buscar en prestamos_v2
    SELECT
        pd.saldo, p.Tarifa, p.plazo, p.Semana, p.Anio
    INTO
        v_saldo, v_tarifa, v_plazo, v_semana, v_anio
    FROM prestamos_v2 p
    INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
    WHERE p.PrestamoID = p_prestamo_id
    LIMIT 1;

    -- Si no está en v2, buscar en completados
    IF v_saldo IS NULL THEN
        SELECT
            Saldo, Tarifa, plazo, Semana, Anio
        INTO
            v_saldo, v_tarifa, v_plazo, v_semana, v_anio
        FROM prestamos_completados
        WHERE PrestamoID = p_prestamo_id
        LIMIT 1;
    END IF;

    -- Si no existe el préstamo
    IF v_saldo IS NULL THEN
        RETURN 'NO EXISTE';
    END IF;

    -- Calcular semanas transcurridas
    SET v_semanas_transcurridas = (YEAR(CURDATE()) - v_anio) * 52 + (WEEK(CURDATE()) - v_semana);

    -- Contar no pagos
    SELECT COUNT(*) INTO v_no_pagos
    FROM pagos_v3
    WHERE PrestamoID = p_prestamo_id AND Tipo = 'No_pago';

    -- Verificar criterios
    IF v_saldo < (v_tarifa * 2)
       AND v_semanas_transcurridas <= v_plazo
       AND v_no_pagos = 0 THEN
        SET v_cumple = 'CUMPLE';
    ELSE
        SET v_cumple = 'NO CUMPLE';
    END IF;

    RETURN v_cumple;
END$$

DELIMITER ;

-- Uso de la función:
-- SELECT cumple_criterios_filtrado('ID_DEL_PRESTAMO');


-- =====================================================
-- EJEMPLOS DE USO
-- =====================================================

-- Ejemplo 1: Verificar un préstamo específico
-- SELECT * FROM (QUERY 1 o 2) WHERE PrestamoID = 'ABC-123';

-- Ejemplo 2: Listar todos los que cumplen
-- SELECT * FROM (QUERY 3);

-- Ejemplo 3: Usar la función
-- SELECT PrestamoID, cumple_criterios_filtrado(PrestamoID) AS cumple
-- FROM prestamos_v2 LIMIT 10;
