-- ============================================================================
-- VISTA: vw_movimientos_efectivo_gerencia
--
-- Libro contable de movimientos de efectivo por gerencia.
-- Cada fila = un movimiento de dinero (ingreso, egreso o pendiente).
-- Columnas: gerencia, semana, anio, tipo_mov, concepto, monto, tabla, registro_id
--
-- REGLA FUNDAMENTAL DE ASIGNACIONES:
--   1. Solo contar asignaciones donde al menos un campo de gerencia esta lleno
--      (gerencia_recibe o gerencia_entrega). Si ambos estan vacios, el dinero
--      fue entregado directamente a Regional/Seguridad SIN pasar por la gerencia.
--   2. Cuando hay gerencia identificada, el tipo de movimiento depende de
--      quien_recibio → usuarios.Tipo:
--        - Gerente recibe     → INGRESO (el dinero entra a la caja de la gerencia)
--        - Seguridad recibe   → EGRESO  (el dinero sale via transporte de valores)
--        - Regional recibe    → EGRESO  (el dinero sale al regional)
--        - Admin/Jefe recibe  → EGRESO  (el dinero sale a admin central)
--
-- FUENTES DE DATOS (14 branches):
--   1. Asignaciones donde GERENTE recibe         → INGRESO
--   2. Asignaciones donde SEGURIDAD/REGIONAL etc. recibe  → EGRESO
--   3. Asignaciones donde gerencia ENTREGA (sin recibe) → EGRESO
--   4. Transferencias entre gerencias (entrega→recibe)  → EGRESO para quien entrega
--   5. Cobranza de agencias vacantes              → INGRESO
--   6. Primeros pagos de desembolsos              → INGRESO
--   7. Desembolsos de ventas                      → EGRESO
--   8. Gastos operativos                          → EGRESO
--   9. Incidentes/reposiciones/nomina             → INGRESO o EGRESO
--  10. Cobranza sin asignacion (agencia abierta)  → EN_CAMPO
--  11. Cobranza sin asignacion (agencia cerrada)  → INGRESO (cierre de agencia)
--  12. Comision cobranza pagada a agente          → EGRESO
--  13. Comision ventas pagada a agente            → EGRESO
--  14. Bonos pagados a agente                     → EGRESO
--
-- EJEMPLOS DE USO:
--
--   -- Efectivo de una gerencia
--   SELECT
--       SUM(CASE WHEN tipo_mov = 'INGRESO' THEN monto ELSE 0 END)
--     - SUM(CASE WHEN tipo_mov = 'EGRESO'  THEN monto ELSE 0 END) AS efectivo
--   FROM vw_movimientos_efectivo_gerencia
--   WHERE gerencia = 'GERE011' AND semana = 9 AND anio = 2026;
--
--   -- Detalle con trazabilidad
--   SELECT tipo_mov, concepto, monto, tabla, registro_id
--   FROM vw_movimientos_efectivo_gerencia
--   WHERE gerencia = 'GERC002' AND semana = 7 AND anio = 2026
--   ORDER BY FIELD(tipo_mov, 'INGRESO', 'EGRESO', 'EN_CAMPO'), concepto;
--
-- NOTAS TECNICAS:
--   - Usa CONVERT(... USING utf8mb4) para resolver collation mixta entre tablas
--   - Usa NOT EXISTS en lugar de NOT IN para evitar bug con NULLs en asignaciones_v2
--   - SIEMPRE filtrar por semana/anio para performance (vw_datos_cobranza es pesada)
--   - La gerencia se resuelve via: gerencia_recibe o gerencia_entrega (explicitos)
--   - Si ambos campos estan vacios, la asignacion NO se cuenta (bypass de gerencia)
--   - El tipo_mov se determina por usuarios.Tipo del receptor, NO por gerencia_recibe
-- ============================================================================

DROP VIEW IF EXISTS vw_movimientos_efectivo_gerencia;

CREATE VIEW vw_movimientos_efectivo_gerencia AS

