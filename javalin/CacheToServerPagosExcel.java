package com.clvrt.cache;

import com.clvrt.dao.PersonaDAO;
import com.clvrt.db.ConexionSelector;
import com.clvrt.entities.LoanFull;
import com.clvrt.entities.PayFull;
import com.clvrt.entities.Persona;
import com.clvrt.entities.PrestamoAux;
import com.clvrt.migrator.Constants;
import com.clvrt.migrator.InsertaPagosByBatch;
import com.clvrt.migrator.InsertaPagosByBatchExcel;
import com.clvrt.migrator.InsertaPrestamosV2;
import com.clvrt.repositoryes.EntityManagerProvider;
import com.clvrt.repositoryes.PrestamoAuxRepository;
import com.clvrt.util.JsonUtil;

import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

public class CacheToServerPagosExcel {

    private static final int semana = 49;
    private static final int year = 2025;

    public static void main(String[] args) {
        PrestamoAuxRepository repository = new PrestamoAuxRepository(
                EntityManagerProvider.getEntityManagerFactory().createEntityManager()
        );


        List<PrestamoAux> prestamosAuxs = repository.findAll();
        List<PayFull> pagosAll = new ArrayList<>();
        List<PayFull> pagosAllAux = new ArrayList<>();
        List<Persona> personas = new ArrayList<>();
        List<LoanFull> prestamos = new ArrayList<>();

        for (PrestamoAux prestamoAux : prestamosAuxs) {

            List<PayFull> pagos = JsonUtil.fromJsonList(prestamoAux.getPagosStr(), PayFull.class);
            Persona cliente = JsonUtil.fromJson(prestamoAux.getClienteStr(), Persona.class);
            Persona aval = JsonUtil.fromJson(prestamoAux.getAvalStr(), Persona.class);
            LoanFull prestamo = JsonUtil.fromJson(prestamoAux.getPrestamoStr(), LoanFull.class);


            pagosAll.addAll(pagos);
            personas.add(cliente);
            personas.add(aval);
            prestamos.add(prestamo);

            prestamo.setClientePersonaId(cliente.getId());
            prestamo.setAvalPersonaId(aval.getId());

        }

        System.out.println("\n\nTotal de prestamos: " + prestamosAuxs.size());
        System.out.println("Total de pagos: " + pagosAll.size());
        System.out.println("Total de personas: " + personas.size());

        if (!confirma()) {
            System.out.println("No se ejecutó el proceso");
            return;
        }
        try {
            System.out.println("Iniciando proceso de insersión en base...");


            //limpiar pagos
            for (PayFull pago : pagosAll) {
                if (pago.getPay().getWeek() == semana && pago.getPay().getYear() == year) {
                    pagosAllAux.add(pago);
                }
            }

            //imprimir la lista ya limpia
            System.out.println("\n\nTotal de pagos limpios: " + pagosAllAux.size());
            for (PayFull pago : pagosAllAux) {
              //  System.out.println(pago.getPay().getWeek() + " " + pago.getPay().getYear());
            }

            InsertaPagosByBatchExcel insertaPagos = new InsertaPagosByBatchExcel(pagosAll);
            insertaPagos.start();


        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private static boolean confirma() {
        Scanner entrada = new Scanner(System.in);
        System.out.println("ESTAS CORRIENDO LA CLASE PARA INGRESAR EL CACHE AL SERVER ¡CONFIRMA!\n" +
                "La conexión es : " + Constants.CONEXION.name() + "\n" +
                "La sucursal actual es : " + Constants.SUCURSAL + "\n" +
                "La semana actual es la " + Constants.SEMANA_ACTUAL + " ? Ingresa: [" + Constants.CONEXION.name() + Constants.SEMANA_ACTUAL + "] para continuar");

        String input = entrada.nextLine();
        return input.equalsIgnoreCase(Constants.CONEXION.name() + Constants.SEMANA_ACTUAL);
    }

}
