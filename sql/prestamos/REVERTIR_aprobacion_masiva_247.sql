-- =====================================================================
-- SCRIPT DE REVERSIÓN: Aprobación masiva del 2026-01-26 16:10:46
-- Total a revertir: 247 préstamos
-- =====================================================================
-- IMPORTANTE: Ejecutar en orden y verificar cada paso
-- =====================================================================

-- Timestamp exxacto de la ejecución a revertir
SET @fecha_aprobacion = '2026-01-26 16:10:46';

-- =====================================================================
-- PASO 0: VERIFICACIÓN PREVIA (ejecutar primero para confirmar datos)
-- =====================================================================

-- Verificar préstamos a eliminar
SELECT 'PRESTAMOS A ELIMINAR' as verificacion, COUNT(*) as total
FROM prestamos_v2
WHERE created_at = @fecha_aprobacion;

-- Verificar pagos a eliminar (solo los de primer pago de borradores)
SELECT 'PAGOS A ELIMINAR' as verificacion, COUNT(*) as total
FROM pagos_v3
WHERE Created_at = @fecha_aprobacion
  AND Comentario LIKE 'Primer pago - borrador #%';

-- Verificar borradores a revertir
SELECT 'BORRADORES A REVERTIR' as verificacion, COUNT(*) as total
FROM prestamos_borradores
WHERE fecha_aprobacion = @fecha_aprobacion;

-- =====================================================================
-- PASO 1: ELIMINAR DE prestamos_dynamic
-- =====================================================================

DELETE pd FROM prestamos_dynamic pd
INNER JOIN prestamos_v2 p ON pd.prestamo_id = p.PrestamoID
WHERE p.created_at = @fecha_aprobacion;

SELECT ROW_COUNT() AS prestamos_dynamic_eliminados;

-- =====================================================================
-- PASO 2: ELIMINAR DE pagos_dynamic (si hay registros)
-- =====================================================================

DELETE pd FROM pagos_dynamic pd
INNER JOIN prestamos_v2 p ON pd.prestamo_id = p.PrestamoID
WHERE p.created_at = @fecha_aprobacion;

SELECT ROW_COUNT() AS pagos_dynamic_eliminados;

-- =====================================================================
-- PASO 3: ELIMINAR PAGOS DE pagos_v3
-- =====================================================================

DELETE FROM pagos_v3
WHERE Created_at = @fecha_aprobacion
  AND Comentario LIKE 'Primer pago - borrador #%';

SELECT ROW_COUNT() AS pagos_v3_eliminados;

-- =====================================================================
-- PASO 4: ELIMINAR PRÉSTAMOS DE prestamos_v2
-- =====================================================================

DELETE FROM prestamos_v2
WHERE created_at = @fecha_aprobacion;

SELECT ROW_COUNT() AS prestamos_v2_eliminados;

-- =====================================================================
-- PASO 5: REVERTIR ESTADO DE BORRADORES A 'PENDIENTE'
-- =====================================================================

UPDATE prestamos_borradores
SET
    estado_borrador = 'PENDIENTE',
    fecha_aprobacion = NULL,
    PrestamoID_propuesto = NULL
WHERE fecha_aprobacion = @fecha_aprobacion;

SELECT ROW_COUNT() AS borradores_revertidos;

-- =====================================================================
-- PASO 6: VERIFICACIÓN FINAL
-- =====================================================================

SELECT 'VERIFICACIÓN FINAL' as status;

SELECT estado_borrador, COUNT(*) as total
FROM prestamos_borradores
GROUP BY estado_borrador;

SELECT 'Préstamos con created_at del momento' as verificacion, COUNT(*) as debe_ser_cero
FROM prestamos_v2
WHERE created_at = @fecha_aprobacion;

SELECT 'Pagos de borradores del momento' as verificacion, COUNT(*) as debe_ser_cero
FROM pagos_v3
WHERE Created_at = @fecha_aprobacion
  AND Comentario LIKE 'Primer pago - borrador #%';
