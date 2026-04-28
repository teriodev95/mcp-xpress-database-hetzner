# Incidente: App muestra "Asignaciones $0" — falsa alarma

**Fecha:** 2026-04-23 | **Ticket:** 1776999958572 (cerrado, error de usuario) | **Estado:** comportamiento esperado

## Síntoma

Usuario reporta que en la App, sección "Ingresos Totales > Asignaciones" muestra **$0.00** y dice que "no se reflejan las asignaciones".

## Diagnóstico

No es bug. Las asignaciones tipo `"Agente"` están filtradas intencionalmente del lado de ingresos. Ver [business-rules/asignaciones-tipo-agente.md](../business-rules/asignaciones-tipo-agente.md).

Para sem 17/2026: 45 de 47 gerencias reciben **solo** asignaciones tipo "Agente" → todas ven $0 en la App. Es comportamiento global, no específico.

## Cómo descartarlo rápido

```sql
SELECT tipo, COUNT(*), SUM(monto)
FROM asignaciones_v2
WHERE gerencia_recibe = '<GERID>' AND semana = ? AND anio = ?
GROUP BY tipo;
```

Si todas son `tipo = "Agente"` → falsa alarma, cerrar ticket.

## Mejora UX pendiente (potencial HU)

El campo "Asignaciones $0" en la sección de ingresos confunde. Opciones:
- Esconder el campo cuando es $0
- Renombrarlo o mostrar tooltip explicando que las "Agente" se reflejan dentro de Cobranza
- Mover la sección "Asignaciones recibidas (informativo)" como un detalle expandible

No urgente, pero genera tickets repetidos.
