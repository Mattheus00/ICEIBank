package com.iceibank.agencia.controller;

import com.iceibank.agencia.clock.RelogioLamport;
import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.dto.CreditoRemotoRequest;
import com.iceibank.agencia.dto.TransferenciaRequest;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@RestController
public class TransferenciasController {

    private final int idAgencia;
    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RelogioLamport relogio;
    private final RegistroEventos registro;
    private final RestTemplate restTemplate;
    private final String internalToken;

    public TransferenciasController(
            int idAgencia,
            ConcurrentHashMap<Integer, Conta> contas,
            RelogioLamport relogio,
            RegistroEventos registro,
            RestTemplate restTemplate,
            @Value("${iceibank.internal-token}") String internalToken
    ) {
        this.idAgencia = idAgencia;
        this.contas = contas;
        this.relogio = relogio;
        this.registro = registro;
        this.restTemplate = restTemplate;
        this.internalToken = internalToken;
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

        int tsDebito = relogio.eventoLocal();
        contaOrigem.setSaldo(contaOrigem.getSaldo() - valor);
        Map<String, Object> detalhesDebito = new LinkedHashMap<>();
        detalhesDebito.put("idOrigem", idOrigem);
        detalhesDebito.put("idDestino", idDestino);
        detalhesDebito.put("valor", valor);
        registro.registrar("TRANSFERENCIA_DEBITO", tsDebito, detalhesDebito);

        if (agenciaDestino == idAgencia) {
            Conta contaDestino = contas.get(idDestino);
            if (contaDestino == null) {
                contaOrigem.setSaldo(contaOrigem.getSaldo() + valor);
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                        "erro", "Conta de destino não encontrada."
                ));
            }
            int tsCredito = relogio.eventoLocal();
            contaDestino.setSaldo(contaDestino.getSaldo() + valor);
            Map<String, Object> detalhesCredito = new LinkedHashMap<>();
            detalhesCredito.put("idOrigem", idOrigem);
            detalhesCredito.put("idDestino", idDestino);
            detalhesCredito.put("valor", valor);
            registro.registrar("TRANSFERENCIA_CREDITO", tsCredito, detalhesCredito);
            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (mesma agência)."));
        }

        int tsEnvio = relogio.aoEnviar();
        String urlDestino = ConfigAgencias.agenciaPorId(agenciaDestino).url()
                + "/contas/" + idDestino + "/creditar-remoto";

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("X-Internal-Token", internalToken);

            Map<String, Object> payload = new LinkedHashMap<>();
            payload.put("valor", valor);
            payload.put("timestampLamport", tsEnvio);
            payload.put("origemAgencia", idAgencia);

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(payload, headers);
            restTemplate.exchange(urlDestino, HttpMethod.POST, entity, Map.class);

            return ResponseEntity.ok(Map.of("mensagem", "Transferência concluída (entre agências)."));
        } catch (RestClientException erro) {
            // LIMITAÇÃO CONHECIDA: débito NÃO é revertido (Sprint 4: 2PC/Saga)
            Map<String, Object> detalhesFalha = new LinkedHashMap<>();
            detalhesFalha.put("idOrigem", idOrigem);
            detalhesFalha.put("idDestino", idDestino);
            detalhesFalha.put("valor", valor);
            detalhesFalha.put("erro", erro.getMessage());
            registro.registrar("TRANSFERENCIA_FALHOU", relogio.eventoLocal(), detalhesFalha);

            return ResponseEntity.status(HttpStatus.BAD_GATEWAY).body(Map.of(
                    "erro",
                    "Falha ao contatar agência de destino. Débito já aplicado - inconsistência conhecida (ver Sprint 4)."
            ));
        }
    }

    @PostMapping("/contas/{id}/creditar-remoto")
    public ResponseEntity<?> creditarRemoto(
            @PathVariable int id,
            @Valid @RequestBody CreditoRemotoRequest body
    ) throws IOException {
        int ts = relogio.aoReceber(body.getTimestampLamport());

        Conta conta = contas.get(id);
        if (conta == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of(
                    "erro", "Conta não encontrada nesta agência."
            ));
        }

        conta.setSaldo(conta.getSaldo() + body.getValor());
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idConta", id);
        detalhes.put("valor", body.getValor());
        detalhes.put("origemAgencia", body.getOrigemAgencia());
        registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", ts, detalhes);

        return ResponseEntity.ok(Map.of(
                "mensagem", "Crédito remoto aplicado.",
                "saldoAtual", conta.getSaldo()
        ));
    }
}
