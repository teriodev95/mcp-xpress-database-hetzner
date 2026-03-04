# Reportes Generales Xpress — Especificacion

Aplicacion movil-first para visualizacion de reportes de cobranza con graficos interactivos. Tres vistas: Dashboard, Comparativo semanal y Avance por hora.

---

## 1. Producto

**Tipo:** Single Page Application movil-first (360px+), desplegada como sitio estatico.

**Vistas:**

| Vista | Ruta | Proposito |
|-------|------|-----------|
| Dashboard | `/` | KPIs globales + desglose por nivel organizacional con drill-down |
| Comparativo | `/comparativo` | Comparacion semana actual vs anterior para una entidad |
| Avance | `/avance` | Progresion hora por hora de la cobranza en un dia |

**Navegacion:** Tab bar flotante inferior con 3 tabs. Siempre visible.

---

## 2. Identidad visual

Estilo minimalista tipo iOS. Tipografia: Inter (Google Fonts, pesos 400/500/600/700).

### 2.1 Paleta de colores

| Token | Hex | Uso |
|-------|-----|-----|
| `primary` | `#0E2A3B` | Textos principales, headings, iconos activos |
| `accent` | `#D4A23A` | Botones, barras de grafico, indicador tab activo |
| `surface` | `#F7F9FB` | Fondo de la app |
| `card` | `#FFFFFF` | Fondo de cards, paneles, nav flotante |
| `border` | `#D9E1E7` | Bordes sutiles de cards e inputs |
| `success` | `#1F8F5F` | Rendimiento positivo, deltas favorables |
| `danger` | `#C0392B` | Errores, deltas negativos, faltante |
| `warning` | `#D4A23A` | Rendimiento medio |
| `muted` | `#6B7D8A` | Texto secundario, labels, iconos inactivos |

### 2.2 Semaforo de rendimiento

Se aplica a cualquier valor de rendimiento (%) en toda la app:

| Condicion | Color | Token |
|-----------|-------|-------|
| >= 80% | Verde | `success` |
| >= 50% y < 80% | Amarillo | `warning` |
| < 50% | Rojo | `danger` |

### 2.3 Componentes base

**Card:** Fondo blanco, esquinas redondeadas grandes (16px), borde sutil, padding 16px.

**KPI Card:** Dentro de una card. Label en 11px uppercase muted. Valor en 20px bold primary (o color semaforo si es rendimiento).

**Input/Select:** Fondo `surface`, borde `border`, esquinas redondeadas 12px, padding 12px horizontal / 10px vertical, 14px texto. Focus: borde `accent`.

**Boton primario:** Fondo `accent`, texto blanco 14px semibold, esquinas 12px, ancho completo, opacidad reducida al presionar/disabled.

**Spinner:** Circulo con borde parcial en `accent`, animacion de rotacion.

**Error:** Card con fondo `danger` al 10% opacidad, texto error centrado, boton "Reintentar" en `accent`.

**Lista scrolleable:** Dividers `border` entre items. Cada item: nombre a la izquierda (truncado), valores numericos a la derecha. Altura maxima con scroll.

**Selector toggle (nivel):** Fila de botones de igual ancho. Activo: fondo `primary` texto blanco. Inactivo: fondo `surface` texto `muted`.

---

## 3. API Backend

**Base URL:** `https://elysia.xpress1.cc/api`

> CRITICO: Todas las rutas llevan el prefijo `/api/`. Sin el, retorna NOT_FOUND.

### 3.1 Endpoints

#### GET `/api/reportes-generales/`

Consulta registros con filtros por query params.

**Parametros:**

| Param | Tipo | Descripcion |
|-------|------|-------------|
| `anio` | int | Anio (ej: 2026) |
| `semana` | int | Numero de semana (1-53) |
| `hora` | int | Hora del snapshot (0-23) |
| `dia_semana_es` | string | Dia de la semana en espanol SIN tilde |
| `gerencia` | string | Codigo de gerencia (ej: GERM006) |
| `agencia` | string | Codigo de agencia (ej: AGM052) |
| `sucursal` | string | Nombre de sucursal en minuscula |
| `page` | int | Pagina (default 1) |
| `per_page` | int | Registros por pagina (max 1000) |
| `sort` | string | Campo para ordenar |
| `order` | string | `asc` o `desc` |

#### POST `/api/reportes-generales/search`

Busqueda avanzada con filtros recursivos.

