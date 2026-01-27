# Guía de Migración de Préstamos Completados

## Descripción General

Este sistema de respaldo permite archivar préstamos que ya han sido pagados completamente (Saldo = 0) desde la tabla activa `prestamos_v2` hacia una tabla de respaldo histórico `prestamos_completados`.

## Componentes del Sistema

### 1. Tabla de Respaldo: `prestamos_completados`
- **Estructura**: Idéntica a `prestamos_v2` con dos campos adicionales
- **Campos adicionales**:
  - `created_at`: Fecha cuando el préstamo fue archivado
  - `updated_at`: Última actualización del registro
- **Motor**: InnoDB con índices optimizados para consultas históricas

### 2. Procedimientos Almacenados

#### `verificar_prestamos_completados()`
Permite revisar cuántos préstamos están listos para ser migrados sin ejecutar la migración.

**Retorna**:
- Total de préstamos completados
- Suma de montos cobrados
- Rango de fechas (semana/año más antigua y más reciente)
- Distribución por gerencia

**Uso**:
```sql
CALL verificar_prestamos_completados();
```

#### `migrar_prestamos_completados()`
Ejecuta la migración automática de préstamos con Saldo = 0.

**Proceso**:
1. Inicia una transacción
2. Inserta préstamos con Saldo = 0 en `prestamos_completados`
3. Elimina los préstamos migrados de `prestamos_v2`
4. Confirma la transacción
5. Retorna el número de registros migrados

**Retorna**:
- Número de registros migrados
- Mensaje de confirmación
- Fecha de migración (zona horaria México)

**Uso**:
```sql
CALL migrar_prestamos_completados();
```

**Características**:
- ✅ Transaccional (ROLLBACK automático en caso de error)
- ✅ Manejo de duplicados (ON DUPLICATE KEY UPDATE)
- ✅ Reporte de errores detallado

## Flujo de Trabajo Recomendado

### Paso 1: Crear la Tabla de Respaldo
Ejecutar el script manualmente en la base de datos:
```bash
# Copiar el contenido de crear_tabla_prestamos_completados.sql
# y ejecutarlo en el cliente de base de datos
```

### Paso 2: Crear los Procedimientos Almacenados
Ejecutar el script manualmente en la base de datos:
```bash
# Copiar el contenido de crear_procedure_migrar_prestamos_completados.sql
# y ejecutarlo en el cliente de base de datos
```

### Paso 3: Verificar Préstamos Listos para Migración
Antes de migrar, revisar cuántos préstamos están listos:
```sql
CALL verificar_prestamos_completados();
```

**Ejemplo de salida**:
```
+---------------------------+---------------+------------------+------------------+--------------------+------------------+
| total_prestamos_completados| total_cobrado | semana_mas_antigua| anio_mas_antiguo | semana_mas_reciente| anio_mas_reciente|
+---------------------------+---------------+------------------+------------------+--------------------+------------------+
| 1523                      | 2847563.50    | 1                | 2023             | 43                 | 2025             |
+---------------------------+---------------+------------------+------------------+--------------------+------------------+

+-----------+-------------------------+---------------+
| Gerencia  | prestamos_completados   | total_cobrado |
+-----------+-------------------------+---------------+
| GERE001   | 234                     | 456789.00     |
| GERC001   | 198                     | 387654.50     |
| ...       | ...                     | ...           |
+-----------+-------------------------+---------------+
```

### Paso 4: Ejecutar la Migración
Una vez confirmado, ejecutar la migración:
```sql
CALL migrar_prestamos_completados();
```

**Ejemplo de salida**:
```
+---------------------+--------------------------------------------------------------+---------------------+
| registros_migrados  | mensaje                                                      | fecha_migracion     |
+---------------------+--------------------------------------------------------------+---------------------+
| 1523                | Se migraron 1523 préstamos completados exitosamente         | 2025-11-19 10:30:45 |
+---------------------+--------------------------------------------------------------+---------------------+
```

### Paso 5: Verificar la Migración
Confirmar que los préstamos fueron migrados correctamente:

```sql
-- Verificar cantidad en tabla de respaldo
SELECT COUNT(*) FROM prestamos_completados;

-- Verificar que no quedan préstamos con Saldo = 0 en la tabla activa
SELECT COUNT(*) FROM prestamos_v2 WHERE Saldo = 0;
-- Debe retornar 0

-- Ver últimas migraciones
SELECT
    DATE(created_at) AS fecha_migracion,
    COUNT(*) AS registros_migrados
FROM prestamos_completados
GROUP BY DATE(created_at)
ORDER BY fecha_migracion DESC
LIMIT 10;
```

