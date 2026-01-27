-- =====================================================
-- TABLA: pagares (SOLO para prestamos_completados)

en cuanto termines asegurate planea la siguiente estructura de endpoints
para cumplir con este objetivo desde frontend
para crear un pagare debemos poder buscar por una persona y gerencia
se puede consultar mientras se teclea para hacerlo despues de unos segundos que termine el usuari
luego mostrar la informacion de la persona y sus prestamos
completados, mostrar si alguno ya cuenta con su pagare, 
luego para los que aun no tengan pagare mostrar la opcion de crear pagare
crea o modifica los endpoints necesarios para cumplir con este objetivo
dejeame las indicaciones necesarias en un .md para que front lo pueda implemntar



-- =====================================================

DROP TABLE IF EXISTS pagares;

CREATE TABLE pagares (
    id INT(11) NOT NULL AUTO_INCREMENT,
    id_sistemas VARCHAR(32) NOT NULL,
    prestamo_id VARCHAR(32) NOT NULL,
    gerencia VARCHAR(16) NOT NULL COMMENT 'Para filtrado rápido por gerencia',
    lugar_entrega VARCHAR(128) NULL,
    observaciones TEXT NULL,
    entregado TINYINT(1) NOT NULL DEFAULT 0,
    fecha_entrega_pagare DATE NULL,
    nombre_quien_recibio VARCHAR(128) NULL,
    parentesco_quien_recibio VARCHAR(64) NULL,
    semaforo ENUM(
        'ENTREGADO',
        'RETORNADO_NO_ENCONTRADO',
        'LIQ_ESPECIAL',
        'PERDIDO',
        'ARCHIVO',
        'JURIDICO',
        'DEMANDA',
        'EXPEDIENTE',
        'FINADO'
    ) NULL,
    marca_folio ENUM(
        'HOMONIMOS',
        'ACTUALIZA_INE',
        'BUEN_HISTORIAL',
        'MOROSO',
        'MOROSO_EXPEDIENTE',
        'CREDITO_AGENTE',
        'ACLARACION'
    ) NULL,
    entregado_cliente_at DATETIME NULL,
    entregado_cliente_by VARCHAR(64) NULL,
    recibido_oficina_at DATETIME NULL,
    recibido_oficina_by VARCHAR(64) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(64) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_id_sistemas (id_sistemas),
    UNIQUE KEY uk_prestamo_id (prestamo_id),
    INDEX idx_gerencia (gerencia),
    INDEX idx_entregado (entregado),
    INDEX idx_semaforo (semaforo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- FUNCIÓN: fn_generar_id_sistemas_pagare
-- Genera ID único: {SEMANA}-{AÑO}-{CONSECUTIVO}-{SUCURSAL}
-- Ejemplo: 01-26-0001-ca
-- =====================================================

DROP FUNCTION IF EXISTS fn_generar_folio_pagare;
DROP FUNCTION IF EXISTS fn_generar_id_sistemas_pagare;

DELIMITER //
CREATE FUNCTION fn_generar_id_sistemas_pagare(
    p_sucursal VARCHAR(16)
) RETURNS VARCHAR(32)
NOT DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_semana INT;
    DECLARE v_anio INT;
    DECLARE v_anio_corto INT;
    DECLARE v_sucursal_code VARCHAR(2);
    DECLARE v_prefijo VARCHAR(16);
    DECLARE v_consecutivo INT;
    DECLARE v_id_sistemas VARCHAR(32);

    SELECT semana, anio INTO v_semana, v_anio
    FROM calendario
    WHERE DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')) BETWEEN desde AND hasta
    LIMIT 1;

    IF v_semana IS NULL THEN
        SELECT semana, anio INTO v_semana, v_anio
        FROM calendario
        WHERE hasta <= DATE(CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City'))
        ORDER BY anio DESC, semana DESC
        LIMIT 1;
    END IF;

    SET v_anio_corto = v_anio MOD 100;

    SET v_sucursal_code = CASE LOWER(p_sucursal)
        WHEN 'dinero' THEN 'di'
        WHEN 'efectivo' THEN 'ef'
        WHEN 'moneda' THEN 'mo'
        WHEN 'capital' THEN 'ca'
        WHEN 'plata' THEN 'pl'
        WHEN 'dec' THEN 'dc'
        WHEN 'puebla' THEN 'pu'
        ELSE LOWER(LEFT(p_sucursal, 2))
    END;

    SET v_prefijo = CONCAT(LPAD(v_semana, 2, '0'), '-', v_anio_corto, '-');

    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(id_sistemas, '-', 3), '-', -1) AS UNSIGNED)), 0) + 1
    INTO v_consecutivo
    FROM pagares
    WHERE id_sistemas LIKE CONCAT(v_prefijo, '%');

    SET v_id_sistemas = CONCAT(v_prefijo, LPAD(v_consecutivo, 4, '0'), '-', v_sucursal_code);

    RETURN v_id_sistemas;
