-- =====================================================
-- Script: Eliminar trigger trg_multas_after_insert
-- Descripción: Elimina el trigger que causaba error de tabla bloqueada
-- Fecha: 2026-01-20
-- =====================================================

DROP TRIGGER IF EXISTS trg_multas_after_insert;

-- Verificar que se eliminó correctamente
SELECT 'Trigger trg_multas_after_insert eliminado exitosamente' as resultado;

-- Verificar triggers restantes en tabla multas
SELECT TRIGGER_NAME, EVENT_MANIPULATION, ACTION_TIMING
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE TRIGGER_SCHEMA = 'xpress_dinero'
  AND EVENT_OBJECT_TABLE = 'multas';
