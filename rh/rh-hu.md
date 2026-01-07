# Historia de Usuario: Modulo RH - Gestion de Usuarios

## Descripcion
Sistema de gestion de usuarios con asignacion a gerencias y sucursales.

## Endpoints

### 1. Crear Usuario
**POST** `/api/rh/usuarios`

**Body:**
```json
{
  "nombre": "string",
  "apellido_paterno": "string",
  "apellido_materno": "string",
  "tipo": "enum", // Agente|Gerente|Seguridad|Regional|CallCenter|Administrativo|Jefe de Admin|Oficina|Sistemas|Direccion
  "numero_celular": "string", // max 12 chars
  "fecha_ingreso": "datetime",
  "sucursales": ["SUC001"], // OBLIGATORIO - array de sucursales (minimo 1)
  "puede_verificar_asignaciones": "boolean",
  "puede_cobrar": "boolean"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "pin": 123456, // Generado automaticamente
    "usuario": "EIZA01", // Auto-generado: Iniciales + contador
    "nombre_completo": "ELVIRA IZALDE SANCHEZ",
    "sucursales_asignadas": ["SUC001"]
  }
}
```

**Logica de Generacion de Usuario:**
1. Tomar primera letra del nombre: E (ELVIRA)
2. Tomar primeras dos letras del apellido paterno: IZ (IZALDE)
3. Tomar primera letra del apellido materno: A (SANCHEZ)
4. Generar: EIZA
5. Buscar cuantos usuarios existen con ese patron: EIZA01, EIZA02, etc
6. Asignar siguiente numero disponible con formato 2 digitos

**Ejemplos:**
- "JUAN PEREZ LOPEZ" -> JUPE01
- "MARIA GARCIA MARTINEZ" -> MAGA01
- "JOSE LUIS RODRIGUEZ SANCHEZ" -> JORO01 (primer nombre + primer apellido)

**Validaciones:**
- Pin unico (6 digitos, auto-generado)
- Usuario auto-generado (unico, max 12 chars)
- Tipo valido (enum)
- Minimo 1 sucursal requerida
- Todas las sucursales existen en BD
- Se crean registros en usuarios_sucursales automaticamente

---

### 2. Asignar Usuario a Gerencia (tabla usuarios_gerencias)
**POST** `/api/rh/usuarios/:usuarioId/gerencias`

**Body:**
```json
{
  "gerencias": ["GERD001", "GERD002", "GERD003"]
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "gerencias_asignadas": ["GERD001", "GERD002", "GERD003"],
    "total": 3
  }
}
```

**Logica:**
- Crea registros en tabla `usuarios_gerencias`
- Un usuario puede tener multiples gerencias
- Si ya existe la relacion, no la duplica

**Validaciones:**
- Usuario existe
- Todas las gerencias existen

---

### 3. Actualizar Gerencias de Usuario
**PUT** `/api/rh/usuarios/:usuarioId/gerencias`

**Body:**
```json
{
  "gerencias": ["GERD001", "GERD005"] // Reemplaza todas las existentes
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "gerencias_anteriores": ["GERD001", "GERD002", "GERD003"],
    "gerencias_nuevas": ["GERD001", "GERD005"],
    "eliminadas": 2,
    "agregadas": 1
  }
}
```

**Logica:**
- Elimina TODAS las gerencias actuales del usuario
- Inserta las nuevas gerencias recibidas

---

### 4. Listar Gerencias de Usuario
**GET** `/api/rh/usuarios/:usuarioId/gerencias`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "gerencias": [
      {
        "gerencia_id": "GERD001",
        "nombre": "Gerencia Durango 1"
      },
      {
        "gerencia_id": "GERD002",
        "nombre": "Gerencia Durango 2"
      }
    ]
  }
}
```

---

### 5. Eliminar Gerencia de Usuario
**DELETE** `/api/rh/usuarios/:usuarioId/gerencias/:gerenciaId`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "gerencia_id": "GERD001",
    "mensaje": "Gerencia eliminada del usuario"
  }
}
```

