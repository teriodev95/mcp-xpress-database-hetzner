# CLAUDE.md

Guía operacional para Claude Code en este repositorio. Lógica de negocio detallada vive en `.claude/memory/`.

## 📚 Knowledge Base local

Antes de responder sobre lógica de negocio, reglas no-obvias o problemas conocidos, **consulta `.claude/memory/`**:

- **Índice y mapa:** [.claude/memory/INDEX.md](.claude/memory/INDEX.md)
- **Glosario:** [.claude/memory/glossary.md](.claude/memory/glossary.md)
- **Reglas de negocio** (saldo al inicio de semana, AbreCon/CierraCon, fórmulas de cobranza, asignaciones tipo Agente, formato de IDs): [.claude/memory/business-rules/](.claude/memory/business-rules/)
- **Procedimientos comunes** (transferir cliente, aprobar borrador, sincronizar pagos, revertir completado): [.claude/memory/procedures/](.claude/memory/procedures/)
- **Bitácora de incidentes resueltos:** [.claude/memory/incidents/](.claude/memory/incidents/)

**Convención del equipo:** cuando descubras un quirk, regla, o bug nuevo, invoca **`/recordar`** y se encarga de la categorización, plantilla, y actualización del índice. Esto se comparte con todo el team vía git push.

**No documentes schema básico aquí ni en memory** — usa el MCP (`get_table_details`, `list_mariadb_structure`).

---

## Descripción del Proyecto

Scripts SQL y utilidades para gestionar y consultar la base de datos del sistema financiero **Xpress Dinero** a través de un servidor MCP (Model Context Protocol).

## Acceso a la Base de Datos (MCP)

**Endpoint:** `http://65.21.188.158:7400`
**API Key:** `9mYS%hyyFGBg#x3ByAu%v@d@`

⚠️ **Solo SELECT** vía MCP. DDL (CREATE/ALTER/DROP) y DML (INSERT/UPDATE/DELETE) deben proporcionarse como scripts SQL para ejecución manual del usuario.

### Endpoints disponibles

| Endpoint | Propósito |
|----------|-----------|
| `list_mariadb_structure` | Lista nombres de tablas, vistas, procs, functions, triggers (ligero) |
| `list_mariadb_structure_full` | Estructura completa con columnas (pesado) |
| `db_summary` | Resumen de tablas con tamaños y filas |
| `get_table_details` | Columnas, índices, status de una tabla |
| `get_view_details` | Definición de una vista |
| `get_procedure_details` | Definición de un SP |
| `get_function_details` | Definición de una function |
| `get_trigger_details` | Definición de un trigger |
| `run_query` | Ejecuta SELECT personalizado (también JOINs, agregaciones, INFORMATION_SCHEMA) |
| `select_table_preview` | Preview de tabla con límite |

### Ejemplos curl

```bash
# Detalles de tabla
curl -X POST 'http://65.21.188.158:7400/get_table_details' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"table":"prestamos_v2"}'

# Definición de procedimiento
curl -X POST 'http://65.21.188.158:7400/get_procedure_details' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"procedure":"aprobar_borrador_individual"}'

# Query libre
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT * FROM gerencias WHERE Status = '\''ACTIVA'\'' LIMIT 10"}'
```

### Comillas en JSON

- Strings dentro de SQL: comillas simples escapadas → `'\''`
- Alternativa: dobles comillas escapadas en el JSON → `\"`

## Manejo de Fecha/Hora

- Todas las operaciones usan zona **America/Mexico_City**:
  ```sql
  CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
  ```
- Los números de **semana** vienen de la tabla `calendario`, **no se calculan**.

## Datos para Pruebas

- **Gerencias activas**: GERC001-010, GERD001-011, GERE001-014, GERM001-009, GERP001-004, GERDC001-002, GERGC001-003 (formato dashboard).
- En `prestamos_v2.Gerencia` el formato es `GerC###`/`Ger###` (deprecated_name). Ver `business-rules/formato-codigos.md`.
- Para pruebas concretas: GERE001 sem 43/2025 (100% completitud), GERC001 sem 43/2025 (parcial).

## Sistema de Tickets (Soporte)

Integración con CouchDB REST.

```
URL:  https://couch.clvrt.cc/tickets
Auth: Basic YWRtaW46Y0d3OUttNGVqdXlxbjllY2E3Sio=
```

| Acción | Método | Endpoint |
|--------|--------|----------|
| Listar tickets | GET | `/_design/tickets/_view/summary` |
| Por PIN | GET | `/_design/tickets/_view/by_pin?key={pin}` |
| Obtener uno | GET | `/ticket_{id}` |
| Cambiar status | PUT | `/ticket_{id}` (requiere `_rev`) |
| Agregar mensaje | PUT | `/ticket_{id}` (append a `mensajes[]`) |

**Status válidos:** `pendiente` | `en proceso` | `completado`

Cliente TypeScript listo: `docs/tickets-api/tickets-client.ts`. Documentación detallada: `docs/tickets-api/README.md`.

## Scripts SQL relevantes en este repo

- `crear_function_status_cierre.sql` — SPs para verificar estado de cierre por gerencia
- `query_agencias_con_cierre_semanal.sql` / `query_agencias_sin_cierre_semanal.sql`
- `trigger_pagos_v3_before_insert_modificado.sql` — trigger que calcula AbreCon correcto
- `corregir_abrecon_cierracon_pagos_v3.sql` — corrige cadena rota en datos existentes

Para detalles de SPs específicos (parámetros, comportamiento), usa `get_procedure_details` vía MCP.
