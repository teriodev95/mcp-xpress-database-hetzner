# Reportes Generales Xpress

Frontend movil para visualizacion de reportes de cobranza con graficos interactivos.

---

## 1. Setup desde cero

### 1.1 Crear proyecto SvelteKit

```bash
# En la carpeta deseada (SIN subcarpetas)
npx sv create . --template minimal --types ts --no-add-ons --no-install
```

### 1.2 Instalar dependencias

```bash
pnpm install
pnpm add -D @sveltejs/adapter-cloudflare @tailwindcss/vite tailwindcss
pnpm add echarts
```

### 1.3 Configurar `svelte.config.js`

```js
import adapter from '@sveltejs/adapter-cloudflare';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter()
	}
};

export default config;
```

### 1.4 Configurar `vite.config.ts`

```ts
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()]
});
```

### 1.5 Crear `src/app.html`

```html
<!doctype html>
<html lang="es">
	<head>
		<meta charset="utf-8" />
		<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
		<meta name="apple-mobile-web-app-capable" content="yes" />
		<meta name="apple-mobile-web-app-status-bar-style" content="default" />
		<meta name="theme-color" content="#f2f2f7" />
		<link rel="preconnect" href="https://fonts.googleapis.com" />
		<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous" />
		<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
		%sveltekit.head%
	</head>
	<body data-sveltekit-preload-data="hover">
		<div style="display: contents">%sveltekit.body%</div>
	</body>
</html>
```

### 1.6 Crear `src/app.css`

```css
@import 'tailwindcss';

@theme {
	--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif;
	--color-primary: #0E2A3B;
	--color-accent: #D4A23A;
	--color-surface: #F7F9FB;
	--color-card: #ffffff;
	--color-border: #D9E1E7;
	--color-success: #1F8F5F;
	--color-danger: #C0392B;
	--color-warning: #D4A23A;
	--color-muted: #6B7D8A;
}
```

### 1.7 Verificar build

```bash
pnpm build
```

---

## 2. Branding

Estilo minimalista iOS. Mobile-first (360px+). Font: Inter.

| Token | Hex | Uso |
|-------|-----|-----|
| `primary` | `#0E2A3B` | Textos, headings, fondos oscuros |
| `accent` | `#D4A23A` | Botones, barras de chart, indicador tab activo |
| `surface` | `#F7F9FB` | Fondo principal |
| `card` | `#FFFFFF` | Cards, paneles, nav flotante |
| `border` | `#D9E1E7` | Bordes sutiles |
| `success` | `#1F8F5F` | Rendimiento positivo (>=80%) |
| `danger` | `#C0392B` | Errores, deltas negativos, faltante |
| `warning` | `#D4A23A` | Rendimiento medio (>=50% y <80%) |
| `muted` | `#6B7D8A` | Texto secundario |

**Semaforo de rendimiento:** verde `success` >=80%, amarillo `warning` >=50%, rojo `danger` <50%.

---

## 3. API Backend

**Base URL:** `https://elysia.xpress1.cc/api`

> CRITICO: La ruta lleva el prefix `/api/`. Sin el retorna `NOT_FOUND`.

### 3.1 Endpoints

| Metodo | Ruta | Uso |
|--------|------|-----|
| GET | `/api/reportes-generales/` | Consulta con filtros basicos |
| POST | `/api/reportes-generales/search` | Busqueda avanzada con filtros anidados |
| GET | `/api/reportes-generales/comparativo` | Comparativo semana actual vs anterior |

### 3.2 Reglas criticas

- **Sin filtros = timeout.** La tabla tiene ~122,000+ registros. Siempre filtrar por al menos `dia_semana_es` + `hora`, o `gerencia`, o `sucursal`.
- **Paginacion:** max 1000 por request. Campos `page`, `per_page`.
- **Formato de codigos:** gerencias `GERM006`, agencias `AGM052`, sucursales en minuscula `moneda`.
- **Campos nullable:** `gerencia` y `sucursal` pueden ser `null`.
- **Dias SIN tilde:** la API devuelve `Sabado`, `Miercoles` (sin acentos). Usar siempre: `['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo']`.
- **Comparativo** es el endpoint mas rapido (~5ms) porque filtra internamente.

### 3.3 Ejemplos curl