**Body:**
```json
{
  "limit": 5,
  "sortBy": "cobranza_total",
  "order": "desc",
  "filter": {
    "type": "group",
    "logic": "AND",
    "children": [
      { "type": "rule", "field": "dia_semana_es", "operator": "=", "value": "Viernes" },
      { "type": "rule", "field": "hora", "operator": "=", "value": 10 }
    ]
  }
}
```

**Operadores disponibles:** `=`, `!=`, `>`, `>=`, `<`, `<=`, `between`, `in`, `notIn`, `includes`, `startsWith`, `endsWith`, `isNull`, `isNotNull`, `true`, `false`

#### GET `/api/reportes-generales/comparativo`

Compara semana seleccionada vs la anterior.

**Parametros requeridos:** `anio`, `semana`, `dia_semana_es`, `hora` + al menos uno de: `gerencia`, `agencia`, `sucursal`.

**Respuesta:** `{ semana_actual: SemanaData, semana_anterior: SemanaData }` donde `SemanaData = { semana: int, total: int, registros: ReportRow[] }`.

### 3.2 Formato de respuesta estandar

```json
{
  "success": true,
  "code": "OK",
  "message": "...",
  "request_id": "uuid",
  "duration_ms": 5,
  "meta": {
    "timezone": "America/Mexico_City",
    "as_of": "2026-02-07T10:00:00",
    "pagination": {
      "page": 1,
      "per_page": 100,
      "total": 45,
      "total_pages": 1,
      "has_next": false,
      "has_prev": false
    }
  },
  "data": [...]
}
```

### 3.3 Reglas criticas de uso

| Regla | Detalle |
|-------|---------|
| Sin filtros = timeout | La tabla tiene ~122,000+ registros. SIEMPRE filtrar por al menos `dia_semana_es` + `hora`, o `gerencia`, o `sucursal` |
| Paginacion | Maximo 1000 registros por request |
| Dias sin tilde | La API devuelve `Sabado`, `Miercoles` (sin acentos). Usar siempre la lista: `Lunes, Martes, Miercoles, Jueves, Viernes, Sabado, Domingo` |
| Campos nullable | `gerencia` y `sucursal` pueden ser `null` |
| Comparativo es rapido | ~5ms porque filtra internamente |

---

## 4. Modelo de datos

### 4.1 Concepto: Snapshots (NO acumulativos)

Cada registro es un **snapshot del avance de cobranza** en un momento especifico del tiempo.

**Clave unica:** `anio` + `semana` + `dia_semana_es` + `hora` + `agencia`

**Reglas de agregacion:**

| Operacion | Permitida | Razon |
|-----------|-----------|-------|
| Sumar agencias del MISMO snapshot (misma semana+dia+hora) | SI | Cada agencia es independiente en ese instante |
| Sumar snapshots de DIFERENTES horas/dias para la misma agencia | NO | Duplicaria datos; hora=10 ya incluye lo cobrado hasta las 10:00 |
| Comparar mismo campo entre horas o dias | SI | Asi se ve la evolucion/progresion |
| Promediar rendimiento entre agencias | SI | Rendimiento es un porcentaje individual |

### 4.2 Jerarquia organizacional

```
Gerencia (~45) > Agencia (~100) > Sucursal (6)
```

| Nivel | Codigos ejemplo | Prefijos | Nullable |
|-------|----------------|----------|----------|
| Gerencia | `GERM006`, `GERC001` | `GERC`, `GERD`, `GERDC`, `GERE`, `GERM`, `GERP` | Si |
| Agencia | `AGM052`, `AGD003` | `AGC`, `AGD`, `AGDC`, `AGE`, `AGM`, `AGP`, `MAGA` | No |
| Sucursal | `capital`, `moneda` | Valores fijos: `capital`, `dec`, `dinero`, `efectivo`, `moneda`, `plata` | Si |

Cuando un campo nullable es `null`, mostrarlo como "Sin asignar".

### 4.3 Campos del registro

**Temporales:**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `fecha_mx` | string | Fecha en formato Mexico |
| `anio` | int | Anio |
| `semana` | int | Numero de semana (1-53) |
| `hora` | int | Hora del snapshot (0-23) |
| `dia_semana_es` | string | Dia de la semana sin tilde |

**Organizacion:**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `agencia` | string | Codigo de agencia |
| `gerencia` | string? | Codigo de gerencia (nullable) |
| `sucursal` | string? | Nombre de sucursal (nullable) |

