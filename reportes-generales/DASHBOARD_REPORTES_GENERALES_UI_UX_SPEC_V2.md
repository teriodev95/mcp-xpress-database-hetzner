# Reportes Generales Xpress — Blueprint de Implementacion

Spec determinista para implementar un dashboard movil-first de snapshots de cobranza. Stack: **SvelteKit + Svelte 5 (runes) + Tailwind v4 + ECharts**. Sin decisiones ambiguas; todo esta definido para ejecucion directa.

**Fuentes base:** `master.md` (codigo existente), `spec.md` (requisitos funcionales).

**Regla para la IA:** Seguir este documento seccion por seccion. No inventar features. No cambiar nombres de archivos ni de variables. Reutilizar el codigo existente en `master.md` (types.ts, client.ts, format.ts, time.ts, EChart.svelte). Extender, no reescribir.

---

## 0. Stack y setup

El proyecto ya esta creado con el setup de `master.md` seccion 1. Archivos base que ya existen y NO se deben modificar (salvo extensiones indicadas):

```
src/app.html          ← ya existe
src/app.css           ← ya existe (Tailwind v4 + @theme tokens)
src/lib/charts/EChart.svelte  ← ya existe
src/lib/api/types.ts          ← ya existe, EXTENDER con nuevos tipos
src/lib/api/client.ts         ← ya existe, EXTENDER con nuevas funciones
src/lib/utils/format.ts       ← ya existe, NO tocar
src/lib/utils/time.ts         ← ya existe, NO tocar
```

---

## 1. Estructura de archivos FINAL

Crear exactamente esta estructura. Los archivos marcados `[NUEVO]` no existen aun.

```
src/
  app.html
  app.css
  lib/
    api/
      types.ts                    ← EXTENDER
      client.ts                   ← EXTENDER
      cache.ts                    ← [NUEVO]
    utils/
      format.ts
      time.ts
      url.ts                      ← [NUEVO]
      export.ts                   ← [NUEVO]
    stores/
      filters.ts                  ← [NUEVO]
      entities.ts                 ← [NUEVO]
      recent.ts                   ← [NUEVO]
    components/
      EntityPicker.svelte         ← [NUEVO]
      EntityPickerSheet.svelte    ← [NUEVO]
      FilterBar.svelte            ← [NUEVO]
      FilterChips.svelte          ← [NUEVO]
      BreadcrumbTrail.svelte      ← [NUEVO]
      KpiStrip.svelte             ← [NUEVO]
      SkeletonKpi.svelte          ← [NUEVO]
      SkeletonChart.svelte        ← [NUEVO]
      SkeletonList.svelte         ← [NUEVO]
      ErrorCard.svelte            ← [NUEVO]
      ExportSheet.svelte          ← [NUEVO]
      AgenciaDetailSheet.svelte   ← [NUEVO]
    charts/
      EChart.svelte
      CobranzaBarChart.svelte     ← [NUEVO]
      RendimientoBarChart.svelte  ← [NUEVO]
      AvanceDualChart.svelte      ← [NUEVO]
      FaltanteBarChart.svelte     ← [NUEVO]
      ComparativoChart.svelte     ← [NUEVO]
      TendenciasOverlay.svelte    ← [NUEVO]
  routes/
    +layout.svelte                ← MODIFICAR (agregar persistencia de filtros)
    +page.svelte                  ← REESCRIBIR (Dashboard completo)
    comparativo/
      +page.svelte                ← REESCRIBIR (Comparativo + multi-entidad)
    avance/
      +page.svelte                ← REESCRIBIR (Avance con EntityPicker)
    tendencias/
      +page.svelte                ← REESCRIBIR (Tendencias con EntityPicker)
```

---

## 2. Fases de implementacion (orden obligatorio)

```
FASE 1: Tipos + stores + utilidades (sin UI)
FASE 2: Componentes base (sin logica de negocio)
FASE 3: Dashboard (vista principal)
FASE 4: Comparativo (ambos modos)
FASE 5: Avance
FASE 6: Tendencias
FASE 7: Export
```

Cada fase depende de la anterior. No saltar fases.

---

## 3. FASE 1 — Tipos, stores y utilidades

### 3.1 Extender `src/lib/api/types.ts`

Agregar DEBAJO del codigo existente (no borrar nada):

```ts
// === NUEVOS TIPOS ===

export type NivelOrg = 'sucursal' | 'gerencia' | 'agencia';

export interface EntitySelection {
  level: NivelOrg;
  code: string;
}

export interface RecentEntity {
  code: string;
  level: NivelOrg;
  timestamp: number;
}

export interface EntityCatalog {
  sucursales: Map<string, Set<string>>;   // sucursal → set de gerencias
  gerencias: Map<string, Set<string>>;    // gerencia → set de agencias
  agenciaDetails: Map<string, { gerencia: string | null; sucursal: string | null }>;
}

export interface SharedFilterState {
  anio: number;
  semana: number;
  dia: string;
  hora: number;
  entity: EntitySelection | null;
}

export interface DashboardFilterState extends SharedFilterState {
  groupBy: NivelOrg;
}

export interface BreadcrumbSegment {
  label: string;
  level: NivelOrg | 'root';
  filter: EntitySelection | null;
}

export interface HourAggregate {
  hora: number;
  cobranza_total: number;
  debito: number;
  faltante: number;
  clientes: number;
  rendimiento_avg: number;
  agencias_count: number;
}
```

### 3.2 Extender `src/lib/api/client.ts`

Agregar DEBAJO del codigo existente:

```ts
import type { EntityCatalog, HourAggregate } from './types';

/** Extrae catalogo de entidades desde los rows ya cargados */
export function extractEntityCatalog(rows: ReportRow[]): EntityCatalog {
  const sucursales = new Map<string, Set<string>>();
  const gerencias = new Map<string, Set<string>>();
  const agenciaDetails = new Map<string, { gerencia: string | null; sucursal: string | null }>();

  for (const r of rows) {
    const suc = r.sucursal ?? 'Sin asignar';
    const ger = r.gerencia ?? 'Sin asignar';

    if (!sucursales.has(suc)) sucursales.set(suc, new Set());
    sucursales.get(suc)!.add(ger);

    if (!gerencias.has(ger)) gerencias.set(ger, new Set());
    gerencias.get(ger)!.add(r.agencia);

    agenciaDetails.set(r.agencia, { gerencia: r.gerencia, sucursal: r.sucursal });
  }

  return { sucursales, gerencias, agenciaDetails };
}

/** Agrupa rows por hora para vista Avance. Filtra horas incompletas (< 80% del max). */
export function agruparPorHora(rows: ReportRow[]): { data: HourAggregate[]; excludedCount: number; maxAgencias: number } {
  const map = new Map<number, { cobr: number; deb: number; falt: number; cli: number; rend: number[]; agencias: Set<string> }>();

  for (const r of rows) {
    let g = map.get(r.hora);
    if (!g) {
      g = { cobr: 0, deb: 0, falt: 0, cli: 0, rend: [], agencias: new Set() };
      map.set(r.hora, g);
    }
    g.cobr += r.cobranza_total;
    g.deb += r.debito;
    g.falt += r.faltante;
    g.cli += r.clientes;
    g.rend.push(r.rendimiento);
    g.agencias.add(r.agencia);
  }

  const maxAgencias = Math.max(...[...map.values()].map(g => g.agencias.size));
  const threshold = maxAgencias * 0.8;
  let excludedCount = 0;

  const data: HourAggregate[] = [];
  for (const [hora, g] of [...map.entries()].sort((a, b) => a[0] - b[0])) {
    if (g.agencias.size < threshold) { excludedCount++; continue; }
    data.push({
      hora,
      cobranza_total: g.cobr,
      debito: g.deb,
      faltante: g.falt,
      clientes: g.cli,
      rendimiento_avg: g.rend.length ? g.rend.reduce((a, b) => a + b, 0) / g.rend.length : 0,
      agencias_count: g.agencias.size
    });
  }

  return { data, excludedCount, maxAgencias };
}

/** Fetch con AbortController support */
export async function getReportesAbortable(
  filters: ReportFilters,
  signal?: AbortSignal
): Promise<ApiResponse<ReportRow[]>> {
  const qs = toParams(filters as Record<string, unknown>);
  const url = `${BASE}/reportes-generales/${qs ? `?${qs}` : ''}`;
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

/** Fetch semana actual desde calendario */
export async function getSemanaActual(): Promise<{ semana: number; anio: number }> {
  const res = await fetch(`${BASE}/calendario/semana-actual`);
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  const json = await res.json();
  return { semana: json.data.semana, anio: json.data.anio };
}
```

### 3.3 Crear `src/lib/api/cache.ts`

```ts
const cache = new Map<string, { data: unknown; timestamp: number }>();
const TTL = 5 * 60 * 1000; // 5 minutos
const MAX_ENTRIES = 50;

export function getCached<T>(key: string): T | null {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > TTL) { cache.delete(key); return null; }
  return entry.data as T;
}

export function setCache(key: string, data: unknown): void {
  cache.set(key, { data, timestamp: Date.now() });
  if (cache.size > MAX_ENTRIES) {
    const oldest = [...cache.entries()].sort((a, b) => a[1].timestamp - b[1].timestamp)[0];
    if (oldest) cache.delete(oldest[0]);
  }
}

export function cacheKey(endpoint: string, filters: Record<string, unknown>): string {
  const sorted = Object.keys(filters).sort().reduce((acc, k) => {
    if (filters[k] !== undefined && filters[k] !== null) acc[k] = filters[k];
    return acc;
  }, {} as Record<string, unknown>);
  return `${endpoint}:${JSON.stringify(sorted)}`;
}
```

### 3.4 Crear `src/lib/stores/filters.ts`

```ts
import { writable } from 'svelte/store';
import type { SharedFilterState } from '$lib/api/types';

export const sharedFilters = writable<SharedFilterState>({
  anio: 0,
  semana: 0,
  dia: '',
  hora: 0,
  entity: null
});
```

### 3.5 Crear `src/lib/stores/entities.ts`

```ts
import { writable } from 'svelte/store';
import type { EntityCatalog } from '$lib/api/types';

export const entityCatalog = writable<EntityCatalog>({
  sucursales: new Map(),
  gerencias: new Map(),
  agenciaDetails: new Map()
});
```

### 3.6 Crear `src/lib/stores/recent.ts`

```ts
import { writable } from 'svelte/store';
import type { RecentEntity } from '$lib/api/types';

const STORAGE_KEY = 'xpress_entity_recent';
const MAX_RECENT = 5;

function loadRecent(): RecentEntity[] {
  if (typeof localStorage === 'undefined') return [];
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
  } catch { return []; }
}

function saveRecent(list: RecentEntity[]): void {
  if (typeof localStorage === 'undefined') return;
  localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
}

export const recentEntities = writable<RecentEntity[]>(loadRecent());

export function addRecent(code: string, level: RecentEntity['level']): void {
  recentEntities.update(list => {
    const filtered = list.filter(e => e.code !== code);
    const updated = [{ code, level, timestamp: Date.now() }, ...filtered].slice(0, MAX_RECENT);
    saveRecent(updated);
    return updated;
  });
}
```