-- =============================================
-- 1. INGRESO: Asignaciones donde un GERENTE recibe
-- =============================================
SELECT
    CONVERT(a.gerencia_recibe USING utf8mb4)     AS gerencia,
    a.semana,
    a.anio,
    'INGRESO'                                    AS tipo_mov,
    UPPER(CONVERT(CONCAT('ASIGNACION ', a.tipo, ' - ',
        IF(a.agencia IS NOT NULL AND a.agencia <> '',
            CONCAT(a.agencia, ' (', COALESCE(asa.Agente, ''), ')'),
            CONCAT(COALESCE(u_e.Nombre, '?'), ' -> ', u.Nombre)
        )
    ) USING utf8mb4)) AS concepto,
    CAST(a.monto AS DECIMAL(12,2))               AS monto,
    'asignaciones_v2'                            AS tabla,
    CONVERT(a.id USING utf8mb4)                  AS registro_id
FROM asignaciones_v2 a
LEFT JOIN agencias_status_auxilar asa ON a.agencia = asa.Agencia
INNER JOIN usuarios u ON a.quien_recibio = u.UsuarioID
LEFT JOIN usuarios u_e ON a.quien_entrego = u_e.UsuarioID
WHERE u.Tipo = 'Gerente'
  AND a.gerencia_recibe IS NOT NULL
  AND a.gerencia_recibe <> ''

UNION ALL

-- =============================================
-- 2. EGRESO: Asignaciones donde Seguridad/Regional/Admin recibe
-- =============================================
SELECT
    CONVERT(COALESCE(
        NULLIF(a.gerencia_entrega, ''),
        a.gerencia_recibe
    ) USING utf8mb4)                             AS gerencia,
    a.semana,
    a.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('ENTREGA ', a.tipo, ' A ', u.Tipo, ' - ',
        IF(a.agencia IS NOT NULL AND a.agencia <> '',
            CONCAT(a.agencia, ' (', COALESCE(asa.Agente, ''), ')'),
            CONCAT(COALESCE(u_e.Nombre, '?'), ' -> ', u.Nombre)
        )
    ) USING utf8mb4)) AS concepto,
    CAST(a.monto AS DECIMAL(12,2))               AS monto,
    'asignaciones_v2'                            AS tabla,
    CONVERT(a.id USING utf8mb4)                  AS registro_id
FROM asignaciones_v2 a
LEFT JOIN agencias_status_auxilar asa ON a.agencia = asa.Agencia
INNER JOIN usuarios u ON a.quien_recibio = u.UsuarioID
LEFT JOIN usuarios u_e ON a.quien_entrego = u_e.UsuarioID
WHERE u.Tipo <> 'Gerente'
  AND u.Tipo <> 'Agente'
  AND (
      (a.gerencia_entrega IS NOT NULL AND a.gerencia_entrega <> '')
      OR (a.gerencia_recibe IS NOT NULL AND a.gerencia_recibe <> '')
  )

UNION ALL

-- =============================================
-- 3. EGRESO: Asignaciones con gerencia_entrega pero sin receptor claro
-- =============================================
SELECT
    CONVERT(a.gerencia_entrega USING utf8mb4)    AS gerencia,
    a.semana,
    a.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('ENTREGA ', a.tipo, ' - ',
        IF(a.agencia IS NOT NULL AND a.agencia <> '',
            CONCAT(a.agencia, ' (', COALESCE(asa.Agente, ''), ')'),
            CONCAT(COALESCE(u_e.Nombre, '?'), ' -> ', COALESCE(u.Nombre, '?'))
        )
    ) USING utf8mb4)) AS concepto,
    CAST(a.monto AS DECIMAL(12,2))               AS monto,
    'asignaciones_v2'                            AS tabla,
    CONVERT(a.id USING utf8mb4)                  AS registro_id
