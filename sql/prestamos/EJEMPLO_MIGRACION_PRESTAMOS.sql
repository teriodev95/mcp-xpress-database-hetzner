-- =====================================================
-- EJEMPLO PASO A PASO: Migración de Préstamos Completados
-- =====================================================
-- Este archivo muestra el proceso completo con ejemplos
-- de salida esperada en cada paso
-- =====================================================

-- =====================================================
-- PASO 1: Verificar estado actual de prestamos_v2
-- =====================================================

-- ¿Cuántos préstamos hay actualmente en prestamos_v2?
SELECT
    COUNT(*) AS total_prestamos_activos,
    SUM(CASE WHEN Saldo > 0 THEN 1 ELSE 0 END) AS con_saldo_pendiente,
    SUM(CASE WHEN Saldo = 0 THEN 1 ELSE 0 END) AS saldo_cero
FROM prestamos_v2;

-- Ejemplo de salida:
-- +--------------------------+-------------------------+-------------+
-- | total_prestamos_activos  | con_saldo_pendiente     | saldo_cero  |
-- +--------------------------+-------------------------+-------------+
-- | 14418                    | 12895                   | 1523        |
-- +--------------------------+-------------------------+-------------+


-- =====================================================
-- PASO 2: Ver detalle de préstamos listos para migrar
-- =====================================================

-- Ver algunos préstamos con Saldo = 0
SELECT
    PrestamoID,
    Cliente_ID,
    Nombres,
    Apellido_Paterno,
    Gerencia,
    Agente,
    Monto_otorgado,
    Cobrado,
    Saldo,
    Semana,
    Anio
FROM prestamos_v2
WHERE Saldo = 0
ORDER BY Anio DESC, Semana DESC
LIMIT 10;

-- Ejemplo de salida:
-- +-------------+-------------+----------+------------------+-----------+---------+-----------------+---------+-------+--------+------+
-- | PrestamoID  | Cliente_ID  | Nombres  | Apellido_Paterno | Gerencia  | Agente  | Monto_otorgado  | Cobrado | Saldo | Semana | Anio |
-- +-------------+-------------+----------+------------------+-----------+---------+-----------------+---------+-------+--------+------+
-- | P001234     | C005678     | MARIA    | GONZALEZ         | GERE001   | A001    | 5000            | 6000.00 | 0.00  | 42     | 2025 |
-- | P001235     | C005679     | JUAN     | PEREZ            | GERC002   | A012    | 3000            | 3600.00 | 0.00  | 41     | 2025 |
-- | ...         | ...         | ...      | ...              | ...       | ...     | ...             | ...     | ...   | ...    | ...  |
-- +-------------+-------------+----------+------------------+-----------+---------+-----------------+---------+-------+--------+------+


-- =====================================================
-- PASO 3: Ejecutar verificación de préstamos completados
-- =====================================================

-- Este procedimiento NO ejecuta la migración, solo muestra estadísticas
CALL verificar_prestamos_completados();

-- Ejemplo de salida (primer resultado - resumen general):
-- +---------------------------+---------------+--------------------+------------------+---------------------+-------------------+
-- | total_prestamos_completados| total_cobrado| semana_mas_antigua | anio_mas_antiguo | semana_mas_reciente | anio_mas_reciente |
-- +---------------------------+---------------+--------------------+------------------+---------------------+-------------------+
-- | 1523                      | 2847563.50    | 1                  | 2023             | 42                  | 2025              |
-- +---------------------------+---------------+--------------------+------------------+---------------------+-------------------+

-- Ejemplo de salida (segundo resultado - por gerencia):
-- +-----------+-------------------------+---------------+
-- | Gerencia  | prestamos_completados   | total_cobrado |
-- +-----------+-------------------------+---------------+
-- | GERE001   | 234                     | 456789.00     |
-- | GERE002   | 198                     | 387654.50     |
-- | GERC001   | 175                     | 342156.25     |
-- | GERC002   | 162                     | 318765.00     |
-- | GERD001   | 143                     | 279543.75     |
-- | ...       | ...                     | ...           |
-- +-----------+-------------------------+---------------+


