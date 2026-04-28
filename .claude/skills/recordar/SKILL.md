---
name: recordar
description: Guarda un hallazgo en la knowledge base local del proyecto en `.claude/memory/`. Usa este skill cuando descubras una regla de negocio no-obvia, diagnostiques un bug, definas un procedimiento útil, o aprendas un término nuevo del dominio. Argumentos opcionales describen el hallazgo.
---

# Recordar — Guardar hallazgo en memory base

Guarda hallazgos, reglas, bugs y procedimientos en `.claude/memory/` para que el equipo los herede vía git push.

## Reglas de oro

1. **Breve y conciso.** Máximo 40-60 líneas por archivo. Si es muy largo, parte en varios.
2. **NO documentar schema de tablas.** Eso lo da el MCP (`get_table_details`). Solo documenta lógica de negocio, quirks, y casos de uso.
3. **Usa nombres descriptivos en kebab-case.** Para incidentes, prefijo con fecha `YYYY-MM-DD-<slug>.md`.
4. **Siempre actualiza `INDEX.md`** al crear un archivo nuevo (agregar entrada en la sección correspondiente).
5. **Si ya existe un archivo del mismo tema**, haz APPEND en lugar de crear uno nuevo.

## Decisión de dónde guardar

Antes de escribir, decide la categoría con esta lógica:

| Tipo de hallazgo | Destino | Plantilla |
|------------------|---------|-----------|
| Regla del dominio que no se ve en el schema (ej: "campo X significa Y al inicio de semana") | `business-rules/<slug>.md` | Plantilla A |
| Diagnóstico de bug ya resuelto o falsa alarma documentada | `incidents/YYYY-MM-DD-<slug>.md` | Plantilla B |
| Cómo hacer algo recurrente (script, llamada SP, secuencia de queries) | `procedures/<slug>.md` | Plantilla C |
| Definición corta de un término | append a `glossary.md` | Una fila tabla |
| Convención general (formato de IDs, nombres) | `business-rules/formato-codigos.md` o nuevo en `business-rules/` | Plantilla A |

Si no estás seguro, pregunta al usuario; no inventes una categoría.

## Plantillas

### A. Regla de negocio (`business-rules/<slug>.md`)

```markdown
# <Título corto descriptivo>

⚠️ **Alerta breve**: <una línea con el "ojo" principal>.

## Regla
<2-4 líneas explicando QUÉ es y POR QUÉ existe>

## Cómo aplicarla / cuándo se activa
<bullet points o tabla>

## Caso de referencia
<si aplica, link a un incident o un ejemplo concreto>
```

### B. Incidente (`incidents/YYYY-MM-DD-<slug>.md`)

```markdown
# Incidente: <título>

**Fecha:** YYYY-MM-DD | **Estado:** resuelto / mitigado / pendiente | **Ticket/HU:** <id si aplica>

## Síntoma
<lo que el usuario reportó>

## Causa raíz
<diagnóstico técnico breve, archivos:líneas, query que lo prueba>

## Fix aplicado
<query/script o link a procedure>

## Lo que aprendimos
<la regla generalizable — esto es lo más valioso>
```

### C. Procedimiento (`procedures/<slug>.md`)

```markdown
# <Acción recurrente>

<1-2 líneas de cuándo aplicar>

## Pasos / Scripts

```sql
-- ...
```

## Validar
<query de verificación>

## Notas
<gotchas, links a business-rules relevantes>
```

## Flujo de ejecución

1. **Leer `INDEX.md`** para ver qué existe.
2. **Decidir categoría** según la tabla de arriba.
3. **Buscar archivo existente del mismo tema** (`ls .claude/memory/<categoria>/`). Si existe, APPEND; si no, crear nuevo.
4. **Escribir el archivo** con la plantilla correspondiente.
5. **Agregar entrada en `INDEX.md`** si es archivo nuevo, en la sección correcta, con descripción de una línea.
6. **Confirmar al usuario**: ruta del archivo, qué se guardó.

## Argumentos

Si `$ARGUMENTS` viene con texto, úsalo como descripción del hallazgo a guardar. Si está vacío, infiere del contexto reciente de la conversación (último diagnóstico, último bug discutido). Si no hay contexto suficiente, pregunta al usuario:
- "¿Qué hallazgo guardamos?"
- "¿Es regla de negocio, incidente, procedimiento o término?"

## Anti-patrones

- ❌ Documentar columnas de tablas (eso es schema, lo da el MCP).
- ❌ Archivos largos que mezclan varios temas.
- ❌ Olvidar actualizar `INDEX.md`.
- ❌ Inventar categorías nuevas sin avisar.
- ❌ Copiar código completo cuando un link basta.
