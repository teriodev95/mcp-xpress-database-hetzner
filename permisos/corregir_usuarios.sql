-- ============================================
-- CORRECCIÓN DE USUARIOS DUPLICADOS
-- ============================================

-- 1. Borrar referencias en tablas relacionadas
DELETE FROM usuarios_sucursales WHERE usuario_id IN (770, 771, 768, 399);

-- 2. BORRAR duplicados
DELETE FROM usuarios WHERE UsuarioID IN (770, 771, 768, 399);
-- 770: DULCE KARINA JULIAN MARCELINO (duplicado de 427)
-- 771: LILIANA ARADITH PEREZ HERNANDEZ (duplicado de 432)
-- 768: MARIELA PEREZ RANGEL (duplicado de 426)
-- 399: MARISOL CASAS RAMIREZ CallCenter (conservar 440 Oficina)

-- 3. Cambiar Administrativo a Oficina
UPDATE usuarios SET Tipo = 'Oficina' WHERE UsuarioID IN (657, 659);
-- 657: LAURA REBECA VEGA VALERIO
-- 659: VALENTINA GALINDO MUÑOZ
