# AbreCon / CierraCon — cadena por semana

## Regla fundamental

```
AbreCon[N] = CierraCon[N-1]
CierraCon = AbreCon - Monto
```

La cadena debe ser continua semana a semana. Si rompes la cadena, los reportes de cobranza se desvían.

## Cómo calcular `AbreCon` correctamente

⚠️ **No tomes el `AbreCon` desde `prestamos_v2.Saldo` directamente** — puede estar desactualizado.

Orden de preferencia:
1. **Usar `CierraCon` de la semana anterior del mismo préstamo** (preferido, mantiene la cadena).
2. **Si no hay pago anterior**: `Total_a_pagar - SUM(Monto de pagos anteriores)`.

## Validar la cadena

```sql
SELECT semana, abre_con, cierra_con,
       LAG(cierra_con) OVER (PARTITION BY prestamo_id ORDER BY semana) AS prev_cierre,
       (abre_con - LAG(cierra_con) OVER (PARTITION BY prestamo_id ORDER BY semana)) AS desfase
FROM pagos_dynamic
WHERE prestamo_id = '<ID>'
ORDER BY semana;
```

Si `desfase != 0` en alguna semana, la cadena está rota.

## Triggers/scripts relacionados

- `trigger_pagos_v3_before_insert_modificado.sql` — calcula `AbreCon` correcto al insertar
- `corregir_abrecon_cierracon_pagos_v3.sql` — corrige datos existentes con desfase

Ver también: [incidents/2026-04-23-pagos-dynamic-merge-bug.md](../incidents/2026-04-23-pagos-dynamic-merge-bug.md) — bug que rompe la cadena en `pagos_dynamic`.