```bash
# GET con filtros (siempre filtrar)
curl 'https://elysia.xpress1.cc/api/reportes-generales/?per_page=2&dia_semana_es=Viernes&hora=10'
curl 'https://elysia.xpress1.cc/api/reportes-generales/?per_page=5&gerencia=GERM006'

# Comparativo semanal (rapido, ~5ms)
curl 'https://elysia.xpress1.cc/api/reportes-generales/comparativo?anio=2026&semana=6&dia_semana_es=Viernes&hora=10&gerencia=GERM006'

# POST search
curl -X POST 'https://elysia.xpress1.cc/api/reportes-generales/search' \
  -H 'Content-Type: application/json' \
  -d '{
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
  }'
```

### 3.4 GET `/api/reportes-generales/`

Query params: `anio`, `semana`, `hora`, `agencia`, `gerencia`, `sucursal`, `dia_semana_es`, `page`, `per_page`, `sort`, `order`

### 3.5 POST `/api/reportes-generales/search`

Body con filtros recursivos (groups + rules), paginacion y orden. Max 1000 registros.

Operadores: `=`, `!=`, `>`, `>=`, `<`, `<=`, `between`, `in`, `notIn`, `includes`, `startsWith`, `endsWith`, `isNull`, `isNotNull`, `true`, `false`

### 3.6 GET `/api/reportes-generales/comparativo`

Params requeridos: `anio`, `semana`, `dia_semana_es`, `hora` + al menos uno de: `gerencia`, `agencia`, `sucursal`

Retorna `{ semana_actual: SemanaData, semana_anterior: SemanaData }`.

### 3.7 Respuesta estandar

```json
{ "success": true, "code": "...", "message": "...", "request_id": "...", "duration_ms": 5, "meta": { "timezone": "America/Mexico_City", "as_of": "...", "pagination": { "page": 1, "per_page": 100, "total": 45, "total_pages": 1, "has_next": false, "has_prev": false } }, "data": [...] }
```

---

## 4. Modelo de datos — Snapshots (NO acumulativos)

> CRITICO: Cada registro es un **snapshot de avance** de cobranza en un momento especifico.

La clave unica es: `anio` + `semana` + `dia_semana_es` + `hora` + `agencia`.

**Reglas:**
- El snapshot de hora=10 para una agencia YA incluye todo lo cobrado hasta las 10:00.
- **Nunca sumar snapshots de diferentes horas/dias para la misma agencia** (duplicaria datos).
- **Si se puede sumar** entre agencias del mismo snapshot (misma semana+dia+hora) para obtener totales por gerencia/sucursal.
- Para ver evolucion, comparar el mismo campo entre distintas horas o dias.

### 4.1 Jerarquia organizacional

```
Gerencia > Agencia > Sucursal
```

- `gerencia` — ~45 codigos. Prefijos: `GERC`, `GERD`, `GERDC`, `GERE`, `GERM`, `GERP`. **Nullable.**
- `agencia` — ~100 codigos. Prefijos: `AGC`, `AGD`, `AGDC`, `AGE`, `AGM`, `AGP`, `MAGA`.
- `sucursal` — 6 valores fijos: `capital`, `dec`, `dinero`, `efectivo`, `moneda`, `plata`. **Nullable.**

### 4.2 Campos completos (vista `vw_cobranza_snapshots_reportes_generales`)

**Sistema:** `id`, `created_at`, `created_at_mx`

**Temporales:** `fecha_mx`, `anio`, `semana`, `hora`, `dia_semana_es`

**Organizacion:** `agencia`, `gerencia` (nullable), `sucursal` (nullable)

**Cobranza:** `clientes`, `no_pagos`, `debito`, `debito_miercoles`, `debito_jueves`, `debito_viernes`, `cobranza_pura`, `excedente`, `liquidaciones`, `cobranza_total`

**Rendimiento:** `rendimiento`, `rendimiento_miercoles`, `rendimiento_jueves`, `rendimiento_viernes` (porcentajes 0-100+)

**Faltantes/Adelantos:** `faltante`, `faltante_miercoles`, `faltante_jueves`, `faltante_viernes`, `adelanto_miercoles`, `adelanto_jueves`

**Ventas:** `ventas_cantidad`, `ventas_monto`

---

## 5. Estructura de archivos

