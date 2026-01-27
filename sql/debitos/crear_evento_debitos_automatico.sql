-- =====================================================
-- Evento: evento_capturar_debitos_semanal
-- Descripción: Captura automáticamente los débitos cada miércoles a las 6:00 AM
--              Se ejecuta para la semana actual
-- =====================================================

-- 1. Activar el Event Scheduler (solo una vez)
SET GLOBAL event_scheduler = ON;

-- 2. Eliminar evento si existe
DROP EVENT IF EXISTS evento_capturar_debitos_semanal;

-- 3. Crear evento que se ejecuta cada miércoles
DELIMITER $$

CREATE EVENT evento_capturar_debitos_semanal
ON SCHEDULE
    EVERY 1 WEEK
    STARTS (
        -- Próximo miércoles a las 6:00 AM hora México
        TIMESTAMP(
            CONVERT_TZ(
                DATE_ADD(
                    DATE_ADD(CURDATE(), INTERVAL (3 - WEEKDAY(CURDATE())) % 7 DAY),
                    INTERVAL 6 HOUR
                ),
                'America/Mexico_City',
                'UTC'
            )
        )
    )
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Captura débitos cada miércoles a las 6:00 AM'
DO
BEGIN
    DECLARE v_semana TINYINT;
    DECLARE v_anio INT;

    -- Obtener semana y año actual desde tabla calendario
    SELECT semana, anio INTO v_semana, v_anio
    FROM calendario
    WHERE CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City') BETWEEN desde AND hasta
    LIMIT 1;

    -- Ejecutar el procedimiento
    IF v_semana IS NOT NULL AND v_anio IS NOT NULL THEN
        CALL sp_insertar_debitos_agencias(v_semana, v_anio);
    END IF;
END$$

DELIMITER ;

-- =====================================================
-- Verificar que el evento se creó correctamente
-- =====================================================

SELECT
    event_name,
    event_definition,
    interval_value,
    interval_field,
    starts,
    status,
    on_completion,
    event_comment
FROM information_schema.events
WHERE event_name = 'evento_capturar_debitos_semanal';

-- =====================================================
-- Comandos útiles para gestionar el evento
-- =====================================================

-- Ver estado del Event Scheduler
-- SHOW VARIABLES LIKE 'event_scheduler';

-- Activar Event Scheduler (si está OFF)
-- SET GLOBAL event_scheduler = ON;

-- Desactivar el evento temporalmente
-- ALTER EVENT evento_capturar_debitos_semanal DISABLE;

-- Activar el evento
-- ALTER EVENT evento_capturar_debitos_semanal ENABLE;

-- Eliminar el evento
-- DROP EVENT IF EXISTS evento_capturar_debitos_semanal;

-- Ver todos los eventos
-- SELECT event_name, status, starts, event_definition
-- FROM information_schema.events;

-- =====================================================
-- Notas importantes
-- =====================================================

-- 1. El evento se ejecuta cada miércoles a las 6:00 AM (hora México)
-- 2. Captura los débitos de la semana ACTUAL
-- 3. ON COMPLETION PRESERVE: El evento no se elimina después de ejecutarse
-- 4. Si el servidor MySQL se reinicia, asegúrate de que event_scheduler esté ON
-- 5. Para hacer persistente el event_scheduler, agregar en my.cnf:
--    [mysqld]
--    event_scheduler = ON

-- =====================================================
-- Ejemplo de log/auditoría (opcional)
-- =====================================================

-- Crear tabla de log para auditar ejecuciones:
/*
CREATE TABLE debitos_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    semana TINYINT,
    anio INT,
    registros_afectados INT,
    ejecutado_en DATETIME DEFAULT (CONVERT_TZ(NOW(), 'UTC', 'America/Mexico_City')),
    mensaje VARCHAR(255)
);
*/

-- Modificar el evento para loguear:
/*
INSERT INTO debitos_log (semana, anio, registros_afectados, mensaje)
VALUES (v_semana, v_anio, ROW_COUNT(), 'Ejecución automática exitosa');
*/
