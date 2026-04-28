# Glosario

| Término | Significado |
|---------|-------------|
| **Débito** | Pago semanal esperado: `LEAST(Saldo, Tarifa)`. NO es lo cobrado, es lo que debería entrar. |
| **Cobranza pura** | Parte del pago que cubre el débito: `LEAST(Monto, LEAST(Tarifa, Saldo))`. |
| **Excedente** | Pago que sobrepasa la tarifa: `Monto - Cobranza_pura`. |
| **Liquidación** | Pago que cierra completamente el préstamo (Saldo → 0). |
| **AbreCon** | Saldo del préstamo al INICIO de la semana (antes del pago de esa semana). |
| **CierraCon** | Saldo al FINAL de la semana (después del pago). Regla: `CierraCon[N] = AbreCon[N+1]`. |
| **Borrador** | Préstamo capturado pero pendiente de aprobación. Vive en `prestamos_borradores`, no impacta a operación hasta ser aprobado. |
| **Cierre semanal** | Snapshot al final de cada semana de las métricas de la agencia/gerencia. Tabla: `cierres_semanales_consolidados_v2`. |
| **Asignación tipo "Agente"** | Dinero que el agente entrega a la gerencia. NO es ingreso adicional — el dinero ya estaba contado en la cobranza del agente. Por eso el dashboard la filtra de ingresos. |
| **Asignación tipo "Seguridad/Operación/Admin"** | Movimiento entre gerencias o desde oficina. SÍ cuenta como ingreso/egreso real. |
| **prestamos_v2** | Tabla principal. `Saldo` y `Cobrado` son al INICIAR la semana actual. |
| **prestamos_dynamic** | Saldo en tiempo real (después de cada pago). |
| **pagos_v3** | Pagos individuales (~3.5M registros). Fuente de verdad. |
| **pagos_dynamic** | Pagos consolidados por (préstamo + semana). Lo que el dashboard lee. Puede desincronizarse — ver [incidents/2026-04-23-pagos-dynamic-merge-bug.md](incidents/2026-04-23-pagos-dynamic-merge-bug.md). |
| **GERXXX vs GerXXX** | El mismo gerente. `GERC001` es el `GerenciaID` (formato API/dashboard); `GerC001` o `Ger001` es el `deprecated_name` (formato en `prestamos_v2.Gerencia`). Ver [formato-codigos.md](business-rules/formato-codigos.md). |
| **AGEXXX / AGM018 / AGDC005** | Código de **agencia**. Se guarda en `prestamos_v2.Agente` (sí, el campo se llama "Agente" pero contiene el código de agencia, no el nombre del agente). |
