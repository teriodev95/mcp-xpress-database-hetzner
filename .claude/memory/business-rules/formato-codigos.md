# Convenciones de códigos

## Gerencias

Hay **dos formatos** para la misma gerencia, según donde se guarde:

| Contexto | Formato | Ejemplo |
|----------|---------|---------|
| `gerencias.GerenciaID` (oficial, dashboard, API) | `GERXX###` | `GERC007`, `GERDC001`, `GERGC001` |
| `gerencias.deprecated_name` (legacy, lo que está en `prestamos_v2.Gerencia`) | `GerXX###` o `Ger###` | `GerC007`, `Ger007`, `GerGC001` |

Ejemplo: `GERC007` (dashboard) ↔ `Ger007` (en `prestamos_v2.Gerencia`).

Para queries que crucen `prestamos_v2` con `gerencias`:
```sql
JOIN gerencias g ON g.deprecated_name = prestamos_v2.Gerencia
-- o filtrar directo por GerenciaID:
WHERE g.GerenciaID = 'GERC007'
```

## Agencias (campo `Agente` en prestamos_v2)

⚠️ **El campo `prestamos_v2.Agente` guarda el código de la AGENCIA, no el nombre del agente.**

Formato: `AG<inicial-zona><nro>`
- `AGE074` — zona Efectivo, agencia 074
- `AGM018` — zona Moneda, agencia 018
- `AGDC005` — zona DEC, agencia 005
- `AGGC003` — zona GoCash, agencia 003
- `AGC079` — zona Capital, agencia 079
- `AGD007` — zona Dinero, agencia 007

El nombre del agente humano vive en `agencias_status_auxilar.Agente`.

## PrestamoID

Formato: `<sem>.<aa>-<consec>-<gXX><zz>`
- `<sem>`: semana de originación, 2 dígitos
- `<aa>`: últimos 2 dígitos del año
- `<consec>`: consecutivo en base36 (3 chars)
- `<gXX>`: últimos 2 chars de la gerencia (`007`, `001`, etc.)
- `<zz>`: sufijo de sucursal (2 chars):
  - `di` = dinero
  - `pl` = plata
  - `mo` = moneda
  - `ef` = efectivo
  - `ca` = capital
  - `dc` = dec
  - `pu` = puebla
  - `gc` = gocash

Ejemplo: `16.26-004-01dc` = sem 16 / 2026, consec 004, gerencia 01, sucursal dec.

⚠️ El consecutivo se calcula al APROBAR el borrador, basado en la **`Semana` del borrador**, no la semana actual. El `PrestamoID_propuesto` del borrador es solo placeholder, lo reemplaza el SP `aprobar_borrador_individual`.
