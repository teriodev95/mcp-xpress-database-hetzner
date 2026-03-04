#!/usr/bin/env python3
"""
Genera dos reportes LaTeX de cobranza adelantada:
1. Reporte Analista (técnico con SQL, fórmulas, métricas)
2. Reporte Auditor (operativo para auditoría de campo)
"""

import json
import urllib.request
import re
import os

MCP_URL = "http://65.21.188.158:7400/run_query"
MCP_KEY = "9mYS%hyyFGBg#x3ByAu%v@d@"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Helpers ──────────────────────────────────────────────────────────

def run_query(query):
    payload = json.dumps({"query": query}).encode("utf-8")
    req = urllib.request.Request(
        MCP_URL, data=payload,
        headers={"x-api-key": MCP_KEY, "Content-Type": "application/json"},
    )
    resp = urllib.request.urlopen(req, timeout=60)
    data = json.loads(resp.read())
    if not data.get("success"):
        raise RuntimeError(data.get("error", "Unknown"))
    return data["rows"]


def tex_esc(s):
    """Escape special LaTeX chars."""
    if not s:
        return ""
    s = str(s)
    s = s.replace("\\", "\\textbackslash{}")
    for ch in "&%$#_{}":
        s = s.replace(ch, "\\" + ch)
    s = s.replace("~", "\\textasciitilde{}")
    s = s.replace("^", "\\textasciicircum{}")
    return s


def tex_name(name):
    """Title-case and escape a client name."""
    if not name:
        return ""
    parts = name.strip().split()
    titled = " ".join(p.capitalize() for p in parts)
    return tex_esc(titled)


def fmt_money(val):
    """Format as $X,XXX.XX for LaTeX."""
    try:
        v = float(val)
    except (ValueError, TypeError):
        return "---"
    return f"\\money{{{v:.0f}}}"


def fmt_pct(val):
    """Format percentage."""
    try:
        v = float(val)
    except (ValueError, TypeError):
        return "---"
    return f"{v:.2f}\\%"


# ── Data Collection ──────────────────────────────────────────────────

SUCURSAL_MAP = {
    "GERC003": "Capital", "GERC001": "Capital", "GERC002": "Capital",
    "GERD009": "Dinero", "GERD011": "Dinero", "GERD001": "Dinero",
    "GERE001": "Efectivo", "GERE002": "Efectivo", "GERE004": "Efectivo", "GERE006": "Efectivo",
    "GERM005": "Moneda", "GERM001": "Moneda",
    "GERP003": "Plata", "GERP001": "Plata",
}

GERENCIA_MAP = {
    "AGC013": "GERC003", "AGC023": "GERC003",
    "AGD066": "GERD009", "AGD067": "GERD009", "AGD076": "GERD009",
    "AGD085": "GERD009", "AGD086": "GERD009",
    "AGD073": "GERD011", "AGD078": "GERD011",
    "AGE003": "GERE001", "AGE007": "GERE001",
    "AGE006": "GERE002", "AGE058": "GERE002",
    "AGE108": "GERE004", "AGE010": "GERE006",
    "AGM055": "GERM005", "AGP014": "GERP003",
}


def get_clients_for_week(semana, anio, agencies, wed_date):
    """Get JUEVES clients paid on Wednesday from prestamos_v2."""
    ag_list = ",".join(f"'{a}'" for a in agencies)
    q = (
        f"SELECT pv.PrestamoID, "
        f"CONCAT(pv.Nombres, ' ', pv.Apellido_Paterno, ' ', pv.Apellido_Materno) AS cliente, "
        f"pv.Dia_de_pago, p.Monto, p.Tipo, pv.Agente AS agencia, "
        f"asa.Agente AS nombre_agente "
        f"FROM pagos_v3 p "
        f"INNER JOIN prestamos_v2 pv ON p.PrestamoID = pv.PrestamoID "
        f"LEFT JOIN agencias_status_auxilar asa ON pv.Agente = asa.Agencia "
        f"WHERE pv.Dia_de_pago = 'JUEVES' "
        f"AND pv.Agente IN ({ag_list}) "
        f"AND DATE(CONVERT_TZ(p.Created_at, 'UTC', 'America/Mexico_City')) = '{wed_date}' "
        f"AND p.Tipo NOT IN ('No_pago','Multa','Visita') "
        f"ORDER BY pv.Agente, p.Monto DESC"
    )
    rows = run_query(q)
    # Also check prestamos_completados
    q2 = (
        f"SELECT pc.PrestamoID, "
        f"CONCAT(per.nombres, ' ', per.apellido_paterno, ' ', per.apellido_materno) AS cliente, "
        f"pc.Dia_de_pago, p.Monto, p.Tipo, pc.Agente AS agencia "
        f"FROM pagos_v3 p "
        f"INNER JOIN prestamos_completados pc ON p.PrestamoID = pc.PrestamoID "
        f"LEFT JOIN personas per ON pc.cliente_persona_id = per.id "
        f"WHERE pc.Dia_de_pago = 'JUEVES' "
        f"AND pc.Agente IN ({ag_list}) "
        f"AND DATE(CONVERT_TZ(p.Created_at, 'UTC', 'America/Mexico_City')) = '{wed_date}' "
        f"AND p.Tipo NOT IN ('No_pago','Multa','Visita') "
        f"ORDER BY pc.Agente, p.Monto DESC"
    )
    try:
        rows2 = run_query(q2)
        rows.extend(rows2)
    except Exception:
        pass
    return rows


