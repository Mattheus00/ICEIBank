package com.iceibank.agencia.controller;

import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.messaging.MensageriaService;
import com.iceibank.agencia.service.OperacoesContaService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class TransferenciasController {

    private final int idAgencia;
    private final OperacoesContaService operacoes;
    private final MensageriaService mensageria;

    public TransferenciasController(
            int idAgencia,
            OperacoesContaService operacoes,
            MensageriaService mensageria
    ) {
        this.idAgencia = idAgencia;
        this.operacoes = operacoes;
        this.mensageria = mensageria;
    }

    @PostMapping("/transferencias")
    public ResponseEntity<?> transferir(@Valid @RequestBody TransferenciaRequest body) throws IOException {
        OperacoesContaService.ResultadoDebitoTransferencia resultado = operacoes.debitarParaTransferencia(
                body.getIdOrigem(),
                body.getIdDestino(),
                body.getValor()
        );

        if (resultado.local()) {
            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (mesma agência)."));
        }

        Map<String, Object> mensagem = new LinkedHashMap<>();
        mensagem.put("idConta", body.getIdDestino());
        mensagem.put("valor", body.getValor());
        mensagem.put("vetorEnvio", Arrays.stream(resultado.vetorEnvio()).boxed().toList());
        mensagem.put("origemAgencia", idAgencia);
        mensageria.publicarCredito(resultado.agenciaDestino(), mensagem);

        return ResponseEntity.ok(Map.of(
                "mensagem", "Transferência publicada para a agência de destino (entrega assíncrona)."
        ));
    }
}
