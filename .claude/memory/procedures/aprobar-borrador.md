# Aprobar borradores de préstamo

## Aprobar uno

```sql
CALL aprobar_borrador_individual(<borrador_id>);
```

El SP:
1. Lee `Semana` y `Anio` del borrador (NO usa la semana actual del calendario).
2. Genera nuevo `PrestamoID` formato `<sem>.<aa>-<consec>-<gXX><zz>` (el `PrestamoID_propuesto` del borrador es solo placeholder, lo reemplaza).
3. Inserta en `prestamos_v2`.
4. Crea primer pago en `pagos_v3` con `Fecha_pago = NOW()` MX pero `Semana = v_semana_borrador`.
5. Marca borrador como `APROBADO` y guarda `fecha_aprobacion`.

## Aprobar varios a la vez

```sql
CALL aprobar_borradores_masivo();
-- o
CALL aprobar_borrador_individual(N);
CALL aprobar_borrador_individual(M);
...
```

## Buscar pendientes

```sql
SELECT borrador_id, Nombres, Apellido_Paterno, Agente, Semana, Anio, fecha_creacion
FROM prestamos_borradores
WHERE estado_borrador = 'PENDIENTE'
ORDER BY fecha_creacion;
```

## Revertir aprobación

```sql
CALL revertir_aprobacion_borrador(<borrador_id>);
```

## Notas importantes

- Si el usuario captura un borrador en la semana actual pero le pone `Semana = N-1` (caso típico al inicio de semana nueva), el SP lo registrará en sem N-1 correctamente. **No editar manualmente la semana del borrador antes de aprobar**, el SP la respeta.
- El primer pago en `pagos_v3` queda con `Fecha_pago` = hoy pero `Semana` = la del borrador. Esto es el comportamiento correcto.
