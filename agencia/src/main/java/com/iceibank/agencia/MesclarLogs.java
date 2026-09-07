package com.iceibank.agencia;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/**
 * Lê os .jsonl de todas as agências e imprime a linha do tempo
 * ordenada por relógio de Lamport.
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
                    todosEventos.add(mapper.readValue(linha, Map.class));
                }
            }
        }

        todosEventos.sort(Comparator.comparingInt(e -> ((Number) e.get("timestampLamport")).intValue()));

        System.out.println("=== Linha do tempo unificada (ordenada por relogio de Lamport) ===");
        for (Map<String, Object> evento : todosEventos) {
            System.out.println(
                    "[Lamport " + evento.get("timestampLamport") + "] ("
                            + evento.get("horaParede") + ") "
                            + evento.get("agencia") + " - "
                            + evento.get("tipo") + " "
                            + mapper.writeValueAsString(evento.get("detalhes"))
            );
        }
    }
}