**Cobranza:**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `clientes` | number | Cantidad de clientes |
| `no_pagos` | number | Cantidad de no pagos |
| `debito` | number | Total debito |
| `debito_miercoles` | number | Debito del miercoles |
| `debito_jueves` | number | Debito del jueves |
| `debito_viernes` | number | Debito del viernes |
| `cobranza_pura` | number | Cobranza pura |
| `excedente` | number | Excedente |
| `liquidaciones` | number | Liquidaciones |
| `cobranza_total` | number | Total de cobranza |

**Rendimiento (porcentajes 0-100+):**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `rendimiento` | number | Rendimiento general |
| `rendimiento_miercoles` | number | Rendimiento del miercoles |
| `rendimiento_jueves` | number | Rendimiento del jueves |
| `rendimiento_viernes` | number | Rendimiento del viernes |

**Faltantes y adelantos:**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `faltante` | number | Faltante total |
| `faltante_miercoles` | number | Faltante del miercoles |
| `faltante_jueves` | number | Faltante del jueves |
| `faltante_viernes` | number | Faltante del viernes |
| `adelanto_miercoles` | number | Adelanto del miercoles |
| `adelanto_jueves` | number | Adelanto del jueves |

**Ventas:**

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| `ventas_cantidad` | number | Cantidad de ventas |
| `ventas_monto` | number | Monto de ventas |

---

## 5. Formateo de valores

Locale: `es-MX`. Moneda: MXN.

| Tipo | Formato | Ejemplo |
|------|---------|---------|
| Moneda | MXN sin decimales | `$1,234,567` |
| Numero | Separador de miles | `1,234` |
| Porcentaje | 1 decimal + simbolo % | `85.3%` |
| Compacto | Millones (M) / Miles (K) | `1.2M`, `45K` |

---

## 6. Funciones de negocio

### 6.1 Calcular semana actual

A partir de la fecha actual, obtener el numero de semana del anio. Usar formula: `ceil((diasDesdeEneroPrimero + diaSemanaDe1Enero + 1) / 7)`.

### 6.2 Obtener dia de la semana

A partir de una fecha, retornar el nombre del dia SIN tilde: `Domingo, Lunes, Martes, Miercoles, Jueves, Viernes, Sabado`.

### 6.3 Agrupar por nivel organizacional

**Entrada:** Lista de registros + nivel (`gerencia` | `agencia` | `sucursal`).

**Proceso:** Agrupar los registros por el campo del nivel. Para cada grupo:
- Sumar: `cobranza_total`, `debito`, `clientes`, `faltante`
- Promediar: `rendimiento`
- Contar: registros en el grupo

**Salida:** Lista de grupos con `{ nombre, cobranza_total, debito, clientes, rendimiento_avg, faltante, registros }`, ordenada desc por `cobranza_total`.

**Caso null:** Si el campo del nivel es `null`, agrupar bajo el nombre `"Sin asignar"`.

### 6.4 Agrupar por hora (solo Avance)

**Entrada:** Lista de registros de TODAS las horas de un dia.

**Proceso:** Agrupar por campo `hora`. Para cada hora:
- Sumar: `cobranza_total`, `debito`, `faltante`, `clientes`
- Promediar: `rendimiento`
- Contar: agencias unicas

**Salida:** Lista de snapshots horarios `{ hora, cobranza_total, debito, rendimiento_avg, faltante, clientes, agencias }`, ordenada asc por `hora`.

### 6.5 Filtrar horas incompletas (solo Avance)

La ultima hora reportada del dia frecuentemente tiene datos parciales (no todas las agencias han reportado), lo que causa caidas dramaticas en graficos y metricas.

**Proceso:**
1. Determinar `maxAgencias` = maximo de agencias observado en cualquier hora
2. Filtrar: conservar solo horas con agencias >= 80% de `maxAgencias`
3. Las horas descartadas se cuentan y se informa al usuario con un banner de advertencia

### 6.6 Paginacion automatica (Avance)

La API tiene un limite de 1000 registros por request. Algunas entidades tienen mas registros por dia (ej: sucursal `efectivo` ~1953, `dinero` ~1659).

**Proceso:**
1. Hacer primer request con `per_page=1000, page=1`
2. Leer `total_pages` de la respuesta
3. Si hay mas paginas, fetchear las restantes en paralelo
4. Concatenar todos los resultados

