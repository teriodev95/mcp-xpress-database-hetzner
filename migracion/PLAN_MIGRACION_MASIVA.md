# Plan de Migración Masiva

## Resumen de Impacto

| Tabla | Registros | Triggers | FK |
|-------|-----------|----------|-----|
| pagos_v3 | ~5M | **7 triggers** | 1 |
| prestamos_completados | ~700K | 0 | 2 (a personas) |
| personas | ~700K | 0 | 0 |

## Orden de Ejecución

**Insertar en este orden por dependencias FK:**
1. `personas` (sin dependencias)
2. `prestamos_completados` (depende de personas)
3. `pagos_v3` (tiene triggers problemáticos)

---

## PASO 1: Deshabilitar Triggers de pagos_v3

```sql
-- EJECUTAR ANTES DE LA MIGRACIÓN
DROP TRIGGER IF EXISTS after_insert_update_pagos_dynamic;
DROP TRIGGER IF EXISTS after_insert_update_prestamos_dynamic;
DROP TRIGGER IF EXISTS after_update_update_prestamos_dynamic;
DROP TRIGGER IF EXISTS after_update_update_pagos_dynamic;
DROP TRIGGER IF EXISTS after_pago_delete;
DROP TRIGGER IF EXISTS after_delete_update_prestamos_dynamic;
DROP TRIGGER IF EXISTS after_delete_update_pagos_dynamic;
```

---

## PASO 2: Ejecutar Migración desde Java

Asegurarse que los INSERTs a `pagos_v3` incluyan:
```sql
Creado_desde = 'Migracion'
```

> **Nota:** Los triggers originales ya tienen lógica para ignorar registros con `Creado_desde = 'Migracion'`, pero es más seguro eliminarlos para evitar overhead durante los 5M de inserts.

---

## PASO 3: Recrear Triggers

Ejecutar después de completar la migración:

```sql
-- Trigger 1: BEFORE INSERT
DELIMITER $$
CREATE DEFINER=`xpress_admin`@`%` TRIGGER after_insert_update_pagos_dynamic
    BEFORE INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE id_pago VARCHAR(64);
    DECLARE tarifa_pago DECIMAL(10, 2);
    DECLARE monto_pago DECIMAL(10, 2);
    DECLARE tipo_pago VARCHAR(16);
    DECLARE tipo_aux_pago VARCHAR(16);

    SELECT prestamo_id INTO id_pago
    FROM pagos_dynamic
    WHERE prestamo_id = NEW.PrestamoID
      AND anio = NEW.Anio
      AND semana = NEW.Semana
      AND tipo_aux = 'Pago';

    IF id_pago IS NOT NULL THEN
        IF (NEW.Creado_desde != 'Migracion' AND NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
            SELECT IF(abre_con < tarifa, abre_con, tarifa), monto + NEW.Monto
            INTO tarifa_pago, monto_pago
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo_aux = 'Pago';

            CASE
                WHEN NEW.Tipo = 'Liquidacion' THEN SET tipo_pago = 'Liquidacion';
                WHEN monto_pago = 0 THEN SET tipo_pago = 'No_Pago';
                WHEN monto_pago < tarifa_pago THEN SET tipo_pago = 'Reducido';
                WHEN monto_pago = tarifa_pago THEN SET tipo_pago = 'Pago';
                WHEN monto_pago > tarifa_pago THEN SET tipo_pago = 'Excedente';
            END CASE;

            CASE
                WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                ELSE SET tipo_aux_pago = 'Pago';
            END CASE;

            UPDATE pagos_dynamic
            SET monto          = monto_pago,
                fecha_pago     = NEW.Fecha_pago,
                cierra_con     = cierra_con - NEW.Monto,
                tipo           = tipo_pago,
                recuperado_por = NEW.recuperado_por,
                tipo_aux       = tipo_aux_pago
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo NOT IN ('Multa', 'Visita');
        ELSE
            IF (NEW.Creado_desde != 'Migracion') THEN
                IF NEW.abrecon < NEW.tarifa THEN
                    SET tarifa_pago = NEW.abrecon;
                ELSE
                    SET tarifa_pago = NEW.Tarifa;
                END IF;
                CASE
                    WHEN NEW.Monto = 0 AND NEW.Tipo != 'Visita' THEN SET tipo_pago = 'No_pago';
                    WHEN NEW.Tipo = 'Liquidacion' THEN SET tipo_pago = 'Liquidacion';
                    WHEN NEW.Tipo = 'Visita' THEN SET tipo_pago = 'Visita';
                    WHEN NEW.Tipo = 'No_pago' THEN SET tipo_pago = 'No_pago';
                    WHEN NEW.Tipo = 'Multa' THEN SET tipo_pago = 'Multa';
                    WHEN NEW.Monto < tarifa_pago THEN SET tipo_pago = 'Reducido';
                    WHEN NEW.Monto = tarifa_pago THEN SET tipo_pago = 'Pago';
                    WHEN NEW.Monto > tarifa_pago THEN SET tipo_pago = 'Excedente';
                END CASE;

                CASE
                    WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                    WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                    ELSE SET tipo_aux_pago = 'Pago';
                END CASE;

                INSERT INTO pagos_dynamic (prestamo_id, monto, semana, anio, es_primer_pago, abre_con, cierra_con,
                                           tarifa, agencia, tipo, fecha_pago, identificador, cliente, prestamo,
                                           quien_pago, comentario, pago_id, lat, lng, tipo_aux, recuperado_por)
                VALUES (NEW.PrestamoID, NEW.Monto, NEW.Semana, NEW.Anio, NEW.EsPrimerPago,
                        NEW.AbreCon, NEW.CierraCon, NEW.Tarifa, NEW.Agente, tipo_pago, NEW.Fecha_pago,
                        NEW.Identificador, NEW.cliente, NEW.prestamo, NEW.quien_pago, NEW.Comentario,
                        NEW.PagoID, NEW.Lat, NEW.Lng, tipo_aux_pago, NEW.recuperado_por);
            END IF;
        END IF;
    ELSE
        IF (NEW.Creado_desde != 'Migracion') THEN
            IF NEW.abrecon < NEW.tarifa THEN
                SET tarifa_pago = NEW.abrecon;
            ELSE
                SET tarifa_pago = NEW.Tarifa;
            END IF;

            CASE
                WHEN NEW.Monto = 0 AND NEW.Tipo != 'Visita' THEN SET tipo_pago = 'No_pago';
                WHEN NEW.Tipo = 'Liquidacion' THEN SET tipo_pago = 'Liquidacion';
                WHEN NEW.Tipo = 'Visita' THEN SET tipo_pago = 'Visita';
                WHEN NEW.Tipo = 'No_pago' THEN SET tipo_pago = 'No_pago';
                WHEN NEW.Tipo = 'Multa' THEN SET tipo_pago = 'Multa';
                WHEN NEW.Monto < tarifa_pago THEN SET tipo_pago = 'Reducido';
                WHEN NEW.Monto = tarifa_pago THEN SET tipo_pago = 'Pago';
                WHEN NEW.Monto > tarifa_pago THEN SET tipo_pago = 'Excedente';
            END CASE;

            CASE
                WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                ELSE SET tipo_aux_pago = 'Pago';
            END CASE;

            INSERT INTO pagos_dynamic (prestamo_id, monto, semana, anio, es_primer_pago, abre_con, cierra_con,
                                       tarifa, agencia, tipo, fecha_pago, identificador, cliente, prestamo,
                                       quien_pago, comentario, pago_id, lat, lng, tipo_aux, recuperado_por)
            VALUES (NEW.PrestamoID, NEW.Monto, NEW.Semana, NEW.Anio, NEW.EsPrimerPago,
                    NEW.AbreCon, NEW.CierraCon, NEW.Tarifa, NEW.Agente, tipo_pago, NEW.Fecha_pago,
                    NEW.Identificador, NEW.cliente, NEW.prestamo, NEW.quien_pago, NEW.Comentario,
                    NEW.PagoID, NEW.Lat, NEW.Lng, tipo_aux_pago, NEW.recuperado_por);
        END IF;
    END IF;
END$$
DELIMITER ;

-- Trigger 2: AFTER INSERT
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_insert_update_prestamos_dynamic
    AFTER INSERT ON pagos_v3
    FOR EACH ROW
BEGIN
    IF (NEW.Creado_desde != 'Migracion' AND NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
        IF (NEW.tipo = 'Liquidacion') THEN
            UPDATE prestamos_dynamic prest_dyn
                INNER JOIN prestamos_v2 prest ON prest_dyn.prestamo_id = prest.PrestamoID
            SET prest_dyn.saldo = 0,
                prest_dyn.cobrado = prest.Total_a_pagar
            WHERE prestamo_id = NEW.PrestamoID;
        ELSE
            UPDATE prestamos_dynamic
            SET saldo = Saldo - NEW.Monto,
                cobrado = Cobrado + NEW.Monto
            WHERE prestamo_id = NEW.PrestamoID;
        END IF;
    END IF;
END$$
DELIMITER ;

-- Trigger 3: AFTER UPDATE (prestamos_dynamic)
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_update_update_prestamos_dynamic
    AFTER UPDATE ON pagos_v3
    FOR EACH ROW
BEGIN
    IF (OLD.Creado_desde != 'Migracion' AND OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
        UPDATE prestamos_dynamic
        SET saldo   = Saldo + OLD.Monto - NEW.Monto,
            cobrado = Cobrado - OLD.Monto + NEW.Monto
        WHERE prestamo_id = NEW.PrestamoID;
    END IF;
END$$
DELIMITER ;

-- Trigger 4: AFTER UPDATE (pagos_dynamic)
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_update_update_pagos_dynamic
    AFTER UPDATE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE id_pago VARCHAR(64);
    DECLARE tarifa_pago DECIMAL(10, 2);
    DECLARE monto_pago DECIMAL(10, 2);
    DECLARE tipo_pago VARCHAR(16);
    DECLARE tipo_aux_pago VARCHAR(16);

    SELECT prestamo_id INTO id_pago
    FROM pagos_dynamic
    WHERE prestamo_id = NEW.PrestamoID
      AND anio = NEW.Anio
      AND semana = NEW.Semana
      AND tipo NOT IN ('Multa', 'Visita');

    IF id_pago IS NOT NULL THEN
        IF (NEW.Creado_desde != 'Migracion' AND NEW.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
            SELECT IF(abre_con < tarifa, abre_con, tarifa), monto + NEW.Monto - OLD.Monto
            INTO tarifa_pago, monto_pago
            FROM pagos_dynamic
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo NOT IN ('Multa', 'Visita');

            CASE
                WHEN monto_pago = 0 THEN SET tipo_pago = 'No_pago';
                WHEN NEW.Tipo = 'Liquidacion' THEN SET tipo_pago = 'Liquidacion';
                WHEN monto_pago < tarifa_pago THEN SET tipo_pago = 'Reducido';
                WHEN monto_pago = tarifa_pago THEN SET tipo_pago = 'Pago';
                WHEN monto_pago > tarifa_pago THEN SET tipo_pago = 'Excedente';
            END CASE;

            CASE
                WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                ELSE SET tipo_aux_pago = 'Pago';
            END CASE;

            UPDATE pagos_dynamic
            SET monto          = monto_pago,
                fecha_pago     = NEW.Fecha_pago,
                cierra_con     = cierra_con + OLD.Monto - NEW.Monto,
                recuperado_por = NEW.recuperado_por,
                tipo           = tipo_pago,
                tipo_aux       = tipo_aux_pago
            WHERE prestamo_id = NEW.PrestamoID
              AND anio = NEW.Anio
              AND semana = NEW.Semana
              AND tipo NOT IN ('Multa', 'Visita');
        END IF;
    ELSE
        IF (NEW.Creado_desde != 'Migracion') THEN
            IF NEW.abrecon < NEW.tarifa THEN
                SET tarifa_pago = NEW.abrecon;
            ELSE
                SET tarifa_pago = NEW.Tarifa;
            END IF;

            CASE
                WHEN NEW.Monto = 0 AND NEW.Tipo != 'Visita' THEN SET tipo_pago = 'No_pago';
                WHEN NEW.Tipo = 'Liquidacion' THEN SET tipo_pago = 'Liquidacion';
                WHEN NEW.Tipo = 'Visita' THEN SET tipo_pago = 'Visita';
                WHEN NEW.Tipo = 'No_pago' THEN SET tipo_pago = 'No_pago';
                WHEN NEW.Tipo = 'Multa' THEN SET tipo_pago = 'Multa';
                WHEN NEW.Monto < tarifa_pago THEN SET tipo_pago = 'Reducido';
                WHEN NEW.Monto = tarifa_pago THEN SET tipo_pago = 'Pago';
                WHEN NEW.Monto > tarifa_pago THEN SET tipo_pago = 'Excedente';
            END CASE;

            CASE
                WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                ELSE SET tipo_aux_pago = 'Pago';
            END CASE;

            INSERT INTO pagos_dynamic (prestamo_id, monto, semana, anio, es_primer_pago, abre_con, cierra_con,
                                       tarifa, agencia, tipo, fecha_pago, identificador, cliente, prestamo,
                                       quien_pago, comentario, pago_id, lat, lng, tipo_aux, recuperado_por)
            VALUES (NEW.PrestamoID, NEW.Monto, NEW.Semana, NEW.Anio, NEW.EsPrimerPago,
                    NEW.AbreCon, NEW.CierraCon, NEW.Tarifa, NEW.Agente, tipo_pago, NEW.Fecha_pago,
                    NEW.Identificador, NEW.cliente, NEW.prestamo, NEW.quien_pago, NEW.Comentario,
                    NEW.PagoID, NEW.Lat, NEW.Lng, tipo_aux_pago, NEW.recuperado_por);
        END IF;
    END IF;
END$$
DELIMITER ;

-- Trigger 5: AFTER DELETE (log)
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_pago_delete
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    INSERT INTO pagos_eliminados_log (
        PagoID, PrestamoID, Prestamo, Monto, Semana, Anio, EsPrimerPago, AbreCon,
        CierraCon, Tarifa, Cliente, Agente, Tipo, Creado_desde, Identificador,
        Fecha_pago, Lat, Lng, Comentario, Datos_migracion, Created_at, Updated_at,
        Log, quien_pago, eliminado_en
    )
    VALUES (
        OLD.PagoID, OLD.PrestamoID, OLD.Prestamo, OLD.Monto, OLD.Semana, OLD.Anio, OLD.EsPrimerPago, OLD.AbreCon,
        OLD.CierraCon, OLD.Tarifa, OLD.Cliente, OLD.Agente, OLD.Tipo, OLD.Creado_desde, OLD.Identificador,
        OLD.Fecha_pago, OLD.Lat, OLD.Lng, OLD.Comentario, OLD.Datos_migracion, OLD.Created_at, OLD.Updated_at,
        OLD.Log, OLD.quien_pago, NOW()
    );
END$$
DELIMITER ;

-- Trigger 6: AFTER DELETE (prestamos_dynamic)
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_delete_update_prestamos_dynamic
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    IF (OLD.Creado_desde != 'Migracion' AND OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
        IF (OLD.Tipo = 'Liquidacion') THEN
            UPDATE prestamos_dynamic pag_dyn
                INNER JOIN liquidaciones liq ON pag_dyn.prestamo_id = liq.prestamoID
            SET pag_dyn.saldo   = Saldo + OLD.Monto + liq.descuento_en_dinero,
                pag_dyn.cobrado = Cobrado - OLD.Monto - liq.descuento_en_dinero
            WHERE prestamo_id = OLD.PrestamoID;
        ELSE
            UPDATE prestamos_dynamic
            SET saldo   = Saldo + OLD.Monto,
                cobrado = Cobrado - OLD.Monto
            WHERE prestamo_id = OLD.PrestamoID;
        END IF;
    END IF;
END$$
DELIMITER ;

-- Trigger 7: AFTER DELETE (pagos_dynamic)
DELIMITER $$
CREATE DEFINER=`xpress_dinero_noco`@`%` TRIGGER after_delete_update_pagos_dynamic
    AFTER DELETE ON pagos_v3
    FOR EACH ROW
BEGIN
    DECLARE id_pago VARCHAR(64);
    DECLARE tarifa_pago DECIMAL(10, 2);
    DECLARE monto_pago DECIMAL(10, 2);
    DECLARE tipo_pago VARCHAR(16);
    DECLARE tipo_aux_pago VARCHAR(16);

    SELECT prestamo_id INTO id_pago
    FROM pagos_dynamic
    WHERE prestamo_id = OLD.PrestamoID
      AND anio = OLD.Anio
      AND semana = OLD.Semana
      AND tipo NOT IN ('Multa', 'Visita');

    IF id_pago IS NOT NULL THEN
        IF (OLD.Creado_desde != 'Migracion' AND OLD.Tipo NOT IN ('Multa', 'Visita', 'No_pago')) THEN
            SELECT IF(abre_con < tarifa, abre_con, tarifa), monto - OLD.Monto
            INTO tarifa_pago, monto_pago
            FROM pagos_dynamic
            WHERE prestamo_id = OLD.PrestamoID
              AND anio = OLD.Anio
              AND semana = OLD.Semana
              AND tipo NOT IN ('Multa', 'Visita');

            CASE
                WHEN monto_pago = 0 THEN SET tipo_pago = 'No_pago';
                WHEN monto_pago < tarifa_pago THEN SET tipo_pago = 'Reducido';
                WHEN monto_pago = tarifa_pago THEN SET tipo_pago = 'Pago';
                WHEN monto_pago > tarifa_pago THEN SET tipo_pago = 'Excedente';
            END CASE;

            CASE
                WHEN tipo_pago = 'Multa' THEN SET tipo_aux_pago = 'Multa';
                WHEN tipo_pago = 'Visita' THEN SET tipo_aux_pago = 'Visita';
                ELSE SET tipo_aux_pago = 'Pago';
            END CASE;

            UPDATE pagos_dynamic
            SET monto      = monto_pago,
                cierra_con = cierra_con + OLD.Monto,
                tipo       = tipo_pago,
                tipo_aux   = tipo_aux_pago
            WHERE prestamo_id = OLD.PrestamoID
              AND anio = OLD.Anio
              AND semana = OLD.Semana
              AND tipo NOT IN ('Multa', 'Visita');
        END IF;
    END IF;
END$$
DELIMITER ;
```

---

## Verificación Post-Migración

```sql
-- Verificar triggers recreados
SELECT TRIGGER_NAME, EVENT_MANIPULATION, ACTION_TIMING
FROM INFORMATION_SCHEMA.TRIGGERS
WHERE EVENT_OBJECT_TABLE = 'pagos_v3';

-- Contar registros migrados
SELECT 'pagos_v3' AS tabla, COUNT(*) AS total FROM pagos_v3 WHERE Creado_desde = 'Migracion'
UNION ALL
SELECT 'prestamos_completados', COUNT(*) FROM prestamos_completados
UNION ALL
SELECT 'personas', COUNT(*) FROM personas;
```

---

## Notas Importantes

1. **prestamos_completados** y **personas**: No tienen triggers, solo FKs. Insertar personas primero.

2. **Optimización adicional** (opcional para mayor velocidad):
```sql
-- Antes de migrar
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET AUTOCOMMIT = 0;

-- Después de migrar
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;
COMMIT;
```

3. **El campo `Creado_desde = 'Migracion'`** en pagos_v3 es crítico para que los triggers (cuando estén activos) ignoren esos registros.