def get_snapshot_data(semana, anio):
    """Get agencies with adelanto > 0 from the view."""
    q = (
        f"SELECT v1.agencia, v1.gerencia, v1.sucursal, v1.semana, "
        f"v1.clientes, v1.debito, v1.debito_miercoles, v1.debito_jueves, v1.debito_viernes, "
        f"v1.cobranza_pura, v1.excedente, v1.liquidaciones, v1.cobranza_total, "
        f"v1.rendimiento_miercoles, v1.rendimiento_jueves, v1.rendimiento_viernes, v1.rendimiento, "
        f"v1.faltante_miercoles, v1.faltante_jueves, v1.faltante_viernes, v1.faltante, "
        f"v1.adelanto_miercoles, v1.adelanto_jueves, "
        f"v1.no_pagos, v1.ventas_cantidad, v1.ventas_monto "
        f"FROM vw_cobranza_snapshots_reportes_generales v1 "
        f"INNER JOIN (SELECT agencia, hora, fecha_mx, MAX(id) AS max_id "
        f"FROM vw_cobranza_snapshots_reportes_generales "
        f"WHERE anio = {anio} AND semana = {semana} AND dia_semana_es = 'Miercoles' AND hora = 20 "
        f"GROUP BY agencia, hora, fecha_mx) v2 ON v1.id = v2.max_id "
        f"WHERE v1.adelanto_miercoles > 0 "
        f"ORDER BY v1.sucursal, v1.gerencia, v1.agencia"
    )
    return run_query(q)


def get_agent_names(agencies):
    ag_list = ",".join(f"'{a}'" for a in agencies)
    q = f"SELECT Agencia, Agente FROM agencias_status_auxilar WHERE Agencia IN ({ag_list})"
    rows = run_query(q)
    return {r["Agencia"]: r["Agente"] for r in rows}


# ── LaTeX Preamble ───────────────────────────────────────────────────

def preamble(title_short, period):
    return r"""\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage[spanish]{babel}
\usepackage{geometry}
\usepackage{booktabs}
\usepackage{longtable}
\usepackage{array}
\usepackage{xcolor}
\usepackage{colortbl}
\usepackage{fancyhdr}
\usepackage{titlesec}
\usepackage{enumitem}
\usepackage{multirow}
\usepackage{siunitx}
\usepackage{hyperref}
\usepackage{pdflscape}

\geometry{margin=1.8cm, top=2.8cm, bottom=2.2cm}

\definecolor{xpressblue}{RGB}{31, 78, 121}
\definecolor{xpressgray}{RGB}{89, 89, 89}
\definecolor{alertred}{RGB}{192, 0, 0}
\definecolor{lightgray}{RGB}{242, 242, 242}
\definecolor{lightblue}{RGB}{220, 235, 250}

\titleformat{\section}{\Large\bfseries\color{xpressblue}}{}{0em}{}[\titlerule]
\titleformat{\subsection}{\large\bfseries\color{xpressgray}}{}{0em}{}
\titleformat{\subsubsection}{\normalsize\bfseries\color{xpressgray}}{}{0em}{}

\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\color{xpressgray}""" + tex_esc(title_short) + r"""}
\fancyhead[R]{\small\color{xpressgray}""" + tex_esc(period) + r"""}
\fancyfoot[C]{\small\color{xpressgray}\thepage}
\renewcommand{\headrulewidth}{0.4pt}

\sisetup{
  group-separator={,},
  group-minimum-digits=4,
  output-decimal-marker={.},
  round-mode=places,
  round-precision=2
}

\newcommand{\money}[1]{\$\num{#1}}

\begin{document}
"""


# ── Build client data structure ──────────────────────────────────────

def organize_by_sucursal(clients, agent_names):
    """Organize client rows into sucursal > gerencia > agencia hierarchy."""
    tree = {}  # sucursal -> gerencia -> agencia -> {agent, clients[]}
    for c in clients:
        ag = c["agencia"]
        ger = GERENCIA_MAP.get(ag, "DESCONOCIDA")
        suc = SUCURSAL_MAP.get(ger, "Desconocida")
        agent = c.get("nombre_agente") or agent_names.get(ag, "---")
        if suc not in tree:
            tree[suc] = {}
        if ger not in tree[suc]:
            tree[suc][ger] = {}
        if ag not in tree[suc][ger]:
            tree[suc][ger][ag] = {"agent": agent, "clients": []}
        tree[suc][ger][ag]["clients"].append(c)
    return tree


