# Incidente: Eliminar liquidación/pago no hace rollback en prestamos_dynamic

**Fecha:** 2026-04-24 | **Estado:** identificado, fix manual aplicado a 1 caso, bug sistémico pendiente

## Síntoma

Dashboard muestra `Cierra Con` distinto al saldo real del préstamo. Al investigar, `prestamos_dynamic.cobrado` tiene un monto **mayor** que la suma de pagos en `pagos_v3`, y `prestamos_dynamic.saldo` tiene el mismo monto **faltante**.

## Causa raíz

Al eliminar una liquidación (o un pago), el `UPDATE` que actualizó `prestamos_dynamic` cuando se creó **no se revierte**. El pago desaparece de `pagos_v3` y de la tabla `liquidaciones`, pero los $X que se descontaron del saldo y se sumaron al cobrado quedan "fantasma" en `prestamos_dynamic`.

No existe tabla de auditoría de pagos eliminados, así que no hay traza de cuándo/quién lo borró.

## Caso de referencia

Préstamo `02.26-008-04di` (NANCY MEDINA MONTIEL):
- Total_a_pagar: $14,582.50
- Suma real `pagos_v3`: $11,118.80 (16 pagos)
- `prestamos_dynamic.cobrado`: $11,776.85 → **$658.05 fantasma**
- `prestamos_dynamic.saldo`: $2,805.65 → debería ser $3,463.70

## Diagnóstico rápido

```sql
SELECT
    p.PrestamoID,
    p.Total_a_pagar,
    pd.cobrado AS cobrado_dynamic,
    (SELECT COALESCE(SUM(Monto),0) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID) AS suma_real_pagos,
    pd.cobrado - (SELECT COALESCE(SUM(Monto),0) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID) AS fantasma,
    pd.saldo AS saldo_dynamic,
    p.Total_a_pagar - (SELECT COALESCE(SUM(Monto),0) FROM pagos_v3 WHERE PrestamoID = p.PrestamoID) AS saldo_correcto
FROM prestamos_v2 p
JOIN prestamos_dynamic pd ON pd.prestamo_id = p.PrestamoID
WHERE p.PrestamoID = '<ID>';
```

Si `fantasma != 0`, hay desfase.

## Fix manual

```sql
UPDATE prestamos_dynamic
SET cobrado = (SELECT COALESCE(SUM(Monto),0) FROM pagos_v3 WHERE PrestamoID = '<ID>'),
    saldo = (SELECT Total_a_pagar FROM prestamos_v2 WHERE PrestamoID = '<ID>')
            - (SELECT COALESCE(SUM(Monto),0) FROM pagos_v3 WHERE PrestamoID = '<ID>')
WHERE prestamo_id = '<ID>';
```

## Detección masiva (préstamos afectados)

```sql
SELECT
    p.PrestamoID,
    pd.cobrado - SUM(pv.Monto) AS fantasma
FROM prestamos_v2 p
JOIN prestamos_dynamic pd ON pd.prestamo_id = p.PrestamoID
LEFT JOIN pagos_v3 pv ON pv.PrestamoID = p.PrestamoID
GROUP BY p.PrestamoID, pd.cobrado
HAVING ABS(fantasma) > 0.10  -- tolerancia para redondeos
ORDER BY ABS(fantasma) DESC;
```

## Lo que aprendimos

- **Bug sistémico**: el flujo de eliminar liquidación/pago debe revertir `prestamos_dynamic`. Hay que revisar el SP/código que borra para agregar el rollback.
- **Falta tabla de auditoría** de pagos eliminados (`pagos_v3_delete_log` no existe). Sería útil para rastrear quién/cuándo eliminó qué.
- **Workaround para detección periódica**: query de detección masiva (arriba) puede correrse semanalmente para encontrar desfases y corregirlos.
