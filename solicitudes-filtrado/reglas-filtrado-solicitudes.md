# Reglas de Filtrado de Solicitudes - Xpress Dinero

## Rol: Revisor

Al iniciar una sesión de filtrado, **preguntar al usuario**:
1. Gerencia a filtrar
2. Semana y año

Con esos datos, consultar las solicitudes pendientes y revisarlas una por una.

---

## API del Revisor

**Base URL**: `https://elysia.xpress1.cc/api/solicitud-filtro`
**Base URL Historial**: `https://elysia.xpress1.cc/api/filtrado-clientes/historial`

| Acción | Método | Endpoint | Body requerido |
|---|---|---|---|
| Listar pendientes | `GET` | `/?gerencia=X&semana=N&anio=N&status=pendiente` | — |
| Ver detalle | `GET` | `/:id` | — |
| Aprobar | `PATCH` | `/:id` | `status`, `reviewed_by`, `diagnostico`, `resultado_revision`, `tabla_cargos_id_sugerido` |
| Rechazar | `PATCH` | `/:id` | Lo anterior + `motivo_rechazo` |
| Pedir corrección | `PATCH` | `/:id` | Lo anterior + `motivo_rechazo`, `doc_invalido_detalle` |
| Corregir datos | `PATCH` | `/:id` | Campos a corregir (`nombre_cliente`, `curp_cliente`, etc.) |
| Historial cliente | `GET` | `/api/filtrado-clientes/historial/:persona_id` | — |

### Flujo de status

```
pendiente  →  aprobada     (requiere resultado_revision + diagnostico + tabla_cargos_id_sugerido)
pendiente  →  rechazada    (requiere lo anterior + motivo_rechazo)
pendiente  →  corregir     (requiere lo anterior + motivo_rechazo + doc_invalido_detalle)
corregir   →  pendiente    (automático al subir doc corregido)
```

---

## Los 33 Checks

Cada solicitud debe pasar los 33 checks en orden. El resultado se guarda en `resultado_revision` con estructura fija.

### Paso 0: Identidad e historial (checks c08-c13, c14-c17, c25-c26)

#### 0a. Buscar al cliente en BD

**No confiar en `tipo_credito`.** El agente puede marcar "nuevo" a un cliente existente. Siempre buscar.

**Si tiene `persona_id_cliente`** → consultar historial directo:
```bash
curl -s 'https://elysia.xpress1.cc/api/filtrado-clientes/historial/{persona_id_cliente}'
```

**Si NO tiene `persona_id_cliente`** → buscar en BD en este orden:

1. **Por nombre + agencia** (más confiable, datos migrados no tienen CURP):
```sql
SELECT pv.PrestamoID, pv.Nombres, pv.Apellido_Paterno, pv.Apellido_Materno,
       pv.Monto_otorgado, pv.Tipo_de_Cliente, pv.cliente_persona_id, pv.Agente
FROM prestamos_v2 pv
WHERE CONCAT(pv.Apellido_Paterno, ' ', pv.Apellido_Materno, ' ', pv.Nombres) = '{nombre_cliente}'
  AND pv.Agente = '{agencia}'
```

2. **Por nombre sin agencia** (pudo cambiar de agencia):
```sql
SELECT id, nombres, apellido_paterno, apellido_materno
FROM personas
WHERE CONCAT(apellido_paterno, ' ', apellido_materno, ' ', nombres) = '{nombre_cliente}'
```

3. **Por CURP** (solo si existe):
```sql
SELECT id, nombres, apellido_paterno, apellido_materno
FROM personas WHERE curp = '{curp_cliente}'
```

4. **Por nombre invertido** (OCR a veces invierte apellidos):
```sql
SELECT id, nombres, apellido_paterno, apellido_materno
FROM personas
WHERE CONCAT(apellido_materno, ' ', apellido_paterno, ' ', nombres) = '{nombre_cliente}'
```

Si se encuentra → asignar `persona_id_cliente` y llamar al historial.

**Respuesta del historial:**
```json
{
  "score_final": 100,
  "prestamos": [
    {
      "PrestamoID": "L-9820-ef",
      "tipo_prestamo": "ACTIVO",
      "Tipo_de_Cliente": "LEAL",
      "Agente": "AGE037",
      "Monto_otorgado": 14000,
      "Saldo": 870.31,
      "Tarifa": 877.69,
      "plazo": 26,
      "total_semanas_pagadas": 25,
      "semanas_sin_pago": 0,
      "semanas_reducidas": 0,
      "semanas_reducidas_bajo_50": 0,
      "pct_deficit_promedio": 0,
      "score": 100,
      "cumple_saldo": 1,
      "cumple_plazo": 1,
      "cumple_sin_no_pagos": 1,
      "cumple_sin_reducidos_graves": 1,
      "cumple_minimo_reducido": 1
    }
  ]
}
```

**Datos que se extraen del historial:**

