# Pendiente: Migración de cierres_gerencias_v2 para todas las gerencias

**Fecha de sesión:** 2026-03-17
**Rama FAX:** `main` (ya deployado a fax-prod.xpress1.cc y fax-dev.xpress1.cc)

---

## Contexto del problema

El endpoint `/api/snapshots-gerencias/reporte_diario/v4/{gerencia_id}` mostraba datos históricos distintos para la misma semana dependiendo de cuándo se consultaba (LUNES/MARTES), porque siempre reconsultaba los snapshots en tiempo real.

**Solución implementada:** Se creó `cierres_gerencias_v2` + `vw_cierres_gerencias` para "congelar" los datos al momento del cierre. El servicio FAX (`services.py`) fue modificado para usar esta vista cuando el `reporte_del_dia` es LUNES o MARTES.

---

## Lo que ya está hecho

- [x] Tabla `cierres_gerencias_v2` creada en DB
- [x] Vista `vw_cierres_gerencias` creada en DB
- [x] Servicio FAX modificado (`snapshots_gerencias/services.py`) y deployado a `main`
- [x] **GERE011 migrada** con datos del fin del día (pendiente corrección, ver abajo)

---

## Problema detectado con GERE011

La migración de GERE011 usó `vw_cobranza_snapshots_reportes_generales` con `es_reporte_del_dia=1` (snapshot fin del día), pero el valor correcto debe ser el snapshot **más cercano anterior al momento del cierre** (`cierres_gerencias.created_at`).

### Ejemplo semana 10:
| Fuente | Valor `cobranza_pura` |
|--------|----------------------|
| Snapshot 11am (`snapshots_gerencias`) | 95,369.39 |
| Snapshot al momento del cierre (4:19pm) | **95,369.39** ← CORRECTO |
| Snapshot fin del día (10:56pm) | 98,101.81 ← lo que está guardado (MALO) |

Solo **semana 11** quedó correcta porque el cierre se hizo a las 11:19am (antes de cualquier cambio intradía).

---

## Script de corrección para GERE011

> **Ejecutar manualmente en la DB.** El MCP solo permite SELECT.

```sql
UPDATE cierres_gerencias_v2 cgv2
INNER JOIN (
    SELECT
        cg.semana, cg.anio,
        SUM(cs.cobranza_pura)  AS cob_pura,
        SUM(cs.excedente)      AS excedente,
        SUM(cs.liquidaciones)  AS liquidaciones,
        SUM(cs.no_pagos)       AS no_pagos
    FROM cierres_gerencias_v2 cg
    INNER JOIN agencias a ON a.GerenciaID = cg.gerencia
    INNER JOIN cobranza_snapshots cs
        ON  cs.agencia  = a.AgenciaID
        AND cs.semana   = cg.semana
        AND cs.anio     = cg.anio
        AND cs.created_at = (
            SELECT MAX(cs2.created_at)
            FROM cobranza_snapshots cs2
            WHERE cs2.agencia = cs.agencia
              AND cs2.semana  = cg.semana
              AND cs2.anio    = cg.anio
              AND cs2.created_at < cg.created_at  -- snapshot ANTES del cierre
        )
    WHERE cg.gerencia = 'GERE011'
    GROUP BY cg.semana, cg.anio
) AS correct ON correct.semana = cgv2.semana AND correct.anio = cgv2.anio
SET
    cgv2.cobranza_pura  = correct.cob_pura,
    cgv2.excedente      = correct.excedente,
    cgv2.liquidaciones  = correct.liquidaciones,
    cgv2.no_pagos       = correct.no_pagos
WHERE cgv2.gerencia = 'GERE011';
```

---

## Script de migración para TODAS las gerencias (excepto GERE011 ya existente)

Misma lógica: tomar el snapshot de `cobranza_snapshots` más reciente **anterior** al `created_at` del cierre.

```sql
INSERT INTO cierres_gerencias_v2
    (gerencia, semana, anio, creado_por, tabulador_id,
     cobranza_pura, excedente, liquidaciones, no_pagos,
     clientes_cobrados, pagos_reducidos, created_at)
SELECT
    cg.gerencia,
    cg.semana,
    cg.anio,
    cg.creado_por,
    cg.tabulador_id,
    SUM(cs.cobranza_pura)   AS cobranza_pura,
    SUM(cs.excedente)       AS excedente,
    SUM(cs.liquidaciones)   AS liquidaciones,
    SUM(cs.no_pagos)        AS no_pagos,
    -- clientes_cobrados: pagos tipo Pago con monto > 0, no primer pago
    (
        SELECT COUNT(DISTINCT pd.prestamo_id)
        FROM pagos_dynamic pd
        INNER JOIN agencias a2 ON pd.agencia = a2.AgenciaID
        WHERE a2.GerenciaID = cg.gerencia
          AND pd.semana = cg.semana AND pd.anio = cg.anio
          AND pd.tipo_aux = 'Pago' AND pd.monto > 0
          AND (pd.es_primer_pago = 0 OR pd.es_primer_pago IS NULL)
    ) AS clientes_cobrados,
    0 AS pagos_reducidos,
    cg.created_at
FROM cierres_gerencias cg
INNER JOIN agencias a ON a.GerenciaID = cg.gerencia
INNER JOIN cobranza_snapshots cs
    ON  cs.agencia  = a.AgenciaID
    AND cs.semana   = cg.semana
    AND cs.anio     = cg.anio
    AND cs.created_at = (
        SELECT MAX(cs2.created_at)
        FROM cobranza_snapshots cs2
        WHERE cs2.agencia = cs.agencia
          AND cs2.semana  = cg.semana
          AND cs2.anio    = cg.anio
          AND cs2.created_at < cg.created_at  -- snapshot más cercano ANTES del cierre
    )
WHERE cg.gerencia != 'GERE011'  -- ya existe, no duplicar
GROUP BY cg.gerencia, cg.semana, cg.anio, cg.creado_por, cg.tabulador_id, cg.created_at
ON DUPLICATE KEY UPDATE
    cobranza_pura     = VALUES(cobranza_pura),
    excedente         = VALUES(excedente),
    liquidaciones     = VALUES(liquidaciones),
    no_pagos          = VALUES(no_pagos),
    clientes_cobrados = VALUES(clientes_cobrados);
```

