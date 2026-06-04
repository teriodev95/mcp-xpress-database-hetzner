-- ============================================================
-- Migración: vistas de antigüedad — regla CALENDARIO + semana completa
-- Fecha: 2026-06-03
--
-- Esta migración REEMPLAZA la versión anterior basada en "mes Xpress
-- estricto". El stakeholder pidió cambio a regla calendario porque da
-- al agente certidumbre sobre la fecha exacta en que empieza a cobrar.
--
-- Reglas vigentes (Opción A — la semana cuya `desde` (miércoles) es
-- >= cumple cuenta entera, incluido el caso desde == cumple):
--
--   1. Día efectivo del agente = miércoles inmediato a Fecha_ingreso.
--      Si Fecha_ingreso es miércoles, es el mismo día.
--      Si no, el siguiente miércoles.
--
--   2. Cumple N meses = día_efectivo + N meses CALENDARIO.
--      Si el día destino no existe (31 en Feb/Abr/etc.) se ajusta al
--      último día del mes (MariaDB DATE_ADD lo hace automáticamente).
--
--   3. Califica para bono de N meses desde la PRIMERA semana Xpress
--      cuyo miércoles `desde` es >= cumple_Nm_fecha. BonoService filtra
--      con `calendario.id >= califica_Nm_desde_id`.
--
-- Cambio respecto a la versión anterior:
--   - Antes: cumple_Nm_id apuntaba a la última semana del N-ésimo mes
--     Xpress; filtro `> cumple_id`.
--   - Ahora: califica_Nm_desde_id apunta a la primera semana que cuenta
--     para el bono; filtro `>= califica_id`.
--
-- Debug del caso histórico (Edith, AGGC002, ingreso 2026-02-25 miér):
--   - día_efectivo = 2026-02-25.
--   - cumple_3m_fecha = 2026-05-25 (Lunes).
--   - califica_3m_desde_id = id de S22/2026 (mié 2026-05-27 >= 2026-05-25).
--   - Mayo Xpress 2026 = S18-S22. S22 SÍ cuenta. Edith cobra 1/5 semanas.
-- ============================================================

-- ------------------------------------------------------------
-- 0) Limpieza de vistas obsoletas (versión mes-Xpress-estricto)
-- ------------------------------------------------------------
DROP VIEW IF EXISTS vw_antiguedad_agentes;
DROP VIEW IF EXISTS vw_meses_agente;
-- vw_meses_xpress se mantiene como helper genérico (agrupa calendario
-- por mes Xpress; útil para reportes mensuales, no para bonos).


-- ------------------------------------------------------------
-- 1) vw_dia_efectivo_agente: helper interno.
-- Por cada agente, calcula el día efectivo y la semana de ingreso.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS vw_dia_efectivo_agente;

CREATE OR REPLACE
DEFINER=`xpress_admin`@`%`
SQL SECURITY INVOKER
VIEW vw_dia_efectivo_agente AS
SELECT
    u.UsuarioID,
    u.empresa,
    u.Status,
    DATE(u.Fecha_ingreso)         AS fecha_ingreso,
    ci.id                         AS calendario_id_ingreso,
    ci.semana                     AS semana_ingreso,
    ci.anio                       AS anio_semana_ingreso,
    ci.mes                        AS mes_xpress_ingreso,
    ci.desde                      AS inicio_semana_ingreso,
    ci.hasta                      AS fin_semana_ingreso,
    -- Día efectivo: si entró miércoles, ese día; si no, el siguiente miércoles.
    CASE WHEN DATE(u.Fecha_ingreso) = ci.desde
         THEN ci.desde
         ELSE DATE_ADD(ci.hasta, INTERVAL 1 DAY)
    END                           AS dia_efectivo,
    -- Primer id de calendario que cuenta como "semana trabajada".
    CASE WHEN DATE(u.Fecha_ingreso) = ci.desde
         THEN ci.id
         ELSE ci.id + 1
    END                           AS primer_calendario_id_contado
FROM usuarios u
JOIN calendario ci ON DATE(u.Fecha_ingreso) BETWEEN ci.desde AND ci.hasta
WHERE u.Tipo = 'Agente';


