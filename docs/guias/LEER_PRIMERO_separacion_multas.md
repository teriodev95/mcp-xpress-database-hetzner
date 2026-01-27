# Separación de Multas de pagos_dynamic

## Problema Detectado

La tabla `pagos_dynamic` almacena múltiples tipos de transacciones para el mismo préstamo/semana:
- Pago principal (tipo='Pago', tipo_aux='Pago')
- Multas (tipo='Multa', tipo_aux='Multa')
- Excedentes (tipo='Excedente', tipo_aux='Pago')

Esto causa:
❌ Duplicados en `vw_datos_cobranza` cuando se hace LEFT JOIN
❌ Conteos incorrectos en queries que no usan DISTINCT
❌ Complejidad innecesaria en SPs y vistas

## Solución Implementada

Separar las multas en tabla independiente `multas` y eliminarlas automáticamente de `pagos_dynamic` y `pagos_v3` usando triggers.

## Archivos Creados

1. **crear_tabla_multas.sql**
   - Tabla para almacenar multas separadas
   - Índices optimizados
   - Foreign key a prestamos_v2

2. **triggers_separar_multas.sql**
   - Trigger AFTER INSERT en pagos_v3 → crea registro en multas
   - Trigger AFTER INSERT en pagos_dynamic → elimina multas automáticamente
   - Trigger AFTER UPDATE en pagos_v3 → maneja cambios de tipo
   - Script de migración de datos existentes

3. **sp_insertar_cobranza_agencias_OPTIMIZADO_V3.sql**
   - SP actualizado que obtiene multas de la nueva tabla
   - Elimina dependencia de tipo='Multa' en pagos_dynamic
   - Mantiene todas las 352 agencias

## Orden de Ejecución

### Paso 1: Crear tabla multas
```sql
SOURCE crear_tabla_multas.sql;
```

### Paso 2: Ejecutar triggers y migración
```sql
SOURCE triggers_separar_multas.sql;
```

Este script:
- ✅ Crea los 3 triggers
- ✅ Migra todas las multas existentes de pagos_v3 → multas
- ✅ Elimina multas de pagos_dynamic
- ✅ Muestra estadísticas de migración

### Paso 3: Verificar migración
```sql
-- Ver cantidad de multas migradas
SELECT COUNT(*) as total_multas FROM multas;

-- Verificar que pagos_dynamic ya no tiene multas
SELECT COUNT(*) as multas_restantes
FROM pagos_dynamic
WHERE tipo = 'Multa';
-- Debe retornar 0

-- Ver multas por semana
SELECT semana, anio, COUNT(*) as total, SUM(monto) as total_monto
FROM multas
GROUP BY semana, anio
ORDER BY anio DESC, semana DESC
LIMIT 10;
```

### Paso 4: Actualizar SP de cobranza
```sql
SOURCE sp_insertar_cobranza_agencias_OPTIMIZADO_V3.sql;
```

### Paso 5: Probar el SP actualizado
```sql
-- Limpiar datos de prueba anteriores
DELETE FROM cobranza_historial WHERE semana = 3 AND anio = 2026;

-- Ejecutar SP actualizado
CALL sp_insertar_cobranza_agencias(3, 2026);

-- Verificar resultados
SELECT COUNT(*) as total_registros FROM cobranza_historial
WHERE semana = 3 AND anio = 2026;
-- Debe retornar 352

-- Verificar multas
SELECT agencia, multas FROM cobranza_historial
WHERE semana = 3 AND anio = 2026 AND multas > 0;
```

## Validación de Datos

### Antes de la migración:
```sql
-- Contar multas en pagos_v3
SELECT COUNT(*) FROM pagos_v3 WHERE Tipo = 'Multa';

-- Contar multas en pagos_dynamic
SELECT COUNT(*) FROM pagos_dynamic WHERE tipo = 'Multa';
```

### Después de la migración:
```sql
-- Deben coincidir:
SELECT
    (SELECT COUNT(*) FROM multas) as multas_nueva_tabla,
    (SELECT COUNT(*) FROM pagos_v3 WHERE Tipo = 'Multa') as multas_pagos_v3,
    (SELECT COUNT(*) FROM pagos_dynamic WHERE tipo = 'Multa') as multas_pagos_dynamic;

-- multas_nueva_tabla = multas_pagos_v3 (deben ser iguales)
-- multas_pagos_dynamic = 0 (debe ser cero)
```

## Impacto en el Sistema

### ✅ Beneficios:
1. **Elimina duplicados** en pagos_dynamic (de 2 registros → 1 por préstamo/semana)
2. **vw_datos_cobranza sin duplicados** (1 fila = 1 préstamo)
3. **Queries más simples** (no necesitan DISTINCT ni GROUP BY complejos)
4. **Mejor rendimiento** en JOINs
5. **Separación de responsabilidades** (pagos vs multas)

### ⚠️ Consideraciones:
1. Los triggers se ejecutan automáticamente en cada INSERT/UPDATE
2. Las multas se mantienen en `pagos_v3` (solo se copian a `multas`)
3. Las multas se eliminan de `pagos_dynamic` automáticamente
4. Cualquier query que use `pagos_dynamic` con `tipo='Multa'` necesita actualizarse

## Archivos que Necesitan Actualización

### SPs que usan pagos_dynamic con multas:
- ✅ sp_insertar_cobranza_agencias_OPTIMIZADO_V3.sql (ya actualizado)
- ⚠️ Revisar otros SPs que calculen multas desde pagos_dynamic

### Vistas que necesitan actualización:
- ⚠️ vw_datos_cobranza (agregar LEFT JOIN a tabla multas)

### Código Java que puede necesitar actualización:
- ⚠️ DashboardV2Service.java (verificar si usa tipo='Multa')
- ⚠️ Cualquier servicio que consulte multas

## Pruebas Recomendadas

1. **Insertar nueva multa en pagos_v3**:
   ```sql
   -- Simular inserción de multa
   -- Verificar que se crea automáticamente en tabla multas
   -- Verificar que NO aparece en pagos_dynamic
   ```

2. **Validar totales**:
   ```sql
   -- Comparar totales de multas antes/después de migración
   -- Deben coincidir al centavo
   ```

3. **Ejecutar SP de cobranza**:
   ```sql
   -- Verificar que el campo multas se llena correctamente
   -- Comparar con versión anterior
   ```

## Rollback (Si es necesario)

Si algo sale mal, ejecutar en orden inverso:

```sql
-- 1. Eliminar triggers
DROP TRIGGER IF EXISTS trg_pagos_v3_multas_after_insert;
DROP TRIGGER IF EXISTS trg_pagos_dynamic_multas_after_insert;
DROP TRIGGER IF EXISTS trg_pagos_v3_multas_after_update;

-- 2. Restaurar multas en pagos_dynamic desde pagos_v3
-- (Ejecutar el SP o trigger que originalmente llenaba pagos_dynamic)

-- 3. Eliminar tabla multas (CUIDADO: perderás los datos)
-- DROP TABLE multas;
```

## Contacto

Para dudas o problemas con la migración, contactar al equipo de desarrollo.
