# Incidente: buscar-personas devuelve duplicados y conteos inflados

**Fecha:** 2026-04-23 | **Estado:** HU asignada a Diego/Luis (`5486814b-f736-4be9-8cf5-522ad2aa693b`)

## Síntoma

Endpoint `GET /api/prestamos/buscar-personas` devuelve la misma persona N veces ("Sin historial") y los conteos `activos_cliente`, `completados_cliente` aparecen multiplicados.

## Causa raíz

`back-cierres-gerencias-elysiajs/src/prestamos/prestamos.service.ts:594-702` (función `buscarPersonasPorGerencia`):

1. **Cartesian product**: 4 LEFT JOINs (`prestamos_v2` cliente/aval + `prestamos_completados` cliente/aval) multiplican filas. Si hay `A` activos × `B` completados, los `SUM()` se inflan por multiplicación.

2. **Segundo UNION sin dedupe**: La subconsulta de personas sin historial en la gerencia no deduplica por `(nombres + apellidos + telefono)`. Trae todos los registros duplicados de `personas` (la tabla no tiene UNIQUE constraint).

## Caso de referencia

Cliente `MARIA TERESA ESTEBAN MACARIO` (`MTEM-2472-K9CD-de`) en GERDC001:
- BD: 1 registro real, 1 préstamo activo, 4 completados
- API devuelve: 5 resultados, `activos_cliente=4` (debería ser 1)

## Fix propuesto

1. Reemplazar JOINs por subqueries escalares `(SELECT COUNT(*) FROM ... WHERE ...)`
2. Deduplicar el segundo UNION con `ROW_NUMBER() OVER (PARTITION BY nombre_normalizado, telefono ORDER BY tiene_historial DESC, created_at ASC)`

⚠️ **No eliminar el segundo UNION**: hay que mantener personas sin historial para permitir asignarles primer préstamo.

## Lo que aprendimos

- La tabla `personas` no tiene UNIQUE constraint. Hay duplicados creados por intentos de captura. Limpiar y agregar constraint queda para HU futura.
- Hay un endpoint similar (`POST /api/pagares/buscar-personas`) que puede tener el mismo bug — revisar.