END //
DELIMITER ;


-- =====================================================
-- PROCEDIMIENTO: sp_crear_pagares_por_semana
-- Crea pagarés para TODOS los préstamos completados en una semana/año
-- Uso: CALL sp_crear_pagares_por_semana(1, 2026, 'sistema', @total);
-- =====================================================

DROP PROCEDURE IF EXISTS sp_crear_pagares_por_semana;

DELIMITER //
CREATE PROCEDURE sp_crear_pagares_por_semana(
    IN p_semana INT,
    IN p_anio INT,
    IN p_usuario VARCHAR(64),
    OUT p_total_creados INT
)
BEGIN
    DECLARE v_prestamo_id VARCHAR(32);
    DECLARE v_sucursal VARCHAR(16);
    DECLARE v_gerencia_id VARCHAR(16);
    DECLARE v_id_sistemas VARCHAR(32);
    DECLARE v_done INT DEFAULT FALSE;

    DECLARE cur_prestamos CURSOR FOR
        SELECT
            pc.PrestamoID,
            pc.SucursalID,
            a.GerenciaID
        FROM prestamos_completados pc
        INNER JOIN pagos_dynamic pd ON pc.PrestamoID = pd.prestamo_id
        INNER JOIN agencias a ON pc.Agente = a.AgenciaID
        WHERE pd.cierra_con <= 0
          AND pd.semana = p_semana
          AND pd.anio = p_anio
          AND NOT EXISTS (SELECT 1 FROM pagares pag WHERE pag.prestamo_id = pc.PrestamoID);

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    SET p_total_creados = 0;

    OPEN cur_prestamos;

    read_loop: LOOP
        FETCH cur_prestamos INTO v_prestamo_id, v_sucursal, v_gerencia_id;

        IF v_done THEN
            LEAVE read_loop;
        END IF;

        SET v_id_sistemas = fn_generar_id_sistemas_pagare(v_sucursal);

        INSERT INTO pagares (
            id_sistemas,
            prestamo_id,
            gerencia,
            created_by
        ) VALUES (
            v_id_sistemas,
            v_prestamo_id,
            v_gerencia_id,
            p_usuario
        );

        SET p_total_creados = p_total_creados + 1;
    END LOOP;

    CLOSE cur_prestamos;

    SELECT p_total_creados AS pagares_creados;
END //
DELIMITER ;


-- =====================================================
-- VISTA: vw_pagare_impresion
-- Uso: SELECT * FROM vw_pagare_impresion WHERE gerencia = 'GERC001';
-- =====================================================

DROP VIEW IF EXISTS vw_pagare_impresion;

CREATE VIEW vw_pagare_impresion AS
SELECT
    pag.id_sistemas,
    pc.Folio_de_pagare AS folio,
    pag.prestamo_id,
    pag.gerencia,
    DATE_FORMAT(pag.fecha_entrega_pagare, '%d/%m/%y') AS fecha_entrega_pagare,
    TIME_FORMAT(pag.fecha_entrega_pagare, '%H:%i') AS hora_entrega_pagare,
    pc.SucursalID AS sucursal,
    pc.Agente AS agencia,
    asa.Agente AS nombre_agente,
    pag.lugar_entrega,
    pc.Monto_otorgado AS monto_prestamo,
    pc.Cargo AS cargo,
    pc.Total_a_pagar AS total_a_pagar,
    pc.Primer_pago AS primer_pago,
    pc.Tarifa AS pago_semanal,
    CONCAT(pc.plazo, ' SEM') AS plazo,
    pc.Tipo_de_credito AS tipo_credito,
    pc.Dia_de_pago AS dia_de_pago,
    pc.Semana AS semana_inicio,
    pc.Anio AS anio_inicio,
    CONCAT(per_cli.nombres, ' ', per_cli.apellido_paterno, ' ', per_cli.apellido_materno) AS cliente_nombre,
    CONCAT(per_cli.calle, ' ', per_cli.no_exterior, ', ', per_cli.colonia, ', C.P. ', per_cli.codigo_postal) AS cliente_domicilio,
    per_cli.telefono AS cliente_telefono,
    CONCAT(per_aval.nombres, ' ', per_aval.apellido_paterno, ' ', per_aval.apellido_materno) AS aval_nombre,
    CONCAT(per_aval.calle, ' ', per_aval.no_exterior, ', ', per_aval.colonia, ', C.P. ', per_aval.codigo_postal) AS aval_domicilio,
    per_aval.telefono AS aval_telefono,
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
INNER JOIN prestamos_completados pc ON pag.prestamo_id = pc.PrestamoID
INNER JOIN agencias a ON pc.Agente = a.AgenciaID
LEFT JOIN personas per_cli ON pc.cliente_persona_id = per_cli.id
LEFT JOIN personas per_aval ON pc.aval_persona_id = per_aval.id
LEFT JOIN agencias_status_auxilar asa ON pc.Agente = asa.Agencia;
