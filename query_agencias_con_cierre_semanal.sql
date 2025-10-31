-- ============================================================
-- Query: Status de cierre por gerencia, semana y año
-- Descripción: Lista TODAS las agencias de una gerencia con
--              su status de cierre (CERRADA o PENDIENTE)
-- ============================================================
-- DATOS REALES DISPONIBLES:
--   - 46 Gerencias (GERC001 a GERP004)
--   - Semana más reciente: 43 del 2025 (242 cierres)
--   - Semana anterior: 42 del 2025 (291 cierres)
-- ============================================================
-- Parámetros a cambiar:
--   - GerenciaID (ej: 'GERC001', 'GERD001', 'GERE001', etc.)
--   - Semana (ej: 43)
--   - Año (ej: 2025)
-- ============================================================

SELECT
    a.AgenciaID AS agencia,
    a.GerenciaID AS gerencia,
    asa.Agente,
    asa.MesesTrabajados,
    CASE
        WHEN c.agencia IS NOT NULL THEN 'CERRADA'
        ELSE 'PENDIENTE'
    END AS status_cierre
FROM agencias a
INNER JOIN agencias_status_auxilar asa
    ON a.AgenciaID = asa.Agencia
LEFT JOIN cierres_semanales_consolidados_v2 c
    ON c.agencia = a.AgenciaID
    AND c.semana = 43          -- ← Cambiar semana aquí (última: 43)
    AND c.anio = 2025          -- ← Cambiar año aquí
WHERE a.GerenciaID = 'GERC001' -- ← Cambiar gerencia aquí (ej: GERC001, GERD001, GERE001)
  AND asa.Agente <> 'VACANTE'
ORDER BY status_cierre, a.AgenciaID;

-- ============================================================
-- EJEMPLOS DE RESULTADOS REALES (Semana 43, Año 2025):
-- ============================================================
--
-- EJEMPLO 1: Gerencia GERC001 (5 agencias activas)
--   - 2 CERRADAS: AGC005, AGC007
--   - 3 PENDIENTES: AGC001, AGC022, AGC077
--
-- EJEMPLO 2: Gerencia GERE001 (4 agencias activas)
--   - 4 CERRADAS: AGE001, AGE003, AGE007, AGE091
--   - 0 PENDIENTES (¡Todas cerradas! ✓)
--
-- ============================================================
-- Para probar con otras gerencias disponibles:
-- GERC001-GERC010, GERD001-GERD011, GERE001-GERE014,
-- GERM001-GERM009, GERP001-GERP004
-- ============================================================

