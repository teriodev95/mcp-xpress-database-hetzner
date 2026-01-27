-- TEST: Insertar multa de prueba (sin DELIMITER)

-- ANTES: Ver estado actual
SELECT COUNT(*) as multas_antes FROM multas;

-- INSERT DE PRUEBA
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
    UUID(),
    '2924-pl',
    1.00,
    3,
    2026,
    'Multa',
    'AGP011',
    CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'),
    CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
);

-- DESPUÉS: Verificar que se copió
SELECT COUNT(*) as multas_despues FROM multas;
SELECT multa_id, prestamo_id, monto, semana, anio, agencia
FROM multas
WHERE prestamo_id = '2924-pl'
ORDER BY created_at DESC
LIMIT 1;

-- CLEANUP
DELETE FROM pagos_v3 WHERE PrestamoID = '2924-pl' AND Tipo = 'Multa' AND Monto = 1.00;
DELETE FROM multas WHERE prestamo_id = '2924-pl' AND monto = 1.00;

-- FINAL
SELECT COUNT(*) as multas_final FROM multas;
