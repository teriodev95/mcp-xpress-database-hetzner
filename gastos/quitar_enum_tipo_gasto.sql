-- ============================================
-- QUITAR COLUMNA tipo_gasto (ENUM REDUNDANTE)
-- ============================================
-- EJECUTAR SOLO DESPUÉS DE VERIFICAR QUE LA APP
-- YA USA concepto_id EN LUGAR DE tipo_gasto
-- ============================================

-- ============================================
-- PASO 1: Corregir registros huérfanos
-- ============================================
-- Asignar concepto_id a registros que aún no lo tienen

UPDATE gastos SET concepto_id = 12 WHERE tipo_gasto = 'GASOLINA' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 18 WHERE tipo_gasto = 'CASETAS' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 35 WHERE tipo_gasto = 'MANTENIMIENTO_VEHICULAR' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 9  WHERE tipo_gasto = 'CELULAR' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 69 WHERE tipo_gasto = 'VIATICOS' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 15 WHERE tipo_gasto = 'ALIMENTACION' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 11 WHERE tipo_gasto = 'SERVICIOS' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 1  WHERE tipo_gasto = 'VIVIENDA' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 13 WHERE tipo_gasto = 'SALUD' AND concepto_id IS NULL;
UPDATE gastos SET concepto_id = 19 WHERE tipo_gasto = 'OTROS' AND concepto_id IS NULL;


-- ============================================
-- PASO 2: Verificar que no queden NULL
-- ============================================
-- SELECT COUNT(*) as huerfanos FROM gastos WHERE concepto_id IS NULL;
-- Si retorna 0, continuar. Si no, investigar.


-- ============================================
-- PASO 3: Hacer concepto_id NOT NULL
-- ============================================
ALTER TABLE gastos MODIFY concepto_id SMALLINT UNSIGNED NOT NULL;


-- ============================================
-- PASO 4: Agregar FK (integridad referencial)
-- ============================================
ALTER TABLE gastos
ADD CONSTRAINT fk_gastos_concepto
FOREIGN KEY (concepto_id) REFERENCES gastos_conceptos(id);


-- ============================================
-- PASO 5: Quitar columna tipo_gasto
-- ============================================
ALTER TABLE gastos DROP COLUMN tipo_gasto;


-- ============================================
-- PASO 6: Actualizar vista vw_gastos_detalle
-- ============================================
CREATE OR REPLACE VIEW vw_gastos_detalle AS
SELECT
    g.gasto_id,
    g.creado_por_id,
    g.gerencia,
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
INNER JOIN gastos_conceptos gc ON g.concepto_id = gc.id
INNER JOIN gastos_categorias cat ON gc.cat_id = cat.id;


-- ============================================
-- VERIFICACIÓN FINAL
-- ============================================
-- DESCRIBE gastos;
-- SELECT * FROM vw_gastos_detalle LIMIT 5;
