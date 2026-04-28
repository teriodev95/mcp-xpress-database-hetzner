# Saldo y Cobrado: 3 fuentes, 3 momentos distintos

⚠️ **El campo `Saldo` no es lo mismo en todas las tablas.** Confundirlo causa diagnósticos erróneos.

## Reglas

| Tabla | `Saldo` representa | `Cobrado` representa |
|-------|--------------------|-----------------------|
| `prestamos_v2.Saldo` | Saldo **AL INICIAR** la semana actual (snapshot estático) | Cobrado **AL INICIAR** la semana actual |
| `prestamos_dynamic.saldo` | Saldo **en tiempo real** (después del último pago) | Cobrado **en tiempo real** |
| `pagos_dynamic.cierra_con` | Saldo **al final de la semana N** del registro | — |

## Cuándo usar cada uno

- **Cálculo de débito semanal** → `prestamos_v2.Saldo` (es el saldo al iniciar la semana, que es exactamente lo que define el débito)
- **¿Cuánto debe el cliente AHORA?** → `prestamos_dynamic.saldo`
- **¿Cómo evolucionó por semana?** → `pagos_dynamic.abre_con` / `cierra_con` o `pagos_v3.AbreCon` / `CierraCon`

## Pista de diagnóstico

Si ves `prestamos_v2.Saldo > 0` y `prestamos_dynamic.saldo = 0`, **NO es un bug** — es porque el cliente pagó dentro de la semana actual y el snapshot semanal aún no rota. El préstamo está liquidado y será migrado a `prestamos_completados` por `migrar_prestamos_completados()`.

## Caso real

Préstamo `03.26-005-03mo` (sem 17/2026):
- `prestamos_v2.Saldo`: $595.81 ← saldo al iniciar sem 17 ✅
- `prestamos_dynamic.saldo`: -$0.19 ← real-time, pagó completo + $0.19 excedente ✅
- Ambos correctos, solo distintos momentos.
