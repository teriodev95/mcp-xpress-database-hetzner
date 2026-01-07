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
- `prestamos_v2`: Préstamos activos - **campos `Saldo` y `Cobrado` son valores AL INICIAR la semana actual**
- `prestamos_dynamic`: Saldo y cobrado **actualizados en tiempo real** después de cada pago
- `prestamos_completados`: Tabla de respaldo para préstamos pagados completamente (Saldo = 0) con auditoría
- `pagos_v3`: Tabla principal de pagos individuales (~3.5 millones de registros)
- `pagos_dynamic`: Tabla consolidada de pagos por préstamo/semana/año con saldos `abre_con` y `cierra_con`
- `ventas`: Registros de ventas por semana/año
- `cierres_semanales_consolidados_v2`: Seguimiento de cierres semanales
- `calendario`: Mapeo de números de semana y fechas para zona horaria de Ciudad de México

### Diferencia entre prestamos_v2 y prestamos_dynamic

| Campo | `prestamos_v2` | `prestamos_dynamic` |
|-------|----------------|---------------------|
| `Saldo` | Saldo **AL INICIAR** la semana actual | Saldo actualizado en tiempo real |
| `Cobrado` | Cobrado **AL INICIAR** la semana actual | Cobrado actualizado en tiempo real |

**Uso:**
- `prestamos_v2.Saldo`: Usar para cálculos de débito semanal (representa lo que debía al inicio de semana)
- `prestamos_dynamic.saldo`: Usar para conocer el saldo actual real del préstamo

### Estructura de pagos_dynamic

Tabla consolidada que almacena un registro por préstamo por semana:

| Campo | Descripción |
|-------|-------------|
| `prestamo_id` | ID del préstamo |
| `monto` | Monto total pagado en la semana |
| `semana`, `anio` | Semana y año del pago |
| `abre_con` | Saldo del préstamo AL INICIO de la semana |
| `cierra_con` | Saldo del préstamo AL FINAL de la semana (después del pago) |
| `tarifa` | Tarifa semanal del préstamo |
| `agencia` | Agencia del préstamo |
| `tipo` | Tipo de pago: Pago, Excedente, Liquidacion, No_pago, etc. |
| `tipo_aux` | Clasificación auxiliar: Pago, Multa, Visita |

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

*Snapshots y Cierres:*
- `insertar_resumen_gerencia_dinamico(p_gerencia, p_anio, p_semana)`: Genera snapshot para una gerencia
- `obtener_status_cierre_por_gerencia(p_gerencia, p_semana, p_anio)`: Retorna estado de cierre de todas las agencias en una gerencia
- `obtener_resumen_todas_gerencias(p_semana, p_anio)`: Resumen del % de completitud de cierres en todas las gerencias
- `obtener_agencias_sin_cierre(p_semana, p_anio)`: Lista agencias sin cierre semanal

*Gestión de Préstamos Completados:*
- `verificar_prestamos_completados()`: Revisa cuántos préstamos con Saldo = 0 están listos para migración (sin ejecutar la migración)
- `migrar_prestamos_completados()`: Migra préstamos con Saldo = 0 desde `prestamos_v2` a `prestamos_completados` y los elimina de la tabla activa

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

**Cierres Semanales:**
- `crear_function_status_cierre.sql`: Procedimientos para verificar estado de cierre por gerencia
- `query_agencias_con_cierre_semanal.sql`: Template de query para agencias CON cierres
- `query_agencias_sin_cierre_semanal.sql`: Template de query para agencias SIN cierres
- `crear_table_function.sql`: Función/procedimiento reutilizable para encontrar agencias sin cerrar



**Corrección de AbreCon/CierraCon:**
- `trigger_pagos_v3_before_insert_modificado.sql`: Trigger modificado que calcula AbreCon correctamente
- `corregir_abrecon_cierracon_pagos_v3.sql`: Script para corregir datos existentes con discrepancias

## Sistema de Pagos (pagos_v3 / pagos_dynamic)

### Tablas de Pagos
- `pagos_v3`: Tabla principal de pagos individuales (~3.5 millones de registros)
- `pagos_dynamic`: Tabla consolidada de pagos por préstamo/semana/año (un registro por préstamo por semana)

### Campos Críticos: AbreCon y CierraCon

