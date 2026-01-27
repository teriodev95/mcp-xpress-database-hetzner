-- ============================================================
-- Table Function: obtener_agencias_sin_cierre
-- Descripción: Retorna agencias que NO tienen cierre semanal
--              para una semana y año específicos, excluyendo
--              agencias vacantes
-- ============================================================
-- Parámetros:
--   p_semana: Número de semana (1-53)
--   p_anio:   Año (ej: 2025)
-- ============================================================
-- Uso:
--   SELECT * FROM obtener_agencias_sin_cierre(42, 2025);
-- ============================================================

DELIMITER $$

-- Opción 1: Procedimiento Almacenado (Más compatible)
CREATE OR REPLACE PROCEDURE obtener_agencias_sin_cierre(
    IN p_semana INT,
    IN p_anio INT
)
BEGIN
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
          AND c.semana = p_semana
          AND c.anio = p_anio
    )
    ORDER BY a.GerenciaID, a.AgenciaID;
END$$

DELIMITER ;

-- ============================================================
-- Ejemplos de uso:
-- ============================================================

-- Ver todas las agencias sin cierre para la semana 42 de 2025
CALL obtener_agencias_sin_cierre(42, 2025);

-- Para usar en consultas más complejas, puedes crear una tabla temporal:
-- Crear tabla temporal con los resultados
DROP TEMPORARY TABLE IF EXISTS tmp_agencias_sin_cierre;
CREATE TEMPORARY TABLE tmp_agencias_sin_cierre AS
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
      AND c.semana = 42
      AND c.anio = 2025
);

-- Ahora puedes hacer consultas sobre la tabla temporal:
-- Contar cuántas agencias sin cierre hay
SELECT COUNT(*) as total_agencias_sin_cierre
FROM tmp_agencias_sin_cierre;

-- Agrupar por gerencia
SELECT
    gerencia,
    COUNT(*) as agencias_sin_cierre
FROM tmp_agencias_sin_cierre
GROUP BY gerencia
ORDER BY agencias_sin_cierre DESC;

-- Filtrar solo agencias con más de 6 meses trabajados
SELECT *
FROM tmp_agencias_sin_cierre
WHERE MesesTrabajados > 6;