## Consultas Útiles

El archivo `queries_prestamos_completados.sql` contiene más de 13 consultas predefinidas para analizar préstamos completados:

### Estadísticas Generales
```sql
SELECT
    COUNT(*) AS total_prestamos,
    COUNT(DISTINCT cliente_persona_id) AS clientes_unicos,
    SUM(Monto_otorgado) AS monto_total_otorgado,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados;
```

### Análisis por Gerencia
```sql
SELECT
    Gerencia,
    COUNT(*) AS total_prestamos,
    SUM(Cobrado) AS total_cobrado
FROM prestamos_completados
GROUP BY Gerencia
ORDER BY total_prestamos DESC;
```

### Buscar Préstamos por Cliente
```sql
SELECT *
FROM prestamos_completados
WHERE Nombres LIKE '%JUAN%'
   OR Apellido_Paterno LIKE '%PEREZ%'
ORDER BY created_at DESC;
```

### Comparar Activos vs Completados
```sql
SELECT
    'Activos' AS tipo,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total
FROM prestamos_v2
UNION ALL
SELECT
    'Completados' AS tipo,
    COUNT(*) AS cantidad,
    SUM(Monto_otorgado) AS monto_total
FROM prestamos_completados;
```

## Consideraciones Importantes

### Seguridad
- ✅ El procedimiento usa transacciones para garantizar integridad de datos
- ✅ En caso de error, se ejecuta ROLLBACK automático
- ✅ Los registros nunca se pierden durante la migración

### Rendimiento
- Los índices en `prestamos_completados` están optimizados para consultas históricas
- La migración puede tardar varios segundos dependiendo de la cantidad de registros
- Se recomienda ejecutar durante períodos de baja actividad

### Frecuencia Recomendada
- **Mensual**: Para bases de datos con alto volumen de préstamos
- **Trimestral**: Para bases de datos con volumen moderado
- **Manual**: Cuando sea necesario liberar espacio en la tabla activa

### Respaldo
- Antes de ejecutar la primera migración, se recomienda hacer un respaldo completo de la base de datos
- Los registros en `prestamos_completados` son permanentes y deben respaldarse regularmente

## Solución de Problemas

### Error: Tabla prestamos_completados no existe
**Solución**: Ejecutar el script `crear_tabla_prestamos_completados.sql`

### Error: Procedimiento no encontrado
**Solución**: Ejecutar el script `crear_procedure_migrar_prestamos_completados.sql`

### Error durante la migración
El procedimiento ejecutará ROLLBACK automático. Revisar:
- Permisos de usuario en la base de datos
- Espacio disponible en disco
- Logs de MySQL/MariaDB para más detalles

### No se migraron todos los préstamos esperados
Verificar el criterio de migración:
- Solo se migran préstamos con `Saldo = 0` exactamente
- Si hay préstamos con Saldo cercano a 0 (ej: 0.01), no se migrarán

## Acceso Mediante MCP

Recuerda que el servidor MCP solo permite consultas SELECT. Para ejecutar los procedimientos almacenados, debes acceder directamente a la base de datos con un cliente MySQL/MariaDB.

### Consultas Permitidas via MCP
```bash
# Ver estructura de prestamos_completados
curl -X POST 'http://65.21.188.158:7400/get_table_details' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"table":"prestamos_completados"}'

# Consultar préstamos completados
curl -X POST 'http://65.21.188.158:7400/run_query' \
  -H 'x-api-key: 9mYS%hyyFGBg#x3ByAu%v@d@' \
  -H 'Content-Type: application/json' \
  -d '{"query":"SELECT COUNT(*) as total FROM prestamos_completados"}'
```

## Mantenimiento

### Auditoría Regular
Revisar periódicamente:
```sql
-- Distribución temporal de migraciones
SELECT
    DATE(created_at) AS fecha,
    COUNT(*) AS registros
FROM prestamos_completados
GROUP BY DATE(created_at)
ORDER BY fecha DESC
LIMIT 30;
```

### Limpieza de Datos Antiguos (Opcional)
Si se desea archivar préstamos muy antiguos a otro sistema:
```sql
-- Identificar préstamos completados hace más de 5 años
SELECT COUNT(*)
FROM prestamos_completados
WHERE Anio < (YEAR(CURRENT_DATE) - 5);
```

## Recursos Adicionales

- **CLAUDE.md**: Documentación completa del proyecto
- **README.md**: Guía rápida de uso
- Scripts SQL incluidos en el repositorio

---

**Última actualización**: 2025-11-19
