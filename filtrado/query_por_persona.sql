-- =====================================================
-- QUERY 1: LISTA DE PERSONAS POR AGENCIA
-- =====================================================
-- Para el UI: Mostrar lista de personas de una agencia específica
-- Retorna: cliente_persona_id, nombre completo, teléfono, total de préstamos

SELECT
    persona.id AS cliente_persona_id,
    persona.nombres,
    persona.apellido_paterno,
    persona.apellido_materno,
    CONCAT(persona.nombres, ' ', persona.apellido_paterno, ' ', persona.apellido_materno) AS nombre_completo,
    persona.telefono,

    -- Conteo de préstamos
    COUNT(DISTINCT CASE WHEN p.tipo = 'ACTIVO' THEN p.PrestamoID END) AS prestamos_activos,
    COUNT(DISTINCT CASE WHEN p.tipo = 'COMPLETADO' THEN p.PrestamoID END) AS prestamos_completados,
    COUNT(DISTINCT p.PrestamoID) AS total_prestamos

FROM personas persona

-- UNION de préstamos activos y completados
INNER JOIN (
    SELECT PrestamoID, cliente_persona_id, 'ACTIVO' AS tipo
    FROM prestamos_v2
    WHERE Agente = 'AGD043'

    UNION ALL

    SELECT PrestamoID, cliente_persona_id, 'COMPLETADO' AS tipo
    FROM prestamos_completados
    WHERE Agente = 'AGD043'
) AS p ON persona.id = p.cliente_persona_id

GROUP BY persona.id, persona.nombres, persona.apellido_paterno, persona.apellido_materno, persona.telefono

ORDER BY nombre_completo;


-- =====================================================
-- QUERY 2: HISTORIAL DE PRÉSTAMOS POR PERSONA
-- =====================================================
-- Para el UI: Mostrar todos los préstamos de una persona
-- Incluye préstamos activos y completados
--
-- RECOMENDADO: Usar el procedimiento almacenado en su lugar:
-- CALL obtener_historial_prestamos_persona('ID_PERSONA');
--
-- El procedimiento está en: filtrado/crear_procedure_historial_persona.sql
-- =====================================================

SELECT
    p.PrestamoID,
    'COMPLETADO' AS tipo_prestamo,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    p.Saldo,
    p.Cobrado,
    p.Monto_otorgado,

    -- Estadísticas de pagos
    COALESCE(pagos.total_pagos, 0) AS total_pagos,
    COALESCE(pagos.no_pagos, 0) AS no_pagos,

    -- Criterios de filtrado
    (p.Saldo < p.Tarifa * 2) AS cumple_saldo,
    (COALESCE(pagos.total_pagos, 0) <= p.plazo) AS cumple_plazo,
    (COALESCE(pagos.no_pagos, 0) = 0) AS cumple_sin_no_pagos,

    -- Resultado final
    CASE
        WHEN (p.Saldo < p.Tarifa * 2)
            AND (COALESCE(pagos.total_pagos, 0) <= p.plazo)
            AND COALESCE(pagos.no_pagos, 0) = 0
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado

FROM prestamos_completados p
LEFT JOIN (
    SELECT PrestamoID, COUNT(*) AS total_pagos, SUM(CASE WHEN Monto = 0 THEN 1 ELSE 0 END) AS no_pagos
    FROM pagos_v3 GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID
WHERE p.cliente_persona_id = 'ID_PERSONA'

UNION ALL

SELECT
    p.PrestamoID,
    'ACTIVO' AS tipo_prestamo,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.plazo,
    p.Tarifa,
    pd.saldo AS Saldo,
    pd.cobrado AS Cobrado,
    p.Monto_otorgado,

    -- Estadísticas de pagos
    COALESCE(pagos.total_pagos, 0) AS total_pagos,
    COALESCE(pagos.no_pagos, 0) AS no_pagos,

    -- Criterios de filtrado
    (pd.saldo < p.Tarifa * 2) AS cumple_saldo,
    (COALESCE(pagos.total_pagos, 0) <= p.plazo) AS cumple_plazo,
    (COALESCE(pagos.no_pagos, 0) = 0) AS cumple_sin_no_pagos,

    -- Resultado final
    CASE
        WHEN (pd.saldo < p.Tarifa * 2)
            AND (COALESCE(pagos.total_pagos, 0) <= p.plazo)
            AND COALESCE(pagos.no_pagos, 0) = 0
        THEN 'CUMPLE'
        ELSE 'NO CUMPLE'
    END AS resultado

FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
LEFT JOIN (
    SELECT PrestamoID, COUNT(*) AS total_pagos, SUM(CASE WHEN Monto = 0 THEN 1 ELSE 0 END) AS no_pagos
    FROM pagos_v3 GROUP BY PrestamoID
) AS pagos ON p.PrestamoID = pagos.PrestamoID
WHERE p.cliente_persona_id = 'ID_PERSONA'

ORDER BY Anio DESC, Semana DESC;