> **Nota:** Puede tardar varios minutos si hay muchas gerencias y años de historial. Ejecutar en horario de bajo tráfico.

---

## Pendiente: Flow de creación de cierre (otro proyecto)

**Proyecto:** `xpress-elisya-back-front-oficina/front-cierres-admon-xpress`
**Endpoint de cierre:** Revisar `app/detalles-cierre` — hace POST al backend al crear un cierre.

**Qué hay que hacer:**
Al momento de crear un cierre en `cierres_gerencias`, el backend debe también hacer INSERT en `cierres_gerencias_v2` consultando los valores actuales de `cobranza_snapshots` en ese instante.

**Query para capturar en tiempo real al crear el cierre:**
```sql
-- Insertar en cierres_gerencias_v2 inmediatamente después de crear en cierres_gerencias
INSERT INTO cierres_gerencias_v2
    (gerencia, semana, anio, creado_por, tabulador_id,
     cobranza_pura, excedente, liquidaciones, no_pagos,
     clientes_cobrados, pagos_reducidos, created_at)
SELECT
    :gerencia, :semana, :anio, :creado_por, :tabulador_id,
    SUM(cs.cobranza_pura),
    SUM(cs.excedente),
    SUM(cs.liquidaciones),
    SUM(cs.no_pagos),
    (
        SELECT COUNT(DISTINCT pd.prestamo_id)
        FROM pagos_dynamic pd
        INNER JOIN agencias a2 ON pd.agencia = a2.AgenciaID
        WHERE a2.GerenciaID = :gerencia
          AND pd.semana = :semana AND pd.anio = :anio
          AND pd.tipo_aux = 'Pago' AND pd.monto > 0
          AND (pd.es_primer_pago = 0 OR pd.es_primer_pago IS NULL)
    ),
    0,
    NOW()
FROM cobranza_snapshots cs
INNER JOIN agencias a ON cs.agencia = a.AgenciaID
WHERE a.GerenciaID = :gerencia
  AND cs.semana = :semana AND cs.anio = :anio
  AND cs.created_at = (
      SELECT MAX(cs2.created_at)
      FROM cobranza_snapshots cs2
      WHERE cs2.agencia = cs.agencia
        AND cs2.semana = :semana AND cs2.anio = :anio
  )
ON DUPLICATE KEY UPDATE
    cobranza_pura     = VALUES(cobranza_pura),
    excedente         = VALUES(excedente),
    liquidaciones     = VALUES(liquidaciones),
    no_pagos          = VALUES(no_pagos),
    clientes_cobrados = VALUES(clientes_cobrados);
```

---

## Verificación post-migración

Después de ejecutar los scripts, validar con:

```bash
# Verificar que semana 10 de GERE011 muestra 95,369.39
curl "https://fax-prod.xpress1.cc/api/snapshots-gerencias/reporte_diario/v4/GERE011?reporte_del_dia=martes&semana=10&anio=2026"

# Verificar cuántas gerencias quedaron migradas
# (ejecutar via MCP)
# SELECT gerencia, COUNT(*) AS semanas FROM cierres_gerencias_v2 GROUP BY gerencia ORDER BY gerencia;
```

---

## Estructura de cierres_gerencias_v2 (referencia)

```sql
CREATE TABLE cierres_gerencias_v2 (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    gerencia        VARCHAR(16) NOT NULL,
    semana          TINYINT UNSIGNED NOT NULL,
    anio            SMALLINT UNSIGNED NOT NULL,
    creado_por      INT NOT NULL,
    tabulador_id    INT,
    cobranza_pura      DECIMAL(12,2) DEFAULT 0,
    excedente          DECIMAL(12,2) DEFAULT 0,
    liquidaciones      DECIMAL(12,2) DEFAULT 0,
    clientes_cobrados  INT DEFAULT 0,
    no_pagos           INT DEFAULT 0,
    pagos_reducidos    INT DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_cierre (gerencia, semana, anio)
);
```

**Nota:** `debito_*`, `clientes`, `ventas_*`, `rendimiento`, `faltante` se calculan en `vw_cierres_gerencias` desde `debitos_historial` y `ventas`.
