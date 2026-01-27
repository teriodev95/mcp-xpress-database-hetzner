# Referencia Rápida - API Tickets

## Autenticación

```
Base URL: https://couch.clvrt.cc/tickets
Auth Header: Authorization: Basic YWRtaW46Y0d3OUttNGVqdXlxbjllY2E3Sio=
```

---

## Consultas (GET)

| Acción | Endpoint |
|--------|----------|
| Todos los tickets | `/_design/tickets/_view/summary` |
| Tickets por PIN | `/_design/tickets/_view/by_pin?key={pin}` |
| Ticket completo | `/ticket_{id}` |

---

## Cambiar Status

```bash
# 1. Obtener doc actual
curl -X GET "https://couch.clvrt.cc/tickets/ticket_123" \
  -H "Authorization: Basic YWRtaW46Y0d3OUttNGVqdXlxbjllY2E3Sio="

# 2. PUT con nuevo status (incluir _rev del paso 1)
curl -X PUT "https://couch.clvrt.cc/tickets/ticket_123" \
  -H "Authorization: Basic YWRtaW46Y0d3OUttNGVqdXlxbjllY2E3Sio=" \
  -H "Content-Type: application/json" \
  -d '{
    "_id": "ticket_123",
    "_rev": "5-abc...",
    "status": "completado",
    "updatedAt": "2024-06-19T16:00:00.000Z",
    ... resto de campos ...
  }'
```

**Status válidos:** `pendiente` | `en proceso` | `completado`

---

## Agregar Mensaje

```bash
# Mismo flujo: GET -> modificar mensajes[] -> PUT
```

**Estructura mensaje:**
```json
{
  "id": "msg_1704068000000_xyz",
  "autor": "mcp-xpress",
  "autorNombre": "MCP Xpress",
  "autorTipo": "sistemas",
  "texto": "Tu mensaje aquí",
  "adjuntos": [],
  "createdAt": "2024-06-19T16:10:00.000Z"
}
```

---

## Errores Comunes

| Código | Causa | Solución |
|--------|-------|----------|
| 401 | Auth inválida | Verificar header Authorization |
| 404 | Ticket no existe | Verificar ID |
| 409 | Conflicto de versión | Obtener doc nuevo y reintentar |

---

## Cliente TypeScript

Ver `tickets-client.ts` para módulo listo para usar:

```typescript
import { ticketsClient } from './tickets-client'

// Consultar
const tickets = await ticketsClient.getAll()
const ticket = await ticketsClient.getById(123)

// Cambiar status
await ticketsClient.markCompleted(123)

// Enviar mensaje
await ticketsClient.sendMessage(123, "Mensaje de prueba")
```