FROM asignaciones_v2 a
LEFT JOIN agencias_status_auxilar asa ON a.agencia = asa.Agencia
LEFT JOIN usuarios u ON a.quien_recibio = u.UsuarioID
LEFT JOIN usuarios u_e ON a.quien_entrego = u_e.UsuarioID
WHERE a.gerencia_entrega IS NOT NULL
  AND a.gerencia_entrega <> ''
  AND (a.gerencia_recibe IS NULL OR a.gerencia_recibe = '')
  AND (u.Tipo IS NULL OR u.Tipo = 'Agente')

UNION ALL

-- =============================================
-- 4. EGRESO: Transferencias entre gerencias (entrega→recibe)
-- =============================================
SELECT
    CONVERT(a.gerencia_entrega USING utf8mb4)    AS gerencia,
    a.semana,
    a.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('TRANSF. A ', a.gerencia_recibe, ' (', a.tipo, ') - ',
        IF(a.agencia IS NOT NULL AND a.agencia <> '',
            CONCAT(a.agencia, ' (', COALESCE(asa.Agente, ''), ')'),
            CONCAT(COALESCE(u_e.Nombre, '?'), ' -> ', u.Nombre)
        )
    ) USING utf8mb4)) AS concepto,
    CAST(a.monto AS DECIMAL(12,2))               AS monto,
    'asignaciones_v2'                            AS tabla,
    CONVERT(a.id USING utf8mb4)                  AS registro_id
FROM asignaciones_v2 a
LEFT JOIN agencias_status_auxilar asa ON a.agencia = asa.Agencia
INNER JOIN usuarios u ON a.quien_recibio = u.UsuarioID
LEFT JOIN usuarios u_e ON a.quien_entrego = u_e.UsuarioID
WHERE a.gerencia_entrega IS NOT NULL
  AND a.gerencia_entrega <> ''
  AND a.gerencia_recibe IS NOT NULL
  AND a.gerencia_recibe <> ''
  AND u.Tipo = 'Gerente'

UNION ALL

-- =============================================
-- 5. INGRESO: Cobranza de agencias vacantes
-- =============================================
SELECT
    CONVERT(d.gerencia_id USING utf8mb4)         AS gerencia,
    d.semana,
    d.anio,
    'INGRESO'                                    AS tipo_mov,
    UPPER(CONVERT(CONCAT('COBRANZA VACANTE - ', d.agencia) USING utf8mb4)) AS concepto,
    CAST(SUM(d.monto_pagado) AS DECIMAL(12,2))   AS monto,
    'vw_datos_cobranza'                          AS tabla,
    CONVERT(d.agencia USING utf8mb4)             AS registro_id
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
WHERE asa.Agente = 'VACANTE'
  AND NOT EXISTS (
      SELECT 1 FROM asignaciones_v2 a2
      WHERE a2.agencia = d.agencia
        AND a2.semana = d.semana
        AND a2.anio = d.anio
  )
GROUP BY d.gerencia_id, d.agencia, d.semana, d.anio
HAVING SUM(d.monto_pagado) > 0

UNION ALL

-- =============================================
-- 6. INGRESO: Primeros pagos de desembolsos
-- =============================================
SELECT
    CONVERT(asa.Gerencia USING utf8mb4)          AS gerencia,
    v.semana,
    v.anio,
    'INGRESO'                                    AS tipo_mov,
    UPPER(CONVERT(CONCAT('PRIMER PAGO - ', v.agencia, ' (', v.nombre_cliente, ')') USING utf8mb4)) AS concepto,
    CAST(v.primer_pago AS DECIMAL(12,2))         AS monto,
    'ventas'                                     AS tabla,
    CAST(v.id AS CHAR)                           AS registro_id
FROM ventas v
INNER JOIN agencias_status_auxilar asa ON v.agencia = asa.Agencia

UNION ALL

-- =============================================
-- 7. EGRESO: Desembolsos de ventas
-- =============================================
SELECT
    CONVERT(asa.Gerencia USING utf8mb4)          AS gerencia,
    v.semana,
    v.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('DESEMBOLSO - ', v.agencia, ' (', v.nombre_cliente, ')') USING utf8mb4)) AS concepto,
    CAST(v.monto AS DECIMAL(12,2))               AS monto,
    'ventas'                                     AS tabla,
    CAST(v.id AS CHAR)                           AS registro_id
