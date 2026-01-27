# MCP Xpress Database

Scripts SQL y utilidades para gestionar la base de datos Xpress Dinero mediante servidor MCP.

## Acceso Rápido

```bash
# Ejecutar consulta SQL
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT * FROM gerencias LIMIT 5"}'
```

## Estructura del Proyecto

```
MCP-XPRESS/
├── sql/                    # Scripts SQL organizados por feature
│   ├── cobranza/          # Historial y cálculos de cobranza
│   ├── prestamos/         # Gestión de préstamos (activos, completados, borradores)
│   ├── pagos/             # Triggers y sistema de pagos
│   ├── cierres/           # Cierres semanales por agencia
│   ├── liquidaciones/     # Liquidaciones y descuentos
│   ├── multas/            # Sistema de multas separado
│   ├── debitos/           # Débitos automáticos
│   ├── vistas/            # Vistas de base de datos
│   ├── tests/             # Scripts de prueba
│   └── mantenimiento/     # Alters y correcciones
│
├── docs/                   # Documentación
│   ├── guias/             # Guías de migración y estrategias
│   ├── auditorias/        # Reportes de validación
│   ├── specs/             # Especificaciones de features
│   └── tickets-api/       # API REST para sistema de tickets
│
├── config/                 # Archivos de configuración
│   ├── calendar17-25.json # Mapeo semanas/fechas
│   └── conexion-mcp.txt   # Credenciales MCP
│
├── scripts/                # Scripts shell (cron, validación)
├── assets/                 # Imágenes y recursos
├── filtrado/              # Sistema IA de evaluación crediticia
├── gastos/                # Gestión de gastos
├── javalin/               # Servicios backend Java
├── logs/                  # Auditoría de préstamos
├── migracion/             # Plan de migración masiva
└── rh/                    # Módulo de Recursos Humanos
```

## Features Principales

### SQL por Categoría

| Carpeta | Contenido |
|---------|-----------|
| `sql/cobranza` | SP de cobranza (V1-V4), historial, dashboard |
| `sql/prestamos` | Tablas completados/borradores/congelados, migración |
| `sql/pagos` | Triggers pagos_v3, sincronización, correcciones |
| `sql/cierres` | Functions status cierre, queries agencias |
| `sql/liquidaciones` | SP liquidación, cálculos, porcentajes |
| `sql/multas` | Tabla multas, triggers separación |
| `sql/debitos` | Tabla débitos, evento automático |

### Módulos Especiales

- **filtrado/** - Prompt IA para evaluación crediticia con score 0-10
- **rh/** - Especificación completa de módulo RH (15 endpoints)
- **docs/tickets-api/** - Cliente REST para sistema de tickets CouchDB

## Documentación

- [CLAUDE.md](CLAUDE.md) - Documentación técnica completa
- [docs/guias/](docs/guias/) - Guías de migración y estrategias
- [docs/tickets-api/](docs/tickets-api/) - API de tickets de soporte

## Datos de Prueba

- **46 Gerencias**: GERC001-GERC010, GERD001-GERD011, GERE001-GERE014, etc.
- **Semanas recientes**: 43/2025 (242 cierres), 42/2025 (291 cierres)