| Dato | Cómo obtenerlo | Para qué check |
|------|---------------|-----------------|
| `score_final` | Campo directo | c25 |
| Préstamo ACTIVO con `Saldo < Tarifa` | Filtrar `tipo_prestamo = "ACTIVO"` | c24 (última semana) |
| Último COMPLETADO `Monto_otorgado` | Primer registro COMPLETADO | c21 (aumento max) |
| Último COMPLETADO `Tipo_de_Cliente` | Primer registro COMPLETADO | c22 (nivel válido) |
| Últimos N scores | Array de scores de COMPLETADOS | c22 (nivel por scores) |

**Validar nivel con scores (c22):**
- NUEVO: no requiere historial
- NOBEL: último 1 crédito completado con score ≥ 80
- VIP: últimos 2 créditos completados con score ≥ 80
- PREMIUM: últimos 3 créditos completados con score ≥ 80
- LEAL: últimos 4 créditos completados con score ≥ 80
- DIAMANTE: acumulado mínimo $50,000 pagados puntualmente

#### 0b. Buscar al aval en BD

Mismo proceso que 0a. Buscar por nombre, asignar `persona_id_aval`.

#### 0c. Verificar historial del aval (checks c14, c15, c16, c17)

Si el aval tiene `persona_id_aval`, ejecutar las 4 validaciones:

**c14 — ¿Fue cliente con mal historial?**
```bash
curl -s 'https://elysia.xpress1.cc/api/filtrado-clientes/historial/{persona_id_aval}'
```
- `score_final < 60` → **RECHAZAR**. "Aval {nombre} fue cliente con score {score}."
- `score_final = 0` → **RECHAZAR**. "Aval {nombre} fue cliente moroso severo."
- `score_final ≥ 60` o no fue cliente → OK
- Si no fue cliente (prestamos vacío) → `null` (no aplica)

**c15 — ¿Avaló a un cliente con mal historial?**
```sql
SELECT pv.PrestamoID, pv.cliente_persona_id, pv.Agente
FROM prestamos_v2 pv WHERE pv.aval_persona_id = '{persona_id_aval}'
UNION ALL
SELECT pc.PrestamoID, pc.cliente_persona_id, pc.Agente
FROM prestamos_completados pc WHERE pc.aval_persona_id = '{persona_id_aval}'
```
Por cada `cliente_persona_id` encontrado, consultar su historial. Si alguno tiene `score_final < 60` → **RECHAZAR**. "Aval {nombre} avaló a cliente {nombre_cliente} con score {score}."
- Si nunca avaló a nadie → `null` (no aplica)

**c16 — ¿Avaló a un cliente con liquidación especial?**
```sql
SELECT * FROM liquidaciones
WHERE prestamoID IN ({prestamos_de_clientes_avalados})
AND tipo = 'especial'
```
**NOTA:** La columna es `prestamoID` (camelCase), NO `prestamo_id`.
- Si hay resultado → **RECHAZAR**. "Aval {nombre} avaló a cliente con liquidación especial ({prestamoID})."
- Si nunca avaló a nadie → `null` (no aplica)

**c17 — ¿Es aval activo en otra agencia?**
```sql
SELECT pv.PrestamoID, pv.Agente
FROM prestamos_v2 pv
JOIN prestamos_dynamic pd ON pd.prestamo_id = pv.PrestamoID
WHERE pv.aval_persona_id = '{persona_id_aval}'
AND pv.Agente != '{agencia_solicitud}'
AND pd.saldo > 0
```
- Si hay resultados → **RECHAZAR**. "Aval {nombre} es aval activo en {agencia}."

#### 0d. Acciones según resultado

- Cliente **SÍ existe** pero solicitud dice "nuevo" → corregir `tipo_credito` a "renovacion", asignar `persona_id_cliente`
- Cliente **NO existe** pero solicitud dice "renovacion" → investigar o marcar `corregir`

---

### Paso 1: Documentos (checks c01-c07)

**c01 — Los 4 documentos OCR son legibles**
- `docs_validos = 1` → `true`
- Si alguno falló → `false`, `status: "corregir"`, indicar cuál en `doc_invalido_detalle`

**c02 — INE del cliente vigente**
- Verificar fecha de vigencia en `documentos.ine_cliente.datos_extraidos`
- Si está vencida → `false`, `status: "corregir"`, indicar: "INE del cliente vencida (vigencia: {fecha}). Se requiere INE vigente."

**c03 — INE del aval vigente**
- Misma lógica que c02 con `documentos.ine_aval.datos_extraidos`

**c04 — Comprobante del cliente no mayor a 3 meses**
- Verificar periodo facturado o fecha de emisión en `documentos.comprobante_cliente.datos_extraidos`
- Calcular desde la fecha actual. Si tiene más de 3 meses → `false`, `status: "corregir"`
- Si el periodo no es legible (null) → `false`, `status: "corregir"`, indicar: "No se pudo leer periodo del comprobante. Se requiere nueva foto."
- **Para comprobantes CFE**: el periodo de vigencia se determina con los campos **"LÍMITE DE PAGO"** y **"CORTE A PARTIR"** que aparecen en el recibo. Ejemplo: `LÍMITE DE PAGO: 11 ENE 26` / `CORTE A PARTIR: 12 ENE 26`. La fecha de corte indica el fin del periodo facturado; calcular antigüedad desde esa fecha.

