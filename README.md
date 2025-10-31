# MCP Xpress Database - Hetzner

Scripts SQL y utilidades para consultar la base de datos Xpress Dinero mediante servidor MCP.

## Acceso Rápido

```bash
# Ejecutar consulta SQL
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT * FROM gerencias LIMIT 5"}'

# Listar estructura de base de datos
curl -X POST 'http://65.21.188.158:7400/list_mariadb_structure' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json'
```

## Scripts Disponibles

- **crear_function_status_cierre.sql** - Procedimientos para verificar estado de cierres semanales
- **query_agencias_con_cierre_semanal.sql** - Consulta agencias con cierre
- **query_agencias_sin_cierre_semanal.sql** - Consulta agencias pendientes de cierre
- **crear_table_function.sql** - Función reutilizable para agencias sin cerrar

## Herramientas MCP

El servidor ofrece 10 herramientas para consultar la base de datos:
- Estructura de base de datos (tablas, vistas, procedures)
- Detalles de objetos específicos
- Ejecución de consultas SELECT
- Vista previa de tablas

Ver documentación completa en [CLAUDE.md](CLAUDE.md)

## Datos de Prueba

- **46 Gerencias**: GERC001-GERC010, GERD001-GERD011, GERE001-GERE014, etc.
- **Semanas recientes**: 43/2025 (242 cierres), 42/2025 (291 cierres)

## Documentación

Consulta [CLAUDE.md](CLAUDE.md) para documentación completa sobre:
- Arquitectura de base de datos
- Procedimientos almacenados
- Lógica de negocio (débito, cobranza, snapshots)
- Ejemplos de uso
