-- ============================================================
-- Procedimiento: obtener_status_cierre_por_gerencia
-- Descripción: Retorna TODAS las agencias de una gerencia con
--              su status de cierre (CERRADA o PENDIENTE)
-- ============================================================
-- Parámetros:
--   p_gerencia: ID de la gerencia (ej: 'GERC001')
--   p_semana:   Número de semana (1-53)
--   p_anio:     Año (ej: 2025)
-- ============================================================
-- Uso:
--   CALL obtener_status_cierre_por_gerencia('GERC001', 43, 2025);
--   CALL obtener_status_cierre_por_gerencia('GERE001', 43, 2025);
-- ============================================================

DELIMITER $$

CREATE OR REPLACE PROCEDURE obtener_status_cierre_por_gerencia(
    IN p_gerencia VARCHAR(20),
    IN p_semana INT,
    IN p_anio INT
)
BEGIN
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
        AND c.semana = p_semana
        AND c.anio = p_anio
    WHERE a.GerenciaID = p_gerencia
      AND asa.Agente <> 'VACANTE'
    ORDER BY status_cierre, a.AgenciaID;
END$$

DELIMITER ;

-- ============================================================
-- Ejemplos de uso con datos reales:
-- ============================================================

-- Ver status de cierre de la gerencia GERC001, semana 43, año 2025
CALL obtener_status_cierre_por_gerencia('GERC001', 43, 2025);
-- Resultado esperado: 2 CERRADAS, 3 PENDIENTES

-- Ver status de cierre de la gerencia GERE001, semana 43, año 2025
CALL obtener_status_cierre_por_gerencia('GERE001', 43, 2025);
-- Resultado esperado: 4 CERRADAS, 0 PENDIENTES (¡100% completado!)

-- Ver status de cierre de cualquier gerencia, semana 42, año 2025
CALL obtener_status_cierre_por_gerencia('GERD001', 42, 2025);


-- ============================================================
-- Gerencias disponibles para probar:
-- ============================================================
-- GERC001-GERC010 (10 gerencias)
-- GERD001-GERD011 (11 gerencias)
-- GERDC001-GERDC002, GERDC100 (3 gerencias)
-- GERE001-GERE014 (14 gerencias)
-- GERM001-GERM009 (9 gerencias)
-- GERP001-GERP004 (4 gerencias)
-- Total: 46 gerencias disponibles


-- ============================================================
-- Para obtener estadísticas de todas las gerencias:
-- ============================================================
DROP TEMPORARY TABLE IF EXISTS tmp_status_cierres;
CREATE TEMPORARY TABLE tmp_status_cierres (
    gerencia VARCHAR(20),
    agencia VARCHAR(20),
    agente VARCHAR(200),
    meses_trabajados INT,
    status_cierre VARCHAR(10)
);

-- Insertar datos para todas las gerencias (ejemplo)
DELIMITER $$
CREATE OR REPLACE PROCEDURE obtener_resumen_todas_gerencias(
    IN p_semana INT,
    IN p_anio INT
)
BEGIN
    SELECT
        a.GerenciaID AS gerencia,
        COUNT(*) AS total_agencias,
        SUM(CASE WHEN c.agencia IS NOT NULL THEN 1 ELSE 0 END) AS cerradas,
        SUM(CASE WHEN c.agencia IS NULL THEN 1 ELSE 0 END) AS pendientes,
        ROUND(SUM(CASE WHEN c.agencia IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS porcentaje_cerradas
    FROM agencias a
    INNER JOIN agencias_status_auxilar asa
        ON a.AgenciaID = asa.Agencia
    LEFT JOIN cierres_semanales_consolidados_v2 c
        ON c.agencia = a.AgenciaID
        AND c.semana = p_semana
        AND c.anio = p_anio
    WHERE asa.Agente <> 'VACANTE'
    GROUP BY a.GerenciaID
    ORDER BY porcentaje_cerradas DESC;
END$$

DELIMITER ;

-- Uso del resumen general:
-- CALL obtener_resumen_todas_gerencias(43, 2025);