# ── Auditor Report ───────────────────────────────────────────────────

def gen_auditor_report(snap5, snap6, clients5, clients6, agent_names):
    lines = []
    lines.append(preamble(
        "Xpress Dinero - Reporte Auditor\u00eda Cobranza Adelantada",
        "Semanas 5--6 / 2026"
    ))

    # ── Cover ──
    lines.append(r"""
\thispagestyle{empty}
\vspace*{3cm}
\begin{center}
  {\Huge\bfseries\color{xpressblue} Reporte de Auditor\'ia}\\[0.5cm]
  {\Huge\bfseries\color{xpressblue} Cobranza Adelantada}\\[1.5cm]
  {\Large\color{xpressgray} Clientes Cobrados Fuera de Su D\'ia Asignado}\\[0.5cm]
  {\Large\color{xpressgray} Para Revisi\'on y Cuestionamiento de Agentes}\\[2.5cm]
  {\large Semanas 5 y 6 del 2026}\\[0.3cm]
  {\large Enero 28 --- Febrero 7, 2026}\\[3cm]
  {\normalsize\color{xpressgray} Generado el 6 de febrero de 2026}\\[0.3cm]
  {\normalsize\color{alertred}\bfseries CONFIDENCIAL --- USO INTERNO}
\end{center}
\newpage

\tableofcontents
\newpage
""")

    # ── Resumen Ejecutivo ──
    total_s5 = len(clients5)
    total_s6 = len(clients6)
    monto_s5 = sum(float(c["Monto"]) for c in clients5)
    monto_s6 = sum(float(c["Monto"]) for c in clients6)
    ag_s5 = len(set(c["agencia"] for c in clients5))
    ag_s6 = len(set(c["agencia"] for c in clients6))

    lines.append(r"""
\section{Resumen Ejecutivo}

Se identificaron agencias donde los agentes cobran clientes asignados para el d\'ia
\textbf{jueves} durante su ruta del \textbf{mi\'ercoles}. Este comportamiento se
denomina \textbf{cobranza adelantada} y debe ser revisado.

\subsection{Cifras Generales}

\begin{center}
\renewcommand{\arraystretch}{1.4}
\begin{tabular}{lrr}
\toprule
\textbf{Concepto} & \textbf{Semana 5} & \textbf{Semana 6} \\
\midrule
""")
    lines.append(f"Agencias involucradas & {ag_s5} & {ag_s6} \\\\\n")
    lines.append(f"Clientes cobrados fuera de d\\'ia & {total_s5} & {total_s6} \\\\\n")
    lines.append(f"Monto total adelantado & {fmt_money(monto_s5)} & {fmt_money(monto_s6)} \\\\\n")
    lines.append(r"""
\bottomrule
\end{tabular}
\end{center}

\subsection{Resumen por Sucursal}
""")

    # Summary table by sucursal
    suc_summary = {}
    for cs, sem_label in [(clients5, "s5"), (clients6, "s6")]:
        for c in cs:
            ag = c["agencia"]
            ger = GERENCIA_MAP.get(ag, "?")
            suc = SUCURSAL_MAP.get(ger, "?")
            if suc not in suc_summary:
                suc_summary[suc] = {"ger_s5": set(), "ger_s6": set(), "ag_s5": set(), "ag_s6": set(),
                                    "cli_s5": 0, "cli_s6": 0, "monto_s5": 0.0, "monto_s6": 0.0}
            suc_summary[suc][f"ger_{sem_label}"].add(ger)
            suc_summary[suc][f"ag_{sem_label}"].add(ag)
            suc_summary[suc][f"cli_{sem_label}"] += 1
            suc_summary[suc][f"monto_{sem_label}"] += float(c["Monto"])

    lines.append(r"""
\begin{center}
\renewcommand{\arraystretch}{1.3}
\rowcolors{2}{lightgray}{white}
\begin{tabular}{lrrrrrr}
\toprule
\textbf{Sucursal} & \multicolumn{2}{c}{\textbf{Agencias}} & \multicolumn{2}{c}{\textbf{Clientes}} & \multicolumn{2}{c}{\textbf{Monto Adel.}} \\
\cmidrule(lr){2-3} \cmidrule(lr){4-5} \cmidrule(lr){6-7}
& \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} \\
\midrule
""")
    for suc in ["Capital", "Dinero", "Efectivo", "Moneda", "Plata"]:
        s = suc_summary.get(suc)
        if not s:
            continue
        lines.append(
            f"{tex_esc(suc)} & {len(s['ag_s5'])} & {len(s['ag_s6'])} "
            f"& {s['cli_s5']} & {s['cli_s6']} "
            f"& {fmt_money(s['monto_s5'])} & {fmt_money(s['monto_s6'])} \\\\\n"
        )
    lines.append(r"""
\bottomrule
\end{tabular}
\end{center}

\subsection{C\'omo Usar Este Reporte}

\begin{enumerate}[leftmargin=2em]
  \item Identifique la sucursal y gerencia del agente a auditar.
  \item Localice la agencia en las tablas de detalle por semana.
  \item Cada fila muestra: n\'umero de pr\'estamo, nombre del cliente, d\'ia de pago asignado y monto cobrado.
  \item \textbf{Todos los clientes listados tienen d\'ia de pago JUEVES pero fueron cobrados en MI\'ERCOLES.}
  \item Cuestione al agente sobre el motivo del cobro anticipado.
\end{enumerate}

\newpage
""")

    # ── Detail per week ──
    for sem, sem_clients, sem_label, fecha_desc in [
        (5, clients5, "Semana 5", "Mi\\'ercoles 28 de Enero 2026"),
        (6, clients6, "Semana 6", "Mi\\'ercoles 4 de Febrero 2026"),
    ]:
        tree = organize_by_sucursal(sem_clients, agent_names)
        lines.append(f"\\section{{Detalle --- Semana {sem} ({fecha_desc})}}\n\n")

        total_sem_clients = len(sem_clients)
        total_sem_monto = sum(float(c["Monto"]) for c in sem_clients)
        lines.append(
            f"Total: \\textbf{{{total_sem_clients} clientes}} cobrados fuera de d\\'ia "
            f"por un monto de \\textbf{{{fmt_money(total_sem_monto)}}}.\n\n"
        )

        for suc in ["Capital", "Dinero", "Efectivo", "Moneda", "Plata"]:
            if suc not in tree:
                continue
            lines.append(f"\\subsection{{Sucursal {tex_esc(suc)}}}\n\n")

            for ger in sorted(tree[suc].keys()):
                agencies = tree[suc][ger]
                total_ger_cli = sum(len(a["clients"]) for a in agencies.values())
                total_ger_monto = sum(sum(float(c["Monto"]) for c in a["clients"]) for a in agencies.values())

                lines.append(
                    f"\\subsubsection{{{tex_esc(ger)} --- "
                    f"{len(agencies)} agencia{'s' if len(agencies) > 1 else ''}, "
                    f"{total_ger_cli} clientes, {fmt_money(total_ger_monto)}}}\n\n"
                )

                for ag in sorted(agencies.keys()):
                    info = agencies[ag]
                    agent = tex_esc(info["agent"].strip().title() if info["agent"] else "---")
                    cli_list = info["clients"]
                    ag_monto = sum(float(c["Monto"]) for c in cli_list)

                    lines.append(
                        f"\\noindent\\textbf{{{tex_esc(ag)}}} --- Agente: \\textbf{{{agent}}} "
                        f"--- {len(cli_list)} clientes --- {fmt_money(ag_monto)}\n\n"
                    )

                    lines.append(r"""
\begin{center}
\renewcommand{\arraystretch}{1.1}
\rowcolors{2}{lightgray}{white}
\footnotesize
\begin{longtable}{rlp{6.5cm}lr}
\toprule
\textbf{\#} & \textbf{Pr\'estamo} & \textbf{Cliente} & \textbf{D\'ia Pago} & \textbf{Monto} \\
\midrule
\endfirsthead
\toprule
\textbf{\#} & \textbf{Pr\'estamo} & \textbf{Cliente} & \textbf{D\'ia Pago} & \textbf{Monto} \\
\midrule
\endhead
""")
                    for i, c in enumerate(cli_list, 1):
                        prestamo = tex_esc(c["PrestamoID"])
                        nombre = tex_name(c["cliente"])
                        dia = tex_esc(c["Dia_de_pago"])
                        monto = fmt_money(c["Monto"])
                        lines.append(f"{i} & {prestamo} & {nombre} & {dia} & {monto} \\\\\n")

                    lines.append(r"""
\bottomrule
\end{longtable}
\end{center}
""")
            lines.append("\\newpage\n")

    # ── Consistent agencies ──
    lines.append(r"""
\section{Agencias Consistentes (Ambas Semanas)}

Las siguientes agencias presentan cobranza adelantada en \textbf{ambas semanas}.
Estas requieren atenci\'on prioritaria.

\begin{center}
\renewcommand{\arraystretch}{1.3}
\rowcolors{2}{lightgray}{white}
\footnotesize
\begin{longtable}{lllllrrrr}
\toprule
\textbf{Sucursal} & \textbf{Gerencia} & \textbf{Agencia} & \textbf{Agente}
  & \multicolumn{2}{c}{\textbf{Clientes}} & \multicolumn{2}{c}{\textbf{Monto}} \\
\cmidrule(lr){5-6} \cmidrule(lr){7-8}
& & & & \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} \\
\midrule
\endfirsthead
\toprule
\textbf{Sucursal} & \textbf{Gerencia} & \textbf{Agencia} & \textbf{Agente}
  & \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} \\
\midrule
\endhead
""")

    ag_s5 = {}
    for c in clients5:
        ag = c["agencia"]
        if ag not in ag_s5:
            ag_s5[ag] = {"count": 0, "monto": 0.0}
        ag_s5[ag]["count"] += 1
        ag_s5[ag]["monto"] += float(c["Monto"])

    ag_s6 = {}
    for c in clients6:
        ag = c["agencia"]
        if ag not in ag_s6:
            ag_s6[ag] = {"count": 0, "monto": 0.0}
        ag_s6[ag]["count"] += 1
        ag_s6[ag]["monto"] += float(c["Monto"])

    consistent = sorted(set(ag_s5.keys()) & set(ag_s6.keys()))
    for ag in consistent:
        ger = GERENCIA_MAP.get(ag, "?")
        suc = SUCURSAL_MAP.get(ger, "?")
        agent = tex_esc((agent_names.get(ag, "---")).strip().title())
        s5 = ag_s5[ag]
        s6 = ag_s6[ag]
        lines.append(
            f"{tex_esc(suc)} & {tex_esc(ger)} & {tex_esc(ag)} & {agent} "
            f"& {s5['count']} & {s6['count']} "
            f"& {fmt_money(s5['monto'])} & {fmt_money(s6['monto'])} \\\\\n"
        )

    lines.append(r"""
\bottomrule
\end{longtable}
\end{center}
""")

    lines.append(r"\end{document}" + "\n")
    return "".join(lines)