### 6.7 Timezone Mexico

> CRITICO: Todas las fechas/horas deben calcularse en timezone `America/Mexico_City`, no en la hora local del navegador.

La inicializacion de filtros temporales (anio, semana, dia, hora) en todas las vistas debe basarse en la hora de Mexico City. Usar `Date.toLocaleString('en-US', { timeZone: 'America/Mexico_City' })` para obtener la hora correcta.

---

## 7. Tab Bar flotante

### 7.1 Estructura

Barra de navegacion fija en la parte inferior, flotante (no toca los bordes laterales ni inferior).

| Propiedad | Valor |
|-----------|-------|
| Forma | Card redondeada (radio ~22px) |
| Fondo | Blanco (`card`) |
| Sombra | Doble: difusion suave grande + base |
| Borde | Sutil, 30% opacidad de `border` |
| Margen horizontal | ~20px cada lado |
| Margen inferior | 10px minimo, o safe-area del dispositivo (lo que sea mayor) |
| Altura interior | 68px |

### 7.2 Tabs

| Tab | Ruta | Icono | Descripcion icono |
|-----|------|-------|-------------------|
| Dashboard | `/` | Grid 2x2 | 4 cuadrados redondeados en grilla |
| Comparativo | `/comparativo` | Flechas swap | Dos flechas opuestas (arriba-abajo) |
| Avance | `/avance` | Trending up | Linea ascendente con flecha |

### 7.3 Estados

**Activo:**
- Icono y texto en color `primary`
- Indicador: pill horizontal de 3px de alto, 24px de ancho, color `accent`, centrado en el borde superior del tab

**Inactivo:**
- Icono y texto en color `muted` al 60% opacidad

### 7.4 Iconos

Tamano: 23x23px. Estilo: outline (stroke), sin relleno. Grosor de linea: 1.5px. Color: heredado del estado.

### 7.5 Labels

Tamano: 10px. Peso: semibold. Tracking: wide. Debajo del icono con 5px de separacion.

### 7.6 Deteccion de tab activo

- `/` se activa solo con match exacto del pathname
- `/comparativo` y `/avance` se activan con `startsWith`

---

## 8. Vista: Dashboard (`/`)

### 8.1 Carga inicial

Al montar la vista, hacer fetch automatico con los filtros temporales inicializados a la fecha/hora actual.

### 8.2 Header

- Titulo: "Dashboard" (24px bold `primary`)
- Subtitulo: "Snapshot S{semana} · {dia} {hora}:00 · {total} agencias" (14px `muted`)

### 8.3 Filtros rapidos

Fila horizontal con 3 selects:
1. **Semana** (ancho fijo ~64px): opciones S1 a S53
2. **Dia** (flex): Lunes a Domingo
3. **Hora** (ancho fijo ~80px): 00:00 a 23:00

Cada cambio dispara un nuevo fetch inmediatamente.

### 8.4 Parametros del fetch

```
GET /api/reportes-generales/
  ?anio={anioActual}
  &semana={semanaSeleccionada}
  &dia_semana_es={diaSeleccionado}
  &hora={horaSeleccionada}
  &per_page=500
  &sort=cobranza_total
  &order=desc
```

Si hay drill-down activo, agregar `&gerencia={valor}` o `&agencia={valor}`.

### 8.5 Estados

| Estado | Interfaz |
|--------|----------|
| Cargando | Spinner centrado con padding vertical amplio |
| Error | Card roja con mensaje + boton "Reintentar" |
| Sin datos | Card con texto "Sin datos para este snapshot" + sugerencia |
| Con datos | KPIs + navegacion + charts |

### 8.6 KPIs (grid 2x2)

| Posicion | Label | Valor | Color |
|----------|-------|-------|-------|
| Top-left | COBRANZA | Suma `cobranza_total` de todos los rows | `primary` |
| Top-right | DEBITO | Suma `debito` | `primary` |
| Bottom-left | RENDIMIENTO | Promedio `rendimiento` | Semaforo |
| Bottom-right | FALTANTE | Suma `faltante` | `danger` |

### 8.7 Navegacion organizacional

**Card con:**

1. **Header:** Titulo del nivel activo (ej: "Gerencias"), breadcrumb si hay drill-down (ej: "· GERM006 · AGM052"), contador de grupos, boton ← si no esta en gerencia.

