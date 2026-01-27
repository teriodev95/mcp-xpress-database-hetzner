-- =====================================================
-- CONSULTAS DE AUDITORIA PARA LOGS DE PRESTAMOS_V2
-- =====================================================


-- =====================================================
-- CONSULTAS PARA prestamos_v2_create_log (Altas)
-- =====================================================

-- Préstamos creados hoy
SELECT fecha, prestamo_id, cliente_nombre, agente, monto_otorgado
FROM prestamos_v2_create_log
WHERE DATE(fecha) = CURDATE()
ORDER BY fecha DESC;

-- Préstamos creados por agencia en la última semana
SELECT agente, COUNT(*) AS total_creados, SUM(monto_otorgado) AS monto_total
FROM prestamos_v2_create_log
WHERE fecha >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY agente
ORDER BY total_creados DESC;

-- Buscar cuándo se creó un préstamo específico
SELECT * FROM prestamos_v2_create_log
WHERE prestamo_id = 'XXXXXX';


-- =====================================================
-- CONSULTAS PARA prestamos_v2_delete_log (Bajas)
-- =====================================================

-- Préstamos eliminados hoy
SELECT fecha, PrestamoID,
       CONCAT(Nombres, ' ', Apellido_Paterno) AS cliente,
       Agente, Monto_otorgado, Saldo
FROM prestamos_v2_delete_log
WHERE DATE(fecha) = CURDATE()
ORDER BY fecha DESC;

-- Préstamos eliminados esta semana
SELECT fecha, PrestamoID,
       CONCAT(Nombres, ' ', Apellido_Paterno) AS cliente,
       Agente, Saldo, usuario_db
FROM prestamos_v2_delete_log
WHERE fecha >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY fecha DESC;

-- Recuperar datos de un préstamo eliminado
SELECT * FROM prestamos_v2_delete_log
WHERE PrestamoID = 'XXXXXX';

-- Préstamos eliminados que tenían saldo pendiente (posible error)
SELECT fecha, PrestamoID,
       CONCAT(Nombres, ' ', Apellido_Paterno) AS cliente,
       Agente, Saldo, Cobrado
FROM prestamos_v2_delete_log
WHERE Saldo > 0
ORDER BY fecha DESC;


-- =====================================================
-- CONSULTAS PARA prestamos_v2_update_log (Cambios JSON)
-- =====================================================

-- Todos los cambios de hoy
SELECT fecha, prestamo_id, JSON_PRETTY(cambios) AS cambios
FROM prestamos_v2_update_log
WHERE DATE(fecha) = CURDATE()
ORDER BY fecha DESC;

-- Historia de cambios de un préstamo
SELECT fecha, JSON_PRETTY(cambios) AS cambios
FROM prestamos_v2_update_log
WHERE prestamo_id = 'XXXXXX'
ORDER BY fecha;

-- Cambios de Saldo (pagos)
SELECT fecha, prestamo_id,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Saldo.antes')) AS saldo_antes,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Saldo.despues')) AS saldo_despues,
       (CAST(JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Saldo.antes')) AS DECIMAL(10,2)) -
        CAST(JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Saldo.despues')) AS DECIMAL(10,2))) AS monto_pago
FROM prestamos_v2_update_log
WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Saldo')
  AND DATE(fecha) = CURDATE()
ORDER BY fecha DESC;

-- Traspasos de agencia
SELECT fecha, prestamo_id,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Agente.antes')) AS de_agencia,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Agente.despues')) AS a_agencia,
       usuario_db
FROM prestamos_v2_update_log
WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Agente')
ORDER BY fecha DESC;

-- Cambios de Status
SELECT fecha, prestamo_id,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Status.antes')) AS status_antes,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Status.despues')) AS status_nuevo
FROM prestamos_v2_update_log
WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Status')
ORDER BY fecha DESC;

-- Multas aplicadas
SELECT fecha, prestamo_id,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Multas.antes')) AS multas_antes,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.Multas.despues')) AS multas_despues
FROM prestamos_v2_update_log
WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Multas')
ORDER BY fecha DESC;

-- Cambios que afectan comisión
SELECT fecha, prestamo_id,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.impacta_en_comision.antes')) AS antes,
       JSON_UNQUOTE(JSON_EXTRACT(cambios, '$.impacta_en_comision.despues')) AS despues
FROM prestamos_v2_update_log
WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.impacta_en_comision')
ORDER BY fecha DESC;

-- Resumen: ¿Qué campos se modifican más? (últimos 30 días)
SELECT
    'Saldo' AS campo, COUNT(*) AS total FROM prestamos_v2_update_log
    WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Saldo') AND fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
UNION ALL
SELECT
    'Cobrado', COUNT(*) FROM prestamos_v2_update_log
    WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Cobrado') AND fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
UNION ALL
SELECT
    'Status', COUNT(*) FROM prestamos_v2_update_log
    WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Status') AND fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
UNION ALL
SELECT
    'Agente', COUNT(*) FROM prestamos_v2_update_log
    WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Agente') AND fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
UNION ALL
SELECT
    'Multas', COUNT(*) FROM prestamos_v2_update_log
    WHERE JSON_CONTAINS_PATH(cambios, 'one', '$.Multas') AND fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY total DESC;


-- =====================================================
-- CONSULTAS COMBINADAS (Ciclo de vida de un préstamo)
-- =====================================================

-- Historia completa de un préstamo
-- 1. Cuándo se creó
SELECT 'CREADO' AS evento, fecha, cliente_nombre, agente, monto_otorgado AS detalle
FROM prestamos_v2_create_log WHERE prestamo_id = 'XXXXXX'
UNION ALL
-- 2. Todos sus cambios
SELECT 'MODIFICADO', fecha, NULL, NULL, JSON_PRETTY(cambios)
FROM prestamos_v2_update_log WHERE prestamo_id = 'XXXXXX'
UNION ALL
-- 3. Si fue eliminado
SELECT 'ELIMINADO', fecha, CONCAT(Nombres, ' ', Apellido_Paterno), Agente, CONCAT('Saldo: ', Saldo)
FROM prestamos_v2_delete_log WHERE PrestamoID = 'XXXXXX'
ORDER BY fecha;
