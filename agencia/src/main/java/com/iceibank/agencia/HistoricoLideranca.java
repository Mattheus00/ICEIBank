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
import java.util.Set;
import java.util.stream.Stream;

/**
 * Lê os .jsonl e monta o histórico de lideranças (eventos Bully).
 * Ordenação por hora de parede — útil para apresentação, sem provar
 * ordem causal total entre máquinas.
 *
 * Executar a partir da pasta agencia/:
 *   mvn -q exec:java "-Dexec.mainClass=com.iceibank.agencia.HistoricoLideranca"
 */
public class HistoricoLideranca {

    private static final Set<String> EVENTOS_BULLY = Set.of(
            "ELEICAO_INICIADA",
            "ELEICAO_RECEBIDA",
            "TORNOU_LIDER",
            "LIDER_ANUNCIADO",
            "LIDER_NAO_RESPONDEU"
    );

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        Path pastaDados = Paths.get("data");
        if (!Files.isDirectory(pastaDados)) {
            System.err.println("Pasta data/ não encontrada. Execute a partir de agencia/ após gerar eventos.");
            System.exit(1);
        }

        ObjectMapper mapper = new ObjectMapper();
        List<Map<String, Object>> eventos = new ArrayList<>();

        try (Stream<Path> arquivos = Files.list(pastaDados)) {
            List<Path> jsonl = arquivos
                    .filter(p -> p.getFileName().toString().endsWith(".jsonl"))
                    .toList();

            for (Path arquivo : jsonl) {
                for (String linha : Files.readAllLines(arquivo, StandardCharsets.UTF_8)) {
                    if (linha == null || linha.isBlank()) {
                        continue;
                    }
                    Map<String, Object> evento = mapper.readValue(linha, Map.class);
                    Object tipo = evento.get("tipo");
                    if (tipo != null && EVENTOS_BULLY.contains(tipo.toString())) {
                        eventos.add(evento);
                    }
                }
            }
        }

        eventos.sort(Comparator.comparing(e -> Instant.parse(e.get("horaParede").toString())));

        System.out.println("=== Historico de liderancas (ordenado por hora de parede) ===");
        System.out.println("(A ordem por relogio de parede nao prova ordem causal total entre maquinas.)");
        System.out.println();

        if (eventos.isEmpty()) {
            System.out.println("(nenhum evento Bully encontrado - rode as agencias e uma eleicao antes)");
            return;
        }

        for (Map<String, Object> evento : eventos) {
            System.out.println(
                    evento.get("horaParede")
                            + "  [" + evento.get("agencia") + "] "
                            + evento.get("tipo")
                            + "  " + mapper.writeValueAsString(evento.get("detalhes"))
            );
        }

        System.out.println();
        System.out.println("=== Resumo: quem se tornou lider ===");
        List<Map<String, Object>> tornaram = eventos.stream()
                .filter(e -> "TORNOU_LIDER".equals(String.valueOf(e.get("tipo"))))
                .toList();

        if (tornaram.isEmpty()) {
            System.out.println("(nenhum TORNOU_LIDER nesta execucao)");
            return;
        }

        for (int i = 0; i < tornaram.size(); i++) {
            Map<String, Object> atual = tornaram.get(i);
            String inicio = String.valueOf(atual.get("horaParede"));
            String fim = (i + 1 < tornaram.size())
                    ? String.valueOf(tornaram.get(i + 1).get("horaParede"))
                    : "ainda vigente / fim da janela observada";
            Object detalhes = atual.get("detalhes");
            System.out.println(
                    "- " + atual.get("agencia") + " TORNOU_LIDER em " + inicio
                            + "  detalhes=" + mapper.writeValueAsString(detalhes)
                            + "  ate " + fim
            );
        }

        System.out.println();
        System.out.println("Obs.: anuncios LIDER_ANUNCIADO na fase inicial podem ser temporarios;");
        System.out.println("periodos de estabilidade sao os trechos entre TORNOU_LIDER consecutivos.");
    }
}
