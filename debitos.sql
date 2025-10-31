SELECT
    ger.GerenciaID AS gerencia,
    44 AS semana,
    2025 AS anio,
    SUM(CASE WHEN prest_v2.Dia_de_pago = 'Miercoles' THEN LEAST(prest_v2.Saldo, prest_v2.Tarifa) ELSE 0 END) AS debito_miercoles,
    SUM(CASE WHEN prest_v2.Dia_de_pago = 'Jueves' THEN LEAST(prest_v2.Saldo, prest_v2.Tarifa) ELSE 0 END) AS debito_jueves,
    SUM(CASE WHEN prest_v2.Dia_de_pago = 'Viernes' THEN LEAST(prest_v2.Saldo, prest_v2.Tarifa) ELSE 0 END) AS debito_viernes,
    SUM(LEAST(prest_v2.Saldo, prest_v2.Tarifa)) AS debito_total
FROM
    gerencias ger
    INNER JOIN prestamos_v2 prest_v2
        ON ger.deprecated_name = prest_v2.Gerencia
       AND ger.sucursal = prest_v2.SucursalID
       AND prest_v2.Saldo > 0
WHERE
    ger.GerenciaID = 'GERE011'
GROUP BY
    ger.GerenciaID;