FROM ventas v
INNER JOIN agencias_status_auxilar asa ON v.agencia = asa.Agencia

UNION ALL

-- =============================================
-- 8. EGRESO: Gastos operativos
-- =============================================
SELECT
    CONVERT(g.gerencia USING utf8mb4)            AS gerencia,
    g.semana,
    g.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('GASTO: ', g.tipo_gasto, IF(g.concepto IS NOT NULL AND g.concepto <> '', CONCAT(' - ', g.concepto), '')) USING utf8mb4)) AS concepto,
    CAST(g.monto AS DECIMAL(12,2))               AS monto,
    'gastos'                                     AS tabla,
    CAST(g.gasto_id AS CHAR)                     AS registro_id
FROM gastos g
WHERE g.gerencia IS NOT NULL

UNION ALL

-- =============================================
-- 9. INGRESO/EGRESO: Incidentes, reposiciones, nomina
-- =============================================
SELECT
    CONVERT(ir.gerencia USING utf8mb4)           AS gerencia,
    ir.semana,
    ir.anio,
    CASE WHEN ir.tipo = 'ingreso' THEN 'INGRESO' ELSE 'EGRESO' END AS tipo_mov,
    UPPER(CONVERT(CONCAT(ir.categoria, IF(ir.comentario IS NOT NULL AND ir.comentario <> '', CONCAT(' - ', ir.comentario), '')) USING utf8mb4)) AS concepto,
    CAST(ir.monto AS DECIMAL(12,2))              AS monto,
    'incidentes_reposiciones'                    AS tabla,
    CAST(ir.id AS CHAR)                          AS registro_id
FROM incidentes_reposiciones ir
WHERE ir.gerencia IS NOT NULL
  AND ir.gerencia <> ''

UNION ALL

-- =============================================
-- 10. EN_CAMPO: Diferencia entre cobranza y asignaciones entregadas
--     cobranza - asignaciones = dinero que el agente aun tiene
--     Si no hay asignacion → todo lo cobrado esta en campo
--     Si asigno menos de lo cobrado → la diferencia esta en campo
--     EXCLUYE agencias que ya tienen cierre semanal (ya entregaron)
-- =============================================
SELECT
    CONVERT(d.gerencia_id USING utf8mb4)         AS gerencia,
    d.semana,
    d.anio,
    'EN_CAMPO'                                   AS tipo_mov,
    UPPER(CONVERT(CONCAT('EN CAMPO - ', d.agencia, ' (', asa.Agente, ')') USING utf8mb4)) AS concepto,
    CAST(
        SUM(d.monto_pagado) - COALESCE(asig.total_asignado, 0)
    AS DECIMAL(12,2))                            AS monto,
    'vw_datos_cobranza'                          AS tabla,
    CONVERT(d.agencia USING utf8mb4)             AS registro_id
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT a2.agencia, a2.semana, a2.anio, SUM(a2.monto) AS total_asignado
    FROM asignaciones_v2 a2
    GROUP BY a2.agencia, a2.semana, a2.anio
) asig ON d.agencia = asig.agencia
      AND d.semana = asig.semana
      AND d.anio = asig.anio
WHERE asa.Agente <> 'VACANTE'
  AND d.monto_pagado > 0
  AND NOT EXISTS (
      SELECT 1 FROM cierres_semanales_consolidados_v2 c
      WHERE c.agencia = d.agencia
        AND c.semana = d.semana
        AND c.anio = d.anio
  )
GROUP BY d.gerencia_id, d.agencia, asa.Agente, d.semana, d.anio, asig.total_asignado
HAVING SUM(d.monto_pagado) - COALESCE(asig.total_asignado, 0) > 0

UNION ALL

