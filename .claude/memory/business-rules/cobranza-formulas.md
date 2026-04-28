# Fórmulas de cobranza

## Métricas

| Métrica | Fórmula | Descripción |
|---------|---------|-------------|
| **Débito** | `LEAST(Saldo, Tarifa)` | Pago esperado de la semana |
| **Cobranza Pura** | `LEAST(Monto, LEAST(Tarifa, Saldo))` | Parte que cubre el débito |
| **Excedente** | `Monto - Cobranza_Pura` | Pago adicional sobre el débito |
| **Cobranza Total** | `Cobranza_Pura + Excedente + Liquidaciones` | Todo lo cobrado |
| **Débito Faltante** | `Débito - Cobranza_Pura` | Lo que faltó por cobrar |
| **Rendimiento %** | `(Cobranza_Pura / Débito) * 100` | % de cumplimiento |

## ¿Saldo desde dónde?

- **Para débito (semana actual)**: `prestamos_v2.Saldo` o `pagos_dynamic.abre_con` — ambos son saldo al inicio de semana, equivalentes. Ver [saldo-cobrado-tiempo.md](saldo-cobrado-tiempo.md).
- **Para reportes históricos**: `pagos_dynamic.abre_con` (preserva el saldo de cada semana en el tiempo).

## Query base — resumen por agencia

```sql
SELECT
    d.gerencia_id, d.agencia, asa.Agente AS nombre_agente,
    COUNT(d.prestamo_id) AS clientes,
    SUM(d.debito) AS total_debito,
    SUM(d.monto_pagado) AS total_pagado,
    SUM(d.cobranza_pura) AS total_cobranza_pura,
    SUM(d.excedente) AS total_excedente,
    SUM(d.monto_liquidacion) AS total_liquidaciones,
    SUM(d.cobranza_total) AS cobranza_total,
    SUM(d.debito_faltante) AS total_debito_faltante,
    COALESCE(np.total_no_pagos, 0) AS total_no_pagos,
    ROUND(SUM(d.cobranza_pura) / NULLIF(SUM(d.debito), 0) * 100, 2) AS porcentaje_cobranza
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT agencia, semana, anio, COUNT(*) AS total_no_pagos
    FROM pagos_dynamic
    WHERE tipo = 'No_pago'
    GROUP BY agencia, semana, anio
) np ON d.agencia = np.agencia AND d.semana = np.semana AND d.anio = np.anio
WHERE d.semana = @semana AND d.anio = @anio AND d.agencia = @agencia
GROUP BY d.agencia;
```

Para una gerencia entera: cambia `WHERE ... d.agencia = @agencia` por `d.gerencia_id = @gerencia` y elimina el `GROUP BY` final o cámbialo a `d.gerencia_id, d.agencia`.

## Performance

- `pagos_v3` tiene ~3.5M registros. Evita window functions (LEAD/LAG) sobre todo el dataset, usa JOINs simples filtrados.
- `pagos_dynamic` está consolidado por (préstamo, semana). Mantenerlo sincronizado es crítico — un desfase rompe los reportes. Ver [incidents/2026-04-23-pagos-dynamic-merge-bug.md](../incidents/2026-04-23-pagos-dynamic-merge-bug.md).
