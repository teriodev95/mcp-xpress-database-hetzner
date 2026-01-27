-- ============================================
-- SISTEMA DE PERMISOS MOX (SIMPLE)
-- Usa el campo Tipo de la tabla usuarios
-- ============================================

-- 1. Borrar tablas innecesarias
DROP TABLE IF EXISTS tipos_usuario_modulos;
DROP TABLE IF EXISTS usuarios_modulos;
DROP TABLE IF EXISTS usuarios_tipo;
DROP TABLE IF EXISTS tipos_usuario;

-- 2. Actualizar plataforma a MOX
UPDATE plataformas SET nombre = 'mox', description = 'Módulo Oficina Xpress' WHERE id = 1;

-- 3. Agregar módulos faltantes
INSERT INTO modulos (plataforma_id, nombre) VALUES
(1, 'dashboard'),
(1, 'flujo-efectivo'),
(1, 'solicitudes'),
(1, 'prestamos'),
(1, 'pagares'),
(1, 'gastos'),
(1, 'liquidaciones'),
(1, 'bonos'),
(1, 'simulador-credito'),
(1, 'pines-dinamicos'),
(1, 'respaldo-pagos'),
(1, 'calendario'),
(1, 'reporte-agencias'),
(1, 'reporte-diario-agencias'),
(1, 'reporte-gerencia'),
(1, 'snapshots-agencia'),
(1, 'snapshots-gerencia'),
(1, 'rh');

-- ============================================
-- LÓGICA DE PERMISOS (en código, no en BD)
-- ============================================
--
-- Tipo "Jefe de Admin" → Todo menos 'rh'
-- Tipo "Oficina"       → Solo: dashboard, cobranza, desglose,
--                        resumen-ventas, resumen-asignaciones,
--                        flujo-efectivo, detalles-cierre, solicitudes
--
-- ============================================

-- Query para obtener módulos según tipo de usuario:

-- JEFA (Jefe de Admin):
-- SELECT nombre FROM modulos WHERE plataforma_id = 1 AND nombre != 'rh' AND activo = 1;

-- OFICINA:
-- SELECT nombre FROM modulos WHERE plataforma_id = 1 AND activo = 1
-- AND nombre IN ('dashboard','cobranza','desglose','resumen-ventas',
--                'resumen-asignaciones','flujo-efectivo','detalles-cierre','solicitudes');