2. **Tabs de nivel** (solo visibles sin drill-down): Gerencia | Agencia | Sucursal. Tab activo: texto `accent` con borde inferior `accent` de 2px.

3. **Lista scrolleable** (max 320px alto): Cada item muestra:
   - Izquierda: nombre del grupo (truncado), cantidad clientes + cantidad agencias
   - Derecha: cobranza total (moneda), rendimiento (semaforo)
   - Tap: ejecuta drill-down (excepto nivel sucursal que es el mas bajo)

### 8.8 Drill-down

| Accion | Desde | Hacia | Filtro API agregado |
|--------|-------|-------|---------------------|
| Tap en gerencia | Gerencia | Agencia | `gerencia={nombre}` |
| Tap en agencia | Agencia | Sucursal | `agencia={nombre}` |
| Boton ← desde Sucursal | Sucursal | Agencia | Quita `agencia` |
| Boton ← desde Agencia | Agencia | Gerencia | Quita `gerencia` y `agencia` |

Cada transicion dispara un nuevo fetch con los filtros actualizados.

### 8.9 Graficos

**Grafico 1: Cobranza por {nivel}**
- Tipo: barras horizontales
- Datos: top 15 grupos ordenados por cobranza desc
- Eje Y: nombres de grupo (truncados a 70px)
- Eje X: valores en formato compacto
- Color barra: `accent`
- Esquinas: redondeadas a la derecha (4px)
- Ancho maximo barra: 20px
- Tooltip: formato moneda

**Grafico 2: Rendimiento por {nivel}**
- Tipo: barras horizontales
- Datos: top 15 grupos, valor = rendimiento promedio
- Eje X: 0% a 120%
- Color barra: semaforo individual (cada barra segun su valor)
- Esquinas: redondeadas a la derecha (4px)
- Tooltip: formato porcentaje 1 decimal

**Ambos graficos:**
- Contenidos en cards independientes
- Titulo: "Cobranza por {nivel}" / "Rendimiento por {nivel}"
- Altura responsiva: clamp(300px, 40vh, 500px)
- Grid: containLabel true, margenes 8px

---

## 9. Vista: Comparativo (`/comparativo`)

### 9.1 Header

- Titulo: "Comparativo" (24px bold `primary`)
- Subtitulo: "Semana actual vs anterior" (14px `muted`)

### 9.2 Filtros (dentro de una card)

**Fila 1 (grid 2x2):**
- Anio: input numerico
- Semana: input numerico (min 1, max 53)
- Dia: select con los 7 dias
- Hora: select 00:00 a 23:00

**Selector de nivel:** "Filtrar por" + 3 botones toggle (Gerencia / Agencia / Sucursal). Al cambiar nivel, limpiar el valor.

**Input de valor:**
- Si nivel = sucursal: dropdown con las 6 opciones fijas (`capital`, `dec`, `dinero`, `efectivo`, `moneda`, `plata`)
- Si nivel = gerencia: input texto con placeholder "Ej: GERM006"
- Si nivel = agencia: input texto con placeholder "Ej: AGM052"

**Boton "Comparar":** Deshabilitado si no hay valor. Muestra "Cargando..." durante fetch.

### 9.3 Fetch

```
GET /api/reportes-generales/comparativo
  ?anio={anio}
  &semana={semana}
  &dia_semana_es={dia}
  &hora={hora}
  &{nivel}={valor}
```

### 9.4 Resultados (solo visibles con datos)

**Deltas (grid 2x2):**

| Card | Calculo | Formato |
|------|---------|---------|
| Cobranza | `((cobrActual - cobrAnterior) / cobrAnterior) * 100` | `+X.X%` o `-X.X%`, color success/danger |
| Rendimiento | `rendActual - rendAnterior` | `+X.Xpp` o `-X.Xpp`, color success/danger |

Ambas muestran "vs S{semanaAnterior}" debajo.

**Totales (grid 2x2):**
- Semana actual: label "S{n} actual" en `accent`, cobranza en moneda, registros + rendimiento
- Semana anterior: label "S{n} anterior" en `muted`, mismos datos

