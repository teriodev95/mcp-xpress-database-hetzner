# Buscador de Clientes - Especificación

## Endpoint

```
POST /run_query
```

## Query SQL

```sql
SELECT
    p.PrestamoID,
    p.Cliente_ID,
    CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS nombre_completo,
    pd.saldo,
    pd.cobrado,
    p.Total_a_pagar,
    p.Tarifa,
    p.Agente,
    p.Gerencia,
    p.Telefono_Cliente
FROM prestamos_v2 p
INNER JOIN prestamos_dynamic pd ON pd.prestamo_id = p.PrestamoID
WHERE CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) LIKE '%{busqueda}%'
LIMIT 20
```

---

## Reglas del Frontend

| Regla | Valor |
|-------|-------|
| Caracteres mínimos para buscar | 3 |
| Debounce | 300-500ms |
| Límite de resultados | 20 |
| Convertir a mayúsculas | Sí (la BD usa mayúsculas) |

---

## Campos de Respuesta

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `PrestamoID` | string | Identificador único del préstamo |
| `Cliente_ID` | string | Identificador del cliente |
| `nombre_completo` | string | Nombres + Apellido Paterno + Apellido Materno |
| `saldo` | decimal | Saldo actual pendiente |
| `cobrado` | decimal | Total cobrado al momento |
| `Total_a_pagar` | decimal | Monto total del préstamo |
| `Tarifa` | decimal | Pago semanal |
| `Agente` | string | Código del agente asignado |
| `Gerencia` | string | Código de gerencia |
| `Telefono_Cliente` | string | Teléfono de contacto |

---

## Validaciones

1. No ejecutar búsqueda si `texto.length < 3`
2. Sanitizar input (evitar inyección SQL)
3. Mostrar loader durante la búsqueda
4. Mostrar mensaje si no hay resultados
5. El texto de búsqueda debe convertirse a MAYÚSCULAS antes de enviar

---

## UX Sugerida

- Input con placeholder: "Buscar por nombre..."
- Mostrar resultados en lista/tabla
- Al seleccionar un resultado, copiar o navegar con el `PrestamoID`
- Mostrar saldo con formato moneda
- Indicador visual si `saldo = 0` (préstamo liquidado)
