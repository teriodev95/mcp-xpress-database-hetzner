-- =====================================================
-- Corrección de Saldos Duplicados
-- Préstamos semana 47/2025 con doble aplicación de pago
-- =====================================================

-- =====================================================
-- DIAGNÓSTICO
-- =====================================================

-- Ver préstamos afectados (674 registros)
SELECT
    pv.PrestamoID,
    pv.Total_a_pagar,
    pv.Tarifa,
    pd.saldo AS saldo_actual,
    pd.cobrado AS cobrado_actual,
    SUM(pg.Monto) AS suma_pagos,
    pd.cobrado - SUM(pg.Monto) AS diferencia,
    pv.Total_a_pagar - SUM(pg.Monto) AS saldo_correcto,
    SUM(pg.Monto) AS cobrado_correcto
FROM prestamos_v2 pv
INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
INNER JOIN pagos_v3 pg ON pv.PrestamoID = pg.PrestamoID
WHERE pv.Semana = 47 AND pv.Anio = 2025
  AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
GROUP BY pv.PrestamoID, pv.Total_a_pagar, pv.Tarifa, pd.saldo, pd.cobrado
HAVING ABS(pd.cobrado - SUM(pg.Monto)) > 1;

-- =====================================================
-- CORRECCIÓN
-- =====================================================

-- Actualizar prestamos_dynamic con saldo/cobrado correcto
UPDATE prestamos_dynamic pd
INNER JOIN (
    SELECT
        pv.PrestamoID,
        pv.Total_a_pagar - SUM(pg.Monto) AS saldo_correcto,
        SUM(pg.Monto) AS cobrado_correcto
    FROM prestamos_v2 pv
    INNER JOIN pagos_v3 pg ON pv.PrestamoID = pg.PrestamoID
    WHERE pv.Semana = 47 AND pv.Anio = 2025
      AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
    GROUP BY pv.PrestamoID, pv.Total_a_pagar
) calc ON pd.prestamo_id = calc.PrestamoID
SET pd.saldo = calc.saldo_correcto,
    pd.cobrado = calc.cobrado_correcto;

-- Sincronizar prestamos_v2 con prestamos_dynamic
UPDATE prestamos_v2 pv
INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
SET pv.Saldo = pd.saldo,
    pv.Cobrado = pd.cobrado
WHERE pv.Semana = 47 AND pv.Anio = 2025;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

-- Confirmar que ya no hay discrepancias
SELECT COUNT(*) AS prestamos_con_diferencia
FROM prestamos_v2 pv
INNER JOIN prestamos_dynamic pd ON pv.PrestamoID = pd.prestamo_id
INNER JOIN pagos_v3 pg ON pv.PrestamoID = pg.PrestamoID
WHERE pv.Semana = 47 AND pv.Anio = 2025
  AND pg.Tipo NOT IN ('Multa', 'Visita', 'No_pago')
GROUP BY pv.PrestamoID, pd.cobrado
HAVING ABS(pd.cobrado - SUM(pg.Monto)) > 1;