**c05 — Comprobante del aval no mayor a 3 meses**
- Misma lógica que c04 con `documentos.comprobante_aval.datos_extraidos`

**c06 — Si comprobante cliente es de agua: periodos vencidos = 0**
- Solo aplica si el comprobante es de agua (HidroSistema, CONAGUA, etc.), NO de CFE
- Si es agua y `periodos_vencidos > 0` → `false`, `status: "corregir"`, indicar: "Comprobante de agua tiene {N} periodos vencidos."
- Si no es agua → `null`

**c07 — Si comprobante aval es de agua: periodos vencidos = 0**
- Misma lógica que c06

**Tipo de comprobante e identificador de domicilio:**

| Tipo | Cómo identificarlo | Identificador para regla domicilio |
|------|--------------------|------------------------------------|
| CFE (luz) | Dice "CFE", "Comisión Federal de Electricidad" | `no_servicio` |
| Agua | Dice "HidroSistema", "CONAGUA", "Agua Potable", etc. | `contrato` |

---

### Paso 2: Datos de identidad (checks c08-c13)

**c08 — Nombre cliente coincide con INE**
- Comparar `nombre_cliente` con el nombre extraído de `documentos.ine_cliente.datos_extraidos.nombre`
- Si no coincide y el OCR leyó mal → corregir con PATCH antes de continuar

**c09 — Nombre aval coincide con INE**
- Misma lógica con `nombre_aval` vs `documentos.ine_aval.datos_extraidos.nombre`

**c10 — CURP cliente válido**
- 18 caracteres, formato alfanumérico correcto
- Si no tiene CURP (dato migrado antiguo) → `true` (no es motivo de rechazo)

**c11 — CURP aval válido**
- Misma lógica

**c12 — persona_id_cliente asignado**
- Se encontró en BD (Paso 0a/0b) o es cliente nuevo verificado → `true`
- No se pudo encontrar ni verificar → `false`

**c13 — persona_id_aval asignado**
- Misma lógica

---

### Paso 3: Domicilio (checks c18-c20)

El identificador depende del tipo de comprobante (Paso 1):
- **CFE** → usar `no_servicio`
- **Agua** → usar `contrato`

**c18 — Máximo 3 clientes en el mismo domicilio**
```sql
SELECT COUNT(*) as clientes
FROM prestamos_v2 pv
JOIN prestamos_dynamic pd ON pd.prestamo_id = pv.PrestamoID
WHERE pv.NoServicio = '{identificador}'
AND pd.saldo > 0
```
- `clientes < 3` o `clientes = 3` y el solicitante ya es uno de ellos → `true`
- `clientes ≥ 3` y el solicitante es nuevo en ese domicilio → `false`

**c19 — Saldo total + monto nuevo no supera límite**
```sql
SELECT COALESCE(SUM(pd.saldo), 0) as saldo_total
FROM prestamos_v2 pv
JOIN prestamos_dynamic pd ON pd.prestamo_id = pv.PrestamoID
WHERE pv.NoServicio = '{identificador}'
AND pd.saldo > 0
```
- Límite: **$30,000** (o **$40,000** si nivel = DIAMANTE)
- `saldo_total + monto_solicitado ≤ límite` → `true`

**c20 — Domicilio no cruzado con otra agencia/gerencia**
```sql
SELECT pv.PrestamoID, pv.Agente, pv.Gerencia, pd.saldo
FROM prestamos_v2 pv
JOIN prestamos_dynamic pd ON pd.prestamo_id = pv.PrestamoID
WHERE pv.NoServicio = '{identificador}'
AND pd.saldo > 0
AND (pv.Agente != '{agencia_solicitud}' OR pv.Gerencia != '{gerencia_solicitud}')
```
- Sin resultados → `true`
- Con resultados → `false`, **RECHAZAR**. "Domicilio ({identificador}) tiene clientes activos en {agencia}/{gerencia}."

---

### Paso 4: Renovación (checks c21-c27)

**Solo aplica si `tipo_credito = "renovacion"`.** Si es "nuevo", poner `null` en c21-c25, c27.

Datos necesarios del historial (Paso 0a):
- Préstamo ACTIVO (si existe): para detectar última semana
- Último préstamo COMPLETADO: monto anterior, nivel anterior, score

**c21 — Aumento máximo $2,000**
- `monto_solicitado - monto_anterior ≤ 2,000` → `true`
- Si supera → `false`
- Si es nuevo → `null`

**c22 — Nivel justificado por scores**
- Los últimos N créditos COMPLETADOS deben tener `score ≥ 80`
- NOBEL: 1, VIP: 2, PREMIUM: 3, LEAL: 4
- Si cumple → `true`, si no → `false`
- Si es nuevo → `null`