```
src/
  app.html                     <- HTML base con meta movil + Inter font
  app.css                      <- Tailwind v4 + @theme con colores
  lib/
    charts/
      EChart.svelte            <- componente base reutilizable de ECharts
    api/
      client.ts                <- fetch wrapper + getReportesAll() + agruparPor()
      types.ts                 <- ReportRow, ApiResponse, filtros, tipos
    utils/
      format.ts                <- currency(), pct(), compact(), number()
      time.ts                  <- getMexicoNow(), getDayName(), getWeekNumber(), DIAS_SEMANA
  routes/
    +layout.svelte             <- shell: floating tab bar iOS-style (4 tabs)
    +page.svelte               <- dashboard: KPIs + charts + drill-down
    comparativo/
      +page.svelte             <- comparacion semanal con deltas
    avance/
      +page.svelte             <- progresion hora por hora de cobranza
    tendencias/
      +page.svelte             <- monitoreo semanal con deteccion automatica + desglose
```

---

## 6. Codigo fuente completo

### 6.1 `src/lib/api/types.ts`

```ts
export interface ReportRow {
	id: number;
	created_at: string;
	created_at_mx: string;
	fecha_mx: string;
	anio: number;
	semana: number;
	hora: number;
	dia_semana_es: string;
	agencia: string;
	gerencia: string | null;
	sucursal: string | null;
	clientes: number;
	no_pagos: number;
	debito: number;
	debito_miercoles: number;
	debito_jueves: number;
	debito_viernes: number;
	cobranza_pura: number;
	excedente: number;
	liquidaciones: number;
	cobranza_total: number;
	rendimiento: number;
	rendimiento_miercoles: number;
	rendimiento_jueves: number;
	rendimiento_viernes: number;
	faltante: number;
	faltante_miercoles: number;
	faltante_jueves: number;
	faltante_viernes: number;
	adelanto_miercoles: number;
	adelanto_jueves: number;
	ventas_cantidad: number;
	ventas_monto: number;
}

export interface ResumenGrupo {
	nombre: string;
	cobranza_total: number;
	debito: number;
	clientes: number;
	rendimiento_avg: number;
	faltante: number;
	registros: number;
}

export interface Pagination {
	page: number;
	per_page: number;
	total: number;
	total_pages: number;
	has_next: boolean;
	has_prev: boolean;
}

export interface ApiResponse<T> {
	success: boolean;
	code: string;
	message: string;
	request_id: string;
	duration_ms: number;
	meta: {
		timezone: string;
		as_of: string;
		pagination?: Pagination;
		query?: Record<string, unknown>;
		filtros?: Record<string, unknown>;
	};
	data: T;
}

export interface ComparativoData {
	semana_actual: SemanaData;
	semana_anterior: SemanaData;
}

export interface SemanaData {
	semana: number;
	total: number;
	registros: ReportRow[];
}

export type NivelOrg = 'gerencia' | 'agencia' | 'sucursal';

export interface ReportFilters {
	anio?: number;
	semana?: number;
	hora?: number;
	agencia?: string;
	gerencia?: string;
	sucursal?: string;
	dia_semana_es?: string;
	page?: number;
	per_page?: number;
	sort?: string;
	order?: 'asc' | 'desc';
}

export interface ComparativoFilters {
	anio: number;
	semana: number;
	dia_semana_es: string;
	hora: number;
	gerencia?: string;
	agencia?: string;
	sucursal?: string;
}
```

### 6.2 `src/lib/api/client.ts`