### 3.7 Crear `src/lib/utils/url.ts`

```ts
import type { SharedFilterState, NivelOrg, EntitySelection } from '$lib/api/types';

export function filtersToUrl(state: SharedFilterState, groupBy?: NivelOrg): URLSearchParams {
  const p = new URLSearchParams();
  if (state.semana) p.set('s', String(state.semana));
  if (state.anio) p.set('a', String(state.anio));
  if (state.dia) p.set('d', state.dia);
  if (state.hora !== undefined) p.set('h', String(state.hora));
  if (state.entity) p.set('e', `${state.entity.level}:${state.entity.code}`);
  if (groupBy) p.set('g', groupBy);
  return p;
}

export function urlToFilters(params: URLSearchParams): Partial<SharedFilterState> & { groupBy?: NivelOrg } {
  const result: Partial<SharedFilterState> & { groupBy?: NivelOrg } = {};
  const s = params.get('s'); if (s) result.semana = Number(s);
  const a = params.get('a'); if (a) result.anio = Number(a);
  const d = params.get('d'); if (d) result.dia = d;
  const h = params.get('h'); if (h) result.hora = Number(h);
  const e = params.get('e');
  if (e && e.includes(':')) {
    const [level, code] = e.split(':');
    if (['sucursal','gerencia','agencia'].includes(level)) {
      result.entity = { level: level as NivelOrg, code };
    }
  }
  const g = params.get('g');
  if (g && ['sucursal','gerencia','agencia'].includes(g)) result.groupBy = g as NivelOrg;
  return result;
}

export function syncUrlParams(state: SharedFilterState, groupBy?: NivelOrg): void {
  const params = filtersToUrl(state, groupBy);
  const url = `${window.location.pathname}?${params.toString()}`;
  window.history.replaceState({}, '', url);
}
```

### 3.8 Crear `src/lib/utils/export.ts`

```ts
export function exportCSV(rows: Record<string, unknown>[], filename: string): void {
  if (!rows.length) return;
  const BOM = '\uFEFF';
  const headers = Object.keys(rows[0]);
  const csv = BOM + headers.join(',') + '\n' +
    rows.map(r => headers.map(h => `"${String(r[h] ?? '')}"`).join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function triggerPrint(): void {
  window.print();
}
```

---

## 4. Modelo de datos critico — Snapshots

Cada registro es un **snapshot puntual** del avance de cobranza.

**Clave unica:** `anio + semana + dia_semana_es + hora + agencia`.

**Reglas de agregacion (violar = bugs):**

| Operacion | Permitido | Razon |
| --- | --- | --- |
| Sumar agencias del MISMO snapshot (misma semana+dia+hora) | SI | Cada agencia es independiente |
| Sumar snapshots de diferentes horas/dias para la MISMA agencia | NO | hora=10 ya incluye lo anterior; duplicaria datos |
| Comparar mismo campo entre horas o dias | SI | Muestra progresion |
| Agregar rendimiento | PROMEDIO | Es un porcentaje, no sumar |

**Jerarquia organizacional real:**
```
Sucursal (7) > Gerencia (~48) > Agencia (~384)
```

Sucursales actuales (lista dinamica, derivar de datos): `capital`, `dec`, `dinero`, `efectivo`, `gocash`, `moneda`, `plata`.

---

## 5. API — Contratos exactos

**Base URL:** `https://elysia.xpress1.cc/api`

**Regla critica:** Sin filtros = timeout (126K+ registros). SIEMPRE filtrar por al menos `dia_semana_es` + `hora`, o `gerencia`, o `sucursal`.

### 5.1 GET `/api/reportes-generales/`

Params: `anio`, `semana`, `hora`, `dia_semana_es`, `gerencia`, `agencia`, `sucursal`, `page`, `per_page` (max 1000), `sort`, `order`.

Respuesta: `{ success, code, message, request_id, duration_ms, meta: { timezone, as_of, pagination }, data: ReportRow[] }`

### 5.2 GET `/api/reportes-generales/comparativo`

Params requeridos: `anio`, `semana`, `dia_semana_es`, `hora` + exactamente 1 de: `gerencia` | `agencia` | `sucursal`.

Respuesta: `{ ..., data: { semana_actual: { semana, total, registros: ReportRow[] }, semana_anterior: { ... } } }`

Velocidad: ~5ms (optimizado internamente).

### 5.3 POST `/api/reportes-generales/search`

Body:
```json
{
  "limit": 500,
  "sortBy": "cobranza_total",
  "order": "desc",
  "filter": {
    "type": "group",
    "logic": "AND",
    "children": [
      { "type": "rule", "field": "gerencia", "operator": "in", "value": ["GERM006","GERM009"] },
      { "type": "rule", "field": "dia_semana_es", "operator": "=", "value": "Viernes" },
      { "type": "rule", "field": "hora", "operator": "=", "value": 10 }
    ]
  }
}
```

Operadores: `=`, `!=`, `>`, `>=`, `<`, `<=`, `between`, `in`, `notIn`, `includes`, `startsWith`, `endsWith`, `isNull`, `isNotNull`.

### 5.4 GET `/api/calendario/semana-actual`

Sin params. Retorna `{ data: { semana, anio } }`.

Usar como fuente de verdad para inicializar filtros en todas las vistas.

---

## 6. Tokens de diseno (referencia para Tailwind)

Ya definidos en `src/app.css` bajo `@theme`. Usar como clases Tailwind:

| Token | Clase Tailwind | Hex |
| --- | --- | --- |
| primary | `text-primary`, `bg-primary` | `#0E2A3B` |
| accent | `text-accent`, `bg-accent` | `#D4A23A` |
| surface | `bg-surface` | `#F7F9FB` |
| card | `bg-card` | `#FFFFFF` |
| border | `border-border` | `#D9E1E7` |
| success | `text-success`, `bg-success` | `#1F8F5F` |
| danger | `text-danger`, `bg-danger` | `#C0392B` |
| warning | `text-warning` | `#D4A23A` |
| muted | `text-muted` | `#6B7D8A` |

**Semaforo de rendimiento** — usar en TODA la app:
```ts
function semaforoColor(pct: number): string {
  if (pct >= 80) return 'text-success';
  if (pct >= 50) return 'text-warning';
  return 'text-danger';
}
```

---

## 7. FASE 2 — Componentes base

### 7.1 `SkeletonKpi.svelte`

2x2 grid de cards pulsantes. Cada card: rectangulo label (h-3 w-16) + rectangulo valor (h-6 w-24). Clase: `bg-border/40 animate-pulse rounded-lg`.

### 7.2 `SkeletonChart.svelte`

Card con titulo (h-4 w-32) + 5 barras horizontales de ancho variable pulsantes. Misma clase pulse.

### 7.3 `SkeletonList.svelte`

4 filas de 3 rectangulos pulsantes simulando columnas de tabla.

### 7.4 `ErrorCard.svelte`

Props: `{ message: string; suggestion?: string; requestId?: string; onRetry: () => void }`.

Card con `border-danger/20 bg-danger/5`. Icono warning + message + suggestion (si existe) + boton "Reintentar" + request_id en 10px muted.

### 7.5 `KpiStrip.svelte`

Props: `{ cobranza: number; debito: number; rendimiento: number; faltante: number; agenciasCount: number }`.

Grid 2x2 de KPI cards. Rendimiento usa semaforo. Faltante siempre `text-danger`. Tooltip de cada card: `Calculado sobre {agenciasCount} agencias del snapshot seleccionado.`

Formato: cobranza y debito con `compact()`, rendimiento con `pct()`, faltante con `compact()`.

### 7.6 `FilterBar.svelte`

Props: `{ semana: number; dia: string; hora: number; showHora?: boolean; semanaEditable?: boolean; onSemanaChange, onDiaChange, onHoraChange }`.

Fila horizontal con 3 selects inline (o 2 si `showHora=false`):
- Semana: opciones S1..S53, display `S{n}`
- Dia: opciones `DIAS_SEMANA` de time.ts
- Hora: opciones 0..23, display `{n}:00`

Si `semanaEditable=false`: mostrar como label bold no editable (para Tendencias).

Cada `on:change` llama el callback correspondiente.

### 7.7 `FilterChips.svelte`

Props: `{ semana: number; dia: string; hora?: number; entity?: EntitySelection; onReset: () => void }`.

Fila horizontal: `S{semana} · {dia} · {hora}:00 · {entity.code}` + boton "Restablecer" en `text-accent text-xs font-medium`.

Ocultar si no hay entity y los temporales estan en default.

### 7.8 `BreadcrumbTrail.svelte`

Props: `{ segments: BreadcrumbSegment[]; onNavigate: (segment: BreadcrumbSegment) => void }`.

Fila horizontal con segmentos separados por `>` en `text-muted`. Ultimo segmento: `font-bold text-primary`. Anteriores: `text-accent cursor-pointer`. Tap en segmento llama `onNavigate`.

### 7.9 `EntityPicker.svelte`

**El componente mas complejo. Implementar exactamente asi:**

Props: `{ value: EntitySelection | null; required?: boolean; requiredMessage?: string; onChange: (entity: EntitySelection | null) => void }`.

**Trigger (siempre visible):**
- Sin seleccion: input con placeholder "Seleccionar entidad" en muted, icono chevron-down
- Con seleccion: chip con codigo + icono `x` para limpiar. Color del chip segun nivel:
  - sucursal: `bg-accent/10`
  - gerencia: `bg-primary/10`
  - agencia: `bg-success/10`
- Si `required && !value`: mostrar `requiredMessage` en `text-danger text-xs` debajo

**Tap en trigger:** abre `EntityPickerSheet`

### 7.10 `EntityPickerSheet.svelte`

Bottom sheet (overlay oscuro 40%, card blanca desde abajo, radio top 20px, drag handle, max-height 85vh).

**Estructura interna (de arriba a abajo):**

1. **Header:** "Seleccionar entidad" + boton `x` para cerrar
2. **SearchBar:** Input con placeholder "Buscar por codigo...", icono lupa. Debounce 250ms. Min 2 chars para buscar.
3. **LevelTabs:** 3 tabs `Sucursal | Gerencia | Agencia`. Default: `Gerencia`. Activo: `bg-primary text-white rounded-lg`. Inactivo: `bg-surface text-muted`.
4. **Breadcrumb interno (cascada):** Solo visible si se ha hecho drill-down. Ej: `moneda > GERM006 > Agencias`. Tap en segmento regresa a ese nivel.
5. **Seccion RECIENTES:** Solo si no hay busqueda activa. Header "RECIENTES" en 11px uppercase muted. Max 5 items de `recentEntities` store.
6. **EntityList:** Lista principal. Lazy loading: render inicial 20, cargar 20 mas con IntersectionObserver.

**Cada fila (EntityRow):**
```
[●] CODIGO                          [>]
    Contexto secundario
```

