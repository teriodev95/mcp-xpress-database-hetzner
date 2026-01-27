# Estrategia de Clave Primaria para Préstamos Completados

## Problema Identificado

1. **PrestamoID duplicados**: Los datos de Excel pueden tener PrestamoIDs duplicados
2. **Volumen alto**: Se esperan ~500,000 registros en la migración
3. **Performance crítica**: Los inserts masivos deben ser rápidos

## Solución Implementada

### Clave Primaria: `id` BIGINT UNSIGNED AUTO_INCREMENT

**Ventajas:**
- ✅ **Performance óptima**: Los índices numéricos auto-incrementales son los más rápidos para inserts masivos
- ✅ **Sin conflictos**: Nunca habrá duplicados (auto-incremental garantiza unicidad)
- ✅ **Espacio eficiente**: BIGINT UNSIGNED soporta hasta 18,446,744,073,709,551,615 registros
- ✅ **Índice secuencial**: Mejor para caché de InnoDB (menos fragmentación)
- ✅ **Joins rápidos**: Los joins por enteros son mucho más rápidos que por VARCHAR

**Por qué BIGINT y no INT:**
- INT soporta hasta ~2 mil millones de registros
- Con 500k registros iniciales y crecimiento futuro, BIGINT es más seguro
- Solo usa 8 bytes vs 4 bytes de INT (diferencia mínima)

### Índice Único Compuesto: `(PrestamoID, Semana, Anio, SucursalID)`

Este índice UNIQUE previene duplicados reales:

```sql
UNIQUE KEY `idx_unique_prestamo` (`PrestamoID`, `Semana`, `Anio`, `SucursalID`)
```

**Por qué incluir SucursalID:**
- Un mismo PrestamoID podría aparecer en diferentes sucursales
- Diferentes períodos (Semana/Anio) del mismo préstamo
- Garantiza que cada combinación sea única

## Comparación con Otras Opciones

### ❌ Opción Rechazada 1: PRIMARY KEY (PrestamoID)
```sql
PRIMARY KEY (`PrestamoID`)
```
**Problema:**
- Falla si hay PrestamoIDs duplicados
- VARCHAR como PK es menos eficiente que INT
- Índice más grande en disco

### ❌ Opción Rechazada 2: PRIMARY KEY Compuesta
```sql
PRIMARY KEY (`PrestamoID`, `Semana`, `Anio`, `SucursalID`)
```
**Problema:**
- PK compuesta de 4 campos es ineficiente
- Cada índice secundario incluiría estos 4 campos (mucho overhead)
- Inserts más lentos
- Mayor uso de espacio en disco

### ✅ Opción Implementada: id AUTO_INCREMENT + UNIQUE Compuesto
```sql
PRIMARY KEY (`id`),
UNIQUE KEY `idx_unique_prestamo` (`PrestamoID`, `Semana`, `Anio`, `SucursalID`)
```
**Ventajas:**
- PK simple y eficiente (8 bytes)
- UNIQUE index previene duplicados
- Índices secundarios solo referencian `id`
- Inserts optimizados para volumen alto

## Impacto en el Procedimiento de Migración

El procedimiento `migrar_prestamos_completados()` **NO necesita cambios**:

```sql
INSERT INTO prestamos_completados (
    PrestamoID, Cliente_ID, ...
)
SELECT ...
ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP;
```

**Funcionamiento:**
1. El `id` se genera automáticamente (no necesita especificarse en el INSERT)
2. Si hay duplicado por el UNIQUE index `(PrestamoID, Semana, Anio, SucursalID)`:
   - Se ejecuta UPDATE en lugar de INSERT
   - Solo actualiza `updated_at`
3. MySQL maneja todo automáticamente

## Estimación de Espacio en Disco

Para **500,000 registros**:

