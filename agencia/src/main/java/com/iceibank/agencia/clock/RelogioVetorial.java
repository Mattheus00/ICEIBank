package com.iceibank.agencia.clock;

import java.util.Arrays;

/**
 * Relógio vetorial: uma posição por agência.
 * synchronized porque o Spring atende várias requisições ao mesmo tempo.
 */
public class RelogioVetorial {

    private final int idAgencia;
    private final int[] vetor;

    public RelogioVetorial(int idAgencia, int numeroAgencias) {
        this.idAgencia = idAgencia;
        this.vetor = new int[numeroAgencias];
    }

    public synchronized int[] eventoLocal() {
        vetor[idAgencia] += 1;
        return vetor.clone();
    }

    public synchronized int[] aoEnviar() {
        vetor[idAgencia] += 1;
        return vetor.clone();
    }

    public synchronized int[] aoReceber(int[] vetorRecebido) {
        for (int i = 0; i < vetor.length; i++) {
            vetor[i] = Math.max(vetor[i], vetorRecebido[i]);
        }
        vetor[idAgencia] += 1;
        return vetor.clone();
    }

    public synchronized int[] copia() {
        return vetor.clone();
    }

    public static int[] copiaDe(int[] origem) {
        return Arrays.copyOf(origem, origem.length);
    }
}
