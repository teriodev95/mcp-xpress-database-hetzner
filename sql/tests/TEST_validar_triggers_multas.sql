-- =====================================================
-- TEST: Validar funcionamiento de triggers de multas
-- Descripción: Inserta una multa de prueba en pagos_v3
--              y verifica que se copie a tabla multas
-- Fecha: 2026-01-20
-- =====================================================

-- Paso 1: Ver estado ANTES del INSERT
SELECT '=== ANTES DEL INSERT ===' as Estado;

SELECT COUNT(*) as multas_en_tabla_multas FROM multas;
SELECT COUNT(*) as multas_en_pagos_dynamic FROM pagos_dynamic WHERE tipo = 'Multa';

-- Paso 2: INSERT DE PRUEBA en pagos_v3 (tipo='Multa')
-- Este INSERT debería:
-- 1. Insertarse en pagos_v3
-- 2. Trigger copia automáticamente a tabla multas
-- 3. Si se inserta en pagos_dynamic, trigger lo elimina automáticamente

INSERT INTO pagos_v3 (
    pagoID,
    PrestamoID,
    Monto,
    Semana,
    Anio,
    Tipo,
    Agente,
    Fecha_pago,
    created_at
)
VALUES (
    UUID(),                                              -- pagoID único
    '2924-pl',                                           -- PrestamoID existente
    75.00,                                               -- Monto de multa
    3,                                                   -- Semana
    2026,                                                -- Año
    'Multa',                                             -- Tipo='Multa' (activa trigger)
    'AGP011',                                            -- Agencia
    CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),    -- Fecha pago
    CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')     -- created_at
);

-- Paso 3: Ver estado DESPUÉS del INSERT
SELECT '=== DESPUÉS DEL INSERT ===' as Estado;

-- Verificar que se creó en tabla multas (debe haber 3 ahora)
SELECT COUNT(*) as multas_en_tabla_multas FROM multas;

-- Ver la multa recién insertada
SELECT
    multa_id,
    prestamo_id,
    monto,
    semana,
    anio,
    agencia,
    DATE_FORMAT(fecha_multa, '%Y-%m-%d %H:%i:%s') as fecha_multa,
    DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') as created_at
FROM multas
WHERE prestamo_id = '2924-pl'
ORDER BY created_at DESC
LIMIT 2;

-- Verificar que sigue en 0 en pagos_dynamic
SELECT COUNT(*) as multas_en_pagos_dynamic FROM pagos_dynamic WHERE tipo = 'Multa';

-- Paso 4: Cleanup - Eliminar la multa de prueba
SELECT '=== LIMPIEZA ===' as Estado;

-- Eliminar multa de prueba de pagos_v3
DELETE FROM pagos_v3
WHERE PrestamoID = '2924-pl'
  AND Tipo = 'Multa'
  AND Monto = 75.00
  AND Semana = 3
  AND Anio = 2026;

-- Eliminar multa de prueba de tabla multas
DELETE FROM multas
WHERE prestamo_id = '2924-pl'
  AND monto = 75.00
  AND semana = 3
  AND anio = 2026;

-- Verificar estado final (debe volver a 2 multas)
SELECT COUNT(*) as multas_finales FROM multas;

SELECT '=== TEST COMPLETADO ===' as Estado;

-- =====================================================
-- RESULTADO ESPERADO:
-- =====================================================
-- ANTES: 2 multas en tabla multas, 0 en pagos_dynamic
-- DESPUÉS: 3 multas en tabla multas, 0 en pagos_dynamic
-- FINAL: 2 multas en tabla multas (después de cleanup)
--
-- Si los números coinciden, los triggers funcionan correctamente ✅
-- =====================================================