- Circulo de color por nivel (sucursal=accent, gerencia=primary, agencia=success)
- Codigo en bold primary
- Linea secundaria en 12px muted:
  - Sucursal: `{N} gerencias · {N} agencias`
  - Gerencia: `Sucursal: {suc} · {N} agencias`
  - Agencia: `Gerencia: {ger} · {suc}`
- Chevron `>` solo en sucursal y gerencia (drillable)

**Interacciones:**
- Tap en fila (no chevron): SELECCIONA la entidad, llama `onChange`, cierra sheet, guarda en recientes
- Tap en chevron: DRILL-DOWN → cambia al tab hijo filtrado (sucursal→gerencia, gerencia→agencia), actualiza breadcrumb interno

**Busqueda activa:**
- Ocultar LevelTabs
- Buscar en los 3 niveles simultaneamente
- Agrupar resultados con headers de seccion: "SUCURSALES (N)", "GERENCIAS (N)", "AGENCIAS (N)"
- Resaltar texto coincidente en `text-accent font-bold`
- Sin resultados: "Sin resultados para '{query}'."

**Datos:** Lee de `entityCatalog` store. La busqueda filtra client-side sobre el catalogo.

### 7.11 `AgenciaDetailSheet.svelte`

Props: `{ agencia: ReportRow; semana: number; dia: string; hora: number; onComparar: () => void; onAvance: () => void; onClose: () => void }`.

Bottom sheet con:
- Titulo: `Agencia {agencia.agencia}`
- Subtitulo: `Snapshot S{semana} · {dia} {hora}:00 (CDMX)`
- Contexto: `Gerencia: {agencia.gerencia} · Sucursal: {agencia.sucursal}`
- Mini KPIs (3x2): Cobranza, Debito, Rendimiento, Faltante, Clientes, Ventas
- 2 CTAs: "Comparar semana" (accent, llama onComparar) + "Ver avance" (secondary, llama onAvance)

### 7.12 `ExportSheet.svelte`

Props: `{ onCopyLink: () => void; onCSV: () => void; onPDF: () => void; onClose: () => void }`.

Bottom sheet simple con 3 opciones + "Cancelar".

---

## 8. FASE 3 — Vista Dashboard `/`

### 8.1 Estado local del componente

```ts
let anio = $state(0);
let semana = $state(0);
let dia = $state('');
let hora = $state(0);
let entity: EntitySelection | null = $state(null);
let groupBy: NivelOrg = $state('sucursal');
let rows: ReportRow[] = $state([]);
let loading = $state(true);
let error: string | null = $state(null);
let requestId: string = $state('');
let abortController: AbortController | null = $state(null);
let breadcrumbs: BreadcrumbSegment[] = $state([{ label: 'Inicio', level: 'root', filter: null }]);
let showAgenciaSheet = $state(false);
let selectedAgencia: ReportRow | null = $state(null);
let showExportSheet = $state(false);
```

### 8.2 Inicializacion (onMount)

1. Leer URL params con `urlToFilters()`
2. Si hay params: usar esos valores
3. Si no: llamar `getSemanaActual()` + `getMexicoNow()` para dia y hora
4. Escribir a `sharedFilters` store
5. Llamar `fetchData()`

### 8.3 fetchData()

```
1. abortController?.abort()
2. abortController = new AbortController()
3. loading = true; error = null
4. Construir ReportFilters: { anio, semana, dia_semana_es: dia, hora, per_page: 500, sort: 'cobranza_total', order: 'desc' }
5. Si entity: agregar entity.level = entity.code al filtro
6. Revisar cache (cacheKey + getCached)
7. Si cache hit: usar datos cacheados
8. Si cache miss: llamar getReportesAbortable(filters, signal)
9. rows = response.data
10. Actualizar entityCatalog store con extractEntityCatalog(rows)
11. setCache(key, rows)
12. loading = false
13. Actualizar URL con syncUrlParams()
14. Escribir a sharedFilters store
```

En catch: si AbortError, ignorar. Si otro error: `error = message; requestId = response.request_id`.

### 8.4 Layout (de arriba a abajo)

```svelte
<header>
  <div class="flex justify-between items-center">
    <div>
      <h1 class="text-lg font-bold text-primary">Dashboard</h1>
      <p class="text-xs text-muted">Snapshot S{semana} · {dia} {hora}:00 (CDMX) · {rows.length} agencias</p>
    </div>
    <button on:click={() => showExportSheet = true}><!-- icono share --></button>
  </div>
</header>

<FilterBar {semana} {dia} {hora} onSemanaChange=... onDiaChange=... onHoraChange=... />
<EntityPicker value={entity} onChange={handleEntityChange} />

<!-- Solo en Dashboard -->
<div class="flex gap-2"><!-- Toggle: Sucursal | Gerencia | Agencia --></div>

<FilterChips {semana} {dia} {hora} {entity} onReset={handleReset} />

{#if loading}
  <SkeletonKpi />
  <SkeletonChart />
{:else if error}
  <ErrorCard message={error} {requestId} onRetry={fetchData} />
{:else if rows.length === 0}
  <div class="text-center text-muted py-12">
    <p>Sin datos para este filtro.</p>
    <p class="text-xs mt-1">Prueba otra hora o cambia la entidad.</p>
  </div>
{:else}
  <KpiStrip cobranza={sumCobranza} debito={sumDebito} rendimiento={avgRendimiento} faltante={sumFaltante} agenciasCount={rows.length} />
  <BreadcrumbTrail segments={breadcrumbs} onNavigate={handleBreadcrumb} />
  <CobranzaBarChart data={groupedData} onTap={handleChartTap} />
  <RendimientoBarChart data={groupedData} onTap={handleChartTap} />
{/if}

{#if showAgenciaSheet && selectedAgencia}
  <AgenciaDetailSheet agencia={selectedAgencia} {semana} {dia} {hora} onComparar={...} onAvance={...} onClose={...} />
{/if}
{#if showExportSheet}
  <ExportSheet onCopyLink={...} onCSV={...} onPDF={...} onClose={...} />
{/if}
```

