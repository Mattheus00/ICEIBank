package com.iceibank.agencia.controller;

import com.iceibank.agencia.bully.BullyService;
import com.iceibank.agencia.dto.CoordenadorRequest;
import com.iceibank.agencia.dto.EleicaoRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/bully")
public class BullyController {

    private final BullyService bullyService;

    public BullyController(BullyService bullyService) {
        this.bullyService = bullyService;
    }

    @PostMapping("/eleicao")
    public ResponseEntity<?> receberEleicao(@Valid @RequestBody EleicaoRequest body) throws IOException {
        try {
            int[] vetor = BullyService.paraVetor(body.getVetor());
            bullyService.receberEleicao(body.getIdOrigem(), vetor);
            return ResponseEntity.ok(Map.of("mensagem", "OK"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("erro", e.getMessage()));
        }
    }

    @PostMapping("/coordenador")
    public ResponseEntity<?> receberCoordenador(@Valid @RequestBody CoordenadorRequest body) throws IOException {
        try {
            int[] vetor = BullyService.paraVetor(body.getVetor());
            bullyService.receberCoordenador(body.getIdLider(), vetor);
            return ResponseEntity.ok(Map.of("mensagem", "coordenador registrado"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("erro", e.getMessage()));
        }
    }

    @GetMapping("/lider")
    public Map<String, Object> consultarLider() {
        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("idAgencia", bullyService.getIdAgencia());
        Integer lider = bullyService.getLiderAtual();
        resposta.put("liderAtual", lider);
        resposta.put("estado", lider == null ? "DESCONHECIDO" : "CONHECIDO");
        return resposta;
    }
}