**c23 — Si liquidó con descuento: no sube de nivel**
- Verificar si el último crédito tuvo liquidación con descuento
- Si tuvo descuento y el nivel solicitado es mayor al anterior → `false`
- Si tuvo descuento pero mantiene o baja nivel → `true`
- Si no tuvo descuento → `null`

**c24 — Si última semana: mismo monto y nivel**
- Última semana = préstamo ACTIVO con `Saldo < Tarifa`
- Si es última semana y solicita más monto o mayor nivel → `false`
- Si es última semana pero mantiene monto y nivel → `true`
- Si no es última semana → `null`

**c25 — Score del cliente aceptable**
- `score_final ≥ 80` → `true` (buen cliente)
- `60 ≤ score_final < 80` → `true` (con observaciones, anotar en diagnóstico)
- `score_final < 60` → `false`, **RECHAZAR**. Cliente de alto riesgo.
- `score_final = 0` → `false`, **RECHAZAR inmediatamente**. Moroso severo.
- Si es nuevo → `null`

**c26 — Cliente no tiene liquidación especial**
```sql
SELECT * FROM liquidaciones
WHERE prestamoID IN ({prestamos_del_cliente})
AND tipo = 'especial'
```
- Sin resultados → `true`
- Con resultados → `false`, **RECHAZAR**.

**c27 — Estudio socioeconómico requerido**
- Si `monto_solicitado > 5,000` (renovación) → `true` (marcar que requiere estudio)
- Si `monto_solicitado ≤ 5,000` → `null`
- **NOTA:** Este check no bloquea, solo informa.

---

### Paso 5: Tabla de cargos (checks c28-c33)

Consultar el plan solicitado:
```sql
SELECT id, monto_solicitado, nivel, plazo_semanas, tarifa_semanal, total_pagar,
       gerente, oficina, garantias_cliente, seguridad, direccion
FROM tabla_cargos
WHERE id = {tabla_cargos_id}
```

**c28 — tabla_cargos_id existe y corresponde**
- El ID existe y el monto/nivel/plazo coinciden con lo solicitado → `true`
- No existe o no corresponde → `false`

**c29 a c33 — Flags de requerimientos adicionales**

Estos checks son **informativos**: indican qué autorizaciones adicionales necesita el crédito según `tabla_cargos`. El valor es `true` si SÍ se requiere esa autorización.

| Check | Campo en tabla_cargos | Significado si `true` |
|-------|----------------------|----------------------|
| c29 | `gerente = 1` | Requiere aprobación del gerente |
| c30 | `oficina = 1` | Requiere aprobación de oficina |
| c31 | `garantias_cliente = 1` | Requiere garantías del cliente |
| c32 | `seguridad = 1` | Requiere verificación de seguridad |
| c33 | `direccion = 1` | Requiere verificación de dirección |

---

### Paso 6: Decisión

**NUNCA rechazar sin buscar alternativa.** Si el monto/nivel no procede, buscar plan alternativo:

```sql
SELECT id, monto_solicitado, nivel, plazo_semanas, tarifa_semanal, total_pagar,
       gerente, oficina, garantias_cliente, seguridad, direccion
FROM tabla_cargos
WHERE nivel = '{nivel_permitido}'
  AND plazo_semanas = {plazo_solicitado}
  AND monto_solicitado <= {monto_anterior} + 2000
ORDER BY monto_solicitado DESC
LIMIT 1
```

| Resultado | status | Campos obligatorios |
|-----------|--------|---------------------|
| Todo OK | `aprobada` | `resultado_revision`, `diagnostico`, `tabla_cargos_id_sugerido` (= mismo ID solicitado) |
| No procede pero hay alternativa | `rechazada` | Lo anterior + `motivo_rechazo`, `tabla_cargos_id_sugerido` (= ID alternativo) |
| No procede sin alternativa | `rechazada` | Lo anterior + `motivo_rechazo` (sin sugerencia viable) |
| Doc inválido/vencido | `corregir` | Lo anterior + `motivo_rechazo`, `doc_invalido_detalle` |

---

## Formato fijo de `resultado_revision`

**IMPORTANTE: Respetar SIEMPRE esta estructura exacta. No agregar ni quitar keys. Si un check no aplica, poner `null`. Si no se pudo evaluar, poner `false` y explicar en diagnóstico.**

