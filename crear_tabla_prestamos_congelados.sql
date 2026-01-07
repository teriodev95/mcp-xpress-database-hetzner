-- =====================================================
-- TABLA PRESTAMOS_CONGELADOS (VERSIÓN SIMPLE)
-- =====================================================

-- 1. CREAR TABLA (copia exacta de prestamos_v2)
CREATE TABLE IF NOT EXISTS prestamos_congelados LIKE prestamos_v2;


-- =====================================================
-- 2. MOVER PRÉSTAMOS DE AGE000 A CONGELADOS
-- =====================================================

-- Paso 1: Insertar en congelados
INSERT INTO prestamos_congelados
SELECT * FROM prestamos_v2 WHERE Agente = 'AGE000';

-- Paso 2: Eliminar de prestamos_v2
DELETE FROM prestamos_v2 WHERE Agente = 'AGE000';
