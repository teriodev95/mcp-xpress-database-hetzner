package com.clvrt.cobranza_por_agencia;

import com.clvrt.db.SecureQueryExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Servicio para operaciones de cobranza por agencia
 */
public class CobranzaPorAgenciaService {
    private static final Logger logger = LoggerFactory.getLogger(CobranzaPorAgenciaService.class);
    private final SecureQueryExecutor queryExecutor;

    public CobranzaPorAgenciaService() {
        this.queryExecutor = new SecureQueryExecutor();
    }

    /**
     * Obtiene los datos de cobranza de clientes por agencia, año y semana
     * @param agencia ID de la agencia (código de agente)
     * @param anio Año para filtrar
     * @param semana Semana para filtrar
     * @return Lista de cobranza por cliente
     * @throws SQLException si ocurre un error en la base de datos
     */
    public List<CobranzaClienteAgencia> obtenerCobranzaPorAgencia(String agencia, Integer anio, Integer semana) throws SQLException {
        String query = """
            SELECT
                p.PrestamoID AS prestamo_id,
                CONCAT(p.Nombres, ' ', p.Apellido_Paterno, ' ', COALESCE(p.Apellido_Materno, '')) AS cliente,
                p.Tarifa AS tarifa_prestamo,
                COALESCE(LEAST(p.Tarifa, p.Saldo), 0) AS tarifa_en_semana,
                p.Saldo AS saldo_al_iniciar_semana,
                p.Dia_de_pago,
                COALESCE(pag_dyn.cierra_con, p.Saldo) AS cierra_con,
                LEAST(p.Saldo, p.Tarifa) AS debito,
                COALESCE(pag_dyn.monto, 0) AS monto_pagado,
                COALESCE(LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0) AS cobranza_pura,
                CASE
                    WHEN liq.liquidacionID IS NOT NULL THEN 0
                    ELSE COALESCE(pag_dyn.monto - LEAST(pag_dyn.monto, LEAST(p.Saldo, p.Tarifa)), 0)
                END AS excedente,
                ROUND(COALESCE(liq.liquido_con, 0), 2) AS monto_liquidacion,
                ROUND(COALESCE(liq.descuento_en_dinero, 0), 2) AS monto_descuento,
                COALESCE(pag_dyn.tipo, 'Sin Pago') AS tipo,
                CASE WHEN pag_dyn.prestamo_id IS NULL AND liq.liquidacionID IS NULL THEN 'NO' ELSE 'SI' END AS pago_semana
            FROM prestamos_v2 p
            LEFT JOIN pagos_dynamic pag_dyn
                ON p.PrestamoID = pag_dyn.prestamo_id
                AND pag_dyn.anio = ?
                AND pag_dyn.semana = ?
            LEFT JOIN liquidaciones liq
                ON p.PrestamoID = liq.prestamoID
                AND liq.anio = ?
                AND liq.semana = ?
            WHERE p.Agente = ?
                AND p.Saldo > 0
            ORDER BY p.Anio, p.Semana DESC
            """;

        logger.info("Obteniendo cobranza por agencia: {}, año: {}, semana: {}", agencia, anio, semana);

        try {
            List<Map<String, Object>> results = queryExecutor.executeQuery(query, anio, semana, anio, semana, agencia);
            List<CobranzaClienteAgencia> cobranzas = new ArrayList<>();

            for (Map<String, Object> row : results) {
                CobranzaClienteAgencia cobranza = new CobranzaClienteAgencia(
                        (String) row.get("prestamo_id"),
                        (String) row.get("cliente"),
                        convertToBigDecimal(row.get("tarifa_prestamo")),
                        convertToBigDecimal(row.get("tarifa_en_semana")),
                        convertToBigDecimal(row.get("saldo_al_iniciar_semana")),
                        (String) row.get("Dia_de_pago"),
                        convertToBigDecimal(row.get("cierra_con")),
                        convertToBigDecimal(row.get("debito")),
                        convertToBigDecimal(row.get("monto_pagado")),
                        convertToBigDecimal(row.get("cobranza_pura")),
                        convertToBigDecimal(row.get("excedente")),
                        convertToBigDecimal(row.get("monto_liquidacion")),
                        convertToBigDecimal(row.get("monto_descuento")),
                        (String) row.get("tipo"),
                        (String) row.get("pago_semana")
                );
                cobranzas.add(cobranza);
            }

            logger.info("Se encontraron {} clientes para la agencia {}", cobranzas.size(), agencia);
            return cobranzas;
        } catch (SQLException e) {
            logger.error("Error al obtener cobranza por agencia: {}", e.getMessage());
            throw e;
        }
    }

    private BigDecimal convertToBigDecimal(Object value) {
        if (value == null) return BigDecimal.ZERO;
        if (value instanceof BigDecimal) return (BigDecimal) value;
        if (value instanceof Number) return BigDecimal.valueOf(((Number) value).doubleValue());
        if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (strValue.isEmpty()) return BigDecimal.ZERO;
            try {
                return new BigDecimal(strValue.replace(",", "."));
            } catch (NumberFormatException e) {
                logger.warn("No se pudo convertir '{}' a BigDecimal, usando 0", strValue);
                return BigDecimal.ZERO;
            }
        }
        return BigDecimal.ZERO;
    }

    /**
     * Calcula el resumen de cobranza desde una lista de clientes
     */
    public ResumenCobranza calcularResumen(List<CobranzaClienteAgencia> clientes) {
        BigDecimal debitoMiercoles = BigDecimal.ZERO;
        BigDecimal debitoJueves = BigDecimal.ZERO;
        BigDecimal debitoViernes = BigDecimal.ZERO;
        BigDecimal totalDebito = BigDecimal.ZERO;
        BigDecimal totalCobranzaPura = BigDecimal.ZERO;
        BigDecimal totalExcedente = BigDecimal.ZERO;
        BigDecimal totalLiquidaciones = BigDecimal.ZERO;

        for (CobranzaClienteAgencia c : clientes) {
            totalDebito = totalDebito.add(c.debito());
            totalCobranzaPura = totalCobranzaPura.add(c.cobranzaPura());
            totalExcedente = totalExcedente.add(c.excedente());
            totalLiquidaciones = totalLiquidaciones.add(c.montoLiquidacion());

            String dia = c.diaDePago();
            if (dia != null) {
                if ("MIERCOLES".equalsIgnoreCase(dia)) {
                    debitoMiercoles = debitoMiercoles.add(c.debito());
                } else if ("JUEVES".equalsIgnoreCase(dia)) {
                    debitoJueves = debitoJueves.add(c.debito());
                } else if ("VIERNES".equalsIgnoreCase(dia)) {
                    debitoViernes = debitoViernes.add(c.debito());
                }
            }
        }

        BigDecimal cobranzaTotal = totalCobranzaPura.add(totalExcedente).add(totalLiquidaciones);
        BigDecimal faltante = totalDebito.subtract(totalCobranzaPura);
        BigDecimal rendimiento = BigDecimal.ZERO;
        if (totalDebito.compareTo(BigDecimal.ZERO) > 0) {
            rendimiento = totalCobranzaPura.multiply(BigDecimal.valueOf(100))
                    .divide(totalDebito, 2, RoundingMode.HALF_UP);
        }

        return new ResumenCobranza(
                totalCobranzaPura,
                totalExcedente,
                totalLiquidaciones,
                cobranzaTotal,
                faltante,
                rendimiento,
                debitoMiercoles,
                debitoJueves,
                debitoViernes
        );
    }

    public void close() {
        if (queryExecutor != null) {
            queryExecutor.close();
        }
    }
}