-- =====================================================
-- PASO 4: Verificar que la tabla de respaldo existe
-- =====================================================

-- Si esta query falla, necesitas ejecutar crear_tabla_prestamos_completados.sql
SELECT COUNT(*) AS registros_actuales
FROM prestamos_completados;

-- Si la tabla está vacía (primera migración):
-- +---------------------+
-- | registros_actuales  |
-- +---------------------+
-- | 0                   |
-- +---------------------+

-- Si ya se han hecho migraciones anteriores:
-- +---------------------+
-- | registros_actuales  |
-- +---------------------+
-- | 8542                |
-- +---------------------+


-- =====================================================
-- PASO 5: Ejecutar la migración (¡IMPORTANTE!)
-- =====================================================

-- Este procedimiento SÍ ejecuta la migración:
-- 1. Inserta préstamos con Saldo = 0 en prestamos_completados
-- 2. Los elimina de prestamos_v2
-- 3. Todo en una transacción (ROLLBACK automático si hay error)

CALL migrar_prestamos_completados();

-- Ejemplo de salida:
-- +---------------------+--------------------------------------------------------------+---------------------+
-- | registros_migrados  | mensaje                                                      | fecha_migracion     |
-- +---------------------+--------------------------------------------------------------+---------------------+
-- | 1523                | Se migraron 1523 préstamos completados exitosamente         | 2025-11-19 10:30:45 |
-- +---------------------+--------------------------------------------------------------+---------------------+


-- =====================================================
-- PASO 6: Verificar el resultado de la migración
-- =====================================================

-- 6.1 Verificar que prestamos_v2 ya no tiene préstamos con Saldo = 0
SELECT COUNT(*) AS prestamos_saldo_cero
FROM prestamos_v2
WHERE Saldo = 0;

-- Resultado esperado (debe ser 0):
-- +-----------------------+
-- | prestamos_saldo_cero  |
-- +-----------------------+
-- | 0                     |
-- +-----------------------+


-- 6.2 Verificar cuántos préstamos hay ahora en prestamos_completados
SELECT COUNT(*) AS total_prestamos_completados
FROM prestamos_completados;

-- Si era la primera migración (antes tenía 0):
-- +----------------------------+
-- | total_prestamos_completados|
-- +----------------------------+
-- | 1523                       |
-- +----------------------------+

-- Si ya había migraciones anteriores (antes tenía 8542):
-- +----------------------------+
-- | total_prestamos_completados|
-- +----------------------------+
-- | 10065                      | (8542 + 1523)
-- +----------------------------+


-- 6.3 Ver los préstamos recién migrados
SELECT
    PrestamoID,
    Nombres,
    Apellido_Paterno,
    Gerencia,
    Cobrado,
    created_at
FROM prestamos_completados
WHERE DATE(created_at) = CURDATE()
ORDER BY created_at DESC
LIMIT 10;

-- Ejemplo de salida:
-- +-------------+----------+------------------+-----------+---------+---------------------+
-- | PrestamoID  | Nombres  | Apellido_Paterno | Gerencia  | Cobrado | created_at          |
-- +-------------+----------+------------------+-----------+---------+---------------------+
-- | P001234     | MARIA    | GONZALEZ         | GERE001   | 6000.00 | 2025-11-19 10:30:45 |
-- | P001235     | JUAN     | PEREZ            | GERC002   | 3600.00 | 2025-11-19 10:30:45 |
-- | P001236     | CARLOS   | LOPEZ            | GERD003   | 4200.00 | 2025-11-19 10:30:45 |
-- | ...         | ...      | ...              | ...       | ...     | ...                 |
-- +-------------+----------+------------------+-----------+---------+---------------------+


