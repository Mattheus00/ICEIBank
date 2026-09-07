package com.iceibank.agencia.controller;

import com.iceibank.agencia.clock.RelogioLamport;
import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.dto.CriarContaRequest;
import com.iceibank.agencia.dto.ValorRequest;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/contas")
public class ContasController {

    private final int idAgencia;
    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RelogioLamport relogio;
    private final RegistroEventos registro;

    public ContasController(
            int idAgencia,
            ConcurrentHashMap<Integer, Conta> contas,
            RelogioLamport relogio,
            RegistroEventos registro
    ) {
        this.idAgencia = idAgencia;
        this.contas = contas;
        this.relogio = relogio;
        this.registro = registro;
    }

    @PostMapping
    public ResponseEntity<?> criarConta(@Valid @RequestBody CriarContaRequest body) throws IOException {
        int id = body.getId();
        if (ConfigAgencias.agenciaResponsavel(id) != idAgencia) {
            return ResponseEntity.badRequest().body(Map.of(
                    "erro", "Conta " + id + " não pertence a esta agência."
            ));
        }
        if (contas.containsKey(id)) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("erro", "Conta já existe."));
        }

        double saldoInicial = body.getSaldoInicial() != null ? body.getSaldoInicial() : 0.0;
        int ts = relogio.eventoLocal();
        Conta conta = new Conta(id, body.getNomeAluno(), saldoInicial);
        contas.put(id, conta);

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("nomeAluno", body.getNomeAluno());
        detalhes.put("saldoInicial", saldoInicial);
        registro.registrar("CRIAR_CONTA", ts, detalhes);

        return ResponseEntity.status(HttpStatus.CREATED).body(conta);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> consultarSaldo(@PathVariable int id) {
        Conta conta = contas.get(id);
        if (conta == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }
        return ResponseEntity.ok(conta);
    }

    @PostMapping("/{id}/depositar")
    public ResponseEntity<?> depositar(@PathVariable int id, @Valid @RequestBody ValorRequest body) throws IOException {
        Conta conta = contas.get(id);
        if (conta == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }

        int ts = relogio.eventoLocal();
        conta.setSaldo(conta.getSaldo() + body.getValor());

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("valor", body.getValor());
        detalhes.put("novoSaldo", conta.getSaldo());
        registro.registrar("DEPOSITO", ts, detalhes);

        return ResponseEntity.ok(conta);
    }

    @PostMapping("/{id}/sacar")
    public ResponseEntity<?> sacar(@PathVariable int id, @Valid @RequestBody ValorRequest body) throws IOException {
        Conta conta = contas.get(id);
        if (conta == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }
        if (conta.getSaldo() < body.getValor()) {
            return ResponseEntity.badRequest().body(Map.of("erro", "Saldo insuficiente."));
        }

        int ts = relogio.eventoLocal();
        conta.setSaldo(conta.getSaldo() - body.getValor());

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("id", id);
        detalhes.put("valor", body.getValor());
        detalhes.put("novoSaldo", conta.getSaldo());
        registro.registrar("SAQUE", ts, detalhes);

        return ResponseEntity.ok(conta);
    }
}
