# Transferir cliente(s) entre agencias

## Caso 1: Un cliente específico

```sql
UPDATE prestamos_v2
SET Agente = '<AGENCIA_DESTINO>'
WHERE PrestamoID = '<PRESTAMOID>';

UPDATE pagos_dynamic
SET agencia = '<AGENCIA_DESTINO>'
WHERE prestamo_id = '<PRESTAMOID>';
```

## Caso 2: Todos los clientes de una agencia

```sql
UPDATE prestamos_v2 SET Agente = '<DESTINO>' WHERE Agente = '<ORIGEN>';
UPDATE pagos_dynamic SET agencia = '<DESTINO>' WHERE agencia = '<ORIGEN>';
```

## Validar

```sql
SELECT COUNT(*) FROM prestamos_v2 WHERE Agente = '<DESTINO>';
SELECT COUNT(*) FROM pagos_dynamic WHERE agencia = '<DESTINO>';
```

## Notas

- El campo `prestamos_v2.Agente` guarda código de agencia (`AGE074`), no nombre. Ver [business-rules/formato-codigos.md](../business-rules/formato-codigos.md).
- Si la transferencia cruza gerencias, considerar también actualizar `prestamos_v2.Gerencia` (formato `Ger###`/`GerXX###`, NO `GERXX###`).
- Las dos UPDATE deben ejecutarse en la misma transacción si es posible, pero no es crítico (los cierres semanales se recalculan).
