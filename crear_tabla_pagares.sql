-- =====================================================
-- VISTA: vw_pagare_impresion (OPTIMIZADA)
-- Usa LEFT JOIN en lugar de UNION ALL para mejor rendimiento
-- =====================================================

DROP VIEW IF EXISTS vw_pagare_impresion;

CREATE VIEW vw_pagare_impresion AS
SELECT
    pag.id_sistemas,
    COALESCE(p.Folio_de_pagare, pc.Folio_de_pagare) AS folio,
    pag.prestamo_id,
    DATE_FORMAT(pag.fecha_entrega_credito, '%d/%m/%y') AS fecha_entrega_credito,
    DATE_FORMAT(pag.fecha_entrega_pagare, '%d/%m/%y') AS fecha_entrega_pagare,
    TIME_FORMAT(pag.fecha_entrega_pagare, '%H:%i') AS hora_entrega_pagare,
    COALESCE(p.SucursalID, pc.SucursalID) AS sucursal,
    COALESCE(p.Agente, pc.Agente) AS agencia,
    asa.Agente AS nombre_agente,
    COALESCE(p.Gerencia, pc.Gerencia) AS gerencia,
    pag.lugar_entrega,
    COALESCE(p.Monto_otorgado, pc.Monto_otorgado) AS monto_prestamo,
    COALESCE(p.Cargo, pc.Cargo) AS cargo,
    COALESCE(p.Total_a_pagar, pc.Total_a_paAGP026gar) AS total_a_pagar,
    COALESCE(p.Primer_pago, pc.Primer_pago) AS primer_pago,
    COALESCE(p.Tarifa, pc.Tarifa) AS pago_semanal,
    CONCAT(COALESCE(p.plazo, pc.plazo), ' SEM') AS plazo,
    CASE UCASE(COALESCE(p.Tipo_de_credito, pc.Tipo_de_credito))
        WHEN 'NUEVO' THEN 'NUEVO'
        WHEN 'RENOVACION' THEN 'RENOVACIÓN'
        ELSE COALESCE(p.Tipo_de_credito, pc.Tipo_de_credito)
    END AS tipo_credito,
    COALESCE(p.Dia_de_pago, pc.Dia_de_pago) AS dia_de_pago,
    COALESCE(p.Semana, pc.Semana) AS semana_inicio,
    COALESCE(p.Anio, pc.Anio) AS anio_inicio,
    COALESCE(
        CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', p.Apellido_Materno),
        CONCAT(per_cli.nombres, ' ', per_cli.apellido_paterno, ' ', per_cli.apellido_materno)
    ) AS cliente_nombre,
    COALESCE(
        CONCAT(p.Direccion, ' ', p.NoExterior, ', ', p.Colonia, ', C.P. ', p.Codigo_postal),
        CONCAT(per_cli.calle, ' ', per_cli.no_exterior, ', ', per_cli.colonia, ', C.P. ', per_cli.codigo_postal)
    ) AS cliente_domicilio,
    COALESCE(p.Telefono_Cliente, per_cli.telefono) AS cliente_telefono,
    COALESCE(
        CONCAT(p.Nombres_Aval, ' ', p.Apellido_Paterno_Aval, ' ', p.Apellido_Materno_Aval),
        CONCAT(per_aval.nombres, ' ', per_aval.apellido_paterno, ' ', per_aval.apellido_materno)
    ) AS aval_nombre,
    COALESCE(
        CONCAT(p.Direccion_Aval, ' ', p.No_Exterior_Aval, ', ', p.Colonia_Aval, ', C.P. ', p.Codigo_Postal_Aval),
        CONCAT(per_aval.calle, ' ', per_aval.no_exterior, ', ', per_aval.colonia, ', C.P. ', per_aval.codigo_postal)
    ) AS aval_domicilio,
    COALESCE(p.Telefono_Aval, per_aval.telefono) AS aval_telefono,
    pag.nombre_quien_recibio,
    pag.parentesco_quien_recibio,
    pag.entregado_cliente_at,
    pag.entregado_cliente_by,
    pag.recibido_oficina_at,
    pag.recibido_oficina_by,
    pag.entregado,
    pag.semaforo,
    pag.marca_folio,
    pag.observaciones,
    pag.created_at,
    pag.created_by
FROM pagares pag
LEFT JOIN prestamos_v2 p ON pag.prestamo_id = p.PrestamoID
LEFT JOIN prestamos_completados pc ON pag.prestamo_id = pc.PrestamoID AND p.PrestamoID IS NULL
LEFT JOIN personas per_cli ON pc.cliente_persona_id = per_cli.id
LEFT JOIN personas per_aval ON pc.aval_persona_id = per_aval.id
LEFT JOIN agencias_status_auxilar asa ON COALESCE(p.Agente, pc.Agente) = asa.Agencia;
