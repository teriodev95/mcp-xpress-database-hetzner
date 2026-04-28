# Incidente: Trigger fusiona pagos de semanas distintas en pagos_dynamic

**Fecha:** 2026-04-23 | **Estado:** identificado, fix manual aplicado a 1 caso, bug del trigger pendiente

## Síntoma

Dashboard "Clientes de Agencia" muestra `Sin Pago` y `Cierra Con` antiguo aunque el cliente sí pagó. El "Historial de Pagos" del préstamo (que lee de `pagos_v3`) sí muestra el pago.

## Causa raíz

Cuando entra un pago en `pagos_v3` con `Semana = N`, el trigger que actualiza `pagos_dynamic` **suma el monto al registro de la semana anterior** en lugar de crear un nuevo registro. Resultado:

| pagos_dynamic | Antes del bug | Después (corrupto) |
|---------------|---------------|---------------------|
| Sem N-1 monto | $304 | **$900** (suma con sem N) |
| Sem N-1 cierra_con | $595.81 | **-$0.19** (final de sem N) |
| Sem N-1 fecha_pago | 15 abr | **20 abr** (la del pago de sem N) |
| Sem N record | — | **NO existe** |

El `pago_id` se queda apuntando al pago original de N-1, pero el monto y cierra_con son del N.

## Caso de referencia

Préstamo `03.26-005-03mo` (cliente Maria Adela Galicia Urrieta):
- pagos_v3 sem 16: $304 ✓ / sem 17: $596 ✓
- pagos_dynamic sem 16: **$900** ❌ / sem 17: **NO existe** ❌

## Fix manual

Ver [procedures/sincronizar-pagos-dynamic.md](../procedures/sincronizar-pagos-dynamic.md).

## Hipótesis del bug

El trigger probablemente hace:
```sql
UPDATE pagos_dynamic SET monto = monto + ?, cierra_con = ?
WHERE prestamo_id = ?  -- ❌ falta AND semana = ? AND anio = ?
ORDER BY ... LIMIT 1
```

Pendiente revisar el trigger o el código del backend que escribe a `pagos_dynamic` para validar.
