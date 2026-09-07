package com.iceibank.agencia.clock;

/**
 * Relógio lógico de Lamport (contador por processo).
 * synchronized: Spring Boot atende requisições em threads concorrentes.
 */
public class RelogioLamport {

    private int contador = 0;

    public synchronized int eventoLocal() {
        contador += 1;
        return contador;
    }

    public synchronized int aoEnviar() {
        contador += 1;
        return contador;
    }

    public synchronized int aoReceber(int timestampRecebido) {
        contador = Math.max(contador, timestampRecebido) + 1;
        return contador;
    }

    public synchronized int getContador() {
        return contador;
    }
}
