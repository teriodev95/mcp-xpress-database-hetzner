# FIX: Doble conteo de cobranza_pura en liquidaciones — vw_datos_cobranza

## Fecha: 2026-02-24

## Ticket origen

> Buenos dias. Ger01, tiene una liquidacion especial con AGE091. El cliente es VIRGINIA HERNANDEZ ORTIZ.
> Liquido con $2075.50. En monto excedente me marca la diferencia, ya que lo esta tomando como una
> liquidacion con descuento. Y el efectivo a entregar me esta variando tambien.

---

## Resumen del bug

La vista `vw_datos_cobranza` cuenta **dos veces** la porción de cobranza_pura ($440) cuando existe una liquidación:

1. Como `cobranza_pura` = LEAST(monto, LEAST(Saldo, Tarifa)) = $440
2. Dentro de `monto_liquidacion` = liquido_con = $2,075.50 (que ya incluye los $440)

Resultado: `cobranza_total` = $440 + $0 + $2,075.50 = **$2,515.50** cuando debería ser **$2,075.50**.

---

## Caso concreto: GERE001 / AGE091 / Semana 8 / 2026

### Préstamo afectado

| Campo | Valor |
|-------|-------|
| PrestamoID | P-2974-ef |
| Cliente | VIRGINIA HERNANDEZ ORTIZ |
| Agencia | AGE091 |
| Gerencia | Ger001 / GERE001 |
| Saldo (inicio semana) | $2,840.00 |
| Tarifa | $440.00 |
| Total a pagar | $7,050.00 |

### Liquidación especial

| Campo | Valor |
|-------|-------|
| liquidacionID | 159 |
| tipo | ESPECIAL |
| liquido_con | $2,075.50 |
| descuento_en_dinero | $764.50 |
| descuento_en_porcentaje | 50% |
| sem_transcurridas | 224 |

### Valores en la vista (ANTES del fix)

| Campo | Valor actual | Valor correcto |
|-------|-------------|----------------|
| monto_pagado | $2,075.50 | $2,075.50 |
| cobranza_pura | **$440.00** | **$0.00** |
| excedente | $0.00 | $0.00 |
| monto_liquidacion | $2,075.50 | $2,075.50 |
| monto_descuento | $764.50 | $764.50 |
| **cobranza_total** | **$2,515.50** | **$2,075.50** |
| debito_faltante | $0.00 | $0.00 (sin cambio) |

### Impacto en el cierre de GERE001 semana 8

| Concepto | Excel (correcto) | App (buggy) | Diferencia |
|----------|-------------------|-------------|------------|
| Ingresos (cobranza) | $161,925.30 | $162,365.30 | +$440.00 |
| Egresos | $156,547.11 | $156,547.11 | $0.00 |
| **Efectivo a Entregar** | **$5,378.19** | **$5,818.19** | **+$440.00** |

---

## Causa raíz

En la definición actual de `vw_datos_cobranza`, los campos `cobranza_pura` y `cobranza_total` no distinguen si el pago es una liquidación:

```sql
-- ACTUAL (buggy): cobranza_pura se calcula siempre, incluso para liquidaciones
COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0) AS cobranza_pura

-- ACTUAL (buggy): cobranza_total suma cobranza_pura + excedente + liquidacion
-- Cuando hay liquidación, la cobranza_pura ($440) se cuenta dos veces:
-- una como cobranza_pura y otra dentro de liquido_con ($2,075.50)
ROUND(
    cobranza_pura + excedente + COALESCE(liq.liquido_con, 0)
, 2) AS cobranza_total
```

---

## Fix: ALTER VIEW

Cuando hay una liquidación (`liq.liquidacionID IS NOT NULL`), `cobranza_pura` debe ser **0** porque el monto completo ya se contabiliza como `monto_liquidacion`.