**AbreCon** (Abre Con): Saldo del préstamo AL INICIO de la semana
**CierraCon** (Cierra Con): Saldo del préstamo AL FINAL de la semana (después del pago)

**Regla fundamental:**
```
AbreCon de semana N = CierraCon de semana N-1
CierraCon = AbreCon - Monto
```

**IMPORTANTE - Cálculo de AbreCon:**
El `AbreCon` NO debe tomarse del campo `Saldo` de `prestamos_v2` directamente porque puede estar desactualizado.
Debe calcularse de una de estas formas:
1. **Preferido**: Usar el `CierraCon` de la semana anterior del mismo préstamo
2. **Si no hay pago anterior**: Calcular como `Total_a_pagar - SUM(pagos anteriores)`

### Cálculo de Métricas de Cobranza

La vista `vw_datos_cobranza` y las queries de dashboard calculan las siguientes métricas:

**Fórmulas:**

| Métrica | Fórmula | Descripción |
|---------|---------|-------------|
| **Débito** | `LEAST(Saldo, Tarifa)` | Pago esperado de la semana |
| **Cobranza Pura** | `LEAST(Monto, LEAST(Tarifa, Saldo))` | Parte del pago que cubre el débito |
| **Excedente** | `Monto - Cobranza_Pura` | Pago adicional sobre el débito |
| **Cobranza Total** | `Cobranza_Pura + Excedente + Liquidaciones` | Todo lo cobrado |
| **Débito Faltante** | `Débito - Cobranza_Pura` | Lo que faltó por cobrar |
| **Rendimiento %** | `(Cobranza_Pura / Débito) * 100` | Porcentaje de cumplimiento |

**Query Principal para Resumen de Cobranza por Agencia:**

```sql
SELECT
    d.gerencia_id,
    d.agencia,
    asa.Agente AS nombre_agente,
    COUNT(d.prestamo_id) AS clientes,
    SUM(d.debito) AS total_debito,
    SUM(d.monto_pagado) AS total_pagado,
    SUM(d.cobranza_pura) AS total_cobranza_pura,
    SUM(d.excedente) AS total_excedente,
    SUM(d.monto_liquidacion) AS total_liquidaciones,
    SUM(d.monto_descuento) AS total_descuentos,
    SUM(d.cobranza_total) AS cobranza_total,
    SUM(d.debito_faltante) AS total_debito_faltante,
    COALESCE(np.total_no_pagos, 0) AS total_no_pagos,
    ROUND(SUM(d.cobranza_pura) / NULLIF(SUM(d.debito), 0) * 100, 2) AS porcentaje_cobranza
FROM vw_datos_cobranza d
INNER JOIN agencias_status_auxilar asa ON d.agencia = asa.Agencia
LEFT JOIN (
    SELECT agencia, semana, anio, COUNT(*) AS total_no_pagos
    FROM pagos_dynamic
    WHERE tipo = 'No_pago'
    GROUP BY agencia, semana, anio
) np ON d.agencia = np.agencia AND d.semana = np.semana AND d.anio = np.anio
WHERE d.semana = @semana AND d.anio = @anio AND d.agencia = @agencia
GROUP BY d.agencia;
```

**Ejemplo de uso:**
```sql
-- Para AGM074 en semana 52 de 2025:
WHERE d.semana = 52 AND d.anio = 2025 AND d.agencia = 'AGM074'

-- Para todas las agencias de una gerencia:
WHERE d.semana = 52 AND d.anio = 2025 AND d.gerencia_id = 'GERM009'
```

### Cálculo de Débitos (Dashboard)

**IMPORTANTE**: Los débitos deben calcularse desde `pagos_dynamic.abre_con`, NO desde `prestamos_v2.Saldo` directamente cuando se necesita el saldo al momento del pago.

```sql
-- Fórmula correcta usando pagos_dynamic:
LEAST(pag_dyn.abre_con, pag_dyn.tarifa)

-- Usando prestamos_v2.Saldo es válido porque representa el saldo AL INICIAR SEMANA:
LEAST(prestamos_v2.Saldo, prestamos_v2.Tarifa)
```

**Nota:** `prestamos_v2.Saldo` es correcto para débitos porque representa el saldo al inicio de la semana actual.

### Consideraciones de Rendimiento

