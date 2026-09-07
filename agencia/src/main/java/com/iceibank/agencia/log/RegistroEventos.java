package com.iceibank.agencia.log;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class RegistroEventos {

    private final String nomeAgencia;
    private final Path caminhoArquivo;
    private final ObjectMapper mapper = new ObjectMapper();

    public RegistroEventos(String nomeAgencia) throws IOException {
        this.nomeAgencia = nomeAgencia;
        Path pastaDados = Paths.get("data");
        Files.createDirectories(pastaDados);
        this.caminhoArquivo = pastaDados.resolve("eventos-" + nomeAgencia + ".jsonl");
    }

    public synchronized Map<String, Object> registrar(String tipo, int timestampLamport, Map<String, Object> detalhes)
            throws IOException {
        Map<String, Object> evento = new LinkedHashMap<>();
        evento.put("agencia", nomeAgencia);
        evento.put("tipo", tipo);
        evento.put("timestampLamport", timestampLamport);
        evento.put("horaParede", Instant.now().toString());
        evento.put("detalhes", detalhes);

        String linha = mapper.writeValueAsString(evento);
        Files.writeString(
                caminhoArquivo,
                linha + System.lineSeparator(),
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE,
                StandardOpenOption.APPEND
        );
        System.out.println("[Lamport " + timestampLamport + "] " + tipo + " " + detalhes);
        return evento;
    }

    public synchronized List<Map<String, Object>> lerTodos() throws IOException {
        List<Map<String, Object>> eventos = new ArrayList<>();
        if (!Files.exists(caminhoArquivo)) {
            return eventos;
        }
        List<String> linhas = Files.readAllLines(caminhoArquivo, StandardCharsets.UTF_8);
        for (String linha : linhas) {
            if (linha == null || linha.isBlank()) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> evento = mapper.readValue(linha, Map.class);
            eventos.add(evento);
        }
        return eventos;
    }

    public Path getCaminhoArquivo() {
        return caminhoArquivo;
    }

    public String getNomeAgencia() {
        return nomeAgencia;
    }
}
