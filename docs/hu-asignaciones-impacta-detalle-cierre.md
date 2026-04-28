# HU: Control de impacto en detalle de cierre para asignaciones con Seguridad

## Contexto del problema

Cuando Seguridad actua como intermediario en el flujo de efectivo (recoge dinero de agencias y lo entrega al gerente), el sistema registra multiples asignaciones para el **mismo dinero**. Todas nacen con `impacta_detalle_cierre = 1` por defecto, causando **doble conteo** en el detalle de cierre de la gerencia.

### Flujos identificados en la BD

```
FLUJO A - Cobranza de agencias (NO debe impactar):
  Agente ──→ Seguridad ──→ Gerente
  El dinero ya esta contado en la cobranza de la agencia.
  Seguridad solo es mensajero.

FLUJO B - Traspaso entre gerencias (el 2do tramo NO debe impactar):
  Gerente A ──→ Seguridad ──→ Gerente B
  El 1er tramo ya impacta como egreso de Gerencia A.
  El 2do tramo NO debe impactar como ingreso de Gerencia B (ya se conto).

FLUJO C - Entrega a Admin/Regional (SI debe impactar):
  Seguridad ──→ Jefe de Admin / Regional
  Es la salida final del efectivo. SI impacta.
```

### Impacto cuantificado (2026)

| Problema | Registros | Monto mal contado |
|---|---|---|
| Seguridad → Gerente (misma gerencia) con impacta=1 | 23 | $492,610 |
| Cadenas Agente → Seguridad → destino (ambos tramos con impacta=1) | ~20 pares | $72,163 |
| Traspasos entre gerencias (2do tramo con impacta=1) | 4 | ~$100,000 |
| **Total estimado de doble conteo** | | **~$664,773** |

### Estado actual del campo `impacta_detalle_cierre`

- El campo siempre nace en `1` (DEFAULT en BD)
- En 2026: 7,131 registros con `1` vs solo 10 con `0`
- Los 10 con `0` fueron correcciones **manuales** (updated_at > created_at)
- No existe logica automatizada para asignar el valor correcto

### Datos de Seguridad relevantes

- Hay 14 usuarios de Seguridad activos
- **No tienen gerencia fija** (campo `usuarios.Gerencia` siempre vacio)
- Cada Seguridad atiende multiples gerencias de la misma "familia" (GERC, GERD, GERE, GERM, GERP)
- No existe el flujo Admin → Seguridad en la BD (0 registros)

---

## Historia de Usuario

**Como** usuario de Seguridad que entrega efectivo a un Gerente,
**quiero** indicar si el dinero proviene de la cobranza de agencias o de otra fuente,
**para que** el sistema registre correctamente si debe impactar o no en el detalle de cierre de la gerencia.

---

## Solucion propuesta

### UX - Pantalla al registrar entrega de Seguridad a Gerente

Cuando un usuario tipo **Seguridad** registra una entrega a un **Gerente**, mostrar un selector de origen **antes** de confirmar:

```
┌──────────────────────────────────────────────────┐
│  Entregar efectivo                               │
│                                                  │
│  Monto:    $5,600.00                             │
│  Entrega:  JAVIER MONTALVO (Seguridad)           │
│  Recibe:   JOSE ALEJANDRO MEDINA (Gerente)       │
│                                                  │
│  ─────────────────────────────────────────────── │
│                                                  │
│  Origen del efectivo:                            │
│                                                  │
│  ● Cobranza de agencias                         │
│    No impacta en cierre - ya esta en cobranza    │
│                                                  │
│  ○ Otro origen                                   │
│    Si impacta en cierre como ingreso             │
│                                                  │
│                          [Confirmar entrega]      │
└──────────────────────────────────────────────────┘
```

### Reglas de negocio

| Condicion | `impacta_detalle_cierre` | Razon |
|---|---|---|
| Seguridad entrega a Gerente + origen = "Cobranza de agencias" | **0** | El dinero ya esta contado en la cobranza de las agencias |
| Seguridad entrega a Gerente + origen = "Otro origen" | **1** | Es dinero nuevo que debe registrarse como ingreso |
| Cualquier otro tipo de asignacion | **1** (default actual) | No cambia el comportamiento existente |

### Default sugerido: "Cobranza de agencias"

- El **95%+** de las entregas Seguridad → Gerente son de cobranza
- El caso raro (otro origen) requiere accion consciente del usuario
- Reduce errores por omision

### Alcance minimo

1. **Solo aplica** cuando `quien_entrego.Tipo = 'Seguridad'` y `quien_recibio.Tipo = 'Gerente'`
2. **No requiere** cambios en la tabla `asignaciones_v2` (el campo `impacta_detalle_cierre` ya existe)
3. **No requiere** cambios en el backend de Elysia (ya respeta el campo correctamente)
4. **Solo requiere** cambio en la app/endpoint que **crea** la asignacion

### Donde implementar

El cambio es en el flujo de creacion de asignaciones:
1. **App movil** (si Seguridad registra desde app): agregar el selector de origen
2. **Endpoint API** que crea asignaciones: recibir el campo y guardarlo

### Lo que NO cambia

- El detalle de cierre de Elysia ya filtra por `impacta_detalle_cierre` (lineas 162 y 193 de `detalles-cierre.service.ts`)
- El dashboard de Javalin (agencias) no usa este campo y no debe cambiar
- Las asignaciones siempre se registran para trazabilidad (solo cambia si impactan o no)

---

## Criterios de aceptacion

1. Al registrar una entrega donde Seguridad entrega a Gerente, se muestra el selector de origen
2. Si selecciona "Cobranza de agencias", el registro se crea con `impacta_detalle_cierre = 0`
3. Si selecciona "Otro origen", el registro se crea con `impacta_detalle_cierre = 1`
4. El default es "Cobranza de agencias"
5. Para cualquier otro tipo de asignacion, el comportamiento no cambia (impacta = 1)
6. El detalle de cierre refleja correctamente los montos sin doble conteo

---

## Datos para testing

### Caso 1 - Cobranza (no impacta)
- Seguridad JAVIER (355) entrega $5,600 a Gerente JOSE ALEJANDRO (305) de GERE004
- Origen: Cobranza de agencias
- Esperado: `impacta_detalle_cierre = 0`
- El detalle de cierre de GERE004 NO debe sumar estos $5,600 como ingreso

### Caso 2 - Otro origen (si impacta)
- Seguridad JAVIER (355) entrega $3,000 a Gerente JOSE ALEJANDRO (305) de GERE004
- Origen: Otro
- Esperado: `impacta_detalle_cierre = 1`
- El detalle de cierre de GERE004 SI debe sumar estos $3,000 como ingreso

### Gerencias para validar correccion retroactiva
- **GERM007**: 9 asignaciones Seguridad→Gerente con impacta=1, $190,060 en doble conteo
- **GERE005**: 2 asignaciones, $114,700
- **GERM005**: 3 asignaciones, $54,000
