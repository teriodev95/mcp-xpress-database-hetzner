#!/bin/bash
# =====================================================
# VALIDACIÓN: Queries Dashboard Corregidas
# =====================================================
# Ejecutar: chmod +x validacion_queries_dashboard.sh && ./validacion_queries_dashboard.sh
# =====================================================

API_URL="http://65.21.188.158:7400/run_query"
API_KEY="9mYS%hyyFGBg#x3ByAu%v@d@"

echo "=============================================="
echo "VALIDACIÓN QUERIES DASHBOARD CORREGIDAS"
echo "=============================================="
echo ""

# -----------------------------------------------------
# TEST 1: Dashboard Agencia AGD029 (semana 48/2025)
# Valores esperados:
#   - total_cobranza_pura: $17,780.55 (antes daba $17,780.84)
#   - debito_total: $21,967.67
#   - rendimiento: 80.94%
# -----------------------------------------------------
echo "TEST 1: Dashboard Agencia AGD029 (semana 48/2025)"
echo "================================================="
curl -s -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT agenc.GerenciaID as gerencia, '\''AGD029'\'' as agencia, 2025 as anio, 48 as semana, COUNT(pag_dyn.prestamo_id) as clientes, SUM(IF(pag_dyn.tipo_aux = '\''Pago'\'' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados, SUM(IF(pag_dyn.tipo = '\''No_pago'\'', 1, 0)) as no_pagos, SUM(IF(pag_dyn.tipo = '\''Liquidacion'\'', 1, 0)) as numero_liquidaciones, SUM(IF(pag_dyn.tipo = '\''Reducido'\'', 1, 0)) as pagos_reducidos, SUM(IF(UPPER(p.Dia_de_pago) = '\''MIERCOLES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles, SUM(IF(UPPER(p.Dia_de_pago) = '\''JUEVES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves, SUM(IF(UPPER(p.Dia_de_pago) = '\''VIERNES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes, SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total, ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 / NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento, SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura, SUM(pag_dyn.monto) as cobranza_total FROM agencias agenc INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID AND pag_dyn.anio = 2025 AND pag_dyn.semana = 48 AND pag_dyn.tipo_aux = '\''Pago'\'' LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID WHERE agenc.AgenciaID = '\''AGD029'\'' GROUP BY agenc.GerenciaID, agenc.AgenciaID"
  }' | jq .
echo ""

# -----------------------------------------------------
# TEST 2: Dashboard Agencia AGM018 (semana 48/2025)
# Valores esperados:
#   - debito_total: $42,174.83 (antes faltaba $510.75 del préstamo liquidado)
#   - clientes: 76
#   - rendimiento: 90.52%
# -----------------------------------------------------
echo "TEST 2: Dashboard Agencia AGM018 (semana 48/2025)"
echo "================================================="
curl -s -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT agenc.GerenciaID as gerencia, '\''AGM018'\'' as agencia, 2025 as anio, 48 as semana, COUNT(pag_dyn.prestamo_id) as clientes, SUM(IF(pag_dyn.tipo_aux = '\''Pago'\'' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados, SUM(IF(pag_dyn.tipo = '\''No_pago'\'', 1, 0)) as no_pagos, SUM(IF(pag_dyn.tipo = '\''Liquidacion'\'', 1, 0)) as numero_liquidaciones, SUM(IF(pag_dyn.tipo = '\''Reducido'\'', 1, 0)) as pagos_reducidos, SUM(IF(UPPER(p.Dia_de_pago) = '\''MIERCOLES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles, SUM(IF(UPPER(p.Dia_de_pago) = '\''JUEVES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves, SUM(IF(UPPER(p.Dia_de_pago) = '\''VIERNES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes, SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total, ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 / NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento, SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura, SUM(pag_dyn.monto) as cobranza_total FROM agencias agenc INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID AND pag_dyn.anio = 2025 AND pag_dyn.semana = 48 AND pag_dyn.tipo_aux = '\''Pago'\'' LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID WHERE agenc.AgenciaID = '\''AGM018'\'' GROUP BY agenc.GerenciaID, agenc.AgenciaID"
  }' | jq .
echo ""

# -----------------------------------------------------
# TEST 3: Dashboard Gerencia GERM003 (semana 48/2025)
# Contiene AGM018, verifica agregación a nivel gerencia
# -----------------------------------------------------
echo "TEST 3: Dashboard Gerencia GERM003 (semana 48/2025)"
echo "==================================================="
curl -s -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT ger.GerenciaID as gerencia, 2025 as anio, 48 as semana, COUNT(pag_dyn.prestamo_id) as clientes, SUM(IF(pag_dyn.tipo_aux = '\''Pago'\'' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados, SUM(IF(pag_dyn.tipo = '\''No_pago'\'', 1, 0)) as no_pagos, SUM(IF(pag_dyn.tipo = '\''Liquidacion'\'', 1, 0)) as numero_liquidaciones, SUM(IF(pag_dyn.tipo = '\''Reducido'\'', 1, 0)) as pagos_reducidos, SUM(IF(UPPER(p.Dia_de_pago) = '\''MIERCOLES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles, SUM(IF(UPPER(p.Dia_de_pago) = '\''JUEVES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves, SUM(IF(UPPER(p.Dia_de_pago) = '\''VIERNES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes, SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total, ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 / NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento, SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura, SUM(pag_dyn.monto) as cobranza_total FROM gerencias ger INNER JOIN agencias agenc ON agenc.GerenciaID = ger.GerenciaID INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID AND pag_dyn.anio = 2025 AND pag_dyn.semana = 48 AND pag_dyn.tipo_aux = '\''Pago'\'' LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID WHERE ger.GerenciaID = '\''GERM003'\'' GROUP BY ger.GerenciaID"
  }' | jq .
echo ""

# -----------------------------------------------------
# TEST 4: Dashboard Gerencia GERD001 (semana 48/2025)
# Contiene AGD029, verifica consistencia
# -----------------------------------------------------
echo "TEST 4: Dashboard Gerencia GERD001 (semana 48/2025)"
echo "==================================================="
curl -s -X POST "$API_URL" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT ger.GerenciaID as gerencia, 2025 as anio, 48 as semana, COUNT(pag_dyn.prestamo_id) as clientes, SUM(IF(pag_dyn.tipo_aux = '\''Pago'\'' AND pag_dyn.monto > 0, 1, 0)) as clientes_cobrados, SUM(IF(pag_dyn.tipo = '\''No_pago'\'', 1, 0)) as no_pagos, SUM(IF(pag_dyn.tipo = '\''Liquidacion'\'', 1, 0)) as numero_liquidaciones, SUM(IF(pag_dyn.tipo = '\''Reducido'\'', 1, 0)) as pagos_reducidos, SUM(IF(UPPER(p.Dia_de_pago) = '\''MIERCOLES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_miercoles, SUM(IF(UPPER(p.Dia_de_pago) = '\''JUEVES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_jueves, SUM(IF(UPPER(p.Dia_de_pago) = '\''VIERNES'\'', LEAST(pag_dyn.abre_con, pag_dyn.tarifa), 0)) as debito_viernes, SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)) as debito_total, ROUND(SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) * 100 / NULLIF(SUM(LEAST(pag_dyn.abre_con, pag_dyn.tarifa)), 0), 2) as rendimiento, SUM(LEAST(pag_dyn.monto, LEAST(pag_dyn.abre_con, pag_dyn.tarifa))) as total_cobranza_pura, SUM(pag_dyn.monto) as cobranza_total FROM gerencias ger INNER JOIN agencias agenc ON agenc.GerenciaID = ger.GerenciaID INNER JOIN pagos_dynamic pag_dyn ON pag_dyn.agencia = agenc.AgenciaID AND pag_dyn.anio = 2025 AND pag_dyn.semana = 48 AND pag_dyn.tipo_aux = '\''Pago'\'' LEFT JOIN prestamos_v2 p ON pag_dyn.prestamo_id = p.PrestamoID WHERE ger.GerenciaID = '\''GERD001'\'' GROUP BY ger.GerenciaID"
  }' | jq .
echo ""

echo "=============================================="
echo "VALIDACIÓN COMPLETADA"
echo "=============================================="
echo ""
echo "Valores esperados:"
echo "  AGD029: cobranza_pura=$17,780.55, debito=$21,967.67, rendimiento=80.94%"
echo "  AGM018: debito=$42,174.83, clientes=76, rendimiento=90.52%"
echo ""