```ts
import type {
	ApiResponse,
	ReportRow,
	ComparativoData,
	ReportFilters,
	ComparativoFilters,
	ResumenGrupo,
	NivelOrg
} from './types';

const BASE = 'https://elysia.xpress1.cc/api';

function toParams(obj: Record<string, unknown>): string {
	const params = new URLSearchParams();
	for (const [k, v] of Object.entries(obj)) {
		if (v !== undefined && v !== null && v !== '') params.set(k, String(v));
	}
	return params.toString();
}

export async function getReportes(
	filters: ReportFilters = {}
): Promise<ApiResponse<ReportRow[]>> {
	const qs = toParams(filters as Record<string, unknown>);
	const url = `${BASE}/reportes-generales/${qs ? `?${qs}` : ''}`;
	const res = await fetch(url);
	if (!res.ok) throw new Error(`API error: ${res.status}`);
	return res.json();
}

/** Fetch all pages when data exceeds per_page limit */
export async function getReportesAll(
	filters: ReportFilters = {}
): Promise<ReportRow[]> {
	const first = await getReportes({ ...filters, per_page: 1000, page: 1 });
	const allRows = [...first.data];
	const totalPages = first.meta.pagination?.total_pages ?? 1;

	const remaining = [];
	for (let p = 2; p <= totalPages; p++) {
		remaining.push(getReportes({ ...filters, per_page: 1000, page: p }));
	}
	for (const res of await Promise.all(remaining)) {
		allRows.push(...res.data);
	}

	return allRows;
}

export async function getComparativo(
	filters: ComparativoFilters
): Promise<ApiResponse<ComparativoData>> {
	const qs = toParams(filters as Record<string, unknown>);
	const res = await fetch(`${BASE}/reportes-generales/comparativo?${qs}`);
	if (!res.ok) throw new Error(`API error: ${res.status}`);
	return res.json();
}

/** Agrupa rows por nivel organizacional y calcula resumen */
export function agruparPor(rows: ReportRow[], nivel: NivelOrg): ResumenGrupo[] {
	const map = new Map<string, { cobr: number; deb: number; cli: number; rend: number[]; falt: number; count: number }>();

	for (const r of rows) {
		const key = r[nivel] ?? 'Sin asignar';
		let g = map.get(key);
		if (!g) {
			g = { cobr: 0, deb: 0, cli: 0, rend: [], falt: 0, count: 0 };
			map.set(key, g);
		}
		g.cobr += r.cobranza_total;
		g.deb += r.debito;
		g.cli += r.clientes;
		g.rend.push(r.rendimiento);
		g.falt += r.faltante;
		g.count++;
	}

	const result: ResumenGrupo[] = [];
	for (const [nombre, g] of map) {
		result.push({
			nombre,
			cobranza_total: g.cobr,
			debito: g.deb,
			clientes: g.cli,
			rendimiento_avg: g.rend.length ? g.rend.reduce((a, b) => a + b, 0) / g.rend.length : 0,
			faltante: g.falt,
			registros: g.count
		});
	}

	return result.sort((a, b) => b.cobranza_total - a.cobranza_total);
}
```

### 6.3 `src/lib/utils/format.ts`

```ts
const currencyFmt = new Intl.NumberFormat('es-MX', {
	style: 'currency',
	currency: 'MXN',
	minimumFractionDigits: 0,
	maximumFractionDigits: 0
});

const numberFmt = new Intl.NumberFormat('es-MX', {
	maximumFractionDigits: 0
});

const pctFmt = new Intl.NumberFormat('es-MX', {
	minimumFractionDigits: 1,
	maximumFractionDigits: 1
});

export function currency(n: number): string {
	return currencyFmt.format(n);
}

export function number(n: number): string {
	return numberFmt.format(n);
}

export function pct(n: number): string {
	return `${pctFmt.format(n)}%`;
}

export function compact(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
	return numberFmt.format(n);
}
```

### 6.4 `src/lib/utils/time.ts`

> CRITICO: Todas las paginas deben usar `getMexicoNow()` para inicializar filtros temporales. Nunca usar `new Date()` directamente.

```ts
const MX_TZ = 'America/Mexico_City';

/** Returns a Date object representing the current time in Mexico City */
export function getMexicoNow(): Date {
	return new Date(new Date().toLocaleString('en-US', { timeZone: MX_TZ }));
}

const DIAS_MAP = ['Domingo', 'Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado'];

export const DIAS_SEMANA = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];

export function getDayName(d: Date): string {
	return DIAS_MAP[d.getDay()];
}

export function getWeekNumber(d: Date): number {
	const oneJan = new Date(d.getFullYear(), 0, 1);
	return Math.ceil(((d.getTime() - oneJan.getTime()) / 86400000 + oneJan.getDay() + 1) / 7);
}
```

### 6.5 `src/lib/charts/EChart.svelte`

```svelte
<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import type { EChartsOption } from 'echarts';

	let { option, height = 'clamp(260px, 35vh, 420px)' }: { option: EChartsOption; height?: string } =
		$props();

	let el: HTMLDivElement;
	let chart: any;
	let ro: ResizeObserver | null = null;

	const rafThrottle = (fn: () => void) => {
		let raf = 0;
		return () => {
			if (raf) return;
			raf = requestAnimationFrame(() => {
				raf = 0;
				fn();
			});
		};
	};

	onMount(async () => {
		const echarts = await import('echarts/core');
		const { LineChart, BarChart, PieChart } = await import('echarts/charts');
		const {
			GridComponent,
			TooltipComponent,
			LegendComponent,
			DataZoomComponent
		} = await import('echarts/components');
		const { CanvasRenderer } = await import('echarts/renderers');

		echarts.use([
			LineChart,
			BarChart,
			PieChart,
			GridComponent,
			TooltipComponent,
			LegendComponent,
			DataZoomComponent,
			CanvasRenderer
		]);

		chart = echarts.init(el, undefined, { renderer: 'canvas' });
		chart.setOption(option);

		const doResize = rafThrottle(() => chart?.resize());

		ro = new ResizeObserver(doResize);
		ro.observe(el);
		window.addEventListener('orientationchange', doResize);

		onDestroy(() => {
			window.removeEventListener('orientationchange', doResize);
			ro?.disconnect();
			chart?.dispose();
		});
	});

	$effect(() => {
		if (chart && option) {
			chart.setOption(option, { notMerge: true });
		}
	});

	export function resize() {
		chart?.resize();
	}
</script>

<div bind:this={el} class="w-full min-h-[260px]" style:height></div>
```

