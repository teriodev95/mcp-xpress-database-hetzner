# Auditoria cobranza_historial vs Dashboard V2

- Fecha de ejecucion: 2026-01-20 15:38:49
- Semana: 3
- Anio: 2026

## Queries usadas

Dashboard V2:
```sql
SELECT d.agencia, 
       SUM(d.cobranza_pura) AS total_cobranza_pura,
       SUM(d.excedente) AS total_excedente,
       COALESCE(np.total_no_pagos, 0) AS total_no_pagos,
       COALESCE(m.total_multas, 0) AS total_multas
FROM vw_datos_cobranza d
LEFT JOIN (SELECT agencia, semana, anio, COUNT(*) AS total_no_pagos 
           FROM pagos_dynamic WHERE tipo = 'No_pago' GROUP BY agencia, semana, anio) np 
    ON d.agencia = np.agencia AND d.semana = np.semana AND d.anio = np.anio
LEFT JOIN (SELECT agencia, semana, anio, SUM(monto) AS total_multas 
           FROM multas GROUP BY agencia, semana, anio) m 
    ON d.agencia = m.agencia AND d.semana = m.semana AND d.anio = m.anio
WHERE d.semana = 3 AND d.anio = 2026
GROUP BY d.agencia
ORDER BY d.agencia
```

cobranza_historial:
```sql
SELECT agencia,
       total_cobranza_pura,
       monto_excedente,
       no_pagos,
       multas
FROM cobranza_historial
WHERE semana = 3 AND anio = 2026
ORDER BY agencia
```

## Resultados

- Total agencias Dashboard V2: 352
- Total agencias cobranza_historial: 352
- Total agencias comparadas: 352
- Total agencias que coinciden: 352/352
- Porcentaje de precision: 100.00%

## Diferencias encontradas

No se encontraron diferencias.

## Resumen de tipos de errores

Sin errores.

## Nota
Comparacion realizada con igualdad exacta por campo (sin tolerancia).