```json
{
  "checks": {
    "c01_docs_legibles":                         true,
    "c02_ine_cliente_vigente":                   true,
    "c03_ine_aval_vigente":                      true,
    "c04_comprobante_cliente_reciente":           true,
    "c05_comprobante_aval_reciente":              true,
    "c06_comprobante_agua_al_corriente_cliente":  null,
    "c07_comprobante_agua_al_corriente_aval":     null,
    "c08_nombre_cliente_coincide":                true,
    "c09_nombre_aval_coincide":                   true,
    "c10_curp_cliente_valido":                    true,
    "c11_curp_aval_valido":                       true,
    "c12_persona_id_cliente_asignado":            true,
    "c13_persona_id_aval_asignado":               true,
    "c14_aval_no_fue_cliente_moroso":             true,
    "c15_aval_no_avalo_cliente_moroso":            true,
    "c16_aval_no_avalo_liq_especial":             true,
    "c17_aval_no_activo_otra_agencia":            true,
    "c18_domicilio_max_3_clientes":               true,
    "c19_domicilio_max_monto":                    true,
    "c20_domicilio_no_cruce_agencia":             true,
    "c21_aumento_max_2000":                       null,
    "c22_nivel_valido_por_scores":                null,
    "c23_no_liquido_con_descuento_y_sube":        null,
    "c24_ultima_semana_respetada":                null,
    "c25_score_cliente_aceptable":                null,
    "c26_no_liq_especial_cliente":                true,
    "c27_estudio_socioeconomico":                 null,
    "c28_tabla_cargos_valida":                    true,
    "c29_requiere_gerente":                       false,
    "c30_requiere_oficina":                       false,
    "c31_requiere_garantias":                     false,
    "c32_requiere_seguridad":                     false,
    "c33_requiere_direccion":                     false
  },
  "detalle": {
    "cliente": {
      "persona_id": "J0ZR-1645-DTSD-de",
      "score_final": 100
    },
    "aval": {
      "persona_id": "N0MG-7334-AA4C-de",
      "fue_cliente": false,
      "score_como_cliente": null,
      "clientes_avalados_scores": [100]
    },
    "prestamo_anterior": {
      "prestamo_id": "L-9820-ef",
      "monto": 14000,
      "nivel": "LEAL",
      "score": 100
    },
    "prestamo_activo": {
      "prestamo_id": "L-9820-ef",
      "saldo": 870.31,
      "tarifa": 877.69,
      "ultima_semana": true
    },
    "domicilio": {
      "identificador": "237091102595",
      "tipo": "cfe",
      "clientes_activos": 1,
      "saldo_activo": 870.31,
      "saldo_con_nuevo": 14870.31,
      "limite": 30000
    },
    "tabla_cargos": {
      "id": 318,
      "monto": 14000,
      "nivel": "LEAL",
      "plazo": 26,
      "tarifa": 877.69,
      "total_pagar": 22820,
      "requiere_gerente": false,
      "requiere_oficina": false,
      "requiere_garantias": false,
      "requiere_seguridad": false,
      "requiere_direccion": false
    }
  },
  "tabla_cargos_id_sugerido": 318
}
```

### Valores de cada campo en `detalle`

| Campo | Cuándo es `null` |
|-------|-----------------|
| `cliente.persona_id` | Si es nuevo y no se encontró en BD |
| `cliente.score_final` | Si es nuevo (no tiene historial) |
| `aval.persona_id` | Si no se encontró en BD |
| `aval.fue_cliente` | Nunca es null (siempre true/false) |
| `aval.score_como_cliente` | Si no fue cliente |
| `aval.clientes_avalados_scores` | Si nunca avaló a nadie (poner `[]`) |
| `prestamo_anterior` | Todo el objeto es `null` si es nuevo |
| `prestamo_activo` | Todo el objeto es `null` si no tiene préstamo activo |
| `domicilio` | Nunca es null |
| `tabla_cargos` | Nunca es null |
| `tabla_cargos_id_sugerido` | Nunca es null: mismo ID si aprobada, alternativo si rechazada, solicitado si corregir |

---

## Ejemplo completo: PATCH aprobada