```sql
ALTER VIEW vw_datos_cobranza AS
SELECT
    g.GerenciaID AS gerencia_id,
    p.Agente AS agencia,
    p.PrestamoID AS prestamo_id,
    CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS cliente,
    p.Tarifa AS tarifa_prestamo,
    COALESCE(LEAST(p.Tarifa, p.Saldo), 0) AS tarifa_en_semana,
    p.Saldo AS saldo_al_iniciar_semana,
    p.Dia_de_pago,
    pag_dyn.cierra_con,
    LEAST(p.Saldo, p.Tarifa) AS debito,
    COALESCE(pag_dyn.monto, 0) AS monto_pagado,

    -- FIX: cobranza_pura = 0 cuando hay liquidación (evita doble conteo)
    CASE WHEN liq.liquidacionID IS NOT NULL THEN 0
         ELSE COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
    END AS cobranza_pura,

    -- excedente = 0 cuando hay liquidación (sin cambio, ya estaba correcto)
    CASE WHEN liq.liquidacionID IS NOT NULL THEN 0
         ELSE COALESCE(pag_dyn.monto - LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
    END AS excedente,

    ROUND(COALESCE(liq.liquido_con, 0), 2) AS monto_liquidacion,
    ROUND(COALESCE(liq.descuento_en_dinero, 0), 2) AS monto_descuento,

    -- FIX: cobranza_total sin doble conteo
    ROUND(
        CASE WHEN liq.liquidacionID IS NOT NULL THEN 0
             ELSE COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
        END
        + CASE WHEN liq.liquidacionID IS NOT NULL THEN 0
               ELSE COALESCE(pag_dyn.monto - LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
          END
        + COALESCE(liq.liquido_con, 0)
    , 2) AS cobranza_total,

    -- SIN CAMBIO: debito_faltante se queda como estaba originalmente
    ROUND(
        LEAST(p.Saldo, p.Tarifa) -
        COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
    , 2) AS debito_faltante,

    COALESCE(pag_dyn.tipo, 'Sin Pago') AS tipo,
    CASE WHEN pag_dyn.prestamo_id IS NULL AND liq.liquidacionID IS NULL THEN 'NO'
         ELSE 'SI'
    END AS pago_semana,
    cal.Semana AS semana,
    cal.Anio AS anio
FROM prestamos_v2 p
JOIN gerencias g
    ON p.Gerencia = g.deprecated_name AND p.SucursalID = g.sucursal
JOIN (
    SELECT DISTINCT semana AS Semana, anio AS Anio
    FROM calendario
    WHERE anio >= 2024
) cal
LEFT JOIN pagos_dynamic pag_dyn
    ON p.PrestamoID = pag_dyn.prestamo_id
    AND pag_dyn.semana = cal.Semana
    AND pag_dyn.anio = cal.Anio
LEFT JOIN liquidaciones liq
    ON p.PrestamoID = liq.prestamoID
    AND liq.anio = cal.Anio
    AND liq.semana = cal.Semana
WHERE p.Saldo > 0;
```

> **Nota:** Solo se modifican `cobranza_pura`, `excedente` y `cobranza_total`. El campo `debito_faltante` **NO se toca** y permanece con la fórmula original.

---

## Valores esperados DESPUÉS del fix

### Para P-2974-ef (VIRGINIA HERNANDEZ ORTIZ)

| Campo | Antes | Después |
|-------|-------|---------|
| cobranza_pura | $440.00 | **$0.00** |
| excedente | $0.00 | $0.00 |
| monto_liquidacion | $2,075.50 | $2,075.50 |
| cobranza_total | $2,515.50 | **$2,075.50** |
| debito_faltante | $0.00 | $0.00 (sin cambio) |

### Para GERE001 semana 8

| Concepto | Antes | Después |
|----------|-------|---------|
| Ingresos | $162,365.30 | **$161,925.30** |
| Efectivo a Entregar | $5,818.19 | **$5,378.19** |

---

## Alcance del impacto

Este bug afecta a **todas las liquidaciones** (tanto CON_DESCUENTO como ESPECIAL) en todas las gerencias/semanas. Cualquier semana que tenga liquidaciones tendrá el efectivo a entregar inflado por el monto de la tarifa de cada préstamo liquidado.

### Consulta para verificar el impacto total en semana 8/2026

```sql
SELECT
    vdc.gerencia_id,
    vdc.agencia,
    vdc.prestamo_id,
    vdc.monto_pagado,
    vdc.cobranza_pura AS cobranza_pura_actual,
    0 AS cobranza_pura_corregida,
    vdc.cobranza_total AS cobranza_total_actual,
    vdc.cobranza_total - vdc.cobranza_pura AS cobranza_total_corregida,
    vdc.cobranza_pura AS diferencia
FROM vw_datos_cobranza vdc
INNER JOIN liquidaciones liq
    ON vdc.prestamo_id = liq.prestamoID
    AND vdc.semana = liq.semana
    AND vdc.anio = liq.anio
WHERE vdc.semana = 8 AND vdc.anio = 2026;
```

---

## Servicios que consumen vw_datos_cobranza

Los siguientes endpoints/servicios se benefician automáticamente del fix sin cambios de código:

1. **Java** — `obtenerDashboardGerencia` (ya migrado a la vista)
2. **FastAPI (FAX)** — `detalles_cierre_v3` (usa la vista directamente)
3. **Elysia** — `detalles-cierre` (usa la vista con Drizzle)
4. **cobranza_snapshots** — procedimiento `insertar_resumen_gerencia_dinamico` (si consume la vista)

---

## Pasos para aplicar

1. **Ejecutar el ALTER VIEW** en producción
2. **Verificar** con la query de impacto que las diferencias desaparecen
3. **Validar** GERE001 semana 8: efectivo a entregar debe ser $5,378.19
4. **Notificar** al equipo que los cierres con liquidaciones previos pudieron haber tenido esta discrepancia