---

### 6. Asignar Encargado/Seguridad a Gerencia (tabla gerencias)
**POST** `/api/rh/gerencias/:gerenciaId/responsable`

**Body:**
```json
{
  "usuario_id": 123,
  "rol": "encargado" // encargado|seguridad
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "gerencia_id": "GERD001",
    "usuario_id": 123,
    "campo_actualizado": "usuario_a_cargo" // o "seguridad_id"
  }
}
```

**Validaciones:**
- Gerencia existe
- Usuario existe
- Si rol=encargado -> actualiza `usuario_a_cargo`
- Si rol=seguridad -> actualiza `seguridad_id`

---

### 7. Asignar Usuario a Sucursales (tabla usuarios_sucursales)
**POST** `/api/rh/usuarios/:usuarioId/sucursales`

**Body:**
```json
{
  "sucursales": ["SUC001", "SUC002"]
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "sucursales_asignadas": ["SUC001", "SUC002"],
    "total": 2
  }
}
```

**Logica:**
- Crea registros en tabla `usuarios_sucursales`
- Un usuario puede tener multiples sucursales
- Si ya existe la relacion, no la duplica

**Validaciones:**
- Usuario existe
- Todas las sucursales existen

---

### 8. Actualizar Sucursales de Usuario
**PUT** `/api/rh/usuarios/:usuarioId/sucursales`

**Body:**
```json
{
  "sucursales": ["SUC001", "SUC003"] // Reemplaza todas las existentes
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "sucursales_anteriores": ["SUC001", "SUC002"],
    "sucursales_nuevas": ["SUC001", "SUC003"],
    "eliminadas": 1,
    "agregadas": 1
  }
}
```

**Logica:**
- Elimina TODAS las sucursales actuales del usuario
- Inserta las nuevas sucursales recibidas

---

### 9. Listar Sucursales de Usuario
**GET** `/api/rh/usuarios/:usuarioId/sucursales`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "sucursales": [
      {
        "sucursal_id": "SUC001",
        "nombre": "Sucursal Durango"
      },
      {
        "sucursal_id": "SUC002",
        "nombre": "Sucursal Chihuahua"
      }
    ]
  }
}
```

---

### 10. Eliminar Sucursal de Usuario
**DELETE** `/api/rh/usuarios/:usuarioId/sucursales/:sucursalId`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "sucursal_id": "SUC001",
    "mensaje": "Sucursal eliminada del usuario"
  }
}
```

---

### 11. Asignar Regional a Sucursal (tabla sucursales)
**POST** `/api/rh/sucursales/:sucursalId/regional`

**Body:**
```json
{
  "usuario_id": 123
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "sucursal_id": "SUC001",
    "regional_id": 123
  }
}
```

**Validaciones:**
- Sucursal existe
- Usuario existe
- Usuario tipo Regional

---

### 12. Listar Usuarios
**GET** `/api/rh/usuarios?tipo=Agente&status=1&gerencia=GERD001`

**Response 200:**
```json
{
  "success": true,
  "count": 150,
  "data": [
    {
      "usuario_id": 1,
      "nombre_completo": "ELVIRA IZALDE SANCHEZ",
      "tipo": "Agente",
      "usuario": "AGD043",
      "pin": 4343,
      "status": 1,
      "gerencia": "GERD003",
      "agencia": "AGD043",
      "fecha_ingreso": "2020-09-16"
    }
  ]
}
```

**Query params:**
- `tipo` (opcional): Filtrar por tipo
- `status` (opcional): 0=inactivo, 1=activo, sin parametro=todos
- `gerencia` (opcional): Filtrar por gerencia

**Nota:** Si no se envia ningun parametro, retorna TODOS los usuarios (activos e inactivos)

---

