package com.iceibank.agencia.config;

import java.util.List;

/**
 * Particionamento de contas entre 3 agências.
 * Conta id pertence à agência (id % NUMERO_AGENCIAS).
 */
public final class ConfigAgencias {

    /** Dois últimos dígitos do RA, se rodar em máquina compartilhada do laboratório. */
    public static final int OFFSET = 0;

    public static final int NUMERO_AGENCIAS = 3;
    public static final int PORTA_BASE = 4000 + OFFSET;

    public record Agencia(int id, String url) {}

    public static final List<Agencia> AGENCIAS = List.of(
            new Agencia(0, "http://localhost:" + PORTA_BASE),
            new Agencia(1, "http://localhost:" + (PORTA_BASE + 1)),
            new Agencia(2, "http://localhost:" + (PORTA_BASE + 2))
    );

    private ConfigAgencias() {}

    public static int agenciaResponsavel(int idConta) {
        return Math.floorMod(idConta, NUMERO_AGENCIAS);
    }

    public static int resolveIdAgencia() {
        String env = System.getenv("AGENCIA_ID");
        if (env == null || env.isBlank()) {
            return 0;
        }
        return Integer.parseInt(env.trim());
    }

    public static int portaDaAgencia(int idAgencia) {
        return PORTA_BASE + idAgencia;
    }

    public static Agencia agenciaPorId(int id) {
        return AGENCIAS.stream()
                .filter(a -> a.id() == id)
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Agência não configurada: " + id));
    }
}