-- =====================================================
-- PASO 7: Análisis post-migración (opcional)
-- =====================================================

-- 7.1 Comparar estado antes y después
SELECT
    'Activos en prestamos_v2' AS tabla,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total
FROM prestamos_v2
UNION ALL
SELECT
    'Completados migrados' AS tabla,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total
FROM prestamos_completados
WHERE DATE(created_at) = CURDATE();

-- Ejemplo de salida:
-- +---------------------------+----------+--------------+
-- | tabla                     | cantidad | monto_total  |
-- +---------------------------+----------+--------------+
-- | Activos en prestamos_v2   | 12895    | 87456321.50  |
-- | Completados migrados      | 1523     | 8234567.25   |
-- +---------------------------+----------+--------------+


-- 7.2 Ver distribución de préstamos migrados por gerencia
SELECT
    Gerencia,
    COUNT(*) AS migrados_hoy,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
WHERE DATE(created_at) = CURDATE()
GROUP BY Gerencia
ORDER BY migrados_hoy DESC;

-- Ejemplo de salida:
-- +-----------+---------------+---------------+
-- | Gerencia  | migrados_hoy  | total_cobrado |
-- +-----------+---------------+---------------+
-- | GERE001   | 234           | 456789.00     |
-- | GERE002   | 198           | 387654.50     |
-- | GERC001   | 175           | 342156.25     |
-- | GERC002   | 162           | 318765.00     |
-- | ...       | ...           | ...           |
-- +-----------+---------------+---------------+


-- 7.3 Historial de todas las migraciones ejecutadas
SELECT
    DATE(created_at) AS fecha_migracion,
    COUNT(*) AS registros_migrados,
    SUM(Cobrado) AS total_cobrado,
    MIN(Semana) AS semana_min,
    MAX(Semana) AS semana_max,
    MIN(Anio) AS anio_min,
    MAX(Anio) AS anio_max
FROM prestamos_completados
GROUP BY DATE(created_at)
ORDER BY fecha_migracion DESC
LIMIT 10;

-- Ejemplo de salida:
-- +------------------+---------------------+---------------+------------+------------+----------+----------+
-- | fecha_migracion  | registros_migrados  | total_cobrado | semana_min | semana_max | anio_min | anio_max |
-- +------------------+---------------------+---------------+------------+------------+----------+----------+
-- | 2025-11-19       | 1523                | 2847563.50    | 1          | 42         | 2023     | 2025     |
-- | 2025-10-15       | 842                 | 1576234.25    | 1          | 38         | 2023     | 2025     |
-- | 2025-09-10       | 653                 | 1234567.00    | 5          | 35         | 2023     | 2025     |
-- | ...              | ...                 | ...           | ...        | ...        | ...      | ...      |
-- +------------------+---------------------+---------------+------------+------------+----------+----------+


-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

-- 1. La migración es transaccional: Si algo falla, se ejecuta ROLLBACK automático
-- 2. Los préstamos se copian CON TODOS sus datos originales
-- 3. Los campos created_at y updated_at se establecen automáticamente
-- 4. Si un préstamo ya existe en prestamos_completados (por PrestamoID), solo se actualiza updated_at
-- 5. Después de la migración, prestamos_v2 solo contiene préstamos con Saldo > 0

-- =====================================================
-- MANTENIMIENTO PERIÓDICO RECOMENDADO
-- =====================================================

-- Ejecutar mensualmente o según sea necesario:
-- 1. CALL verificar_prestamos_completados();
-- 2. Si hay préstamos listos, ejecutar: CALL migrar_prestamos_completados();
-- 3. Verificar el resultado con las queries del PASO 6

-- =====================================================
-- CONSULTAS ADICIONALES
-- =====================================================

-- Para más consultas de análisis, ver el archivo:
-- queries_prestamos_completados.sql

-- Para guía completa con instrucciones detalladas, ver:
-- GUIA_MIGRACION_PRESTAMOS.md