-- =============================================
-- 11. INGRESO: Cierre de agencia (cobranza - asignaciones para agencias cerradas)
--     Misma logica que EN_CAMPO pero para agencias que YA cerraron.
--     Como ya entregaron, la diferencia es INGRESO (dinero entregado al cierre).
--     NO usa efectivo_entregado_cierre (campo editable), calcula desde cobranza.
-- =============================================
SELECT
    CONVERT(d.gerencia_id USING utf8mb4)         AS gerencia,
    d.semana,
    d.anio,
    'INGRESO'                                    AS tipo_mov,
    UPPER(CONVERT(CONCAT('CIERRE AGENCIA - ', d.agencia, ' (', asa.Agente, ')') USING utf8mb4)) AS concepto,
    CAST(
        SUM(d.monto_pagado) - COALESCE(asig.total_asignado, 0)
    AS DECIMAL(12,2))                            AS monto,
    'vw_datos_cobranza'                          AS tabla,
    CONVERT(d.agencia USING utf8mb4)             AS registro_id
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT a2.agencia, a2.semana, a2.anio, SUM(a2.monto) AS total_asignado
    FROM asignaciones_v2 a2
    GROUP BY a2.agencia, a2.semana, a2.anio
) asig ON d.agencia = asig.agencia
      AND d.semana = asig.semana
      AND d.anio = asig.anio
WHERE asa.Agente <> 'VACANTE'
  AND d.monto_pagado > 0
  AND EXISTS (
      SELECT 1 FROM cierres_semanales_consolidados_v2 c
      WHERE c.agencia = d.agencia
        AND c.semana = d.semana
        AND c.anio = d.anio
  )
GROUP BY d.gerencia_id, d.agencia, asa.Agente, d.semana, d.anio, asig.total_asignado
HAVING SUM(d.monto_pagado) - COALESCE(asig.total_asignado, 0) > 0

UNION ALL

-- =============================================
-- 12. EGRESO: Comision de cobranza pagada a agente
-- =============================================
SELECT
    CONVERT(c.gerencia USING utf8mb4)            AS gerencia,
    c.semana,
    c.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('COMISION COBRANZA - ', c.agencia, ' (', c.agente, ')') USING utf8mb4)) AS concepto,
    CAST(c.comision_cobranza_pagada_en_semana AS DECIMAL(12,2)) AS monto,
    'cierres_v2'                                 AS tabla,
    CAST(c.id AS CHAR)                           AS registro_id
FROM cierres_semanales_consolidados_v2 c
WHERE c.gerencia IS NOT NULL
  AND c.comision_cobranza_pagada_en_semana > 0

UNION ALL

-- =============================================
-- 13. EGRESO: Comision de ventas pagada a agente
-- =============================================
SELECT
    CONVERT(c.gerencia USING utf8mb4)            AS gerencia,
    c.semana,
    c.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('COMISION VENTAS - ', c.agencia, ' (', c.agente, ')') USING utf8mb4)) AS concepto,
    CAST(c.comision_ventas_pagada_en_semana AS DECIMAL(12,2)) AS monto,
    'cierres_v2'                                 AS tabla,
    CAST(c.id AS CHAR)                           AS registro_id
FROM cierres_semanales_consolidados_v2 c
WHERE c.gerencia IS NOT NULL
  AND c.comision_ventas_pagada_en_semana > 0

UNION ALL

-- =============================================
-- 14. EGRESO: Bonos pagados a agente
-- =============================================
SELECT
    CONVERT(c.gerencia USING utf8mb4)            AS gerencia,
    c.semana,
    c.anio,
    'EGRESO'                                     AS tipo_mov,
    UPPER(CONVERT(CONCAT('BONO AGENTE - ', c.agencia, ' (', c.agente, ')') USING utf8mb4)) AS concepto,
    CAST(c.bonos_pagados_en_semana AS DECIMAL(12,2)) AS monto,
    'cierres_v2'                                 AS tabla,
    CAST(c.id AS CHAR)                           AS registro_id
FROM cierres_semanales_consolidados_v2 c
WHERE c.gerencia IS NOT NULL
  AND c.bonos_pagados_en_semana > 0;
