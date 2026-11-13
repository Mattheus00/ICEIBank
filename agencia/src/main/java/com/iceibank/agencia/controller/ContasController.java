package com.iceibank.agencia.controller;

import com.iceibank.agencia.dto.CriarContaRequest;
import com.iceibank.agencia.dto.SincronizarRequest;
import com.iceibank.agencia.dto.ValorRequest;
import com.iceibank.agencia.model.Conta;
import com.iceibank.agencia.service.OperacoesContaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/contas")
public class ContasController {

    private final OperacoesContaService operacoes;

    public ContasController(OperacoesContaService operacoes) {
        this.operacoes = operacoes;
    }

    @PostMapping
    public ResponseEntity<?> criarConta(@Valid @RequestBody CriarContaRequest body) throws IOException {
        double saldoInicial = body.getSaldoInicial() != null ? body.getSaldoInicial() : 0.0;
        Conta conta = operacoes.criarConta(body.getId(), body.getNomeAluno(), saldoInicial);
        return ResponseEntity.status(HttpStatus.CREATED).body(conta);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> consultarSaldo(@PathVariable int id) {
        Map<String, Object> snapshot = operacoes.snapshot(id);
        if (snapshot == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }
        return ResponseEntity.ok(snapshot);
    }

    @PostMapping("/{id}/depositar")
    public ResponseEntity<?> depositar(@PathVariable int id, @Valid @RequestBody ValorRequest body) throws IOException {
        return ResponseEntity.ok(operacoes.depositar(id, body.getValor()));
    }

    @PostMapping("/{id}/sacar")
    public ResponseEntity<?> sacar(@PathVariable int id, @Valid @RequestBody ValorRequest body) throws IOException {
        return ResponseEntity.ok(operacoes.sacar(id, body.getValor()));
    }

    @PostMapping("/{id}/sincronizar")
    public ResponseEntity<?> sincronizar(
            @PathVariable int id,
            @Valid @RequestBody SincronizarRequest body,
            Authentication authentication
    ) throws IOException {
        String usuario = authentication != null ? authentication.getName() : "anon";
        Map<String, Object> resposta = operacoes.sincronizar(
                id,
                body.getTipo(),
                body.getValor(),
                body.getVetorConhecido(),
                body.getOperacaoId(),
                usuario
        );
        return ResponseEntity.ok(resposta);
    }
}
