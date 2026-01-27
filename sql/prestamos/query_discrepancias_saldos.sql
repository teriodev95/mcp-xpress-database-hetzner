-- =====================================================
-- Queries para Analizar Discrepancias de Saldos
-- =====================================================
-- Compara los saldos entre prestamos_v2 y prestamos_dynamic
-- para entender qué préstamos están listos para migrar
--
-- IMPORTANTE: prestamos_dynamic es la fuente de verdad
-- =====================================================

-- =====================================================
-- 1. RESUMEN DE DISCREPANCIAS
-- =====================================================

-- Resumen general de diferencias entre las tablas
SELECT
    COUNT(*) AS total_prestamos,
    SUM(CASE WHEN p.Saldo = pd.saldo THEN 1 ELSE 0 END) AS saldos_coinciden,
    SUM(CASE WHEN p.Saldo != pd.saldo THEN 1 ELSE 0 END) AS saldos_difieren,
    SUM(CASE WHEN p.Saldo = 0 AND pd.saldo = 0 THEN 1 ELSE 0 END) AS ambos_cero,
    SUM(CASE WHEN p.Saldo = 0 AND pd.saldo > 0 THEN 1 ELSE 0 END) AS v2_cero_dynamic_pendiente,
    SUM(CASE WHEN p.Saldo > 0 AND pd.saldo = 0 THEN 1 ELSE 0 END) AS v2_pendiente_dynamic_cero,
    SUM(CASE WHEN p.Cobrado = pd.cobrado THEN 1 ELSE 0 END) AS cobrado_coincide,
    SUM(CASE WHEN p.Cobrado != pd.cobrado THEN 1 ELSE 0 END) AS cobrado_difiere
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id;


-- =====================================================
-- 2. PRÉSTAMOS LISTOS PARA MIGRAR (SEGÚN DYNAMIC)
-- =====================================================

-- Préstamos con saldo = 0 en prestamos_dynamic
-- (estos son los que se migrarán)
SELECT
    p.PrestamoID,
    p.Cliente_ID,
    p.Nombres,
    p.Apellido_Paterno,
    p.Gerencia,
    p.Agente,
    p.Semana,
    p.Anio,
    p.Saldo AS saldo_v2,
    pd.saldo AS saldo_dynamic,
    p.Cobrado AS cobrado_v2,
    pd.cobrado AS cobrado_dynamic,
    (pd.cobrado - p.Cobrado) AS diferencia_cobrado
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE pd.saldo = 0 OR pd.saldo IS NULL
ORDER BY p.Gerencia, p.Agente, p.Semana DESC
LIMIT 100;

-- Conteo de préstamos listos para migrar por gerencia
SELECT
    p.Gerencia,
    COUNT(*) AS listos_para_migrar,
    SUM(pd.cobrado) AS total_cobrado,
    AVG(pd.cobrado) AS promedio_cobrado,
    SUM(CASE WHEN p.Saldo != pd.saldo THEN 1 ELSE 0 END) AS con_discrepancia_saldo
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE pd.saldo = 0 OR pd.saldo IS NULL
GROUP BY p.Gerencia
ORDER BY listos_para_migrar DESC;


-- =====================================================
-- 3. PRÉSTAMOS CON DISCREPANCIAS SIGNIFICATIVAS
-- =====================================================

-- Casos donde prestamos_v2 dice que el saldo es 0
-- pero prestamos_dynamic dice que aún hay saldo pendiente
SELECT
    p.PrestamoID,
    p.Nombres,
    p.Apellido_Paterno,
    p.Gerencia,
    p.Agente,
    p.Monto_otorgado,
    p.Saldo AS saldo_v2,
    pd.saldo AS saldo_dynamic,
    p.Cobrado AS cobrado_v2,
    pd.cobrado AS cobrado_dynamic,
    p.Total_a_pagar,
    (p.Total_a_pagar - pd.cobrado) AS diferencia_vs_total
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE p.Saldo = 0 AND pd.saldo > 0
ORDER BY pd.saldo DESC
LIMIT 50;

-- Casos donde prestamos_v2 dice que hay saldo pendiente
-- pero prestamos_dynamic dice que está completamente pagado
SELECT
    p.PrestamoID,
    p.Nombres,
    p.Apellido_Paterno,
    p.Gerencia,
    p.Agente,
    p.Monto_otorgado,
    p.Saldo AS saldo_v2,
    pd.saldo AS saldo_dynamic,
    p.Cobrado AS cobrado_v2,
    pd.cobrado AS cobrado_dynamic,
    p.Total_a_pagar,
    (p.Total_a_pagar - pd.cobrado) AS diferencia_vs_total
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE p.Saldo > 0 AND pd.saldo = 0
ORDER BY p.Saldo DESC
LIMIT 50;