**Reglas ECharts en SvelteKit:**
1. SSR-safe: Importar solo en `onMount` con `await import()`.
2. Altura real: `min-height: 260px` + `clamp()`.
3. ResizeObserver + `chart.resize()` throttleado con rAF. Backup: `orientationchange`.
4. Tabs ocultos: Llamar `chart.resize()` al mostrar el panel.
5. Config base: `grid.containLabel: true`, `tooltip.trigger: 'axis'`, `renderer: 'canvas'`.
6. Cleanup: `onDestroy` -> disconnect observer, remove listeners, `chart.dispose()`.

### 6.6 `src/routes/+layout.svelte` — Floating Tab Bar

```svelte
<script lang="ts">
	import '../app.css';
	import { page } from '$app/state';

	let { children } = $props();

	const tabs = [
		{ href: '/', label: 'Dashboard', icon: 'dashboard' },
		{ href: '/comparativo', label: 'Comparativo', icon: 'comparativo' },
		{ href: '/avance', label: 'Avance', icon: 'avance' }
	] as const;
</script>

<svelte:head>
	<title>Reportes Xpress</title>
</svelte:head>

<div class="flex flex-col h-dvh bg-surface font-sans antialiased">
	<main class="flex-1 overflow-y-auto pb-28">
		{@render children()}
	</main>

	<!-- Floating tab bar -->
	<nav
		class="fixed bottom-0 inset-x-0 z-50 px-5"
		style="padding-bottom: max(10px, env(safe-area-inset-bottom));"
	>
		<div
			class="bg-card rounded-[22px] border border-border/30"
			style="box-shadow: 0 4px 32px rgba(14, 42, 59, 0.10), 0 1px 4px rgba(14, 42, 59, 0.04);"
		>
			<div class="flex items-center h-[68px]">
				{#each tabs as tab}
					{@const active = tab.href === '/' ? page.url.pathname === '/' : page.url.pathname.startsWith(tab.href)}
					<a
						href={tab.href}
						class="relative flex-1 flex flex-col items-center justify-center gap-[5px] h-full transition-colors duration-200 {active ? 'text-primary' : 'text-muted/60'}"
						aria-current={active ? 'page' : undefined}
					>
						{#if active}
							<span class="absolute top-0 left-1/2 -translate-x-1/2 w-6 h-[3px] rounded-full bg-accent"></span>
						{/if}

						{#if tab.icon === 'dashboard'}
							<svg class="w-[23px] h-[23px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
								<rect x="3" y="3" width="7.5" height="7.5" rx="2" />
								<rect x="13.5" y="3" width="7.5" height="7.5" rx="2" />
								<rect x="3" y="13.5" width="7.5" height="7.5" rx="2" />
								<rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2" />
							</svg>
						{:else if tab.icon === 'comparativo'}
							<svg class="w-[23px] h-[23px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
								<path d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5" />
							</svg>
						{:else}
							<svg class="w-[23px] h-[23px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
								<path d="M2.25 18L9 11.25l4.306 4.306a11.95 11.95 0 015.814-5.518l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" />
							</svg>
						{/if}

						<span class="text-[10px] font-semibold tracking-wide leading-none">{tab.label}</span>
					</a>
				{/each}
			</div>
		</div>
	</nav>
</div>
```

**Especificacion del nav:**
- Flotante con margins horizontales `px-5`, separado del borde inferior
- Card `rounded-[22px]`, fondo blanco, `box-shadow` dual (difusion + base)
- Indicador activo: pill dorado 3px en top del tab (`bg-accent`)
- Estados: activo `text-primary`, inactivo `text-muted/60`
- Safe area: `padding-bottom: max(10px, env(safe-area-inset-bottom))`
- Iconos: SVG outline 23x23px, stroke 1.5, `currentColor`
- Altura contenedor: 68px
- Active detection: `/` con match exacto, resto con `startsWith`