### 8.5 Drill-down

Cuando el usuario toca un item en el ranking:

| groupBy actual | Tap item | Accion |
| --- | --- | --- |
| sucursal | "moneda" | `entity = { level: 'sucursal', code: 'moneda' }`, `groupBy = 'gerencia'`, agregar segmento a breadcrumbs, refetch |
| gerencia | "GERM006" | `entity = { level: 'gerencia', code: 'GERM006' }`, `groupBy = 'agencia'`, agregar segmento, refetch |
| agencia | "AGM052" | Abrir AgenciaDetailSheet con esa row |

Tap en breadcrumb: truncar breadcrumbs al segmento tocado, restaurar entity y groupBy correspondientes, refetch.

### 8.6 Datos agrupados para charts

```ts
$derived groupedData = agruparPor(rows, groupBy).slice(0, 15);
$derived sumCobranza = rows.reduce((s, r) => s + r.cobranza_total, 0);
$derived sumDebito = rows.reduce((s, r) => s + r.debito, 0);
$derived avgRendimiento = rows.length ? rows.reduce((s, r) => s + r.rendimiento, 0) / rows.length : 0;
$derived sumFaltante = rows.reduce((s, r) => s + r.faltante, 0);
```

---

## 9. FASE 4 — Vista Comparativo `/comparativo`

### 9.1 Modos

Toggle en header: `(vs Semana anterior)` | `(Multi-entidad)`. Default: "vs Semana anterior".

### 9.2 Modo "vs Semana anterior"

**Filtros:** FilterBar (semana, dia, hora) + EntityPicker (REQUERIDO).

**Fetch:** `getComparativo({ anio, semana, dia_semana_es: dia, hora, [entity.level]: entity.code })`.

**KPIs (2x2 con deltas):**
- Cobranza: valor actual + `((act - ant) / ant) * 100` %. Si ant==0: mostrar "Sin base" + delta absoluto.
- Rendimiento: valor actual + `act - ant` pp.
- Faltante: valor actual + `((ant - act) / ant) * 100` % (invertido, menos es mejor).
- Clientes: valor actual + `act - ant` absoluto.

**Chart:** Barras agrupadas. Serie anterior: `#D9E1E7`. Serie actual: `accent`. Mini-tabs `SUC/GER/AGE` para reagrupar client-side (sin refetch).

**Lista:** Tabla con nombre + cobranza + rendimiento + clientes + faltante por sub-grupo.

### 9.3 Modo "Multi-entidad"

**Filtros:** FilterBar + selector de nivel (toggle Sucursal/Gerencia/Agencia) + chips de entidades (2-4) + boton "+ Agregar" que abre EntityPicker filtrado al nivel.

**Reglas:** Mismo nivel obligatorio. Min 2, max 4. Cambiar nivel limpia entidades.

**Fetch:** `POST /api/reportes-generales/search` con operador `in` para el campo del nivel seleccionado + filtros temporales. Separar client-side por entidad.

**KPIs:** Grid de N columnas (1 por entidad). Rows: Cobranza, Rendimiento, Faltante, Clientes. Mejor valor resaltado con `text-success`.

**Chart:** Barras agrupadas horizontales. Metricas en eje Y. Cada entidad un color (paleta: `#D4A23A`, `#6AA7FF`, `#B09EFF`, `#1F8F5F`).

**Tabla:** Filas = metricas. Columnas = entidades + "Delta" + "Mejor".

---

## 10. FASE 5 — Vista Avance `/avance`

**Filtros:** FilterBar (semana, dia, SIN hora) + EntityPicker (REQUERIDO).

**Fetch:** `getReportesAll({ anio, semana, dia_semana_es: dia, [entity.level]: entity.code })` — NO enviar `hora`, trae todas.

**Procesamiento client-side:** `agruparPorHora(rows)` → filtra horas incompletas. Si `excludedCount > 0`: mostrar banner "Excluimos {N} hora(s) por datos incompletos".

**KPIs (2x2):**
- Cobrado al cierre: cobranza de ultima hora + badge `+{delta} en el dia` (success)
- Rendimiento cierre: rendimiento ultima hora + badge `+{delta} pp` (semaforo)
- Debito: debito ultima hora
- Faltante cierre: faltante ultima hora (danger)

**Chart A (dual axis):** X = `HH:00`. Y izq = cobranza (linea + area accent). Y der = rendimiento 0-120% (linea success). Tooltip con ambos. `dataZoom inside`.

**Chart B (faltante):** Barras verticales. Eje Y invertido. Gradiente danger.

**Tabla por hora:** Hora | Cobranza | Delta vs hora anterior (badge `+$X` success) | Rendimiento (semaforo) | Faltante (danger).

---

## 11. FASE 6 — Vista Tendencias `/tendencias`

**Filtros:** Semana auto-detectada (no editable) via `getSemanaActual()`. Dia seleccionable. EntityPicker (REQUERIDO).

**Fetch:** 2 requests en paralelo:
1. Semana actual: `getReportesAll({ anio, semana, dia_semana_es: dia, [entity.level]: entity.code })`
2. Semana anterior: `getReportesAll({ anio: anioAnterior, semana: semana-1, dia_semana_es: dia, [entity.level]: entity.code })`