```bash
curl -X PATCH "https://elysia.xpress1.cc/api/solicitud-filtro/5" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "aprobada",
    "reviewed_by": "claude_revisor",
    "tabla_cargos_id_sugerido": 318,
    "diagnostico": "Renovación $14,000 LEAL 26sem. Anterior: $14,000 LEAL (L-9820-ef). Mismo monto y nivel. Score 100. Última semana (saldo $870 < tarifa $877) pero no sube monto ni nivel. Domicilio OK (1 cliente, $870 activo, límite $30K). Aval N0MG nunca fue cliente. Docs OK.",
    "resultado_revision": {
      "checks": {
        "c01_docs_legibles": true,
        "c02_ine_cliente_vigente": true,
        "c03_ine_aval_vigente": true,
        "c04_comprobante_cliente_reciente": true,
        "c05_comprobante_aval_reciente": true,
        "c06_comprobante_agua_al_corriente_cliente": null,
        "c07_comprobante_agua_al_corriente_aval": null,
        "c08_nombre_cliente_coincide": true,
        "c09_nombre_aval_coincide": true,
        "c10_curp_cliente_valido": true,
        "c11_curp_aval_valido": true,
        "c12_persona_id_cliente_asignado": true,
        "c13_persona_id_aval_asignado": true,
        "c14_aval_no_fue_cliente_moroso": null,
        "c15_aval_no_avalo_cliente_moroso": true,
        "c16_aval_no_avalo_liq_especial": true,
        "c17_aval_no_activo_otra_agencia": true,
        "c18_domicilio_max_3_clientes": true,
        "c19_domicilio_max_monto": true,
        "c20_domicilio_no_cruce_agencia": true,
        "c21_aumento_max_2000": true,
        "c22_nivel_valido_por_scores": true,
        "c23_no_liquido_con_descuento_y_sube": null,
        "c24_ultima_semana_respetada": true,
        "c25_score_cliente_aceptable": true,
        "c26_no_liq_especial_cliente": true,
        "c27_estudio_socioeconomico": true,
        "c28_tabla_cargos_valida": true,
        "c29_requiere_gerente": false,
        "c30_requiere_oficina": false,
        "c31_requiere_garantias": false,
        "c32_requiere_seguridad": false,
        "c33_requiere_direccion": false
      },
      "detalle": {
        "cliente": {"persona_id": "J0ZR-1645-DTSD-de", "score_final": 100},
        "aval": {"persona_id": "N0MG-7334-AA4C-de", "fue_cliente": false, "score_como_cliente": null, "clientes_avalados_scores": [100]},
        "prestamo_anterior": {"prestamo_id": "L-9820-ef", "monto": 14000, "nivel": "LEAL", "score": 100},
        "prestamo_activo": {"prestamo_id": "L-9820-ef", "saldo": 870.31, "tarifa": 877.69, "ultima_semana": true},
        "domicilio": {"identificador": "237091102595", "tipo": "cfe", "clientes_activos": 1, "saldo_activo": 870.31, "saldo_con_nuevo": 14870.31, "limite": 30000},
        "tabla_cargos": {"id": 318, "monto": 14000, "nivel": "LEAL", "plazo": 26, "tarifa": 877.69, "total_pagar": 22820, "requiere_gerente": false, "requiere_oficina": false, "requiere_garantias": false, "requiere_seguridad": false, "requiere_direccion": false}
      },
      "tabla_cargos_id_sugerido": 318
    }
  }'
```

## Ejemplo completo: PATCH rechazada con sugerencia

```bash
curl -X PATCH "https://elysia.xpress1.cc/api/solicitud-filtro/7" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "rechazada",
    "reviewed_by": "claude_revisor",
    "motivo_rechazo": "Score 0 en último crédito (29 semanas sin pago). No califica para LEAL.",
    "tabla_cargos_id_sugerido": 85,
    "diagnostico": "Solicita $16,000 LEAL 26sem. Score 0 — moroso severo (29 sem sin pago en último crédito). No califica para ningún nivel con historial. Se sugiere reiniciar como NUEVO $8,000 21sem (id 85, tarifa $594.29).",
    "resultado_revision": {
      "checks": {
        "c01_docs_legibles": true,
        "c02_ine_cliente_vigente": true,
        "c03_ine_aval_vigente": true,
        "c04_comprobante_cliente_reciente": true,
        "c05_comprobante_aval_reciente": true,
        "c06_comprobante_agua_al_corriente_cliente": null,
        "c07_comprobante_agua_al_corriente_aval": null,
        "c08_nombre_cliente_coincide": true,
        "c09_nombre_aval_coincide": true,
        "c10_curp_cliente_valido": true,
        "c11_curp_aval_valido": true,
        "c12_persona_id_cliente_asignado": true,
        "c13_persona_id_aval_asignado": true,
        "c14_aval_no_fue_cliente_moroso": null,
        "c15_aval_no_avalo_cliente_moroso": null,
        "c16_aval_no_avalo_liq_especial": null,
        "c17_aval_no_activo_otra_agencia": true,
        "c18_domicilio_max_3_clientes": true,
        "c19_domicilio_max_monto": true,
        "c20_domicilio_no_cruce_agencia": true,
        "c21_aumento_max_2000": true,
        "c22_nivel_valido_por_scores": false,
        "c23_no_liquido_con_descuento_y_sube": null,
        "c24_ultima_semana_respetada": null,
        "c25_score_cliente_aceptable": false,
        "c26_no_liq_especial_cliente": true,
        "c27_estudio_socioeconomico": true,
        "c28_tabla_cargos_valida": true,
        "c29_requiere_gerente": false,
        "c30_requiere_oficina": false,
        "c31_requiere_garantias": false,
        "c32_requiere_seguridad": false,
        "c33_requiere_direccion": false
      },
      "detalle": {
        "cliente": {"persona_id": "R0GR-3635-RXYV-de", "score_final": 0},
        "aval": {"persona_id": null, "fue_cliente": false, "score_como_cliente": null, "clientes_avalados_scores": []},
        "prestamo_anterior": {"prestamo_id": "47666", "monto": 14000, "nivel": "LEAL", "score": 0},
        "prestamo_activo": null,
        "domicilio": {"identificador": "237190803325", "tipo": "cfe", "clientes_activos": 0, "saldo_activo": 0, "saldo_con_nuevo": 16000, "limite": 30000},
        "tabla_cargos": {"id": 154, "monto": 8000, "nivel": "LEAL", "plazo": 21, "tarifa": 594.29, "total_pagar": 12480, "requiere_gerente": false, "requiere_oficina": false, "requiere_garantias": false, "requiere_seguridad": false, "requiere_direccion": false}
      },
      "tabla_cargos_id_sugerido": 85
    }
  }'
```