### 6.7 `src/routes/+page.svelte` — Dashboard

**Funcionalidad:**
- Carga automatica en `onMount` con filtros `anio+semana+dia+hora`
- Usa `getMexicoNow()` para inicializar filtros (timezone Mexico)
- Filtros rapidos: select semana (S1-S53), dia, hora — cada cambio dispara fetch
- KPIs (grid 2x2): Cobranza total, Debito total, Rendimiento promedio (semaforo), Faltante total
- Navegacion organizacional: tabs Gerencia / Agencia / Sucursal
- Drill-down: tap gerencia -> filtra API por gerencia, muestra agencias -> tap agencia -> muestra sucursales
- Drill-up: boton <- vuelve al nivel anterior
- Lista scrolleable (max-h-80) con nombre, clientes, registros, cobranza y rendimiento
- Chart 1: barras horizontales top 15 cobranza por grupo activo (color `accent`)
- Chart 2: barras horizontales top 15 rendimiento por grupo (semaforo por barra)
- Estados: loading (spinner), error (con reintentar), sin datos

**Fetch:** `GET /api/reportes-generales/?anio=X&semana=X&dia_semana_es=X&hora=X&per_page=500&sort=cobranza_total&order=desc` + filtros drill-down opcionales (`gerencia`, `agencia`).

**KPIs:** Se suman entre agencias del mismo snapshot (correcto). `rendimiento` se promedia.

**agruparPor():** Agrupa rows por el nivel activo, suma cobranza/debito/clientes/faltante, promedia rendimiento, cuenta registros. Ordena desc por cobranza_total.

### 6.8 `src/routes/comparativo/+page.svelte` — Comparativo Semanal

**Funcionalidad:**
- Usa `getMexicoNow()` para inicializar filtros (timezone Mexico)
- Filtros: anio (input number), semana (input number), dia (select), hora (select)
- Selector de nivel: botones gerencia/agencia/sucursal. Activo: `bg-primary text-white`.
- Input de valor: texto libre para gerencia/agencia, dropdown para sucursal (6 valores fijos)
- Boton "Comparar" — deshabilitado sin valor. Llama `GET /api/reportes-generales/comparativo`
- Deltas (grid 2x2): % cambio cobranza (success/danger), pp cambio rendimiento
- Totales: cards semana actual vs anterior con cobranza, registros y rendimiento
- Chart comparativo: barras agrupadas (anterior gris `#D9E1E7`, actual dorado `accent`)
- Mini-tabs en chart: GER/AGE/SUC para cambiar agrupacion visual
- Lista detalle: grupos de semana actual con nombre, clientes, cobranza, rendimiento

**Fetch:** `GET /api/reportes-generales/comparativo?anio=X&semana=X&dia_semana_es=X&hora=X&[nivel]=valor`

**Deltas:** `deltaCobranza = ((cobrAct - cobrAnt) / cobrAnt) * 100`, `deltaRendimiento = rendAct - rendAnt` (en pp).

### 6.9 `src/routes/avance/+page.svelte` — Avance Hora por Hora

**Funcionalidad:**
- Usa `getMexicoNow()` para inicializar filtros (timezone Mexico)
- Filtros: semana (select), dia (select col-span-2), nivel (botones), valor (input/select)
- Boton "Ver avance" — fetch SIN filtro `hora` para obtener todos los snapshots del dia
- Usa `getReportesAll()` para paginacion automatica (algunas sucursales tienen >1000 registros por dia)
- Agrupacion client-side por hora: suma cobranza/debito/faltante, promedia rendimiento, cuenta agencias unicas
- **Filtro de horas incompletas:** Excluye horas con <80% de agencias vs el maximo observado. Muestra banner de advertencia con cantidad de horas excluidas.
- KPIs (grid 2x2): Cobrado al cierre, Rendimiento cierre (semaforo), Debito, Faltante cierre
- Sub-KPIs: delta cobranza en el dia (`+currency`), delta rendimiento pp en el dia
- Chart 1: dual-axis linea — Cobranza (area dorada gradient) + Rendimiento (linea verde) por hora
- Chart 2: barras faltante por hora (eje Y invertido, gradient rojo)
- Tabla hora por hora: hora, cobranza con delta vs hora anterior (+compact), rendimiento (semaforo), faltante
- Header de tabla muestra cantidad de agencias esperadas