-- =====================================================
-- 4. ANÁLISIS DE COBRADO
-- =====================================================

-- Comparar cobrado entre las dos tablas
SELECT
    CASE
        WHEN ABS(p.Cobrado - pd.cobrado) = 0 THEN 'Exactamente igual'
        WHEN ABS(p.Cobrado - pd.cobrado) < 10 THEN 'Diferencia < 10'
        WHEN ABS(p.Cobrado - pd.cobrado) < 100 THEN 'Diferencia < 100'
        WHEN ABS(p.Cobrado - pd.cobrado) < 1000 THEN 'Diferencia < 1000'
        ELSE 'Diferencia >= 1000'
    END AS rango_diferencia,
    COUNT(*) AS cantidad_prestamos,
    AVG(ABS(p.Cobrado - pd.cobrado)) AS promedio_diferencia,
    MAX(ABS(p.Cobrado - pd.cobrado)) AS max_diferencia
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
GROUP BY rango_diferencia
ORDER BY MIN(ABS(p.Cobrado - pd.cobrado));


-- =====================================================
-- 5. PRÉSTAMOS SIN REGISTRO EN PRESTAMOS_DYNAMIC
-- =====================================================

-- Préstamos en prestamos_v2 que NO tienen registro en prestamos_dynamic
SELECT
    p.PrestamoID,
    p.Nombres,
    p.Apellido_Paterno,
    p.Gerencia,
    p.Agente,
    p.Saldo,
    p.Cobrado,
    p.Semana,
    p.Anio,
    'NO EXISTE EN prestamos_dynamic' AS observacion
FROM prestamos_v2 p
LEFT JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE pd.prestamo_id IS NULL
LIMIT 100;


-- =====================================================
-- 6. DETALLE DE SALDOS Y COBRADOS
-- =====================================================

-- Ver detalle de los 50 préstamos con mayor diferencia en saldo
SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Agente,
    p.Monto_otorgado,
    p.Total_a_pagar,
    p.Saldo AS saldo_v2,
    pd.saldo AS saldo_dynamic,
    ABS(p.Saldo - pd.saldo) AS diferencia_saldo,
    p.Cobrado AS cobrado_v2,
    pd.cobrado AS cobrado_dynamic,
    ABS(p.Cobrado - pd.cobrado) AS diferencia_cobrado,
    CASE
        WHEN pd.saldo = 0 THEN 'LISTO PARA MIGRAR'
        WHEN p.Saldo = 0 AND pd.saldo > 0 THEN 'v2 dice completado pero dynamic NO'
        WHEN p.Saldo > 0 AND pd.saldo = 0 THEN 'dynamic dice completado pero v2 NO'
        ELSE 'Ambos pendientes'
    END AS estado
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE p.Saldo != pd.saldo
ORDER BY ABS(p.Saldo - pd.saldo) DESC
LIMIT 50;


-- =====================================================
-- 7. VERIFICACIÓN DE INTEGRIDAD DE DATOS
-- =====================================================

-- Verificar si hay préstamos con cobrado > Total_a_pagar
SELECT
    COUNT(*) AS prestamos_con_sobrepago,
    SUM(pd.cobrado - p.Total_a_pagar) AS total_sobrepagado
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE pd.cobrado > p.Total_a_pagar;

-- Ver ejemplos de préstamos con sobrepago
SELECT
    p.PrestamoID,
    p.Gerencia,
    p.Monto_otorgado,
    p.Total_a_pagar,
    pd.cobrado,
    (pd.cobrado - p.Total_a_pagar) AS sobrepago,
    pd.saldo
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
WHERE pd.cobrado > p.Total_a_pagar
LIMIT 20;


-- =====================================================
-- 8. CONSULTA UNIFICADA PARA AUDITORÍA
-- =====================================================

-- Vista completa de un préstamo específico (reemplazar 'ID_PRESTAMO')
-- SELECT
--     p.*,
--     pd.saldo AS saldo_dynamic,
--     pd.cobrado AS cobrado_dynamic,
--     'prestamos_v2' AS tabla
-- FROM prestamos_v2 p
-- LEFT JOIN prestamos_dynamic pd ON p.PrestamoID = pd.prestamo_id
-- WHERE p.PrestamoID = 'ID_PRESTAMO';


-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
-- 1. prestamos_dynamic es mantenida por triggers que se ejecutan
--    cuando hay cambios en pagos_dynamic
--
-- 2. Los valores en prestamos_v2 pueden estar desactualizados si:
--    - Se insertaron/actualizaron pagos directamente
--    - Hubo errores en la sincronización
--    - Se hicieron correcciones manuales
--
-- 3. Para la migración, SIEMPRE usar prestamos_dynamic.saldo
--    como criterio de verdad
--
-- 4. Las discrepancias deben investigarse antes de migrar
--    para asegurar la integridad de los datos
-- =====================================================
