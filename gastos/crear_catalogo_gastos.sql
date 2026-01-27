-- ============================================
-- CATÁLOGO DE GASTOS - ESTRUCTURA HÍBRIDA
-- ============================================

-- 1. TABLA DE CATEGORÍAS
-- ============================================
CREATE TABLE IF NOT EXISTS gastos_categorias (
    id          TINYINT UNSIGNED PRIMARY KEY,
    codigo      VARCHAR(3) NOT NULL UNIQUE,
    nombre      VARCHAR(50) NOT NULL,
    activo      TINYINT(1) NOT NULL DEFAULT 1,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar categorías
INSERT INTO gastos_categorias (id, codigo, nombre) VALUES
(1, 'FIJ', 'Gastos Fijos'),
(2, 'FRE', 'Gastos Frecuentes'),
(3, 'HER', 'Herramientas de Trabajo'),
(4, 'COM', 'Compras'),
(5, 'MAN', 'Mantenimiento'),
(6, 'LEG', 'Legal/Accidentes/Robos'),
(7, 'EVE', 'Eventos/Festejos'),
(8, 'CAP', 'Capacitación'),
(9, 'NOM', 'Nómina');


-- 2. TABLA DE CONCEPTOS
-- ============================================
CREATE TABLE IF NOT EXISTS gastos_conceptos (
    id          SMALLINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    cat_id      TINYINT UNSIGNED NOT NULL,
    nombre      VARCHAR(100) NOT NULL,
    activo      TINYINT(1) NOT NULL DEFAULT 1,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (cat_id) REFERENCES gastos_categorias(id),
    INDEX idx_cat (cat_id),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- INSERTAR CONCEPTOS POR CATEGORÍA
-- ============================================

-- CAT 1: GASTOS FIJOS (FIJ)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(1, 'Renta Local/Oficina'),
(1, 'Teléfono'),
(1, 'Internet'),
(1, 'Luz/Gas'),
(1, 'Servicio de Basura'),
(1, 'Soporte de App'),
(1, 'Página Web'),
(1, 'Renta Mensual Servidor'),
(1, 'Saldo de Celulares'),
(1, 'Pensiones/Rentas/Estacionamientos'),
(1, 'Otro Gasto Fijo');

-- CAT 2: GASTOS FRECUENTES (FRE)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(2, 'Gasolina'),
(2, 'Médico y Medicinas'),
(2, 'Papelería'),
(2, 'Despensa'),
(2, 'Intendente/Artículos de Limpieza'),
(2, 'Imprenta'),
(2, 'Casetas'),
(2, 'Otro Gasto Frecuente');

-- CAT 3: HERRAMIENTAS DE TRABAJO (HER)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(3, 'Compra de Celulares'),
(3, 'Compra de Tablet/Laptop'),
(3, 'Compra de Computadora'),
(3, 'Compra de Software/Paquetería'),
(3, 'Compra de Impresora'),
(3, 'Compra de Proyector'),
(3, 'Pago de Sistema de la Empresa'),
(3, 'Compra de Chips para Celulares'),
(3, 'Otra Herramienta de Trabajo');

-- CAT 4: COMPRAS (COM)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(4, 'Alarma'),
(4, 'Mobiliario'),
(4, 'Cámaras/Herramientas de Seguridad'),
(4, 'Diseños/Marca/Publicidad'),
(4, 'Baterías para Caja Fuerte'),
(4, 'Otra Compra');

-- CAT 5: MANTENIMIENTO (MAN)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(5, 'Mantenimiento de Automóvil'),
(5, 'Seguro de Automóvil'),
(5, 'Remodelación de Oficina/Limpieza/Accesorios'),
(5, 'Mantenimiento de Cómputo'),
(5, 'Carpintero/Vidrios'),
(5, 'Herrero/Cerrajero'),
(5, 'Material para Remodelación'),
(5, 'Otro Mantenimiento');

-- CAT 6: LEGAL/ACCIDENTES/ROBOS (LEG)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(6, 'Finiquitos/Liquidaciones Laborales'),
(6, 'Registro Público de la Propiedad'),
(6, 'Gastos Jurídicos'),
(6, 'Honorarios Jurídicos'),
(6, 'Despacho Externo'),
(6, 'Gastos Notariales'),
(6, 'Gastos Médicos Mayores'),
(6, 'Faltante/Robo Agentes'),
(6, 'Faltante/Robo Gerentes'),
(6, 'Otro Gasto Legal');

-- CAT 7: EVENTOS/FESTEJOS (EVE)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(7, 'Eventos de Integración de Personal'),
(7, 'Comidas Directores/GTS Directivos'),
(7, 'Desayuno Agentes'),
(7, 'Festejos por Aniversario'),
(7, 'Día de las Madres'),
(7, 'Día del Padre'),
(7, 'Comida Fin de Año/Brindis'),
(7, 'Obsequios/Premios/Roscas de Reyes'),
(7, 'Reconocimientos/Música'),
(7, 'Patrocinios/Bonos Fin de Año/Rifa'),
(7, 'Gastos CAMBACEO'),
(7, 'Comisión a Seguridad/Adornos/Caja de Ahorro'),
(7, 'Otro Evento/Festejo');

-- CAT 8: CAPACITACIÓN (CAP)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(8, 'Gastos por Capacitación'),
(8, 'Cursos de Capacitación Externos'),
(8, 'Aviso Clasificado'),
(8, 'Viáticos Autorizados'),
(8, 'Otro Gasto de Capacitación');

-- CAT 9: NÓMINA (NOM)
INSERT INTO gastos_conceptos (cat_id, nombre) VALUES
(9, 'Salarios'),
(9, 'Aguinaldo'),
(9, 'Prima Vacacional'),
(9, 'Bonos/Comisiones'),
(9, 'Finiquitos'),
(9, 'IMSS Patronal'),
(9, 'Infonavit'),
(9, 'Otro Gasto de Nómina');


-- ============================================
-- 3. VISTA PARA CONSULTAR CATÁLOGO COMPLETO
-- ============================================
CREATE OR REPLACE VIEW vw_catalogo_gastos AS
SELECT
    c.id,
    cat.codigo AS cat_codigo,
    cat.nombre AS categoria,
    c.nombre AS concepto,
    c.activo
FROM gastos_conceptos c
INNER JOIN gastos_categorias cat ON c.cat_id = cat.id
WHERE c.activo = 1
ORDER BY cat.id, c.id;


-- ============================================
-- CONSULTAS DE VERIFICACIÓN
-- ============================================

-- Ver catálogo completo
-- SELECT * FROM vw_catalogo_gastos;

-- Ver conceptos por categoría
-- SELECT cat_codigo, categoria, COUNT(*) as conceptos
-- FROM vw_catalogo_gastos
-- GROUP BY cat_codigo, categoria;

-- Buscar concepto por ID
-- SELECT * FROM vw_catalogo_gastos WHERE id = 12;

-- Buscar conceptos por categoría
-- SELECT * FROM vw_catalogo_gastos WHERE cat_codigo = 'FRE';
