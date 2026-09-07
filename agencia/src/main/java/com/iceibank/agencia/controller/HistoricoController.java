package com.iceibank.agencia.controller;

import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
public class HistoricoController {

    private final int idAgencia;
    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RegistroEventos registro;

    public HistoricoController(
            int idAgencia,
            ConcurrentHashMap<Integer, Conta> contas,
            RegistroEventos registro
    ) {
        this.idAgencia = idAgencia;
        this.contas = contas;
        this.registro = registro;
    }

    @GetMapping("/contas/{id}/historico")
    public ResponseEntity<?> historico(@PathVariable int id) throws IOException {
        if (ConfigAgencias.agenciaResponsavel(id) != idAgencia) {
            return ResponseEntity.badRequest().body(Map.of(
                    "erro", "Conta " + id + " não pertence a esta agência."
            ));
        }
        if (!contas.containsKey(id)) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }

        List<Map<String, Object>> filtrados = new ArrayList<>();
        for (Map<String, Object> evento : registro.lerTodos()) {
            if (eventoReferenciaConta(evento, id)) {
                filtrados.add(evento);
            }
        }
        return ResponseEntity.ok(filtrados);
    }

    @SuppressWarnings("unchecked")
    private boolean eventoReferenciaConta(Map<String, Object> evento, int idConta) {
        Object detalhesObj = evento.get("detalhes");
        if (!(detalhesObj instanceof Map<?, ?> detalhes)) {
            return false;
        }
        return idIgual(detalhes.get("id"), idConta)
                || idIgual(detalhes.get("idConta"), idConta)
                || idIgual(detalhes.get("idOrigem"), idConta)
                || idIgual(detalhes.get("idDestino"), idConta);
    }

    private boolean idIgual(Object valor, int idConta) {
        if (valor == null) {
            return false;
        }
        if (valor instanceof Number number) {
            return number.intValue() == idConta;
        }
        try {
            return Integer.parseInt(valor.toString()) == idConta;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
