# Asignaciones tipo "Agente" no son ingreso de gerencia

⚠️ El backend filtra intencionalmente las asignaciones tipo `"Agente"` del lado de **ingresos** del detalle de cierre.

## Por qué

Una asignación tipo `"Agente"` representa **dinero que el agente le entrega a la gerencia**. Ese dinero **ya fue contabilizado** en `cobranza.cobranzaPura` cuando el agente lo recibió del cliente. Sumarlo otra vez como ingreso de la gerencia sería **doble contabilidad**.

Tipos que SÍ cuentan como ingreso:
- `"Operación"`, `"Admin"`, `"Seguridad"` — son movimientos entre gerencias o desde oficina (flujo nuevo).

## Dónde está el filtro

`back-cierres-gerencias-elysiajs/src/detalles-cierre/detalles-cierre.service.ts:159`:
```ts
if (a.tipo === "Agente") continue;
```

Solo aplica a INGRESOS. En egresos no hay filtro por tipo (todos cuentan).

## Síntoma común

App muestra `Ingresos.Asignaciones = $0.00` y el usuario reporta que "faltan asignaciones".  
**Casi siempre es esto** — 45 de 47 gerencias en sem 17/2026 reciben solo asignaciones tipo "Agente", todas verán $0.

Antes de tratarlo como bug:
1. Query rápido: `SELECT tipo, COUNT(*), SUM(monto) FROM asignaciones_v2 WHERE gerencia_recibe = ? AND semana = ? AND anio = ? GROUP BY tipo`
2. Si todas son tipo "Agente" → es comportamiento esperado, NO es bug de datos.

Caso de referencia: [incidents/2026-04-23-asignaciones-cero-app.md](../incidents/2026-04-23-asignaciones-cero-app.md)