## Ejemplo completo: PATCH corregir

```bash
curl -X PATCH "https://elysia.xpress1.cc/api/solicitud-filtro/10" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "corregir",
    "reviewed_by": "claude_revisor",
    "motivo_rechazo": "Comprobante de domicilio del cliente vencido. Periodo: 19 AGO 25 - 20 OCT 25 (más de 4 meses). Se requiere comprobante reciente (máximo 3 meses).",
    "doc_invalido_detalle": "comprobante_cliente",
    "tabla_cargos_id_sugerido": 1,
    "diagnostico": "Nuevo $3,000 NUEVO 16sem. Comprobante cliente periodo AGO-OCT 2025 — vencido (>4 meses). Demás checks OK. Se pide corrección del comprobante.",
    "resultado_revision": {
      "checks": {
        "c01_docs_legibles": true,
        "c02_ine_cliente_vigente": true,
        "c03_ine_aval_vigente": true,
        "c04_comprobante_cliente_reciente": false,
        "c05_comprobante_aval_reciente": true,
        "c06_comprobante_agua_al_corriente_cliente": null,
        "c07_comprobante_agua_al_corriente_aval": null,
        "c08_nombre_cliente_coincide": true,
        "c09_nombre_aval_coincide": true,
        "c10_curp_cliente_valido": true,
        "c11_curp_aval_valido": true,
        "c12_persona_id_cliente_asignado": true,
        "c13_persona_id_aval_asignado": false,
        "c14_aval_no_fue_cliente_moroso": null,
        "c15_aval_no_avalo_cliente_moroso": null,
        "c16_aval_no_avalo_liq_especial": null,
        "c17_aval_no_activo_otra_agencia": true,
        "c18_domicilio_max_3_clientes": true,
        "c19_domicilio_max_monto": true,
        "c20_domicilio_no_cruce_agencia": true,
        "c21_aumento_max_2000": null,
        "c22_nivel_valido_por_scores": null,
        "c23_no_liquido_con_descuento_y_sube": null,
        "c24_ultima_semana_respetada": null,
        "c25_score_cliente_aceptable": null,
        "c26_no_liq_especial_cliente": true,
        "c27_estudio_socioeconomico": null,
        "c28_tabla_cargos_valida": true,
        "c29_requiere_gerente": false,
        "c30_requiere_oficina": false,
        "c31_requiere_garantias": false,
        "c32_requiere_seguridad": false,
        "c33_requiere_direccion": false
      },
      "detalle": {
        "cliente": {"persona_id": "DMJO-5586-DOAQ-de", "score_final": null},
        "aval": {"persona_id": null, "fue_cliente": false, "score_como_cliente": null, "clientes_avalados_scores": []},
        "prestamo_anterior": null,
        "prestamo_activo": null,
        "domicilio": {"identificador": "237960901576", "tipo": "cfe", "clientes_activos": 0, "saldo_activo": 0, "saldo_con_nuevo": 3000, "limite": 30000},
        "tabla_cargos": {"id": 1, "monto": 3000, "nivel": "NUEVO", "plazo": 16, "tarifa": 367.00, "total_pagar": 5880, "requiere_gerente": false, "requiere_oficina": false, "requiere_garantias": false, "requiere_seguridad": false, "requiere_direccion": false}
      },
      "tabla_cargos_id_sugerido": 1
    }
  }'
```

---

## Reglas de Negocio (Referencia)

### Niveles de Clientes

| Nivel | Requisito |
|---|---|
| **Nuevo** | Sin historial o no calificó para subir |
| **Nobel** | 1 crédito anterior con score ≥ 80 |
| **VIP** | 2 últimos créditos con score ≥ 80 |
| **Premium** | 3 últimos créditos con score ≥ 80 |
| **Leal** | 4 últimos créditos con score ≥ 80 |
| **Diamante** | Acumulado mínimo $50,000 pagados puntualmente |

### Condiciones de Renovación

1. **Aumento máximo**: $2,000 sobre el crédito anterior
2. **Renovación > $5,000**: requiere estudio socioeconómico
3. **Última semana** (Saldo < Tarifa en préstamo activo): NO aumento de monto ni nivel
4. **Liquidación con descuento**: NO sube de nivel, SÍ puede aumentar monto
5. **Liquidación especial**: se rechaza (`SELECT * FROM liquidaciones WHERE prestamoID = '{id}' AND tipo = 'especial'`)
6. **Liquidación anticipada sin descuento**: SÍ puede subir nivel y monto (mínimo 6 días naturales después)

### Regla de Domicilio

