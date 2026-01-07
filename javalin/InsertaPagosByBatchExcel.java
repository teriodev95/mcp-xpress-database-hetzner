package com.clvrt.migrator;

import com.clvrt.db.ConexionSelector;
import com.clvrt.entities.Pay;
import com.clvrt.entities.PayFull;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.text.ParseException;
import java.util.ArrayList;
import java.util.List;

public class InsertaPagosByBatchExcel {

    private static final int BATCH_SIZE = 10_000; // Reducido para evitar bloqueos
    private final List<PayFull> list;
    private final Connection connection;

    public InsertaPagosByBatchExcel(List<PayFull> list) {
        this.list = list;
        this.connection = null;
    }

    public InsertaPagosByBatchExcel(List<PayFull> list, Connection connection) {
        this.list = list;
        this.connection = connection;
    }

    public void start() {
        System.out.println("Total de pagos por insertar: " + list.size());

        List<PayFull> validRecords = new ArrayList<>();
        List<PayFull> invalidRecords = new ArrayList<>();

        // Separar registros válidos e inválidos
        for (PayFull record : list) {
            if (validateRecord(record)) {
                validRecords.add(record);
            } else {
                invalidRecords.add(record);
            }
        }

        // Loggear registros inválidos
        if (!invalidRecords.isEmpty()) {
            System.out.println("Registros inválidos encontrados: " + invalidRecords.size());
            for (PayFull invalid : invalidRecords) {
                System.out.println("Registro inválido: " + invalid);
            }
        }

        System.out.println("Total de pagos válidos para inserción: " + validRecords.size());

        if (validRecords.isEmpty()) {
            System.out.println("No hay registros válidos para insertar.");
            return;
        }

        String query = "REPLACE INTO pagos_excel(" + // Evita duplicados automáticamente
                "PagoID, PrestamoID, Prestamo, Monto, Semana, Anio, EsPrimerPago, " +
                "AbreCon, CierraCon, Tarifa, Cliente, Agente, Tipo, Creado_desde, " +
                "Identificador, Fecha_pago, Comentario) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

        try {
            Connection conn = this.connection != null ? this.connection : ConexionSelector.getConection();
            boolean shouldCloseConnection = (this.connection == null);
            
            try {
                conn.setAutoCommit(false);
                disableIndexes(conn);
                insertInBatches(conn, query, validRecords);
                enableIndexes(conn);
            } finally {
                if (shouldCloseConnection && conn != null) {
                    conn.close();
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    private void insertInBatches(Connection connection, String query, List<PayFull> validRecords) throws SQLException {
        try (PreparedStatement preparedStatement = connection.prepareStatement(query)) {
            int count = 0;

            for (PayFull record : validRecords) {
                try {
                    setPreparedStatement(record, preparedStatement);
                    preparedStatement.addBatch();
                    count++;

                    if (count % BATCH_SIZE == 0) {
                        executeBatch(preparedStatement, connection);
                    }
                } catch (Exception e) {
                    System.err.println("Error al preparar el pago: " + record);
                    e.printStackTrace();
                }
            }

            // Ejecutar lote remanente
            if (count % BATCH_SIZE != 0) {
                executeBatch(preparedStatement, connection);
            }

            connection.commit();
            System.out.println("Inserción completada. Total de registros insertados: " + count);

        } catch (SQLException e) {
            connection.rollback();
            throw e;
        }
    }

    private void executeBatch(PreparedStatement preparedStatement, Connection connection) throws SQLException {
        System.out.println("Ejecutando batch...");
        int[] result = preparedStatement.executeBatch();
        System.out.println("Pagos insertados en este batch: " + result.length);
        preparedStatement.clearBatch();
        connection.commit();
    }

    private static void setPreparedStatement(PayFull pay, PreparedStatement ps) throws SQLException, ParseException {
        Pay prestamo = pay.getPay();

        ps.setString(1, prestamo.getPayId());
        ps.setString(2, prestamo.getLoanId());
        ps.setString(3, prestamo.getLoanId());
        ps.setDouble(4, prestamo.getAmount());
        ps.setInt(5, prestamo.getWeek());
        ps.setInt(6, prestamo.getYear());
        ps.setBoolean(7, prestamo.isFirstPay());
        ps.setDouble(8, prestamo.getOpen());
        ps.setDouble(9, prestamo.getClose());
        ps.setDouble(10, prestamo.getRate());
        ps.setString(11, pay.getClient());
        ps.setString(12, pay.getAgent());
        ps.setString(13, prestamo.getType());
        ps.setString(14, "Migracion");
        ps.setString(15, pay.getIdentifier());
        ps.setString(16, prestamo.getPayDate());
        ps.setString(17, prestamo.getInfo());
    }

    private boolean validateRecord(PayFull payFull) {
        if (payFull == null) return false;
        Pay pay = payFull.getPay();
        return pay != null && validatePay(pay) &&
                !isNullOrEmpty(payFull.getClient()) &&
                !isNullOrEmpty(payFull.getAgent()) &&
                !isNullOrEmpty(payFull.getIdentifier());
    }

    private boolean validatePay(Pay pay) {
        return !isNullOrEmpty(pay.getPayId()) &&
                !isNullOrEmpty(pay.getLoanId()) &&
                pay.getAmount() != null &&
                pay.getWeek() > 0 &&
                pay.getYear() > 0;
    }

    private boolean isNullOrEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }

    private void disableIndexes(Connection connection) {
        try (PreparedStatement ps = connection.prepareStatement("ALTER TABLE pagos_v3 DISABLE KEYS")) {
            ps.execute();
            System.out.println("Índices deshabilitados para mejorar rendimiento.");
        } catch (SQLException e) {
            System.err.println("Error al deshabilitar los índices: " + e.getMessage());
        }
    }

    private void enableIndexes(Connection connection) {
        try (PreparedStatement ps = connection.prepareStatement("ALTER TABLE pagos_v3 ENABLE KEYS")) {
            ps.execute();
            System.out.println("Índices habilitados nuevamente.");
        } catch (SQLException e) {
            System.err.println("Error al habilitar los índices: " + e.getMessage());
        }
    }
}
