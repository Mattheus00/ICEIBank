package com.iceibank.agencia;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/**
 * Lê os .jsonl e mostra a linha do tempo, apontando pares concorrentes
 * entre agências diferentes pelo relógio vetorial.
 *
 * Executar a partir da pasta agencia/:
 *   mvn -q exec:java -Dexec.mainClass="com.iceibank.agencia.MesclarLogs"
 */
public class MesclarLogs {

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        Path pastaDados = Paths.get("data");
        if (!Files.isDirectory(pastaDados)) {
            System.err.println("Pasta data/ não encontrada. Execute a partir de agencia/ após gerar eventos.");
            System.exit(1);
        }

        ObjectMapper mapper = new ObjectMapper();
        List<Map<String, Object>> todosEventos = new ArrayList<>();

        try (Stream<Path> arquivos = Files.list(pastaDados)) {
            List<Path> jsonl = arquivos
                    .filter(p -> p.getFileName().toString().endsWith(".jsonl"))
                    .toList();

            for (Path arquivo : jsonl) {
                List<String> linhas = Files.readAllLines(arquivo, StandardCharsets.UTF_8);
                for (String linha : linhas) {
                    if (linha == null || linha.isBlank()) {
                        continue;
                    }
                    Map<String, Object> evento = mapper.readValue(linha, Map.class);
                    if (evento.get("timestampVetorial") != null) {
                        todosEventos.add(evento);
                    }
                }
            }
        }

        todosEventos.sort(Comparator.comparing(e -> Instant.parse(e.get("horaParede").toString())));

        System.out.println("=== Linha do tempo (ordenada por hora de parede) ===");
        for (Map<String, Object> evento : todosEventos) {
            System.out.println(
                    "[" + evento.get("agencia") + "] vetor=" + evento.get("timestampVetorial")
                            + " " + evento.get("tipo") + " "
                            + mapper.writeValueAsString(evento.get("detalhes"))
            );
        }

        System.out.println("\n=== Pares de eventos CONCORRENTES entre agências diferentes ===");
        boolean encontrou = false;
        for (int i = 0; i < todosEventos.size(); i++) {
            for (int j = i + 1; j < todosEventos.size(); j++) {
                Map<String, Object> e1 = todosEventos.get(i);
                Map<String, Object> e2 = todosEventos.get(j);
                if (e1.get("agencia").equals(e2.get("agencia"))) {
                    continue;
                }
                if ("CONCORRENTES".equals(com.iceibank.agencia.clock.ComparadorVetores.comparar(paraVetor(e1), paraVetor(e2)))) {
                    encontrou = true;
                    System.out.println(
                            "[" + e1.get("agencia") + "] " + e1.get("tipo") + " (" + e1.get("timestampVetorial") + ") x "
                                    + "[" + e2.get("agencia") + "] " + e2.get("tipo") + " (" + e2.get("timestampVetorial") + ")"
                    );
                }
            }
        }
        if (!encontrou) {
            System.out.println("(nenhum par concorrente encontrado nesta execução - gere mais eventos em paralelo e rode de novo)");
        }
    }

    @SuppressWarnings("unchecked")
    private static int[] paraVetor(Map<String, Object> evento) {
        List<Number> lista = (List<Number>) evento.get("timestampVetorial");
        int[] vetor = new int[lista.size()];
        for (int i = 0; i < lista.size(); i++) {
            vetor[i] = lista.get(i).intValue();
        }
        return vetor;
    }

}
