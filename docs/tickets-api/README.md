# API REST - Sistema de Tickets

Documentación para integrar MCP-XPRESS con el sistema de tickets.

## Conexión CouchDB

```
URL Base: https://couch.clvrt.cc/tickets
Usuario: admin
Password: cGw9Km4ejuyqn9eca7J*
```

### Header de Autenticación

```
Authorization: Basic YWRtaW46Y0d3OUttNGVqdXlxbjllY2E3Sio=
```

En código:
```typescript
const auth = btoa("admin:cGw9Km4ejuyqn9eca7J*")
const headers = { Authorization: `Basic ${auth}` }
```

---

## Endpoints Principales

### 1. Consultar Todos los Tickets (Vista Optimizada)

```http
GET https://couch.clvrt.cc/tickets/_design/tickets/_view/summary
```

Retorna tickets sin base64 de imágenes (ligero).

**Respuesta:**
```json
{
  "rows": [
    {
      "id": "ticket_1704067200123",
      "value": {
        "id": 1704067200123,
        "usuario": "juan.perez",
        "pin": 12345,
        "nombre": "Problema con sistema",
        "status": "pendiente",
        "prioridad": "alta",
        "tipo": "soporte",
        "descripcion": "...",
        "agencia": "Matriz",
        "gerencia": "TI",
        "createdAt": "2024-06-19T15:30:00.000Z",
        "updatedAt": "2024-06-19T15:30:00.000Z",
        "attachmentCount": 2,
        "imageCount": 1
      }
    }
  ]
}
```

### 2. Consultar Tickets por PIN de Usuario

```http
GET https://couch.clvrt.cc/tickets/_design/tickets/_view/by_pin?key=12345
```

Retorna solo los tickets del usuario con ese PIN.

### 3. Obtener Ticket Completo (con mensajes)

```http
GET https://couch.clvrt.cc/tickets/ticket_{id}
```

**Ejemplo:**
```http
GET https://couch.clvrt.cc/tickets/ticket_1704067200123
```

**Respuesta:**
```json
{
  "_id": "ticket_1704067200123",
  "_rev": "5-abc123...",
  "id": 1704067200123,
  "usuario": "juan.perez",
  "pin": 12345,
  "nombre": "Problema con sistema",
  "status": "en proceso",
  "prioridad": "alta",
  "tipo": "soporte",
  "descripcion": "El sistema no permite facturar...",
  "agencia": "Matriz",
  "gerencia": "TI",
  "mensajes": [
    {
      "id": "msg_1704067300000_abc",
      "autor": "juan.perez",
      "autorNombre": "Juan Pérez",
      "autorTipo": "usuario",
      "texto": "Adjunto captura del error",
      "adjuntos": [],
      "createdAt": "2024-06-19T15:35:00.000Z"
    },
    {
      "id": "msg_1704067400000_def",
      "autor": "sistemas",
      "autorNombre": "Equipo de Sistemas",
      "autorTipo": "sistemas",
      "texto": "Ya estamos revisando",
      "adjuntos": [],
      "createdAt": "2024-06-19T15:40:00.000Z"
    }
  ],
  "attachments": [...],
  "supportEvidence": [...],
  "createdAt": "2024-06-19T15:30:00.000Z",
  "updatedAt": "2024-06-19T15:40:00.000Z"
}
```

---

## Operaciones de Escritura

### 4. Cambiar Status de Ticket

**Flujo:**
1. Obtener documento actual (para tener `_rev`)
2. Hacer PUT con el nuevo status

```http
# Paso 1: Obtener documento actual
GET https://couch.clvrt.cc/tickets/ticket_1704067200123

# Paso 2: Actualizar con nuevo status
PUT https://couch.clvrt.cc/tickets/ticket_1704067200123
Content-Type: application/json

{
  "_id": "ticket_1704067200123",
  "_rev": "5-abc123...",
  ... (todos los campos existentes),
  "status": "completado",
  "updatedAt": "2024-06-19T16:00:00.000Z"
}
```

**Status válidos:**
- `"pendiente"`
- `"en proceso"`
- `"completado"`

### 5. Agregar Mensaje al Chat

**Flujo:**
1. Obtener documento actual
2. Agregar mensaje al array `mensajes`
3. Hacer PUT

```http
# Paso 1: Obtener documento
GET https://couch.clvrt.cc/tickets/ticket_1704067200123

# Paso 2: PUT con nuevo mensaje
PUT https://couch.clvrt.cc/tickets/ticket_1704067200123
Content-Type: application/json

{
  "_id": "ticket_1704067200123",
  "_rev": "5-abc123...",
  ... (todos los campos existentes),
  "mensajes": [
    ... (mensajes existentes),
    {
      "id": "msg_1704068000000_xyz",
      "autor": "mcp-xpress",
      "autorNombre": "MCP Xpress",
      "autorTipo": "sistemas",
      "texto": "Mensaje desde MCP",
      "adjuntos": [],
      "createdAt": "2024-06-19T16:10:00.000Z"
    }
  ],
  "updatedAt": "2024-06-19T16:10:00.000Z"
}
```

