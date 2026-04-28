# Sincronizar pagos_dynamic cuando hay desfase con pagos_v3

Aplica cuando el dashboard "Clientes de Agencia" muestra `Sin Pago` pero el "Historial" del préstamo (lee pagos_v3) sí muestra el pago. Causa raíz: bug del trigger documentado en [incidents/2026-04-23-pagos-dynamic-merge-bug.md](../incidents/2026-04-23-pagos-dynamic-merge-bug.md).

## Diagnóstico rápido

```sql
SELECT 'v3' AS src, Semana, Monto, AbreCon, CierraCon, PagoID
FROM pagos_v3
WHERE PrestamoID = '<PRESTAMO_ID>' AND Semana >= <N-2>
UNION ALL
SELECT 'dyn', semana, monto, abre_con, cierra_con, pago_id
FROM pagos_dynamic
WHERE prestamo_id = '<PRESTAMO_ID>' AND semana >= <N-2>
ORDER BY src, Semana;
```

Si los `monto` no coinciden por semana, hay desfase.

## Fix

### 1. Restaurar la semana corrupta a sus valores originales

```sql
UPDATE pagos_dynamic
SET monto = <monto_v3_de_esa_sem>,
    cierra_con = <cierra_con_v3_de_esa_sem>,
    fecha_pago = '<fecha_v3_de_esa_sem>'
WHERE prestamo_id = '<PRESTAMO_ID>'
  AND semana = <N-1>
  AND anio = <YYYY>;
```

### 2. Insertar la semana faltante

`pagos_dynamic` requiere muchos campos. Plantilla:

```sql
INSERT INTO pagos_dynamic (
    pago_id, prestamo_id, prestamo, cliente,
    monto, semana, anio, es_primer_pago,
    abre_con, cierra_con, tarifa,
    agencia, tipo, fecha_pago,
    identificador, quien_pago, comentario,
    lat, lng, tipo_aux, recuperado_por
) VALUES (
    '<PagoID de pagos_v3>',         -- ⚠️ PRIMARY KEY, copiar del pago real en pagos_v3
    '<PRESTAMO_ID>', '<PRESTAMO_ID>',
    '<Nombre Cliente>',
    <monto>, <semana>, <anio>, <0 ó 1>,
    <abre_con>, <cierra_con>, <tarifa>,
    '<AGENCIA>', '<Tipo>',           -- enum: Pago, Excedente, Liquidacion, No_pago, etc.
    '<fecha_pago>',
    '<identificador del préstamo>', 'Cliente', '',
    <lat>, <lng>,
    'Pago', 'agente'
);
```

### 3. Verificar

```sql
SELECT semana, monto, abre_con, cierra_con
FROM pagos_dynamic
WHERE prestamo_id = '<PRESTAMO_ID>' AND anio = <YYYY>
ORDER BY semana;
```

Cierra_con de cada semana debe ser igual al abre_con de la siguiente.

## Recomendación

Si hay muchos préstamos afectados, escribir un script que detecte desfases comparando suma(`pagos_v3.Monto`) vs suma(`pagos_dynamic.monto`) por préstamo y los liste. Por ahora se ha hecho caso por caso.