# ── Analyst Report ───────────────────────────────────────────────────

def gen_analyst_report(snap5, snap6, clients5, clients6, agent_names):
    lines = []
    lines.append(preamble(
        "Xpress Dinero - Reporte Analista Cobranza Adelantada",
        "Semanas 5--6 / 2026"
    ))

    # ── Cover ──
    lines.append(r"""
\thispagestyle{empty}
\vspace*{3cm}
\begin{center}
  {\Huge\bfseries\color{xpressblue} Reporte T\'ecnico de An\'alisis}\\[0.5cm]
  {\Huge\bfseries\color{xpressblue} Cobranza Adelantada}\\[1.5cm]
  {\Large\color{xpressgray} An\'alisis de Datos, Metodolog\'ia SQL\\y M\'etricas de Rendimiento}\\[2.5cm]
  {\large Semanas 5 y 6 del 2026}\\[0.3cm]
  {\large Enero 28 --- Febrero 7, 2026}\\[3cm]
  {\normalsize\color{xpressgray} Generado el 6 de febrero de 2026}\\[0.3cm]
  {\normalsize\color{xpressgray} Fuentes: \texttt{vw\_cobranza\_snapshots\_reportes\_generales},
  \texttt{pagos\_v3}, \texttt{prestamos\_v2}, \texttt{debitos\_historial}}
\end{center}
\newpage

\tableofcontents
\newpage
""")

    # ── Resumen Ejecutivo ──
    total_s5 = len(clients5)
    total_s6 = len(clients6)
    monto_s5 = sum(float(c["Monto"]) for c in clients5)
    monto_s6 = sum(float(c["Monto"]) for c in clients6)
    ag_s5_set = set(c["agencia"] for c in clients5)
    ag_s6_set = set(c["agencia"] for c in clients6)

    lines.append(r"""
\section{Resumen Ejecutivo}

Se detect\'o \textbf{cobranza adelantada} en m\'ultiples agencias: agentes cobran
clientes de \texttt{Dia\_de\_pago = 'JUEVES'} durante el mi\'ercoles, inflando
\texttt{rendimiento\_miercoles} por encima del 100\%.

\subsection{M\'etricas Clave}

\begin{center}
\renewcommand{\arraystretch}{1.4}
\begin{tabular}{lrr}
\toprule
\textbf{M\'etrica} & \textbf{Semana 5} & \textbf{Semana 6} \\
\midrule
""")
    lines.append(f"Agencias con adelanto & {len(ag_s5_set)} & {len(ag_s6_set)} \\\\\n")
    lines.append(f"Clientes jueves cobrados mi\\'ercoles & {total_s5} & {total_s6} \\\\\n")
    lines.append(f"Monto total adelantado & {fmt_money(monto_s5)} & {fmt_money(monto_s6)} \\\\\n")
    consistent = sorted(ag_s5_set & ag_s6_set)
    lines.append(f"Agencias consistentes (ambas sem.) & \\multicolumn{{2}}{{c}}{{{len(consistent)}}} \\\\\n")
    lines.append(r"""
\bottomrule
\end{tabular}
\end{center}

\newpage
""")

    # ── Technical Methodology ──
    lines.append(r"""
\section{Metodolog\'ia T\'ecnica}

\subsection{Fuentes de Datos}

\begin{enumerate}[leftmargin=2em]
  \item \textbf{vw\_cobranza\_snapshots\_reportes\_generales}: Vista principal que cruza
    \texttt{cobranza\_snapshots} con \texttt{debitos\_historial} (desglosados por d\'ia).
    Columnas clave: \texttt{rendimiento\_miercoles}, \texttt{adelanto\_miercoles},
    \texttt{sucursal}, \texttt{gerencia}.
  \item \textbf{debitos\_historial}: D\'ebitos desglosados por d\'ia de la semana
    (\texttt{debito\_miercoles}, \texttt{debito\_jueves}, \texttt{debito\_viernes}).
  \item \textbf{pagos\_v3}: Pagos individuales ($\sim$3.5M registros). Filtro por
    \texttt{Created\_at} del mi\'ercoles.
  \item \textbf{prestamos\_v2}: Pr\'estamos activos. Campo \texttt{Dia\_de\_pago}
    verifica que el cliente tiene asignado JUEVES.
  \item \textbf{prestamos\_completados}: Pr\'estamos ya liquidados (fallback para
    clientes migrados).
\end{enumerate}

\subsection{Detecci\'on de Adelanto}

\begin{enumerate}[leftmargin=2em]
  \item \texttt{rendimiento\_miercoles} $> 100\%$ en la vista indica que la cobranza
    supera el d\'ebito del mi\'ercoles.
  \item \texttt{adelanto\_miercoles} $> 0$ cuantifica el excedente.
  \item Confirmaci\'on cruzada: pagos en \texttt{pagos\_v3} registrados el mi\'ercoles
    donde \texttt{Dia\_de\_pago = 'JUEVES'} en \texttt{prestamos\_v2}.
\end{enumerate}

\subsection{F\'ormulas de la Vista}

\begin{itemize}[leftmargin=2em]
  \item $\texttt{rendimiento\_mie} = \frac{\texttt{cobranza\_pura}}{\texttt{debito\_miercoles}} \times 100$
  \item $\texttt{rendimiento\_jue} = \frac{\texttt{cobranza\_pura}}{\texttt{debito\_mie} + \texttt{debito\_jue}} \times 100$
  \item $\texttt{rendimiento\_vie} = \frac{\texttt{cobranza\_pura}}{\texttt{debito\_mie} + \texttt{debito\_jue} + \texttt{debito\_vie}} \times 100$
  \item $\texttt{adelanto\_mie} = \max(\texttt{cobranza\_pura} - \texttt{debito\_mie}, 0)$
  \item $\texttt{adelanto\_jue} = \max(\texttt{cobranza\_pura} - (\texttt{debito\_mie} + \texttt{debito\_jue}), 0)$
  \item $\texttt{faltante\_mie} = \max(\texttt{debito\_mie} - \texttt{cobranza\_pura}, 0)$
\end{itemize}

\subsection{Query de Verificaci\'on de Clientes}

\begin{verbatim}
SELECT pv.PrestamoID,
       CONCAT(pv.Nombres,' ',pv.Apellido_Paterno,' ',
              pv.Apellido_Materno) AS cliente,
       pv.Dia_de_pago, p.Monto, p.Tipo,
       pv.Agente AS agencia
FROM pagos_v3 p
INNER JOIN prestamos_v2 pv
  ON p.PrestamoID = pv.PrestamoID
WHERE pv.Dia_de_pago = 'JUEVES'
  AND pv.Agente IN (...)
  AND DATE(CONVERT_TZ(p.Created_at,
       'UTC','America/Mexico_City')) = '2026-02-04'
  AND p.Tipo NOT IN ('No_pago','Multa','Visita')
ORDER BY pv.Agente, p.Monto DESC
\end{verbatim}

\subsection{Collation}

\begin{itemize}[leftmargin=2em]
  \item \texttt{debitos\_historial.agencia}: \texttt{utf8mb4\_unicode\_ci}
  \item \texttt{cobranza\_snapshots.agencia}: \texttt{utf8mb4\_general\_ci}
  \item \texttt{agencias.AgenciaID}: \texttt{utf8\_general\_ci}
  \item JOIN en vista: \texttt{dh.agencia COLLATE utf8mb4\_general\_ci = cs.agencia}
\end{itemize}

\newpage
""")

    # ── Snapshot metrics per agency ──
    lines.append(r"""
\section{M\'etricas de Snapshot por Agencia}

Datos de \texttt{vw\_cobranza\_snapshots\_reportes\_generales}, mi\'ercoles hora 20.

""")
    for sem, snap, label in [(5, snap5, "Semana 5"), (6, snap6, "Semana 6")]:
        lines.append(f"\\subsection{{{label}}}\n\n")

        if not snap:
            lines.append("Sin datos de snapshot disponibles.\n\n")
            continue

        lines.append(r"""
\begin{center}
\renewcommand{\arraystretch}{1.2}
\rowcolors{2}{lightgray}{white}
\footnotesize
\begin{longtable}{llrrrrrrrr}
\toprule
\textbf{Suc.} & \textbf{Agencia}
  & {\textbf{D\'eb.Mie}} & {\textbf{D\'eb.Jue}} & {\textbf{Cobr.Pura}}
  & {\textbf{Rend.Mie}} & {\textbf{Rend.Jue}}
  & {\textbf{Adel.Mie}} & {\textbf{Falt.Jue}} \\
\midrule
\endfirsthead
\toprule
\textbf{Suc.} & \textbf{Agencia}
  & {\textbf{D\'eb.Mie}} & {\textbf{D\'eb.Jue}} & {\textbf{Cobr.Pura}}
  & {\textbf{Rend.Mie}} & {\textbf{Rend.Jue}}
  & {\textbf{Adel.Mie}} & {\textbf{Falt.Jue}} \\
\midrule
\endhead
""")
        for s in snap:
            suc = tex_esc(str(s.get("sucursal", "?")))
            ag = tex_esc(str(s.get("agencia", "?")))
            dm = fmt_money(s.get("debito_miercoles", 0))
            dj = fmt_money(s.get("debito_jueves", 0))
            cp = fmt_money(s.get("cobranza_pura", 0))
            rm = fmt_pct(s.get("rendimiento_miercoles", 0))
            rj = fmt_pct(s.get("rendimiento_jueves", 0)) if s.get("rendimiento_jueves") else "---"
            am = fmt_money(s.get("adelanto_miercoles", 0))
            fj = fmt_money(s.get("faltante_jueves", 0))
            lines.append(f"{suc} & {ag} & {dm} & {dj} & {cp} & {rm} & {rj} & {am} & {fj} \\\\\n")

        lines.append(r"""
\bottomrule
\end{longtable}
\end{center}

""")

    lines.append("\\newpage\n")

    # ── Client detail by week ──
    for sem, sem_clients, fecha_desc in [
        (5, clients5, "Mi\\'ercoles 28 de Enero 2026"),
        (6, clients6, "Mi\\'ercoles 4 de Febrero 2026"),
    ]:
        tree = organize_by_sucursal(sem_clients, agent_names)
        lines.append(f"\\section{{Detalle por Cliente --- Semana {sem} ({fecha_desc})}}\n\n")

        for suc in ["Capital", "Dinero", "Efectivo", "Moneda", "Plata"]:
            if suc not in tree:
                continue
            lines.append(f"\\subsection{{Sucursal {tex_esc(suc)}}}\n\n")

            for ger in sorted(tree[suc].keys()):
                agencies = tree[suc][ger]
                for ag in sorted(agencies.keys()):
                    info = agencies[ag]
                    agent = tex_esc(info["agent"].strip().title() if info["agent"] else "---")
                    cli_list = info["clients"]
                    ag_monto = sum(float(c["Monto"]) for c in cli_list)

                    lines.append(
                        f"\\subsubsection{{{tex_esc(ger)} $\\rightarrow$ {tex_esc(ag)} "
                        f"--- {agent} ({len(cli_list)} cli., {fmt_money(ag_monto)})}}\n\n"
                    )

                    lines.append(r"""
\begin{center}
\renewcommand{\arraystretch}{1.1}
\rowcolors{2}{lightgray}{white}
\footnotesize
\begin{longtable}{rlp{5.5cm}llr}
\toprule
\textbf{\#} & \textbf{Pr\'estamo} & \textbf{Cliente} & \textbf{D\'ia} & \textbf{Tipo} & \textbf{Monto} \\
\midrule
\endfirsthead
\toprule
\textbf{\#} & \textbf{Pr\'estamo} & \textbf{Cliente} & \textbf{D\'ia} & \textbf{Tipo} & \textbf{Monto} \\
\midrule
\endhead
""")
                    for i, c in enumerate(cli_list, 1):
                        prestamo = tex_esc(c["PrestamoID"])
                        nombre = tex_name(c["cliente"])
                        dia = tex_esc(c["Dia_de_pago"])
                        tipo = tex_esc(c.get("Tipo", "---"))
                        monto = fmt_money(c["Monto"])
                        lines.append(f"{i} & {prestamo} & {nombre} & {dia} & {tipo} & {monto} \\\\\n")

                    lines.append(r"""
\bottomrule
\end{longtable}
\end{center}
""")

        lines.append("\\newpage\n")

    # ── Consistent agencies ──
    lines.append(r"""
\section{Agencias Consistentes (Ambas Semanas)}

""")
    ag_s5 = {}
    for c in clients5:
        ag = c["agencia"]
        if ag not in ag_s5:
            ag_s5[ag] = {"count": 0, "monto": 0.0}
        ag_s5[ag]["count"] += 1
        ag_s5[ag]["monto"] += float(c["Monto"])

    ag_s6 = {}
    for c in clients6:
        ag = c["agencia"]
        if ag not in ag_s6:
            ag_s6[ag] = {"count": 0, "monto": 0.0}
        ag_s6[ag]["count"] += 1
        ag_s6[ag]["monto"] += float(c["Monto"])

    lines.append(r"""
\begin{center}
\renewcommand{\arraystretch}{1.3}
\rowcolors{2}{lightgray}{white}
\footnotesize
\begin{longtable}{lllllrrrr}
\toprule
\textbf{Suc.} & \textbf{Ger.} & \textbf{Ag.} & \textbf{Agente}
  & \multicolumn{2}{c}{\textbf{Clientes}} & \multicolumn{2}{c}{\textbf{Monto}} \\
\cmidrule(lr){5-6} \cmidrule(lr){7-8}
& & & & \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} \\
\midrule
\endfirsthead
\toprule
\textbf{Suc.} & \textbf{Ger.} & \textbf{Ag.} & \textbf{Agente}
  & \textbf{S5} & \textbf{S6} & \textbf{S5} & \textbf{S6} \\
\midrule
\endhead
""")
    for ag in consistent:
        ger = GERENCIA_MAP.get(ag, "?")
        suc = SUCURSAL_MAP.get(ger, "?")
        agent = tex_esc((agent_names.get(ag, "---")).strip().title())
        s5 = ag_s5[ag]
        s6 = ag_s6[ag]
        lines.append(
            f"{tex_esc(suc)} & {tex_esc(ger)} & {tex_esc(ag)} & {agent} "
            f"& {s5['count']} & {s6['count']} "
            f"& {fmt_money(s5['monto'])} & {fmt_money(s6['monto'])} \\\\\n"
        )

    lines.append(r"""
\bottomrule
\end{longtable}
\end{center}
""")

    lines.append(r"\end{document}" + "\n")
    return "".join(lines)