**Generar ID de mensaje:**
```typescript
const msgId = `msg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
```

---

## Manejo de Conflictos (409)

CouchDB usa versionado optimista. Si otro proceso modificó el documento:
- Respuesta: `409 Conflict`
- Solución: Volver a obtener el documento (nuevo `_rev`) y reintentar

```typescript
async function updateWithRetry(ticketId, updateFn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const doc = await fetch(`${BASE_URL}/ticket_${ticketId}`, { headers }).then(r => r.json())
      const updated = updateFn(doc)

      await fetch(`${BASE_URL}/ticket_${ticketId}`, {
        method: 'PUT',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify(updated)
      })
      return // Éxito
    } catch (err) {
      if (err.status === 409 && i < maxRetries - 1) {
        await new Promise(r => setTimeout(r, 100 * (i + 1)))
        continue
      }
      throw err
    }
  }
}
```

---

## Tipos de Datos

### TicketStatus
```typescript
type TicketStatus = "pendiente" | "en proceso" | "completado"
```

### TicketPriority
```typescript
type TicketPriority = "alta" | "media" | "baja"
```

### TicketMessage
```typescript
interface TicketMessage {
  id: string              // "msg_timestamp_random"
  autor: string           // ID del autor
  autorNombre: string     // Nombre para mostrar
  autorTipo: "usuario" | "sistemas"
  texto: string
  adjuntos?: FileAttachment[]
  createdAt: string       // ISO 8601
}
```

### Ticket (simplificado)
```typescript
interface Ticket {
  id: number
  _id: string             // "ticket_{id}"
  _rev: string            // Versión CouchDB
  usuario: string
  pin: number
  nombre: string          // Título del ticket
  descripcion: string
  status: TicketStatus
  prioridad: TicketPriority
  tipo: string            // "soporte" | "acceso" | "actualización"
  agencia: string
  gerencia: string
  mensajes?: TicketMessage[]
  attachments?: FileAttachment[]
  createdAt: string
  updatedAt: string
}
```

---

## Ejemplos en TypeScript

### Configuración Base

```typescript
const COUCHDB_URL = "https://couch.clvrt.cc/tickets"
const AUTH = btoa("admin:cGw9Km4ejuyqn9eca7J*")

const headers = {
  Authorization: `Basic ${AUTH}`,
  "Content-Type": "application/json"
}

async function request(path: string, options?: RequestInit) {
  const res = await fetch(`${COUCHDB_URL}${path}`, { headers, ...options })
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return res.json()
}
```

### Consultar Tickets

```typescript
// Todos los tickets (vista optimizada)
async function getAllTickets() {
  const data = await request("/_design/tickets/_view/summary")
  return data.rows.map(row => row.value)
}

// Tickets por PIN
async function getTicketsByPin(pin: number) {
  const data = await request(`/_design/tickets/_view/by_pin?key=${pin}`)
  return data.rows.map(row => row.value)
}

// Ticket completo con mensajes
async function getTicket(id: number) {
  return request(`/ticket_${id}`)
}
```

### Cambiar Status

```typescript
async function changeStatus(ticketId: number, newStatus: string) {
  const doc = await request(`/ticket_${ticketId}`)

  await request(`/ticket_${ticketId}`, {
    method: "PUT",
    body: JSON.stringify({
      ...doc,
      status: newStatus,
      updatedAt: new Date().toISOString()
    })
  })
}

// Uso
await changeStatus(1704067200123, "completado")
```

### Enviar Mensaje

```typescript
async function sendMessage(ticketId: number, texto: string, autor = "mcp-xpress") {
  const doc = await request(`/ticket_${ticketId}`)

  const newMessage = {
    id: `msg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    autor,
    autorNombre: "MCP Xpress",
    autorTipo: "sistemas",
    texto,
    adjuntos: [],
    createdAt: new Date().toISOString()
  }

  await request(`/ticket_${ticketId}`, {
    method: "PUT",
    body: JSON.stringify({
      ...doc,
      mensajes: [...(doc.mensajes || []), newMessage],
      updatedAt: new Date().toISOString()
    })
  })

  return newMessage
}

// Uso
await sendMessage(1704067200123, "Problema resuelto, puedes verificar?")
```

---

## Notas Importantes

1. **Siempre incluir `_rev`** al hacer PUT (viene del GET previo)
2. **Manejar 409** con reintentos (máximo 3)
3. **Usar vistas** para listados (evita transferir base64)
4. **autorTipo: "sistemas"** para mensajes del sistema
5. **Generar IDs únicos** para mensajes (`msg_timestamp_random`)
