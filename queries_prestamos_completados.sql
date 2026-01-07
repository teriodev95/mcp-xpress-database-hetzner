-- =====================================================
-- Queries Útiles para Préstamos Completados
-- =====================================================

-- =====================================================
-- 1. ESTADÍSTICAS GENERALES
-- =====================================================

-- Resumen general de préstamos completados
SELECT
    COUNT(*) AS total_prestamos,
    COUNT(DISTINCT cliente_persona_id) AS clientes_unicos,
    SUM(Monto_otorgado) AS monto_total_otorgado,
    SUM(Cobrado) AS total_cobrado,
    AVG(Monto_otorgado) AS promedio_prestamo,
    MIN(created_at) AS primer_registro,
    MAX(created_at) AS ultimo_registro
FROM prestamos_completados;

-- =====================================================
-- 2. ANÁLISIS POR GERENCIA
-- =====================================================

-- Préstamos completados por gerencia
SELECT
    Gerencia,
    COUNT(*) AS total_prestamos,
    SUM(Monto_otorgado) AS monto_otorgado,
    SUM(Cobrado) AS total_cobrado,
    AVG(plazo) AS plazo_promedio,
    COUNT(DISTINCT cliente_persona_id) AS clientes_unicos
FROM prestamos_completados
GROUP BY Gerencia
ORDER BY total_prestamos DESC;

-- =====================================================
-- 3. ANÁLISIS POR AGENTE
-- =====================================================

-- Top 20 agentes con más préstamos completados
SELECT
    Agente,
    Gerencia,
    COUNT(*) AS prestamos_completados,
    SUM(Monto_otorgado) AS monto_total,
    SUM(Cobrado) AS total_cobrado,
    AVG(Monto_otorgado) AS promedio_prestamo
FROM prestamos_completados
GROUP BY Agente, Gerencia
ORDER BY prestamos_completados DESC
LIMIT 20;

-- =====================================================
-- 4. ANÁLISIS TEMPORAL
-- =====================================================

-- Préstamos completados por año y semana de otorgamiento
SELECT
    Anio,
    Semana,
    COUNT(*) AS total_prestamos,
    SUM(Monto_otorgado) AS monto_otorgado,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY Anio, Semana
ORDER BY Anio DESC, Semana DESC
LIMIT 50;

-- Préstamos completados por mes de archivo (created_at)
SELECT
    YEAR(created_at) AS anio,
    MONTH(created_at) AS mes,
    COUNT(*) AS prestamos_migrados,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY YEAR(created_at), MONTH(created_at)
ORDER BY anio DESC, mes DESC;

-- =====================================================
-- 5. ANÁLISIS POR TIPO DE CRÉDITO
-- =====================================================

-- Distribución por tipo de crédito
SELECT
    Tipo_de_credito,
    COUNT(*) AS total_prestamos,
    SUM(Monto_otorgado) AS monto_total,
    AVG(Monto_otorgado) AS promedio,
    AVG(plazo) AS plazo_promedio
FROM prestamos_completados
GROUP BY Tipo_de_credito
ORDER BY total_prestamos DESC;

-- =====================================================
-- 6. ANÁLISIS DE CLIENTES
-- =====================================================

-- Clientes con más préstamos completados
SELECT
    cliente_persona_id,
    Nombres,
    Apellido_Paterno,
    Apellido_Materno,
    COUNT(*) AS prestamos_completados,
    SUM(Monto_otorgado) AS monto_total,
    SUM(Cobrado) AS total_cobrado,
    MIN(Anio) AS primer_anio,
    MAX(Anio) AS ultimo_anio
FROM prestamos_completados
WHERE cliente_persona_id IS NOT NULL
GROUP BY cliente_persona_id, Nombres, Apellido_Paterno, Apellido_Materno
HAVING prestamos_completados > 1
ORDER BY prestamos_completados DESC
LIMIT 50;

-- =====================================================
-- 7. ANÁLISIS DE PAGOS
-- =====================================================

-- Distribución de montos cobrados
SELECT
    CASE
        WHEN Cobrado < 1000 THEN '0-999'
        WHEN Cobrado < 2000 THEN '1000-1999'
        WHEN Cobrado < 3000 THEN '2000-2999'
        WHEN Cobrado < 5000 THEN '3000-4999'
        WHEN Cobrado < 10000 THEN '5000-9999'
        ELSE '10000+'
    END AS rango_cobrado,
    COUNT(*) AS cantidad,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY rango_cobrado
ORDER BY MIN(Cobrado);

-- =====================================================
-- 8. BÚSQUEDA DE PRÉSTAMOS ESPECÍFICOS
-- =====================================================

-- Buscar préstamos completados por cliente (reemplazar 'NOMBRE' con el nombre real)
-- SELECT *
-- FROM prestamos_completados
-- WHERE Nombres LIKE '%NOMBRE%'
--    OR Apellido_Paterno LIKE '%NOMBRE%'
--    OR Apellido_Materno LIKE '%NOMBRE%'
-- ORDER BY created_at DESC;

-- Buscar por PrestamoID específico
-- SELECT *
-- FROM prestamos_completados
-- WHERE PrestamoID = 'ID_DEL_PRESTAMO';

-- =====================================================
-- 9. ANÁLISIS DE RENDIMIENTO POR DÍA DE PAGO
-- =====================================================

-- Distribución de préstamos completados por día de pago
SELECT
    Dia_de_pago,
    COUNT(*) AS total_prestamos,
    AVG(Cobrado) AS promedio_cobrado,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY Dia_de_pago
ORDER BY total_prestamos DESC;

-- =====================================================
-- 10. PRÉSTAMOS CON DESCUENTOS O MULTAS
-- =====================================================

-- Préstamos completados con descuentos aplicados
SELECT
    COUNT(*) AS prestamos_con_descuento,
    SUM(Descuento) AS total_descuentos,
    AVG(Descuento) AS promedio_descuento,
    AVG(Porcentaje) AS porcentaje_promedio
FROM prestamos_completados
WHERE Descuento > 0;

-- Préstamos completados con multas aplicadas
SELECT
    COUNT(*) AS prestamos_con_multas,
    SUM(Multas) AS total_multas,
    AVG(Multas) AS promedio_multas
FROM prestamos_completados
WHERE Multas > 0;

-- =====================================================
-- 11. COMPARACIÓN: ACTIVOS VS COMPLETADOS
-- =====================================================

-- Comparar volumen de préstamos activos vs completados
SELECT
    'Activos' AS tipo,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total,
    SUM(Saldo) AS saldo_pendiente
FROM prestamos_v2
UNION ALL
SELECT
    'Completados' AS tipo,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total,
    0 AS saldo_pendiente
FROM prestamos_completados;

-- =====================================================
-- 12. AUDITORÍA DE MIGRACIONES
-- =====================================================

-- Ver últimas migraciones por fecha
SELECT
    DATE(created_at) AS fecha_migracion,
    COUNT(*) AS registros_migrados,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY DATE(created_at)
ORDER BY fecha_migracion DESC
LIMIT 30;

-- =====================================================
-- 13. PRÉSTAMOS POR SUCURSAL
-- =====================================================

-- Distribución por sucursal
SELECT
    SucursalID,
    COUNT(*) AS total_prestamos,
    SUM(Monto_otorgado) AS monto_total,
    AVG(Monto_otorgado) AS promedio
FROM prestamos_completados
WHERE SucursalID IS NOT NULL
GROUP BY SucursalID
ORDER BY total_prestamos DESC;