Manejar cruce de anio (semana 1 → semana anterior es semana 52/53 del anio anterior).

**Procesamiento:** `agruparPorHora()` para ambas semanas. Aplicar filtro de horas incompletas a ambas.

**KPIs (2x2 con deltas):** Cobranza delta %, Rendimiento delta pp, Faltante delta % invertido, Clientes delta absoluto.

**Chart A (cobranza overlay):** Actual = linea + area accent. Anterior = linea gris punteada. `markLine` en hora actual CDMX.

**Chart B (rendimiento overlay):** Actual = linea success. Anterior = linea gris punteada. `markLine` "Meta 80%" + "Ahora".

**Tabla:** Hora | Cobr. actual | Cobr. anterior | Delta | Rend. actual | Rend. anterior. Hora actual: fondo `accent/10` + badge "ahora".

**Drivers:** Si entity es sucursal → mostrar desglose por gerencias (usar `agruparPor`). Si gerencia → por agencias. Si agencia → sin desglose.

---

## 12. FASE 7 — Export

### 12.1 Copiar enlace

Usar `navigator.clipboard.writeText(window.location.href)`. Toast: "Enlace copiado" (2s, bottom).

### 12.2 CSV

Llamar `exportCSV(visibleRows, filename)` de `export.ts`. Nombre: `xpress_{vista}_{entity?.code ?? 'all'}_{semana}_{dia}_{hora}.csv`.

### 12.3 PDF

Agregar CSS en `app.css`:
```css
@media print {
  nav, .filter-bar, .export-btn, .bottom-sheet-overlay { display: none !important; }
  .print-header { display: block !important; }
  main { padding-bottom: 0 !important; }
  .card { break-inside: avoid; }
}
```

Agregar `<div class="print-header hidden print:block">` con:
```
Xpress Dinero — {Vista}
Snapshot S{semana} · {dia} {hora}:00 (CDMX)
Entidad: {entity?.code ?? 'Todas'} | Generado: {fecha y hora CDMX}
```

Llamar `triggerPrint()`.

---

## 13. Navegacion y layout

### 13.1 `+layout.svelte`

Tab bar flotante inferior con 4 tabs. Codigo base ya existe en `master.md`. Agregar:
- Leer `sharedFilters` store en cada tab change
- Escribir `sharedFilters` store cuando el usuario modifica filtros en cualquier vista

### 13.2 Persistencia de filtros entre tabs

Al navegar de Dashboard a Comparativo via CTA en AgenciaDetailSheet:
1. Escribir entity + filtros temporales a `sharedFilters`
2. Navegar con `goto('/comparativo')`
3. Comparativo lee `sharedFilters` en onMount y pre-llena

Al navegar via tab bar:
1. Vista actual escribe a `sharedFilters` en cada cambio
2. Nueva vista lee en onMount
3. NO disparar fetch automatico (dejar que usuario confirme)

---

## 14. UX writing — Copy exacto

Usar literalmente estos strings. No inventar copy nuevo.

### 14.1 Subtitulos por vista

| Vista | Subtitulo |
| --- | --- |
| Dashboard | `Snapshot S{semana} · {dia} {hora}:00 (CDMX) · {N} agencias` |
| Comparativo | `S{semana} vs S{semana-1} · {dia} {hora}:00 (CDMX)` |
| Comparativo multi | `{N} {nivel}s · S{semana} · {dia} {hora}:00 (CDMX)` |
| Avance | `Progreso hora por hora · {dia} S{semana} (CDMX)` |
| Tendencias | `S{semana} vs S{semana-1} · corte: {dia} {hora}:00 (CDMX)` |

### 14.2 Estados

| Estado | Copy |
| --- | --- |
| Loading | Mostrar skeletons, NO texto |
| Error red | `Sin conexion. Verifica tu red.` + boton "Reintentar" |
| Error timeout | `La consulta tomo demasiado tiempo.` + `Intenta agregar mas filtros.` + "Reintentar" |
| Error 5xx | `Error del servidor. Intenta de nuevo.` + "Reintentar" + `ID: {request_id}` |
| Sin datos | `Sin datos para este filtro.` + `Prueba otra hora o cambia la entidad.` |
| Horas incompletas | Banner: `Excluimos {N} hora(s) por datos incompletos (esperadas: {maxAgencias} agencias).` |
| Datos parciales | Banner: `Datos parciales: {N} de {total} agencias reportadas.` |

### 14.3 EntityPicker

| Situacion | Copy |
| --- | --- |
| Placeholder | `Seleccionar entidad` |
| Titulo sheet | `Seleccionar entidad` |
| Placeholder busqueda | `Buscar por codigo...` |
| Header recientes | `RECIENTES` |
| Sin resultados | `Sin resultados para "{query}".` |
| Requerido (Comparativo) | `Selecciona una entidad para comparar.` |
| Requerido (Avance) | `Selecciona una entidad para ver avance.` |
| Requerido (Tendencias) | `Selecciona una entidad para ver tendencias.` |

### 14.4 Export

| Accion | Copy |
| --- | --- |
| Titulo sheet | `Exportar / Compartir` |
| Toast copiar | `Enlace copiado` |
| Toast export | `Archivo descargado` |

### 14.5 Tooltips (glosario)

