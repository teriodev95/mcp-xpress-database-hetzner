# Memory Base — MCP-XPRESS

Knowledge base local del proyecto. Vive en el repo, se comparte vía git push.

## Cómo usar (instrucciones para Claude)

1. **No listes tablas aquí** — usa el MCP (`list_mariadb_structure`, `get_table_details`) para schema.
2. **Esta carpeta solo guarda lógica de negocio no-obvia, quirks, y bugs ya diagnosticados.**
3. Antes de responder sobre un tema del dominio, consulta `glossary.md` y los archivos relevantes.
4. Cada vez que descubras algo no documentado, usa el skill `/recordar` para guardarlo.

## Contenido

### Reglas de negocio (`business-rules/`)
- [saldo-cobrado-tiempo.md](business-rules/saldo-cobrado-tiempo.md) — `prestamos_v2.Saldo` vs `prestamos_dynamic.saldo` (start-of-week vs real-time)
- [abrecon-cierracon.md](business-rules/abrecon-cierracon.md) — Cadena `AbreCon[N] = CierraCon[N-1]` y cómo calcular bien
- [cobranza-formulas.md](business-rules/cobranza-formulas.md) — Débito, cobranza pura, excedente, query base por agencia
- [asignaciones-tipo-agente.md](business-rules/asignaciones-tipo-agente.md) — Por qué App muestra "$0" en asignaciones
- [formato-codigos.md](business-rules/formato-codigos.md) — `GERXXX` vs `GerXXX`, `AGEXXX`, formato de `PrestamoID`

### Procedimientos (`procedures/`)
- [transferir-cliente-agencia.md](procedures/transferir-cliente-agencia.md)
- [aprobar-borrador.md](procedures/aprobar-borrador.md)
- [sincronizar-pagos-dynamic.md](procedures/sincronizar-pagos-dynamic.md) — Fix del bug de merge de pagos
- [revertir-prestamo-completado.md](procedures/revertir-prestamo-completado.md) — Regresar de `prestamos_completados` a `prestamos_v2`

### Bitácora de incidentes (`incidents/`)
- [2026-04-24-rollback-prestamos-dynamic-no-ejecuta.md](incidents/2026-04-24-rollback-prestamos-dynamic-no-ejecuta.md) — Eliminar liquidación deja "fantasma" en `prestamos_dynamic` (sin rollback)
- [2026-04-23-pagos-dynamic-merge-bug.md](incidents/2026-04-23-pagos-dynamic-merge-bug.md) — Trigger fusiona pagos de semanas distintas
- [2026-04-23-buscar-personas-cartesian.md](incidents/2026-04-23-buscar-personas-cartesian.md) — Cartesian product en search + duplicados
- [2026-04-23-asignaciones-cero-app.md](incidents/2026-04-23-asignaciones-cero-app.md) — Falsa alarma: filtro by-design
- [2026-04-22-borradores-semana-perdida.md](incidents/2026-04-22-borradores-semana-perdida.md) — SP call_center se llamó tarde, semana 16 sin registros

### Glosario
- [glossary.md](glossary.md)