### 13. Obtener Usuario
**GET** `/api/rh/usuarios/:id`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "nombre": "ELVIRA",
    "apellido_paterno": "IZALDE",
    "apellido_materno": "SANCHEZ",
    "tipo": "Agente",
    "pin": 4343,
    "usuario": "AGD043",
    "puede_verificar_asignaciones": false,
    "puede_cobrar": true,
    "status": 1,
    "gerencia": "GERD003",
    "agencia": "AGD043",
    "fecha_ingreso": "2020-09-16",
    "numero_celular": "2411144286",
    "created_at": "2023-02-22",
    "updated_at": "2023-10-01"
  }
}
```

---

### 14. Actualizar Usuario
**PATCH** `/api/rh/usuarios/:id`

**Body:**
```json
{
  "nombre": "string?",
  "apellido_paterno": "string?",
  "numero_celular": "string?",
  "status": "boolean?",
  "gerencia": "string?",
  "agencia": "string?",
  "puede_verificar_asignaciones": "boolean?",
  "puede_cobrar": "boolean?"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "campos_actualizados": ["numero_celular", "status"]
  }
}
```

**Restricciones:**
- NO se puede cambiar: `pin`, `usuario`, `tipo`
- Solo campos enviados se actualizan

---

### 15. Inactivar Usuario
**DELETE** `/api/rh/usuarios/:id`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "usuario_id": 123,
    "status": 0,
    "mensaje": "Usuario inactivado correctamente"
  }
}
```

**Logica:**
- No elimina el registro de la BD
- Actualiza `status = 0` (soft delete)
- Usuario inactivo no puede iniciar sesion ni realizar operaciones

---

## Arquitectura: Todo en un folder (Elysia + Drizzle)

```
src/modules/rh/
├── rh.routes.ts      // Todos los endpoints del modulo
├── rh.schemas.ts     // Schemas de validacion (Elysia t)
└── rh.service.ts     // Logica de negocio + Drizzle queries
```

**Responsabilidades:**
- `rh.routes.ts`: Define todos los endpoints (usuarios, gerencias, sucursales)
- `rh.schemas.ts`: Schemas de validacion con Elysia `t` (TypeBox)
- `rh.service.ts`: Logica de negocio + queries Drizzle ORM

**Ejemplo:**
```typescript
// rh.schemas.ts
import { t } from 'elysia'

export const crearUsuarioSchema = t.Object({
  nombre: t.String(),
  apellido_paterno: t.String(),
  apellido_materno: t.String(),
  tipo: t.Enum({ Agente: 'Agente', Gerente: 'Gerente', /* ... */ }),
  usuario: t.String({ maxLength: 12 }),
  numero_celular: t.String({ maxLength: 12 }),
  fecha_ingreso: t.String(),
  gerencia: t.Optional(t.String()),
  agencia: t.Optional(t.String()),
  puede_verificar_asignaciones: t.Boolean(),
  puede_cobrar: t.Boolean()
})

// rh.service.ts
import { db } from '../../db'
import { usuarios, gerencias } from '../../db/schema'
import { eq } from 'drizzle-orm'

export class RHService {
  async crearUsuario(data: any) {
    const pin = await this.generarPinUnico()
    const [usuario] = await db.insert(usuarios).values({
      ...data,
      pin,
      status: 1
    }).returning()
    return { success: true, data: usuario }
  }

  async generarPinUnico() {
    let pin: number
    let existe = true
    while (existe) {
      pin = Math.floor(100000 + Math.random() * 900000)
      const result = await db.select().from(usuarios).where(eq(usuarios.Pin, pin))
      existe = result.length > 0
    }
    return pin!
  }

  async listarUsuarios(filters: any) {
    // Query con Drizzle + filtros
  }
}

// rh.routes.ts
import { Elysia } from 'elysia'
import { RHService } from './rh.service'
import { crearUsuarioSchema } from './rh.schemas'

const rhService = new RHService()

export const rhRoutes = new Elysia({ prefix: '/api/rh' })
  // Usuarios
  .post('/usuarios', async ({ body }) => {
    return await rhService.crearUsuario(body)
  }, { body: crearUsuarioSchema })

  .get('/usuarios', async ({ query }) => {
    return await rhService.listarUsuarios(query)
  })

  .get('/usuarios/:id', async ({ params }) => {
    return await rhService.obtenerUsuario(params.id)
  })

  .patch('/usuarios/:id', async ({ params, body }) => {
    return await rhService.actualizarUsuario(params.id, body)
  })

  .delete('/usuarios/:id', async ({ params }) => {
    return await rhService.inactivarUsuario(params.id)
  })

  // Gerencias
  .post('/gerencias/:gerenciaId/usuario', async ({ params, body }) => {
    return await rhService.asignarUsuarioGerencia(params.gerenciaId, body)
  })

  // Sucursales
  .post('/sucursales/:sucursalId/regional', async ({ params, body }) => {
    return await rhService.asignarRegionalSucursal(params.sucursalId, body)
  })
```