**Grafico comparativo:**
- Tipo: barras verticales agrupadas (2 series)
- Serie 1 (anterior): color `border` (#D9E1E7)
- Serie 2 (actual): color `accent`
- Eje X: categorias (nombres de grupos), rotar labels 45° si >8 items
- Eje Y: formato compacto
- Leyenda: arriba, con nombres "S{n}"
- Esquinas barras: redondeadas arriba (4px)
- Ancho maximo barra: 24px

**Mini-tabs de agrupacion:** Encima del grafico, 3 botones: GER / AGE / SUC. Permiten cambiar como se agrupan visualmente los datos del comparativo (sin nuevo fetch). Activo: fondo `accent` texto blanco.

**Lista detalle de semana actual:** Card con header "Detalle S{n} por {nivel}". Lista scrolleable (max 288px) con nombre, clientes, registros, cobranza y rendimiento (semaforo).

---

## 10. Vista: Avance (`/avance`)

### 10.1 Header

- Titulo: "Avance" (24px bold `primary`)
- Subtitulo: "Progreso de cobranza hora por hora" (14px `muted`)

### 10.2 Filtros (dentro de una card)

**Fila 1 (grid 3 columnas):**
- Semana (1 col): select S1 a S53
- Dia (2 cols): select con los 7 dias

**Selector de nivel:** "Ver avance de" + 3 botones toggle.

**Input de valor:** Igual que en Comparativo (dropdown para sucursal, texto libre para gerencia/agencia).

**Boton "Ver avance":** Deshabilitado si no hay valor.

### 10.3 Fetch

> IMPORTANTE: No enviar filtro `hora`. Se necesitan TODAS las horas del dia.
> IMPORTANTE: Usar paginacion automatica (seccion 6.6) porque algunas entidades tienen >1000 registros por dia.

```
Paginado automatico con filtros:
  anio={anio}
  semana={semana}
  dia_semana_es={dia}
  sort=hora
  order=asc
  {nivel}={valor}
```

### 10.4 Procesamiento client-side

1. Agrupar los registros por `hora` (ver seccion 6.4). Resultado: array de snapshots horarios ordenados por hora asc.
2. Filtrar horas incompletas (ver seccion 6.5). Excluir horas con <80% de agencias vs el maximo.
3. Si se excluyeron horas, mostrar banner de advertencia: "{N} hora(s) excluida(s) por datos incompletos ({maxAgencias} agencias esperadas)"
4. Mostrar cantidad de agencias en el header de la tabla de detalle.

**Metricas derivadas (sobre datos filtrados):**
- `inicio` = primer snapshot (hora mas temprana con datos completos)
- `cierre` = ultimo snapshot (hora mas tardia con datos completos)
- `avanceCobranza` = cierre.cobranza_total - inicio.cobranza_total
- `avanceRendimiento` = cierre.rendimiento_avg - inicio.rendimiento_avg

### 10.5 KPIs (grid 2x2, solo con datos)

| Posicion | Label | Valor principal | Sub-valor |
|----------|-------|-----------------|-----------|
| Top-left | COBRADO AL CIERRE | Cobranza del ultimo snapshot (moneda) | "+{avanceCobranza} en el dia" (success) |
| Top-right | RENDIMIENTO CIERRE | Rendimiento del ultimo snapshot (semaforo) | "+X.Xpp en el dia" (success/danger) |
| Bottom-left | DEBITO | Debito del ultimo snapshot (moneda) | — |
| Bottom-right | FALTANTE CIERRE | Faltante del ultimo snapshot (danger) | — |

### 10.6 Grafico 1: Cobranza y rendimiento por hora

- Tipo: lineas, doble eje Y
- Eje X: horas en formato "HH:00"
- Eje Y izquierdo: Cobranza (formato compacto)
- Eje Y derecho: Rendimiento (0-120%)
- Serie 1 "Cobranza": linea suave con area debajo (gradiente dorado, de 20% opacidad arriba a 2% abajo), circulos en puntos, ancho 2.5px, color `accent`
- Serie 2 "Rendimiento": linea suave sin area, circulos en puntos, ancho 2px, color `success`
- Leyenda: arriba
- Tooltip: mostrar ambos valores (moneda + porcentaje)
- Altura: clamp(280px, 38vh, 420px)

### 10.7 Grafico 2: Faltante por hora

- Tipo: barras verticales
- Eje X: horas en formato "HH:00"
- Eje Y: invertido (valores crecen hacia abajo) — transmite que faltante es algo negativo
- Color: gradiente vertical de `danger` (arriba) a `danger` 30% opacidad (abajo)
- Esquinas: redondeadas arriba (4px)
- Ancho maximo barra: 20px
- Tooltip: formato moneda
- Altura: clamp(220px, 28vh, 340px)

### 10.8 Tabla hora por hora

Card con header "Detalle por hora". Tabla con scroll horizontal si necesario.

**Columnas:**

| Columna | Alineacion | Formato |
|---------|------------|---------|
| Hora | Izquierda, bold | "HH:00" |
| Cobranza | Derecha | Moneda + delta compacto vs hora anterior |
| Rend. | Derecha | Porcentaje con semaforo |
| Faltante | Derecha | Moneda en `danger` |

**Delta de cobranza:** Para cada hora (excepto la primera), si la cobranza aumento vs la hora anterior, mostrar un badge con "+{delta}" en formato compacto, color `success`, tamano muy pequeno (10px). Solo mostrar si delta > 0.

---

## 11. Helpers reutilizados en todas las vistas

### 11.1 Lista de dias

```
['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo']
```

SIN tildes. El indice de JavaScript `Date.getDay()` retorna 0=Domingo, 1=Lunes, ..., 6=Sabado.

### 11.2 Numero de semana

Dado un Date, calcular: `ceil((milisDesde1Enero / 86400000 + diaSemana1Enero + 1) / 7)`.

### 11.3 Inicializacion de filtros

> CRITICO: Usar siempre timezone `America/Mexico_City` para obtener la fecha/hora actual. No usar la hora local del navegador.

Todas las vistas inician con la fecha/hora de **Mexico City**:
- `anio`: anio actual (Mexico City)
- `semana`: semana actual del anio (Mexico City)
- `dia`: nombre del dia actual sin tilde (Mexico City)
- `hora`: hora actual (solo Dashboard y Comparativo, Mexico City)

---

## 12. Requerimientos tecnicos

### 12.1 Graficos

- Renderizado client-side (canvas)
- SSR-safe: la libreria de graficos debe importarse solo en el cliente (no en server)
- Tree-shaking: importar solo los tipos de grafico necesarios (linea, barra) y componentes (grid, tooltip, leyenda)
- ResizeObserver para responsividad + fallback en cambio de orientacion
- Cleanup: liberar recursos al destruir componente

### 12.2 Performance

- Nunca hacer fetch sin filtros temporales
- Dashboard: max 500 registros por fetch
- Avance: paginacion automatica (algunas entidades tienen >1000 registros por dia; ej: sucursal efectivo ~1953). Fetch pagina 1, luego paginas restantes en paralelo
- Comparativo: usa endpoint optimizado (~5ms)
- Graficos: max 15 items en barras horizontales (top 15)
- Horas incompletas: filtrar horas con <80% de agencias para evitar caidas falsas en graficos

### 12.3 Responsive

- Minimo: 360px de ancho
- Tab bar: safe-area para dispositivos con notch
- Contenido principal: padding bottom suficiente para no quedar detras del tab bar (~112px)
- Graficos: altura con clamp() para adaptarse a viewport

### 12.4 Accesibilidad

- `aria-current="page"` en tab activo
- Labels en inputs de filtro
- Roles semanticos en navegacion
- Contraste suficiente entre texto y fondo

---

## 13. Decisiones de arquitectura

| Decision | Razon |
|----------|-------|
| Sin estado global | Cada vista es independiente, hace su propio fetch. Simplifica y evita sincronizacion |
| Agregacion client-side | Los datos ya vienen filtrados del servidor, la agrupacion local es rapida y flexible |
| Drill-down sin cambio de ruta | La navegacion jerarquica ocurre dentro de la misma vista, solo cambian los filtros del fetch |
| Snapshot puntual en Dashboard | Siempre filtrar 4 ejes temporales (anio+semana+dia+hora) garantiza un snapshot unico por agencia |
| Avance sin filtro hora | Omitir `hora` en el fetch trae todos los snapshots del dia para graficar la progresion |
| Graficos con height clamp() | Balancea entre pantallas pequenas y grandes sin romper layout |
| Formateo es-MX | El negocio opera en Mexico, moneda MXN |
| Timezone Mexico City | Todas las vistas inicializan filtros con hora de Mexico (America/Mexico_City), no hora local del navegador |
| Paginacion automatica | Avance usa fetch paginado porque sucursales grandes exceden 1000 registros/dia |
| Filtro horas incompletas | La ultima hora reportada suele tener datos parciales, causando caidas falsas. Se excluyen horas con <80% agencias |