**Fetch:** Usa `getReportesAll()` que pagina automaticamente. Filtros: `anio, semana, dia_semana_es, sort=hora, order=asc, [nivel]=valor` (nota: sin `hora` para traer todas las horas).

**Agrupacion por hora:**
```ts
interface HoraSnapshot {
	hora: number;
	cobranza_total: number;
	debito: number;
	rendimiento_avg: number;
	faltante: number;
	clientes: number;
	agencias: number;
}
```
Se agrupa con `Map<number, acumulador>`, suma numericos, promedia rendimiento, cuenta agencias unicas con `Set<string>`. Ordena por hora asc.

**Filtro de horas incompletas:**
- `porHoraRaw`: todas las horas agrupadas
- `maxAgencias`: maximo de agencias observado en cualquier hora
- `porHora = porHoraRaw.filter(h => h.agencias >= maxAgencias * 0.8)`: solo horas con datos completos
- `horasExcluidas`: cuantas se descartaron, se muestra en banner de advertencia

**Metricas inicio/cierre:** `inicio = porHora[0]`, `cierre = porHora[porHora.length - 1]`. Avance = cierre - inicio.

### 6.10 `src/routes/tendencias/+page.svelte` — Tendencias (Monitoreo Semanal)

**Funcionalidad:**
- Auto-detecta semana/anio via `GET /api/calendario/semana-actual` + dia/hora via `getMexicoNow()`
- Filtros minimos: solo nivel (gerencia/agencia/sucursal) + valor. Sin semana/dia/hora (automaticos).
- Fetch en paralelo (Promise.all): semana actual y semana anterior, TODAS las horas
- Agrupacion client-side por hora con filtro de horas incompletas (<80% agencias)
- KPIs (2x2): Cobranza (delta%), Rendimiento (delta pp, semaforo), Faltante (delta% invertido), Clientes (delta absoluto)
- Chart 1: Cobranza overlay — linea dorada solida+area (actual) + linea gris punteada (anterior) + markLine "Ahora"
- Chart 2: Rendimiento overlay — linea verde (actual) + gris punteada (anterior) + markLine "Meta 80%" + "Ahora"
- Tabla comparativa por hora: Hora, Cobr.Act, Cobr.Ant, Delta%, Rend.Act, Rend.Ant, Deltapp. Hora actual resaltada con `bg-accent/5` + badge "ahora"

**Desglose por sub-nivel (CRITICO):**
> Los datos son **snapshots NO acumulativos**. Cuando se filtra por un nivel, se desglosan por su sub-nivel inmediato.

- **Sucursal → desglose por gerencias:** Al filtrar por sucursal (ej: "moneda"), se muestran todas las gerencias que pertenecen a esa sucursal con sus metricas y deltas vs semana anterior.
- **Gerencia → desglose por agencias:** Al filtrar por gerencia (ej: "GERM006"), se muestran todas las agencias que pertenecen a esa gerencia con sus metricas y deltas.
- **Agencia → sin desglose:** Es el nivel mas granular, no hay sub-nivel.

El desglose usa los rows del snapshot de la hora actual (con fallback a la ultima hora disponible), agrupa por el sub-nivel y calcula deltas comparando ambas semanas. Se ordena por cobranza descendente.

**Fetch:** Usa `getReportesAll()` dos veces en paralelo. Filtros: `anio, semana, dia_semana_es, sort=hora, order=asc, [nivel]=valor` (sin `hora` para traer todas las horas). Una vez con semana actual, otra con semana-1.

**Tipos adicionales:**
```ts
// En types.ts
interface CalendarioSemana {
	semana: number;
	anio: number;
	fecha_inicio: string;
	fecha_fin: string;
}

// En client.ts
getCalendarioSemanaActual(): Promise<CalendarioSemana>
```

---

## 7. Patrones de UI reutilizables

### Cards
```html
<div class="rounded-2xl bg-card p-4 border border-border">...</div>
```

### KPI Card
```html
<p class="text-[11px] text-muted font-medium uppercase tracking-wide">Label</p>
<p class="text-xl font-bold text-primary mt-1">{value}</p>
```

### Selector de nivel (botones toggle)
```html
<button class="flex-1 py-1.5 rounded-lg text-xs font-medium transition-colors
  {active ? 'bg-primary text-white' : 'bg-surface text-muted'}">
```

### Input/Select de filtro
```html
class="mt-1 w-full rounded-xl bg-surface border border-border px-3 py-2.5 text-sm text-primary outline-none focus:border-accent"
```