---

## Logica de Negocio

### Generacion de Username
```typescript
// Generar username unico basado en iniciales
async function generarUsername(nombre: string, apellidoPaterno: string, apellidoMaterno: string) {
  // Limpiar y normalizar
  const cleanNombre = nombre.trim().toUpperCase()
  const cleanApPaterno = apellidoPaterno.trim().toUpperCase()
  const cleanApMaterno = apellidoMaterno.trim().toUpperCase()

  // Obtener iniciales: 1 letra nombre + 2 letras apellido paterno + 1 letra apellido materno
  const inicial = cleanNombre.charAt(0) +
                  cleanApPaterno.substring(0, 2) +
                  cleanApMaterno.charAt(0)

  // Buscar siguiente numero disponible
  const existentes = await db.select()
    .from(usuarios)
    .where(like(usuarios.Usuario, `${inicial}%`))
    .orderBy(usuarios.Usuario)

  let contador = 1
  let username = `${inicial}${contador.toString().padStart(2, '0')}`

  while (existentes.some(u => u.Usuario === username)) {
    contador++
    username = `${inicial}${contador.toString().padStart(2, '0')}`
  }

  return username
}
```

### Generacion de PIN
```typescript
// Generar PIN unico de 6 digitos
async function generarPinUnico() {
  let pin: number
  let existe = true

  while (existe) {
    pin = Math.floor(100000 + Math.random() * 900000) // 6 digitos
    const result = await db.select()
      .from(usuarios)
      .where(eq(usuarios.Pin, pin))
    existe = result.length > 0
  }

  return pin!
}
```

### Tipos de Usuario
```sql
enum('Agente','Gerente','Seguridad','Regional','CallCenter',
     'Administrativo','Oficina','Sistemas','Jefe de Admin','Direccion')
```

---

## Cambios en Base de Datos

**Ninguno requerido** - La estructura actual soporta todos los casos de uso.

---

## Criterios de Aceptacion

1. Se pueden crear usuarios con PIN unico autogenerado
2. Username se genera automaticamente con formato: Inicial+ApPaterno(2)+ApMaterno(1)+Numero(2)
3. Al crear usuario se asigna obligatoriamente a minimo 1 sucursal (usuarios_sucursales)
4. No se permiten PINs ni Usernames duplicados
5. Usuario puede tener multiples sucursales (usuarios_sucursales)
6. Se pueden actualizar las sucursales de un usuario (agregar/eliminar/reemplazar)
7. Se puede asignar usuario a multiples gerencias (usuarios_gerencias)
8. Se pueden actualizar las gerencias de un usuario (agregar/eliminar/reemplazar)
9. Se puede asignar encargado a gerencia (usuario_a_cargo en tabla gerencias)
10. Se puede asignar seguridad a gerencia (seguridad_id en tabla gerencias)
11. Se puede asignar regional a sucursal (regionalID en tabla sucursales)
12. No se puede modificar PIN ni Usuario una vez creado
13. Filtros funcionales: tipo, status, gerencia
14. Validacion de tipos de usuario segun enum
15. Se pueden listar TODOS los usuarios sin filtros
16. Se pueden inactivar usuarios (soft delete con status=0)
17. Usuarios inactivos no pueden operar en el sistema
18. Usuario siempre debe pertenecer a al menos 1 sucursal