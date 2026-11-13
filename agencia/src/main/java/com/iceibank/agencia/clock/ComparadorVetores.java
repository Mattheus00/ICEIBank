package com.iceibank.agencia.clock;

import com.iceibank.agencia.config.ConfigAgencias;

import java.util.List;

public final class ComparadorVetores {

    private ComparadorVetores() {}

    public static String comparar(int[] v1, int[] v2) {
        if (v1 == null || v2 == null || v1.length != v2.length) {
            throw new IllegalArgumentException("vetores devem ter o mesmo tamanho e nao ser nulos");
        }
        boolean v1MenorOuIgual = true;
        boolean v2MenorOuIgual = true;
        for (int i = 0; i < v1.length; i++) {
            if (v1[i] > v2[i]) {
                v1MenorOuIgual = false;
            }
            if (v2[i] > v1[i]) {
                v2MenorOuIgual = false;
            }
        }
        if (v1MenorOuIgual && v2MenorOuIgual) {
            return "IGUAIS";
        }
        if (v1MenorOuIgual) {
            return "ANTES";
        }
        if (v2MenorOuIgual) {
            return "DEPOIS";
        }
        return "CONCORRENTES";
    }

    public static int[] validarECopiar(List<Integer> lista) {
        if (lista == null || lista.size() != ConfigAgencias.NUMERO_AGENCIAS) {
            throw new IllegalArgumentException(
                    "vetor deve ter " + ConfigAgencias.NUMERO_AGENCIAS + " posicoes"
            );
        }
        int[] vetor = new int[lista.size()];
        for (int i = 0; i < lista.size(); i++) {
            Integer v = lista.get(i);
            if (v == null || v < 0) {
                throw new IllegalArgumentException("vetor nao pode ter nulos ou negativos");
            }
            vetor[i] = v;
        }
        return vetor;
    }

    public static List<Integer> paraLista(int[] vetor) {
        return java.util.Arrays.stream(vetor).boxed().toList();
    }
}
