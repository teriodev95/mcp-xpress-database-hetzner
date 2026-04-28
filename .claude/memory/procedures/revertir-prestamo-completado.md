# Revertir préstamo completado a activo

Aplica cuando un préstamo se migró por error a `prestamos_completados` (ej: pago duplicado eliminado, ajuste post-cierre) y hay que regresarlo a `prestamos_v2`.

## Variables

| Variable | Significado |
|----------|-------------|
| `@PRESTAMO_ID` | ID del préstamo a revertir |
| `@SALDO_CORRECTO` | Saldo real pendiente |
| `@COBRADO_CORRECTO` | Total cobrado real = `Total_a_pagar - @SALDO_CORRECTO` |

## Pasos

```sql
-- 1. Insertar de vuelta en prestamos_v2 (toma persona/aval desde tabla `personas`)
INSERT INTO prestamos_v2 (
    PrestamoID, Cliente_ID, Nombres, Apellido_Paterno, Apellido_Materno,
    Direccion, NoExterior, NoInterior, Colonia, Codigo_postal, Municipio, Estado,
    No_De_Contrato, Agente, Gerencia, SucursalID, Semana, Anio, plazo,
    Monto_otorgado, Cargo, Total_a_pagar, Primer_pago, Tarifa,
    Saldos_Migrados, wk_descu, Descuento, Porcentaje, Multas, wk_refi, Refin, Externo,
    Saldo, Cobrado, Tipo_de_credito, Aclaracion,
    Nombres_Aval, Apellido_Paterno_Aval, Apellido_Materno_Aval,
    Direccion_Aval, No_Exterior_Aval, No_Interior_Aval, Colonia_Aval,
    Codigo_Postal_Aval, Poblacion_Aval, Estado_Aval, Telefono_Aval, NoServicio_Aval,
    Telefono_Cliente, Dia_de_pago, Gerente_en_turno, Agente2, Status, Capturista,
    NoServicio, Tipo_de_Cliente, Identificador_Credito, Seguridad, Depuracion,
    Folio_de_pagare, excel_index, cliente_xpress_id, cliente_persona_id, aval_persona_id,
    impacta_en_comision
)
SELECT 
    pc.PrestamoID, pc.Cliente_ID, p.nombres, p.apellido_paterno, p.apellido_materno,
    p.calle, p.no_exterior, p.no_interior, p.colonia, p.codigo_postal, p.municipio, p.estado,
    pc.No_De_Contrato, pc.Agente, pc.Gerencia, pc.SucursalID, pc.Semana, pc.Anio, pc.plazo,
    pc.Monto_otorgado, pc.Cargo, pc.Total_a_pagar, pc.Primer_pago, pc.Tarifa,
    pc.Saldos_Migrados, pc.wk_descu, pc.Descuento, pc.Porcentaje, pc.Multas, pc.wk_refi, pc.Refin, pc.Externo,
    @SALDO_CORRECTO, @COBRADO_CORRECTO,
    pc.Tipo_de_credito, pc.Aclaracion,
    COALESCE(a.nombres, ''), COALESCE(a.apellido_paterno, ''), COALESCE(a.apellido_materno, ''),
    COALESCE(a.calle, ''), a.no_exterior, a.no_interior, a.colonia,
    a.codigo_postal, COALESCE(a.municipio, ''), COALESCE(a.estado, ''), a.telefono, NULL,
    p.telefono, pc.Dia_de_pago, pc.Gerente_en_turno, pc.Agente2, pc.Status, pc.Capturista,
    pc.NoServicio, pc.Tipo_de_Cliente, pc.Identificador_Credito, pc.Seguridad, pc.Depuracion,
    pc.Folio_de_pagare, pc.excel_index, pc.cliente_xpress_id, pc.cliente_persona_id, pc.aval_persona_id,
    pc.impacta_en_comision
FROM prestamos_completados pc
LEFT JOIN personas p ON pc.cliente_persona_id = p.id
LEFT JOIN personas a ON pc.aval_persona_id = a.id
WHERE pc.PrestamoID = '@PRESTAMO_ID';

-- 2. Sincronizar prestamos_dynamic
INSERT INTO prestamos_dynamic (prestamo_id, saldo, cobrado)
VALUES ('@PRESTAMO_ID', @SALDO_CORRECTO, @COBRADO_CORRECTO)
ON DUPLICATE KEY UPDATE saldo = @SALDO_CORRECTO, cobrado = @COBRADO_CORRECTO;

-- 3. Eliminar de completados
DELETE FROM prestamos_completados WHERE PrestamoID = '@PRESTAMO_ID';

-- 4. Si hay desfase, corregir cadena abre_con/cierra_con en pagos_dynamic
-- Ver procedures/sincronizar-pagos-dynamic.md
```

## Validar

```sql
SELECT 'v2' AS src, PrestamoID, Saldo, Cobrado, Status FROM prestamos_v2 WHERE PrestamoID = '@PRESTAMO_ID'
UNION ALL
SELECT 'dyn', prestamo_id, saldo, cobrado, NULL FROM prestamos_dynamic WHERE prestamo_id = '@PRESTAMO_ID'
UNION ALL
SELECT 'completed', PrestamoID, Saldo, Cobrado, NULL FROM prestamos_completados WHERE PrestamoID = '@PRESTAMO_ID';
```

Esperado: 1 fila en v2, 1 en dyn, 0 en completed.
