-- Enrich cobranza_snapshots with agencia + gerencia context (sucursal)
-- Note: cobranza_snapshots may contain multiple rows per (agencia, anio, semana, hora)
-- because there is no UNIQUE constraint. Use MAX(id) per (agencia, fecha_mx, hora)
-- when you need an unambiguous snapshot.

CREATE OR REPLACE VIEW vw_cobranza_snapshots_enriched AS
SELECT
  cs.id,
  cs.created_at,
  CONVERT_TZ(cs.created_at, 'UTC', 'America/Mexico_City') AS created_at_mx,
  DATE(CONVERT_TZ(cs.created_at, 'UTC', 'America/Mexico_City')) AS fecha_mx,

  cs.anio,
  cs.semana,
  cs.hora,
  cs.agencia,

  a.Status AS agencia_status,
  a.GerenciaID,

  g.SucursalID,
  g.sucursal,

  cs.clientes,
  cs.debito,
  cs.cobranza_pura,
  cs.excedente,
  cs.liquidaciones,
  cs.no_pagos,
  cs.ventas_cantidad,
  cs.ventas_monto
FROM cobranza_snapshots cs
LEFT JOIN agencias a
  ON a.AgenciaID = cs.agencia
LEFT JOIN gerencias g
  ON g.GerenciaID = a.GerenciaID;
