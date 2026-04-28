# Incidente: SP sp_generar_registros_call_center se llamó tarde, semana sin registros

**Fecha:** 2026-04-22 / 23 | **Estado:** resuelto manualmente

## Síntoma

Usuario llamó `CALL sp_generar_registros_call_center()` un lunes de semana N+1, esperando generar registros de call center. SP corrió "OK" pero insertó 0 registros.

## Causa raíz

El SP filtra `prestamos_v2 WHERE Semana = v_semana_actual AND Anio = v_anio_actual`. La semana actual al momento de la llamada era la N+1 (que aún no tiene préstamos cargados), así que encontró 0. La semana N anterior (645 préstamos) nunca se procesó porque nadie llamó al SP durante esa semana.

## Fix manual

Para llenar la semana N pasada, ejecutar el INSERT que el SP haría pero con la semana específica:

```sql
INSERT INTO registros_call_center (prestamo_id, reportar_seguridad, fecha_creacion, fecha_modificacion)
SELECT p.PrestamoID, 0, NOW(), NOW()
FROM prestamos_v2 p
WHERE p.Semana = <N> AND p.Anio = <YYYY>
  AND p.PrestamoID NOT IN (
    SELECT prestamo_id FROM registros_call_center WHERE prestamo_id IS NOT NULL
  );
```

Es idempotente, no duplica.

## Lo que aprendimos

- `sp_generar_registros_call_center` siempre opera sobre la semana del calendario actual; no acepta parámetro de semana.
- Si se brincó una semana, hay que insertar manualmente con el script de arriba.
- Idea: parametrizar el SP para aceptar `(semana, anio)` opcional. Por ahora no urgente.
