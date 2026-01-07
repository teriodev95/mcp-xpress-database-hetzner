-- =====================================================
-- SCRIPT: Corregir AbreCon y CierraCon en pagos_v3
-- =====================================================
-- Solo corrige semanas 46, 47, 48 de 2025
-- Solo préstamos que existen en prestamos_v2 (activos)
-- Considera múltiples pagos por semana (usa MIN(CierraCon))
-- =====================================================

-- =====================================================
-- PASO 1: Diagnóstico rápido
-- =====================================================
SELECT 'Discrepancias en semanas 46-48/2025 (préstamos activos):' as diagnostico;

SELECT actual.Semana, COUNT(DISTINCT actual.PrestamoID) as prestamos_con_discrepancia
FROM pagos_v3 actual
INNER JOIN (
    -- Obtener el CierraCon final de la semana anterior (MIN porque es el saldo después de todos los pagos)
    SELECT PrestamoID, Anio, Semana, MIN(CierraCon) as CierraConFinal
    FROM pagos_v3
    WHERE Anio = 2025 AND Semana IN (45, 46, 47)
    GROUP BY PrestamoID, Anio, Semana
) anterior ON actual.PrestamoID = anterior.PrestamoID
          AND anterior.Anio = actual.Anio
          AND anterior.Semana = actual.Semana - 1
INNER JOIN prestamos_v2 p ON actual.PrestamoID = p.PrestamoID
WHERE actual.Anio = 2025
  AND actual.Semana IN (46, 47, 48)
  AND ABS(actual.AbreCon - anterior.CierraConFinal) > 0.001
GROUP BY actual.Semana;

-- =====================================================
-- PASO 2: Ver detalle de discrepancias
-- =====================================================
SELECT 'Detalle de discrepancias (primeras 20):' as detalle;

SELECT
    actual.PrestamoID,
    actual.Semana,
    ROUND(actual.AbreCon, 2) as abrecon_actual,
    ROUND(anterior.CierraConFinal, 2) as cierracon_anterior_correcto,
    ROUND(actual.AbreCon - anterior.CierraConFinal, 2) as diferencia
FROM pagos_v3 actual
INNER JOIN (
    SELECT PrestamoID, Anio, Semana, MIN(CierraCon) as CierraConFinal
    FROM pagos_v3
    WHERE Anio = 2025 AND Semana IN (45, 46, 47)
    GROUP BY PrestamoID, Anio, Semana
) anterior ON actual.PrestamoID = anterior.PrestamoID
          AND anterior.Anio = actual.Anio
          AND anterior.Semana = actual.Semana - 1
INNER JOIN prestamos_v2 p ON actual.PrestamoID = p.PrestamoID
WHERE actual.Anio = 2025
  AND actual.Semana IN (46, 47, 48)
  AND ABS(actual.AbreCon - anterior.CierraConFinal) > 0.001
GROUP BY actual.PrestamoID, actual.Semana, actual.AbreCon, anterior.CierraConFinal
ORDER BY actual.Semana DESC, ABS(actual.AbreCon - anterior.CierraConFinal) DESC
LIMIT 20;

-- =====================================================
-- PASO 3: Corregir pagos_v3 (semanas 46, 47, 48)
-- =====================================================
-- Actualiza AbreCon con el MIN(CierraCon) de la semana anterior
-- Recalcula CierraCon = AbreCon - Monto

UPDATE pagos_v3 actual
INNER JOIN (
    SELECT PrestamoID, Anio, Semana, MIN(CierraCon) as CierraConFinal
    FROM pagos_v3
    WHERE Anio = 2025 AND Semana IN (45, 46, 47)
    GROUP BY PrestamoID, Anio, Semana
) anterior ON actual.PrestamoID = anterior.PrestamoID
          AND anterior.Anio = actual.Anio
          AND anterior.Semana = actual.Semana - 1
INNER JOIN prestamos_v2 p ON actual.PrestamoID = p.PrestamoID
SET actual.AbreCon = anterior.CierraConFinal,
    actual.CierraCon = anterior.CierraConFinal - actual.Monto
WHERE actual.Anio = 2025
  AND actual.Semana IN (46, 47, 48)
  AND ABS(actual.AbreCon - anterior.CierraConFinal) > 0.001;

SELECT CONCAT('pagos_v3 actualizados: ', ROW_COUNT()) as resultado;

-- =====================================================
-- PASO 4: Sincronizar pagos_dynamic
-- =====================================================
-- pagos_dynamic tiene un registro por préstamo/semana
-- abre_con = MAX(AbreCon) de pagos_v3 (el saldo inicial)
-- cierra_con = MIN(CierraCon) de pagos_v3 (el saldo final)

UPDATE pagos_dynamic pd
INNER JOIN (
    SELECT PrestamoID, Anio, Semana,
           MAX(AbreCon) as abre_con_correcto,
           MIN(CierraCon) as cierra_con_correcto
    FROM pagos_v3
    WHERE Anio = 2025 AND Semana IN (46, 47, 48)
    GROUP BY PrestamoID, Anio, Semana
) pv ON pd.prestamo_id = pv.PrestamoID
    AND pd.anio = pv.Anio
    AND pd.semana = pv.Semana
INNER JOIN prestamos_v2 p ON pd.prestamo_id = p.PrestamoID
SET pd.abre_con = pv.abre_con_correcto,
    pd.cierra_con = pv.cierra_con_correcto
WHERE pd.anio = 2025
  AND pd.semana IN (46, 47, 48)
  AND (ABS(pd.abre_con - pv.abre_con_correcto) > 0.001
       OR ABS(pd.cierra_con - pv.cierra_con_correcto) > 0.001);

SELECT CONCAT('pagos_dynamic sincronizados: ', ROW_COUNT()) as resultado;

-- =====================================================
-- PASO 5: Verificación
-- =====================================================
SELECT 'Verificación - discrepancias restantes:' as verificacion;

SELECT actual.Semana, COUNT(DISTINCT actual.PrestamoID) as discrepancias_restantes
FROM pagos_v3 actual
INNER JOIN (
    SELECT PrestamoID, Anio, Semana, MIN(CierraCon) as CierraConFinal
    FROM pagos_v3
    WHERE Anio = 2025 AND Semana IN (45, 46, 47)
    GROUP BY PrestamoID, Anio, Semana
) anterior ON actual.PrestamoID = anterior.PrestamoID
          AND anterior.Anio = actual.Anio
          AND anterior.Semana = actual.Semana - 1
INNER JOIN prestamos_v2 p ON actual.PrestamoID = p.PrestamoID
WHERE actual.Anio = 2025
  AND actual.Semana IN (46, 47, 48)
  AND ABS(actual.AbreCon - anterior.CierraConFinal) > 0.001
GROUP BY actual.Semana;