| Termino | Tooltip |
| --- | --- |
| Cobranza | `Total cobrado en el snapshot.` |
| Debito | `Pago esperado de la semana.` |
| Rendimiento | `Promedio de (cobranza_pura / debito) entre agencias.` |
| Faltante | `Debito no cubierto por cobranza pura.` |
| Excedente | `Pagos por encima del debito semanal.` |
| Liquidaciones | `Pagos que saldan el prestamo completo.` |
| Cobranza pura | `Parte del pago que cubre el debito (sin excedente ni liquidaciones).` |

---

## 15. Performance — Patrones obligatorios

### 15.1 AbortController

Cada vista mantiene `let abortController: AbortController | null`. En cada fetch: `abortController?.abort()` → `abortController = new AbortController()` → pasar `signal`. En catch: si `e.name === 'AbortError'` → ignorar.

### 15.2 Cache

Usar `cache.ts`. Key = `cacheKey(endpoint, filters)`. Antes de cada fetch: `getCached(key)`. Despues de cada fetch exitoso: `setCache(key, data)`. TTL: 5 min. Max: 50 entries.

### 15.3 Retry

Solo en errores de red y 5xx. Max 3 intentos. Delays: 1s, 2s, 4s. No reintentar 4xx. No reintentar requests abortados.

### 15.4 Rankings

Max 15 items en charts de barras. Usar `.slice(0, 15)` despues de `agruparPor()`.

### 15.5 Lazy loading (EntityPicker)

Render inicial: 20 items. IntersectionObserver en sentinel al fondo. Batch: 20. Busqueda overrides lazy loading (muestra todos los matches).

---

## 16. Accesibilidad — Requerimientos

- Inputs con `<label>` visible (no solo placeholder)
- Tab activo: `aria-current="page"`
- Bottom sheets: `role="dialog"`, `aria-modal="true"`, focus trap (primer elemento focusable al abrir, restaurar foco al cerrar)
- EntityPicker trigger: `role="combobox"`, `aria-expanded`, lista: `role="listbox"`
- No depender solo del color: incluir texto "(Alto)", "(Medio)", "(Bajo)" junto al semaforo de rendimiento

---

## 17. Charts — Configuracion ECharts

### 17.1 CobranzaBarChart

Barras horizontales. Top 15. Color: `accent`. Tap en barra: emit evento con `nombre` del grupo.

```ts
option = {
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  grid: { left: 100, right: 20, top: 10, bottom: 10 },
  xAxis: { type: 'value', axisLabel: { formatter: (v) => compact(v) } },
  yAxis: { type: 'category', data: nombres, inverse: true, axisLabel: { width: 90 } },
  series: [{ type: 'bar', data: valores, itemStyle: { color: '#D4A23A' } }]
};
```

### 17.2 RendimientoBarChart

Barras horizontales. Top 15. Color por semaforo via `visualMap`. `markLine` en 80%.

```ts
option = {
  visualMap: {
    show: false, min: 0, max: 120,
    inRange: { color: ['#C0392B', '#D4A23A', '#1F8F5F'] },
    dimension: 0
  },
  xAxis: { type: 'value', min: 0, max: 120, axisLabel: { formatter: '{value}%' } },
  yAxis: { type: 'category', data: nombres, inverse: true },
  series: [{
    type: 'bar', data: valores,
    markLine: { data: [{ xAxis: 80, label: { formatter: 'Meta 80%' }, lineStyle: { color: '#6B7D8A', type: 'dashed' } }] }
  }]
};
```

### 17.3 AvanceDualChart

Dual axis. X = horas. Y izq = cobranza (linea + area accent). Y der = rendimiento 0-120% (linea success). `dataZoom` inside.

### 17.4 FaltanteBarChart

Barras verticales. Eje Y invertido. Gradiente de `#C0392B` a `#C0392B33`.

### 17.5 ComparativoChart

Barras agrupadas. Serie anterior: `#D9E1E7`. Serie actual: `#D4A23A`.

### 17.6 TendenciasOverlay

Dual series (actual vs anterior). Actual: linea solida + area. Anterior: linea punteada gris. `markLine` "Ahora" y "Meta 80%".

---

## 18. QA — Criterios de aceptacion (checklist)

### Datos
- [ ] Subtitulo SIEMPRE muestra "Snapshot S{semana} · {dia} {hora}:00 (CDMX)"
- [ ] Sumas entre agencias del MISMO snapshot, NUNCA entre horas
- [ ] Rendimiento se agrega como PROMEDIO, nunca suma
- [ ] Comparativo con anterior==0 muestra "Sin base", no Infinity/NaN

### EntityPicker
- [ ] Cascada: tap sucursal → filtra gerencias correctas
- [ ] Cascada: tap gerencia → filtra agencias correctas
- [ ] Busqueda: min 2 chars, debounce 250ms, resultados agrupados por nivel
- [ ] Recientes: max 5, persisten en localStorage
- [ ] Seleccion aplica inmediatamente al API call
- [ ] Limpiar (x) devuelve Dashboard a vista sin filtro

### Navegacion
- [ ] Tap en ranking SIEMPRE produce accion util (drill o sheet)
- [ ] Breadcrumbs correctos y cada segmento navegable
- [ ] Cambiar tab preserva filtros temporales + entidad
- [ ] CTAs en sheet navegan con filtros pre-llenados

### URL y export
- [ ] URL refleja filtros; recargar restaura estado completo
- [ ] CSV con encoding UTF-8 BOM
- [ ] PDF oculta nav/filtros, muestra header con timestamp

### Performance
- [ ] Cambio rapido de filtros: sin parpadeo (AbortController)
- [ ] Cache evita refetch en back-and-forth (TTL 5min)
- [ ] Skeletons aparecen inmediatamente al iniciar fetch