### Con PK compuesta VARCHAR (4 campos):
- Tamaño PK: ~120 bytes (32+4+4+20 chars promedio)
- 500k registros × 120 bytes = ~60 MB solo en PK
- Cada índice secundario repite la PK: +300 MB aprox.
- **Total estimado**: ~360 MB en índices

### Con PK id BIGINT (implementado):
- Tamaño PK: 8 bytes
- 500k registros × 8 bytes = 4 MB en PK
- Índices secundarios: ~40 MB
- Índice UNIQUE compuesto: ~60 MB
- **Total estimado**: ~104 MB en índices

**Ahorro**: ~70% menos espacio en índices

## Performance Esperada

### Inserts Masivos (500k registros):
- **Con PK VARCHAR compuesta**: ~15-25 minutos
- **Con PK id BIGINT**: ~5-10 minutos
- **Mejora**: 2-3x más rápido

### Consultas por PrestamoID:
```sql
SELECT * FROM prestamos_completados WHERE PrestamoID = 'ABC123';
```
- Usa el índice `idx_prestamo_id` (rápido)
- Performance similar a tener PrestamoID como PK

### Consultas por id:
```sql
SELECT * FROM prestamos_completados WHERE id = 12345;
```
- **Más rápido**: Búsqueda directa en PK (O(log n) óptimo)

## Manejo de Duplicados

### Escenario 1: Mismo préstamo, mismo período, misma sucursal
```
PrestamoID: ABC-123
Semana: 42
Anio: 2025
SucursalID: dinero
```
**Resultado**: DUPLICATE KEY → Ejecuta UPDATE (solo actualiza `updated_at`)

### Escenario 2: Mismo préstamo, diferente período
```
PrestamoID: ABC-123
Semana: 43  ← diferente
Anio: 2025
SucursalID: dinero
```
**Resultado**: Nuevo registro (INSERT exitoso con nuevo `id`)

### Escenario 3: Mismo préstamo, diferente sucursal
```
PrestamoID: ABC-123
Semana: 42
Anio: 2025
SucursalID: plata  ← diferente
```
**Resultado**: Nuevo registro (INSERT exitoso con nuevo `id`)

## Consultas de Ejemplo

### Buscar por id (más rápido):
```sql
SELECT * FROM prestamos_completados WHERE id = 100000;
```

### Buscar por PrestamoID:
```sql
SELECT * FROM prestamos_completados WHERE PrestamoID = 'ABC-123';
```

### Verificar duplicados antes de migrar:
```sql
SELECT PrestamoID, Semana, Anio, SucursalID, COUNT(*) as duplicados
FROM prestamos_v2
GROUP BY PrestamoID, Semana, Anio, SucursalID
HAVING COUNT(*) > 1;
```

### Verificar integridad después de migrar:
```sql
-- No debe retornar ningún registro
SELECT PrestamoID, Semana, Anio, SucursalID, COUNT(*) as duplicados
FROM prestamos_completados
GROUP BY PrestamoID, Semana, Anio, SucursalID
HAVING COUNT(*) > 1;
```

## Recomendaciones Finales

1. **No modificar el procedimiento**: El INSERT con ON DUPLICATE KEY UPDATE funciona perfectamente
2. **Monitorear el auto_increment**: Verificar que no se acerque al límite de BIGINT (muy improbable)
3. **Usar id para JOINs internos**: Cuando sea posible, usar `id` en lugar de `PrestamoID` para mejor performance
4. **Mantener el índice único**: Es crítico para evitar duplicados reales

## Conclusión

La estrategia de **id BIGINT AUTO_INCREMENT + UNIQUE index compuesto** es:
- ✅ Óptima para inserts masivos (500k+ registros)
- ✅ Previene duplicados mediante UNIQUE constraint
- ✅ Ahorra ~70% de espacio en índices
- ✅ 2-3x más rápida que PK compuesta
- ✅ Compatible con el procedimiento actual (sin cambios)

**Decisión final**: Implementar esta solución en ambas versiones (normal y optimizada).
