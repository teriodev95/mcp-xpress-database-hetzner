-- ============================================
-- MIGRACIÓN SEGURA DE TABLA GASTOS
-- No elimina columnas, solo agrega
-- ============================================

-- ============================================
-- PASO 1: Crear tablas de catálogo (si no existen)
-- ============================================
-- Ejecutar primero: crear_catalogo_gastos.sql


-- ============================================
-- PASO 2: Agregar columna concepto_id a gastos
-- ============================================
-- Esta columna es NULLABLE inicialmente para no romper inserts existentes

ALTER TABLE gastos
ADD COLUMN concepto_id SMALLINT UNSIGNED NULL AFTER tipo_gasto,
ADD INDEX idx_concepto (concepto_id);

-- Agregar FK (opcional, solo si quieres integridad referencial)
-- ALTER TABLE gastos
-- ADD CONSTRAINT fk_gastos_concepto
-- FOREIGN KEY (concepto_id) REFERENCES gastos_conceptos(id);


-- ============================================
-- PASO 3: Poblar concepto_id basado en tipo_gasto
-- ============================================
-- Mapeo del ENUM actual a los nuevos IDs

UPDATE gastos SET concepto_id = 12 WHERE tipo_gasto = 'GASOLINA';
UPDATE gastos SET concepto_id = 18 WHERE tipo_gasto = 'CASETAS';
UPDATE gastos SET concepto_id = 35 WHERE tipo_gasto = 'MANTENIMIENTO_VEHICULAR';
UPDATE gastos SET concepto_id = 9  WHERE tipo_gasto = 'CELULAR';
UPDATE gastos SET concepto_id = 69 WHERE tipo_gasto = 'VIATICOS';
UPDATE gastos SET concepto_id = 15 WHERE tipo_gasto = 'ALIMENTACION';
UPDATE gastos SET concepto_id = 11 WHERE tipo_gasto = 'SERVICIOS';
UPDATE gastos SET concepto_id = 1  WHERE tipo_gasto = 'VIVIENDA';
UPDATE gastos SET concepto_id = 13 WHERE tipo_gasto = 'SALUD';
UPDATE gastos SET concepto_id = 19 WHERE tipo_gasto = 'OTROS';


-- ============================================
-- PASO 4: Verificar migración
-- ============================================

-- Verificar que todos los registros tienen concepto_id
-- SELECT COUNT(*) as total,
--        SUM(CASE WHEN concepto_id IS NULL THEN 1 ELSE 0 END) as sin_concepto
-- FROM gastos;

-- Ver mapeo resultante
-- SELECT tipo_gasto, concepto_id, COUNT(*) as registros
-- FROM gastos
-- GROUP BY tipo_gasto, concepto_id
-- ORDER BY tipo_gasto;


-- ============================================
-- VISTA ACTUALIZADA PARA CONSULTAS
-- ============================================
CREATE OR REPLACE VIEW vw_gastos_detalle AS
SELECT
    g.gasto_id,
    g.creado_por_id,
    g.gerencia,
    g.tipo_gasto AS tipo_gasto_legacy,
    g.concepto_id,
    gc.nombre AS concepto,
    cat.codigo AS cat_codigo,
    cat.nombre AS categoria,
    g.fecha,
    g.semana,
    g.anio,
    g.monto,
    g.litros,
    g.concepto AS descripcion,
    g.url_recibo,
    g.reembolsado,
    g.created_at
FROM gastos g
LEFT JOIN gastos_conceptos gc ON g.concepto_id = gc.id
LEFT JOIN gastos_categorias cat ON gc.cat_id = cat.id;


-- ============================================
-- QUERIES DE EJEMPLO CON NUEVA ESTRUCTURA
-- ============================================

-- Gastos por categoría (nueva forma)
-- SELECT cat_codigo, categoria, COUNT(*) as registros, SUM(monto) as total
-- FROM vw_gastos_detalle
-- WHERE anio = 2025
-- GROUP BY cat_codigo, categoria
-- ORDER BY total DESC;

-- Gastos por concepto específico
-- SELECT * FROM vw_gastos_detalle WHERE concepto_id = 12; -- Gasolina

-- Buscar por categoría
-- SELECT * FROM vw_gastos_detalle WHERE cat_codigo = 'FRE'; -- Frecuentes


-- ============================================
-- NOTAS IMPORTANTES
-- ============================================
--
-- 1. La columna tipo_gasto (ENUM) sigue existiendo y funcional
-- 2. Los nuevos registros pueden usar concepto_id directamente
-- 3. La app puede migrar gradualmente al nuevo sistema
-- 4. Cuando estés listo, puedes:
--    a) Hacer concepto_id NOT NULL
--    b) Deprecar tipo_gasto (no borrar, solo dejar de usar)
--
-- Para hacer concepto_id obligatorio (CUANDO ESTÉS LISTO):
-- ALTER TABLE gastos MODIFY concepto_id SMALLINT UNSIGNED NOT NULL;