### Boton primario
```html
class="w-full rounded-xl bg-accent py-2.5 text-sm font-semibold text-white active:opacity-80 disabled:opacity-40 transition-opacity"
```

### Spinner de carga
```html
<div class="w-8 h-8 border-3 border-accent/30 border-t-accent rounded-full animate-spin"></div>
```

### Error con reintentar
```html
<div class="rounded-2xl bg-danger/10 p-4 text-center">
  <p class="text-sm text-danger font-medium">{error}</p>
  <button class="mt-2 text-sm text-accent font-semibold" onclick={fetchData}>Reintentar</button>
</div>
```

### Lista con items
```html
<div class="divide-y divide-border max-h-80 overflow-y-auto">
  {#each items as item}
    <div class="px-4 py-3 flex items-center justify-between">
      <div class="min-w-0">
        <p class="text-sm font-medium text-primary truncate">{item.nombre}</p>
        <p class="text-xs text-muted">detalle</p>
      </div>
      <div class="text-right shrink-0 ml-3">
        <p class="text-sm font-semibold text-primary">{valor}</p>
        <p class="text-xs {semaforo}">{rendimiento}</p>
      </div>
    </div>
  {/each}
</div>
```

---

## 8. Helpers compartidos entre paginas

> CRITICO: Todas las funciones de fecha/hora estan centralizadas en `$lib/utils/time.ts`. Nunca definir helpers locales en paginas.

Todas las paginas importan de `$lib/utils/time`:

```ts
import { getMexicoNow, getDayName, getWeekNumber, DIAS_SEMANA } from '$lib/utils/time';

// Inicializacion de filtros temporales — SIEMPRE con timezone Mexico
const now = getMexicoNow();
let anio = $state(now.getFullYear());
let semana = $state(getWeekNumber(now));
let dia = $state(getDayName(now));
let hora = $state(now.getHours()); // solo dashboard y comparativo
```

**Paginacion (Avance):** Usa `getReportesAll()` en vez de `getReportes()` cuando los datos pueden exceder 1000 registros (sucursales como `efectivo` tienen ~1953 registros por dia).

---

## 9. Decisiones de diseno

- **Mobile-first:** Layout disenado para 360px+
- **Floating nav:** Tab bar flotante con sombra, separada del borde, `rounded-[22px]`
- **Tree-shaking:** Imports granulares de ECharts (core, charts, components, renderers)
- **Sin estado global:** Cada vista hace su propio fetch, sin stores compartidos
- **Componente generico:** `EChart.svelte` recibe `option` como prop reactivo
- **Snapshot puntual:** Dashboard siempre filtra `anio+semana+dia+hora` = un snapshot unico por agencia
- **Filtros obligatorios:** Siempre filtrar los 4 ejes temporales para evitar duplicados y timeout
- **Agregacion client-side:** `agruparPor(rows, nivel)` y agrupacion por hora en Avance
- **Drill-down:** Navegacion jerarquica Gerencia -> Agencia -> Sucursal sin cambiar de pagina
- **Avance sin hora:** Fetch sin filtro `hora` para obtener todos los snapshots del dia
- **Svelte 5 runes:** `$state`, `$derived`, `$derived.by`, `$effect`, `$props`
- **Locale MXN:** Todos los formatters usan `es-MX` y moneda MXN
- **Timezone Mexico:** Todos los filtros temporales se inicializan con `getMexicoNow()` (America/Mexico_City). Nunca usar `new Date()` directo.
- **Paginacion automatica:** `getReportesAll()` resuelve el limite de 1000 registros por request, paginando en paralelo. Se usa en Avance donde sucursales como `efectivo` tienen ~1953 registros.
- **Horas incompletas:** Avance filtra horas con <80% de agencias vs el maximo. La ultima hora del dia suele tener datos parciales y causa caidas dramaticas en graficos. Se muestra advertencia.
- **Datos son snapshots (NO acumulativos):** Cada registro es un snapshot de avance en un momento. NUNCA sumar horas/dias de la misma agencia. SI se puede sumar entre agencias del mismo snapshot (misma semana+dia+hora).
- **Desglose por sub-nivel:** Al filtrar por sucursal se desglosa por sus gerencias. Al filtrar por gerencia se desglosa por sus agencias. Esto aplica en Tendencias y debe considerarse en futuras pantallas.
- **Tendencias auto-detecta:** Usa `/api/calendario/semana-actual` para semana/anio y `getMexicoNow()` para dia/hora. El usuario solo elige nivel+valor.
