-- ============================================================
-- Query: Agencias sin cierre semanal (sin vacantes)
-- Descripción: Lista agencias que NO tienen cierre semanal
--              para una semana y año específicos
-- ============================================================
-- Instrucciones:
--   Reemplazar los valores 42 y 2025 por la semana y año deseados
-- ============================================================

SELECT
    a.AgenciaID AS agencia_sin_cierre,
    a.GerenciaID AS gerencia,
    asa.Agente,
    asa.MesesTrabajados
FROM agencias a
INNER JOIN agencias_status_auxilar asa
    ON a.AgenciaID = asa.Agencia
WHERE asa.Agente <> 'VACANTE'
  AND NOT EXISTS (
    SELECT 1
    FROM cierres_semanales_consolidados_v2 c
    WHERE c.agencia = a.AgenciaID
      AND c.semana = 42    -- ← Cambiar semana aquí
      AND c.anio = 2025    -- ← Cambiar año aquí
)
ORDER BY a.GerenciaID, a.AgenciaID;