# ── Main ─────────────────────────────────────────────────────────────

def main():
    print("Obteniendo datos de snapshots...")
    snap5 = get_snapshot_data(5, 2026)
    print(f"  Semana 5: {len(snap5)} agencias con adelanto")
    snap6 = get_snapshot_data(6, 2026)
    print(f"  Semana 6: {len(snap6)} agencias con adelanto")

    all_agencies = set()
    for s in snap5 + snap6:
        all_agencies.add(s["agencia"])

    print(f"  Total agencias únicas: {len(all_agencies)}")

    print("Obteniendo nombres de agentes...")
    agent_names = get_agent_names(all_agencies)

    print("Obteniendo clientes semana 5 (miércoles 28 enero)...")
    clients5 = get_clients_for_week(5, 2026, all_agencies, "2026-01-28")
    print(f"  {len(clients5)} clientes encontrados")

    print("Obteniendo clientes semana 6 (miércoles 4 febrero)...")
    clients6 = get_clients_for_week(6, 2026, all_agencies, "2026-02-04")
    print(f"  {len(clients6)} clientes encontrados")

    print("\nGenerando reporte auditor...")
    auditor_tex = gen_auditor_report(snap5, snap6, clients5, clients6, agent_names)
    auditor_path = os.path.join(SCRIPT_DIR, "reporte_auditor_cobranza_adelantada.tex")
    with open(auditor_path, "w", encoding="utf-8") as f:
        f.write(auditor_tex)
    print(f"  Guardado: {auditor_path}")

    print("Generando reporte analista...")
    analyst_tex = gen_analyst_report(snap5, snap6, clients5, clients6, agent_names)
    analyst_path = os.path.join(SCRIPT_DIR, "reporte_analista_cobranza_adelantada.tex")
    with open(analyst_path, "w", encoding="utf-8") as f:
        f.write(analyst_tex)
    print(f"  Guardado: {analyst_path}")

    print("\nListo. Compilar con:")
    print(f"  cd {SCRIPT_DIR}")
    print("  pdflatex -interaction=nonstopmode reporte_auditor_cobranza_adelantada.tex")
    print("  pdflatex -interaction=nonstopmode reporte_auditor_cobranza_adelantada.tex")
    print("  pdflatex -interaction=nonstopmode reporte_analista_cobranza_adelantada.tex")
    print("  pdflatex -interaction=nonstopmode reporte_analista_cobranza_adelantada.tex")


if __name__ == "__main__":
    main()
