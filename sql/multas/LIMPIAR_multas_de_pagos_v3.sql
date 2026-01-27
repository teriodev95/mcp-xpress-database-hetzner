-- =====================================================
-- Script: Limpiar multas de pagos_v3
-- Descripción: Elimina todas las multas de pagos_v3
--              Las multas ya están en tabla multas separada
-- Fecha: 2026-01-20
-- =====================================================

-- IMPORTANTE: Ejecutar SOLO después de validar que todas las multas
-- están correctamente copiadas en tabla multas

-- =====================================================
-- PASO 1: Validación ANTES de eliminar
-- =====================================================

SELECT '=== VALIDACIÓN ANTES DE ELIMINAR ===' as paso;

-- Contar multas en pagos_v3
SELECT COUNT(*) as multas_en_pagos_v3
FROM pagos_v3
WHERE Tipo = 'Multa';

-- Contar multas en tabla multas
SELECT COUNT(*) as multas_en_tabla_multas
FROM multas;

-- Ver las multas que se eliminarán
SELECT
    pagoID,
    PrestamoID,
    Monto,
    Semana,
    Anio,
    Agente,
    DATE_FORMAT(Fecha_pago, '%Y-%m-%d %H:%i:%s') as Fecha_pago
FROM pagos_v3
WHERE Tipo = 'Multa'
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- PASO 2: Validar que todas las multas de pagos_v3
--         existen en tabla multas
-- =====================================================

SELECT '=== VALIDACIÓN DE INTEGRIDAD ===' as paso;

-- Multas en pagos_v3 que NO están en tabla multas (debe ser 0)
SELECT COUNT(*) as multas_faltantes
FROM pagos_v3 pv
WHERE pv.Tipo = 'Multa'
  AND NOT EXISTS (
      SELECT 1
      FROM multas m
      WHERE m.multa_id = pv.pagoID
  );

-- Si multas_faltantes > 0, NO ejecutar el DELETE

-- =====================================================
-- PASO 3: ELIMINAR multas de pagos_v3
-- =====================================================

-- DESCOMENTAR SOLO SI LA VALIDACIÓN ES EXITOSA:
/*
DELETE FROM pagos_v3
WHERE Tipo = 'Multa';

SELECT ROW_COUNT() as multas_eliminadas;
*/

-- =====================================================
-- PASO 4: Verificación DESPUÉS de eliminar
-- =====================================================

SELECT '=== VERIFICACIÓN FINAL ===' as paso;

-- Debe retornar 0
SELECT COUNT(*) as multas_restantes_en_pagos_v3
FROM pagos_v3
WHERE Tipo = 'Multa';

-- Debe tener el total original
SELECT COUNT(*) as multas_en_tabla_multas
FROM multas;

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- 1. multas_en_pagos_v3: N (antes de eliminar)
-- 2. multas_en_tabla_multas: N (mismo número)
-- 3. multas_faltantes: 0 (todas están copiadas)
-- 4. Después de DELETE: multas_restantes = 0
-- =====================================================

-- =====================================================
-- IMPORTANTE:
-- =====================================================
-- Después de ejecutar este script:
-- 1. Las multas solo existirán en tabla multas
-- 2. pagos_v3 solo tendrá pagos normales, visitas, no_pagos
-- 3. Las nuevas multas se deben insertar con sp_insertar_multa()
-- 4. NO usar INSERT directo en pagos_v3 con Tipo='Multa'
-- =====================================================
