package com.iceibank.agencia.controller;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.messaging.MensageriaService;
import com.iceibank.agencia.model.Conta;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
public class TransferenciasController {

    private final int idAgencia;
    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final MensageriaService mensageria;

    public TransferenciasController(
            int idAgencia,
            ConcurrentHashMap<Integer, Conta> contas,
            RelogioVetorial relogio,
            RegistroEventos registro,
            MensageriaService mensageria
    ) {
        this.idAgencia = idAgencia;
        this.contas = contas;
        this.relogio = relogio;
        this.registro = registro;
        this.mensageria = mensageria;
    }

    @PostMapping("/transferencias")
    public ResponseEntity<?> transferir(@Valid @RequestBody TransferenciaRequest body) throws IOException {
        int idOrigem = body.getIdOrigem();
        int idDestino = body.getIdDestino();
        double valor = body.getValor();

        Conta contaOrigem = contas.get(idOrigem);
        if (contaOrigem == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta de origem não encontrada nesta agência."
            ));
        }
        if (contaOrigem.getSaldo() < valor) {
            return ResponseEntity.badRequest().body(Map.of("erro", "Saldo insuficiente."));
        }

        int agenciaDestino = ConfigAgencias.agenciaResponsavel(idDestino);

        int[] vetorDebito = relogio.eventoLocal();
        contaOrigem.setSaldo(contaOrigem.getSaldo() - valor);
        Map<String, Object> detalhesDebito = new LinkedHashMap<>();
        detalhesDebito.put("idOrigem", idOrigem);
        detalhesDebito.put("idDestino", idDestino);
        detalhesDebito.put("valor", valor);
        registro.registrar("TRANSFERENCIA_DEBITO", vetorDebito, detalhesDebito);

        if (agenciaDestino == idAgencia) {
            Conta contaDestino = contas.get(idDestino);
            if (contaDestino == null) {
                contaOrigem.setSaldo(contaOrigem.getSaldo() + valor);
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                        "erro", "Conta de destino não encontrada."
                ));
            }
            int[] vetorCredito = relogio.eventoLocal();
            contaDestino.setSaldo(contaDestino.getSaldo() + valor);
            Map<String, Object> detalhesCredito = new LinkedHashMap<>();
            detalhesCredito.put("idOrigem", idOrigem);
            detalhesCredito.put("idDestino", idDestino);
            detalhesCredito.put("valor", valor);
            registro.registrar("TRANSFERENCIA_CREDITO", vetorCredito, detalhesCredito);
            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (mesma agência)."));
        }

        int[] vetorEnvio = relogio.aoEnviar();
        Map<String, Object> mensagem = new LinkedHashMap<>();
        mensagem.put("idConta", idDestino);
        mensagem.put("valor", valor);
        mensagem.put("vetorEnvio", Arrays.stream(vetorEnvio).boxed().toList());
        mensagem.put("origemAgencia", idAgencia);
        mensageria.publicarCredito(agenciaDestino, mensagem);

        return ResponseEntity.ok(Map.of(
                "mensagem", "Transferência publicada para a agência de destino (entrega assíncrona)."
        ));
    }
}