-- ------------------------------------------------------------
-- 2) vw_antiguedad_agentes: vista principal para BonoService.
-- ------------------------------------------------------------
CREATE OR REPLACE
DEFINER=`xpress_admin`@`%`
SQL SECURITY INVOKER
VIEW vw_antiguedad_agentes AS
SELECT
    d.UsuarioID,
    d.empresa,
    d.Status,
    d.fecha_ingreso,
    ELT(DAYOFWEEK(d.fecha_ingreso),
        'Domingo','Lunes','Martes','Miércoles',
        'Jueves','Viernes','Sábado')               AS dia_ingreso,

    d.calendario_id_ingreso,
    d.semana_ingreso,
    d.anio_semana_ingreso,
    d.mes_xpress_ingreso,
    d.inicio_semana_ingreso,
    d.fin_semana_ingreso,
    IF(d.fecha_ingreso = d.inicio_semana_ingreso, 'Sí', 'No')
                                                   AS ingreso_en_miercoles,

    d.dia_efectivo,
    d.primer_calendario_id_contado,

    -- Fechas de cumple (calendario civil; DATE_ADD ajusta 31→último día).
    DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH)     AS cumple_3m_fecha,
    DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH)     AS cumple_6m_fecha,
    DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH)    AS cumple_12m_fecha,

    -- Primera semana Xpress que cuenta para tier N (Opción A: desde >= cumple).
    (SELECT MIN(c.id) FROM calendario c
      WHERE c.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH))
                                                   AS califica_3m_desde_id,
    (SELECT MIN(c.id) FROM calendario c
      WHERE c.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH))
                                                   AS califica_6m_desde_id,
    (SELECT MIN(c.id) FROM calendario c
      WHERE c.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH))
                                                   AS califica_12m_desde_id,

    -- Etiqueta legible de la semana en que califica (UI).
    (SELECT CONCAT('S', c.semana, '/', c.anio, ' (', c.mes, ')')
       FROM calendario c
      WHERE c.id = (SELECT MIN(c2.id) FROM calendario c2
                     WHERE c2.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH))
      LIMIT 1)                                     AS califica_3m_semana,
    (SELECT CONCAT('S', c.semana, '/', c.anio, ' (', c.mes, ')')
       FROM calendario c
      WHERE c.id = (SELECT MIN(c2.id) FROM calendario c2
                     WHERE c2.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH))
      LIMIT 1)                                     AS califica_6m_semana,
    (SELECT CONCAT('S', c.semana, '/', c.anio, ' (', c.mes, ')')
       FROM calendario c
      WHERE c.id = (SELECT MIN(c2.id) FROM calendario c2
                     WHERE c2.desde >= DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH))
      LIMIT 1)                                     AS califica_12m_semana,

    -- Flags booleanos: "hoy ya cumplió N meses calendario".
    (DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH))
                                                   AS tiene_3m,
    (DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH))
                                                   AS tiene_6m,
    (DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH))
                                                   AS tiene_12m,

    -- Semanas Xpress trabajadas (solo terminadas, contando desde el día efectivo).
    (SELECT COUNT(*) FROM calendario c
      WHERE c.id >= d.primer_calendario_id_contado
        AND c.hasta <= DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')))
                                                   AS semanas_trabajadas,

    -- Meses calendario transcurridos desde día efectivo (display).
    -- Cuenta el mayor N tal que cumple_Nm_fecha <= hoy. Captura el caso
    -- 31→último-día que TIMESTAMPDIFF no maneja igual que DATE_ADD.
    CASE
        WHEN DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH) THEN
             12 + TIMESTAMPDIFF(MONTH, DATE_ADD(d.dia_efectivo, INTERVAL 12 MONTH),
                                       DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')))
        WHEN DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH) THEN
             6  + TIMESTAMPDIFF(MONTH, DATE_ADD(d.dia_efectivo, INTERVAL 6 MONTH),
                                       DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')))
        WHEN DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')) >= DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH) THEN
             3  + TIMESTAMPDIFF(MONTH, DATE_ADD(d.dia_efectivo, INTERVAL 3 MONTH),
                                       DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')))
        ELSE TIMESTAMPDIFF(MONTH, d.dia_efectivo,
                                  DATE(CONVERT_TZ(NOW(),'UTC','America/Mexico_City')))
    END                                            AS meses_trabajados
FROM vw_dia_efectivo_agente d;


-- ============================================================
-- Verificación post-deploy
-- ============================================================

SHOW CREATE VIEW vw_dia_efectivo_agente;
SHOW CREATE VIEW vw_antiguedad_agentes;

-- Smoke test agentes Gocash
SELECT UsuarioID, fecha_ingreso, dia_efectivo,
       cumple_3m_fecha, califica_3m_semana,
       tiene_3m, tiene_6m, tiene_12m,
       semanas_trabajadas, meses_trabajados
  FROM vw_antiguedad_agentes
 WHERE empresa = 'gocash' AND Status = 1
 ORDER BY fecha_ingreso;

-- Caso del screenshot (UsuarioID=792, EDITH BAILON, ingreso 2026-02-25 miércoles).
-- Esperado:
--   día_efectivo = 2026-02-25
--   cumple_3m_fecha = 2026-05-25 (Lunes)
--   califica_3m_semana = S22/2026 (Mayo)
--   tiene_3m = 1, tiene_6m = 0, tiene_12m = 0
-- Implicación: Mayo Xpress 2026 (S18-S22) → S22 SÍ entra al bono.
SELECT * FROM vw_antiguedad_agentes WHERE UsuarioID = 792;
