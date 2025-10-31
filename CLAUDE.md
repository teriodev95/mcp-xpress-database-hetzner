# CLAUDE.md

Este archivo proporciona orientación a Claude Code (claude.ai/code) al trabajar con código en este repositorio.

## Descripción del Proyecto

Este repositorio contiene scripts SQL y utilidades para gestionar y consultar la base de datos del sistema financiero Xpress Dinero a través de un servidor MCP (Model Context Protocol).

## Acceso a la Base de Datos

Todas las operaciones de base de datos se realizan a través de una API remota del servidor MCP con los siguientes comandos aprobados:

### Herramientas Disponibles del MCP

El servidor MCP ofrece las siguientes herramientas:

**Estructura de la Base de Datos:**
- `list_mariadb_structure`: Lista nombres de tablas, vistas, procedures, functions y triggers (ligero)
- `list_mariadb_structure_full`: Estructura completa con detalles de columnas (pesado)
- `db_summary`: Resumen de tablas con tamaños y cantidad de filas

**Consultas de Metadatos:**
- `get_table_details`: Detalles de tabla específica (columnas, índices, status)
- `get_view_details`: Definición y columnas de una vista
- `get_procedure_details`: Definición de procedimiento almacenado
- `get_function_details`: Definición de función
- `get_trigger_details`: Definición de trigger

**Consultas de Datos:**
- `run_query`: Ejecuta consulta SELECT personalizada
- `select_table_preview`: Vista previa de registros de tabla con límite

**Ejemplos de comandos curl:**
```bash
# Listar estructura de la base de datos
curl -X POST 'http://65.21.188.158:7400/list_mariadb_structure' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json'

# Obtener detalles de una tabla
curl -X POST 'http://65.21.188.158:7400/get_table_details' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"table":"agencias"}'

# Obtener definición de un procedimiento
curl -X POST 'http://65.21.188.158:7400/get_procedure_details' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"procedure":"generar_snapshots_gerencias"}'

# Vista previa de una tabla
curl -X POST 'http://65.21.188.158:7400/select_table_preview' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"table":"gerencias","limit":10}'

# Ejecutar consulta personalizada
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT * FROM gerencias WHERE Status = '\''ACTIVA'\'' LIMIT 10"}'
```

**Importante**: Solo se permiten consultas SELECT a través del servidor MCP. Las operaciones DDL (CREATE, ALTER, DROP) deben proporcionarse como scripts SQL para ejecución manual.

### Flexibilidad del MCP para Consultas

El servidor MCP permite ejecutar cualquier consulta SELECT de forma flexible:
- **Consultas simples**: `SELECT * FROM tabla WHERE condicion`
- **Consultas con JOINs**: Múltiples tablas con relaciones complejas
- **Agregaciones**: COUNT, SUM, AVG, GROUP BY, HAVING
- **Subconsultas**: En SELECT, FROM, WHERE
- **Funciones**: DATE, CONCAT, IF, CASE, COALESCE, etc.
- **Ordenamiento y límites**: ORDER BY, LIMIT, OFFSET
- **Consultas a INFORMATION_SCHEMA**: Para obtener metadatos de tablas, columnas, procedimientos

**Ejemplos de uso flexible:**
```bash
# Consulta simple
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT * FROM gerencias WHERE Status = '\''ACTIVA'\'' LIMIT 10"}'

# Consulta con JOINs y agregaciones
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT g.GerenciaID, COUNT(a.AgenciaID) as total FROM gerencias g LEFT JOIN agencias a ON g.GerenciaID = a.GerenciaID GROUP BY g.GerenciaID"}'

# Consulta de metadatos
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '\''gerencias'\''"}'
```

**Nota importante sobre comillas en consultas JSON:**
- Usar comillas simples escapadas (`'\''`) para strings dentro de SQL
- O alternativamente, usar dobles comillas escapadas (`\"`) en el JSON

## Arquitectura de la Base de Datos

### Tablas Principales y Relaciones

**Entidades Centrales:**
- `gerencias`: Unidades de gerencia (Status: ACTIVA/INACTIVA)
- `agencias`: Agencias pertenecientes a gerencias
- `agencias_status_auxilar`: Asignación de agentes y seguimiento de antigüedad
- `prestamos_v2`: Préstamos activos (Saldo > 0)
- `pagos_dynamic`: Registros de pagos por semana/año
- `ventas`: Registros de ventas por semana/año
- `cierres_semanales_consolidados_v2`: Seguimiento de cierres semanales
- `calendario`: Mapeo de números de semana y fechas para zona horaria de Ciudad de México

**Relaciones Clave:**
- `prestamos_v2` se vincula a `gerencias` mediante `deprecated_name` + `sucursal`/`SucursalID`
- Los pagos se rastrean por semana/año en `pagos_dynamic`
- El estado de cierre se rastrea en `cierres_semanales_consolidados_v2` por agencia/semana/año

### Lógica de Negocio

**Snapshots Semanales:**
Dos procedimientos almacenados generan snapshots de rendimiento semanal:
- `generar_snapshots_gerencias()`: Itera todas las gerencias activas y llama `insertar_resumen_gerencia_dinamico()`
- `generar_snapshots_agencias()`: Patrón similar para agencias

Estos snapshots capturan métricas para una semana/año específica incluyendo:
- Débito (pago esperado) por día de la semana (Miércoles/Jueves/Viernes)
- Cobranza (cobros reales) desglosada en pura vs excedente
- Conteos de clientes, tipos de pago, liquidaciones
- Métricas de rendimiento (rendimiento %)

**Cálculo del Débito:**
El débito representa el pago semanal esperado y se calcula como:
```sql
IF(Saldo < Tarifa, Saldo, Tarifa)
```
Esto es el mínimo entre el saldo restante y la tarifa semanal.

**Procedimientos Almacenados Principales:**
- `insertar_resumen_gerencia_dinamico(p_gerencia, p_anio, p_semana)`: Genera snapshot para una gerencia
- `obtener_status_cierre_por_gerencia(p_gerencia, p_semana, p_anio)`: Retorna estado de cierre de todas las agencias en una gerencia
- `obtener_resumen_todas_gerencias(p_semana, p_anio)`: Resumen del % de completitud de cierres en todas las gerencias
- `obtener_agencias_sin_cierre(p_semana, p_anio)`: Lista agencias sin cierre semanal

## Datos para Pruebas

Usa estos puntos de datos reales para pruebas:
- **Gerencias**: GERC001-GERC010, GERD001-GERD011, GERE001-GERE014, GERM001-GERM009, GERP001-GERP004 (46 en total)
- **Semanas recientes**: Semana 43 de 2025 (242 cierres), Semana 42 de 2025 (291 cierres)
- **Ejemplo**: `GERE001` en semana 43/2025 tiene 100% de completitud (todas las agencias cerradas)
- **Ejemplo**: `GERC001` en semana 43/2025 tiene 2 cerradas, 3 pendientes

## Manejo de Fecha/Hora

Todas las operaciones de fecha/hora usan la zona horaria de Ciudad de México:
```sql
CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')
```

Los números de semana provienen de la tabla `calendario`, no se calculan.

## Archivos de Scripts SQL

- `crear_function_status_cierre.sql`: Procedimientos para verificar estado de cierre por gerencia
- `query_agencias_con_cierre_semanal.sql`: Template de query para agencias CON cierres
- `query_agencias_sin_cierre_semanal.sql`: Template de query para agencias SIN cierres
- `crear_table_function.sql`: Función/procedimiento reutilizable para encontrar agencias sin cerrar