- `pagos_v3` tiene ~3.5 millones de registros
- `pagos_dynamic` consolida pagos por préstamo/semana
- Evitar usar window functions (LEAD/LAG) en tablas grandes, preferir JOINs simples
- **Mantener `pagos_dynamic` actualizado** es crítico para cálculos correctos


### Gestión de Préstamos Activos vs Completados

**Tablas:**
- `prestamos_v2`: Préstamos **activos** (con saldo pendiente)
- `prestamos_completados`: Préstamos **liquidados** (Saldo = 0), respaldo histórico

**Flujo normal:**
Cuando un préstamo llega a Saldo = 0, se migra automáticamente de `prestamos_v2` → `prestamos_completados` y se elimina de `prestamos_dynamic`.

**Revertir migración (regresar a activo):**
Si se detecta un error (ej: pago duplicado eliminado), usar:

```sql
-- 1. Insertar en prestamos_v2 desde completados
INSERT INTO prestamos_v2 (
    PrestamoID, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
    Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
    No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
    Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
    Saldos_Migrados, wk_descu, Descuento, Porcentaje, Multas, wk_refi, Refin, Externo,
    Saldo, Cobrado, Tipo_de_credito, Aclaracion,
    Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
    Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
    Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
    Telefono_Cliente, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
    NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad, Depuracion,
    Folio_de_pagare, excel_index, cliente_xpress_id, cliente_persona_id, aval_persona_id,
    impacta_en_comision
)
SELECT 
    pc.PrestamoID, pc.Cliente_ID, p.nombres, p.apellido_paterno, p.apellido_materno,
    p.calle, p.no_exterior, p.no_interior, p.colonia, p.codigo_postal, p.municipio, p.estado,
    pc.No_De_Contrato, pc.Agente, pc.Gerencia, pc.SucursalID, pc.Semana, pc.Anio, pc.plazo,
    pc.Monto_otorgado, pc.Cargo, pc.Total_a_pagar, pc.Primer_pago, pc.Tarifa,
    pc.Saldos_Migrados, pc.wk_descu, pc.Descuento, pc.Porcentaje, pc.Multas, pc.wk_refi, pc.Refin, pc.Externo,
    @SALDO_CORRECTO AS Saldo,
    @COBRADO_CORRECTO AS Cobrado,
    pc.Tipo_de_credito, pc.Aclaracion,
    COALESCE(a.nombres, ''), COALESCE(a.apellido_paterno, ''), COALESCE(a.apellido_materno, ''),
    COALESCE(a.calle, ''), a.no_exterior, a.no_interior, a.colonia,
    a.codigo_postal, COALESCE(a.municipio, ''), COALESCE(a.estado, ''), a.telefono, NULL,
    p.telefono, pc.Dia_de_pago, pc.Gerente_en_turno, pc.Agente2, pc.Status, pc.Capturista,
    pc.NoServicio, pc.Tipo_de_Cliente, pc.Identificador_Credito, pc.Seguridad, pc.Depuracion,
    pc.Folio_de_pagare, pc.excel_index, pc.cliente_xpress_id, pc.cliente_persona_id, pc.aval_persona_id,
    pc.impacta_en_comision
FROM prestamos_completados pc
LEFT JOIN personas p ON pc.cliente_persona_id = p.id
LEFT JOIN personas a ON pc.aval_persona_id = a.id
WHERE pc.PrestamoID = '@PRESTAMO_ID';

-- 2. Insertar/actualizar en prestamos_dynamic
INSERT INTO prestamos_dynamic (prestamo_id, saldo, cobrado)
VALUES ('@PRESTAMO_ID', @SALDO_CORRECTO, @COBRADO_CORRECTO)
ON DUPLICATE KEY UPDATE saldo = @SALDO_CORRECTO, cobrado = @COBRADO_CORRECTO;

-- 3. Eliminar de completados
DELETE FROM prestamos_completados WHERE PrestamoID = '@PRESTAMO_ID';

-- 4. Corregir cadena abre_con/cierra_con en pagos_dynamic si es necesario
Variables a reemplazar:
@PRESTAMO_ID: ID del préstamo
@SALDO_CORRECTO: Saldo real pendiente
@COBRADO_CORRECTO: Total cobrado real (Total_a_pagar - Saldo)