- Máximo **$30,000** y/o **3 clientes** por identificador de domicilio (no_servicio o contrato)
- Nivel **Diamante**: hasta **$40,000**
- El domicilio NO debe estar registrado en otra agencia/gerencia

### Tabla de Créditos a Avales

Semanas mínimas pagadas del cliente avalado para autorizar crédito al aval:

| Nivel | $2K-$4.9K (16/21/26) | $5K-$7.9K (16/21/26) | $8K-$9.9K (16/21/26) | $10K-$11.9K (16/21/26) | $12K-$20K (16/21/26) |
|---|---|---|---|---|---|
| Nuevo | 10/12/14 | 11/13/15 | -/-/16 | -/-/- | -/-/- |
| Nobel | 9/11/13 | 10/12/14 | -/-/15 | -/-/- | -/-/- |
| VIP | 8/10/12 | 9/11/13 | -/-/14 | -/-/- | -/-/- |
| Premium | 7/9/11 | 8/10/12 | -/-/13 | -/-/- | -/-/- |
| Leal | 6/8/10 | 7/9/11 | -/-/12 | -/-/- | -/-/- |
| Diamante | 4/6/8 | 5/7/9 | -/8/10 | -/-/11 | -/-/12 |

---

## Estructura de Tablas

### solicitudes_filtro

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | int PK | Identificador único |
| `persona_id_cliente` | varchar(64) | ID persona. NULL si nuevo sin historial |
| `persona_id_aval` | varchar(64) | ID persona del aval |
| `no_servicio_cliente` | varchar(64) | Identificador domicilio: no_servicio (CFE) o contrato (agua) |
| `no_servicio_aval` | varchar(64) | Identificador domicilio del aval |
| `curp_cliente` | varchar(20) | CURP extraído de INE por OCR |
| `curp_aval` | varchar(20) | CURP del aval |
| `nombre_cliente` | varchar(192) | Nombre completo (formato: Apellido_P Apellido_M Nombres) |
| `nombre_aval` | varchar(192) | Nombre completo del aval |
| `tabla_cargos_id` | int | FK a tabla_cargos — plan solicitado |
| `monto_solicitado` | int | Monto del crédito |
| `plazo_semanas` | int | 16, 21 o 26 |
| `nivel` | varchar(10) | NUEVO, NOBEL, VIP, PREMIUM, LEAL, DIAMANTE |
| `tipo_credito` | varchar(32) | "nuevo" o "renovacion" |
| `prestamo_anterior_id` | varchar(32) | PrestamoID del último crédito completado |
| `monto_anterior` | int | Monto del crédito anterior |
| `nivel_anterior` | varchar(10) | Nivel del crédito anterior |
| `liquidado_con_descuento` | tinyint(1) | 1 si liquidó con descuento |
| `agencia` | varchar(64) | Código de agencia (ej: AGE037) |
| `gerencia` | varchar(64) | Código de gerencia (ej: GERE011) |
| `semana` | int | Semana del calendario Xpress |
| `anio` | int | Año |
| `documentos` | longtext JSON | 4 docs OCR: ine_cliente, comprobante_cliente, ine_aval, comprobante_aval |
| `data` | longtext JSON | Metadata: solicitud_id_r2, snapshot tabla_cargos, tokens OCR |
| `docs_validos` | tinyint(1) | 1 si los 4 docs fueron leídos por OCR |
| `doc_invalido_detalle` | varchar(255) | Qué documento falló |
| `status` | ENUM | pendiente, aprobada, rechazada, corregir |
| `reviewed_by` | varchar(32) | Quién revisó |
| `reviewed_at` | timestamp | Cuándo se revisó |
| `motivo_rechazo` | text | Razón del rechazo o corrección |
| `resultado_revision` | longtext JSON | JSON con los 33 checks + detalle (formato fijo) |
| `diagnostico` | text | Resumen legible para humanos |
| `tabla_cargos_id_sugerido` | int | FK a tabla_cargos — plan sugerido/aprobado |
| `created_by` | varchar(32) | Agente que creó la solicitud |
| `created_at` | timestamp | Fecha de creación |
| `updated_at` | timestamp | Última modificación |

### tabla_cargos (catálogo, 365 registros)

| Campo | Descripción |
|---|---|
| `id` | PK |
| `monto_solicitado` | $2,000 a $20,000 |
| `nivel` | NUEVO, NOBEL, VIP, PREMIUM, LEAL, DIAMANTE |
| `plazo_semanas` | 16, 21, 26 |
| `cargo_total_porcentaje` | % de cargo (37%-75%) |
| `cargo` | Cargo en pesos |
| `total_pagar` | monto + cargo |
| `tarifa_semanal` | Pago semanal |
| `gerente` | 1 = requiere aprobación gerente (→ c29) |
| `oficina` | 1 = requiere aprobación oficina (→ c30) |
| `garantias_cliente` | 1 = requiere garantías (→ c31) |
| `seguridad` | 1 = requiere verificación seguridad (→ c32) |
| `direccion` | 1 = requiere verificación dirección (→ c33) |
