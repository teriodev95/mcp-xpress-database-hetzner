/**
 * Cliente REST para Sistema de Tickets
 * Uso desde MCP-XPRESS para consultar y gestionar tickets
 */

const COUCHDB_URL = "https://couch.clvrt.cc/tickets"
const COUCHDB_USER = "admin"
const COUCHDB_PASS = "cGw9Km4ejuyqn9eca7J*"

// --- Tipos ---

type TicketStatus = "pendiente" | "en proceso" | "completado"
type TicketPriority = "alta" | "media" | "baja"

interface TicketMessage {
  id: string
  autor: string
  autorNombre: string
  autorTipo: "usuario" | "sistemas"
  texto: string
  adjuntos?: { id: string; name: string; size: number; type: string; url?: string }[]
  createdAt: string
}

interface TicketSummary {
  id: number
  usuario: string
  pin: number
  nombre: string
  descripcion: string
  status: TicketStatus
  prioridad: TicketPriority
  tipo: string
  agencia: string
  gerencia: string
  createdAt: string
  updatedAt: string
  attachmentCount: number
  imageCount: number
}

interface Ticket extends TicketSummary {
  _id: string
  _rev: string
  mensajes?: TicketMessage[]
  attachments?: { id: string; name: string; size: number; type: string; url?: string }[]
  supportEvidence?: { id: string; name: string; size: number; type: string; url?: string }[]
  comentarioSoporte?: string | null
}

// --- Cliente ---

class TicketsClient {
  private auth: string

  constructor() {
    this.auth = btoa(`${COUCHDB_USER}:${COUCHDB_PASS}`)
  }

  private async request<T>(path: string, options?: RequestInit): Promise<T> {
    const res = await fetch(`${COUCHDB_URL}${path}`, {
      ...options,
      headers: {
        Authorization: `Basic ${this.auth}`,
        "Content-Type": "application/json",
        ...options?.headers,
      },
    })

    if (!res.ok) {
      const error = new Error(`HTTP ${res.status}: ${res.statusText}`) as Error & { status: number }
      error.status = res.status
      throw error
    }

    return res.json()
  }

  // --- Consultas ---

  /** Obtener todos los tickets (vista optimizada, sin base64) */
  async getAll(): Promise<TicketSummary[]> {
    const data = await this.request<{ rows: { value: TicketSummary }[] }>(
      "/_design/tickets/_view/summary"
    )
    return data.rows.map((row) => row.value)
  }

  /** Obtener tickets por PIN de usuario */
  async getByPin(pin: number): Promise<TicketSummary[]> {
    const data = await this.request<{ rows: { value: TicketSummary }[] }>(
      `/_design/tickets/_view/by_pin?key=${pin}`
    )
    return data.rows.map((row) => row.value)
  }

  /** Obtener ticket completo con mensajes */
  async getById(id: number): Promise<Ticket> {
    return this.request<Ticket>(`/ticket_${id}`)
  }

  /** Obtener solo los mensajes de un ticket */
  async getMessages(id: number): Promise<TicketMessage[]> {
    const ticket = await this.getById(id)
    return ticket.mensajes || []
  }

  // --- Operaciones con reintentos ---

  private async updateWithRetry<T>(
    ticketId: number,
    updateFn: (doc: Ticket) => Ticket,
    maxRetries = 3
  ): Promise<T> {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const doc = await this.getById(ticketId)
        const updated = updateFn(doc)

        return await this.request<T>(`/ticket_${ticketId}`, {
          method: "PUT",
          body: JSON.stringify(updated),
        })
      } catch (err) {
        const error = err as Error & { status?: number }
        if (error.status === 409 && attempt < maxRetries - 1) {
          await new Promise((r) => setTimeout(r, 100 * (attempt + 1)))
          continue
        }
        throw err
      }
    }
    throw new Error("Max retries exceeded")
  }

  // --- Cambio de Status ---

  /** Cambiar el status de un ticket */
  async changeStatus(ticketId: number, status: TicketStatus): Promise<void> {
    await this.updateWithRetry(ticketId, (doc) => ({
      ...doc,
      status,
      updatedAt: new Date().toISOString(),
    }))
  }

  /** Marcar ticket como pendiente */
  async markPending(ticketId: number): Promise<void> {
    return this.changeStatus(ticketId, "pendiente")
  }

  /** Marcar ticket como en proceso */
  async markInProgress(ticketId: number): Promise<void> {
    return this.changeStatus(ticketId, "en proceso")
  }

  /** Marcar ticket como completado */
  async markCompleted(ticketId: number): Promise<void> {
    return this.changeStatus(ticketId, "completado")
  }

  // --- Mensajes ---

  /** Generar ID único para mensaje */
  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
  }

  /** Enviar mensaje a un ticket */
  async sendMessage(
    ticketId: number,
    texto: string,
    options?: {
      autor?: string
      autorNombre?: string
      autorTipo?: "usuario" | "sistemas"
    }
  ): Promise<TicketMessage> {
    const newMessage: TicketMessage = {
      id: this.generateMessageId(),
      autor: options?.autor || "mcp-xpress",
      autorNombre: options?.autorNombre || "MCP Xpress",
      autorTipo: options?.autorTipo || "sistemas",
      texto,
      adjuntos: [],
      createdAt: new Date().toISOString(),
    }

    await this.updateWithRetry(ticketId, (doc) => ({
      ...doc,
      mensajes: [...(doc.mensajes || []), newMessage],
      updatedAt: new Date().toISOString(),
    }))

    return newMessage
  }

  /** Enviar mensaje como sistema/soporte */
  async sendSystemMessage(ticketId: number, texto: string): Promise<TicketMessage> {
    return this.sendMessage(ticketId, texto, {
      autor: "sistemas",
      autorNombre: "Equipo de Sistemas",
      autorTipo: "sistemas",
    })
  }
}

// --- Instancia singleton ---

export const ticketsClient = new TicketsClient()

// --- Ejemplos de uso ---

/*
// Consultar todos los tickets
const tickets = await ticketsClient.getAll()
console.log(`Total tickets: ${tickets.length}`)

// Filtrar por status
const pendientes = tickets.filter(t => t.status === "pendiente")

// Obtener ticket con mensajes
const ticket = await ticketsClient.getById(1704067200123)
console.log(`Mensajes: ${ticket.mensajes?.length || 0}`)

// Cambiar status
await ticketsClient.markInProgress(1704067200123)

// Enviar mensaje
await ticketsClient.sendMessage(1704067200123, "Estamos revisando tu problema")

// O como mensaje del sistema
await ticketsClient.sendSystemMessage(1704067200123, "Ticket resuelto")
*/
