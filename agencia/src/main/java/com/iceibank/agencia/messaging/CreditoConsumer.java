package com.iceibank.agencia.messaging;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.springframework.amqp.AmqpRejectAndDontRequeueException;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class CreditoConsumer {

    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;

    public CreditoConsumer(
            ConcurrentHashMap<Integer, Conta> contas,
            RelogioVetorial relogio,
            RegistroEventos registro
    ) {
        this.contas = contas;
        this.relogio = relogio;
        this.registro = registro;
    }

    @RabbitListener(queues = "#{filaAgencia.name}")
    public void consumirCredito(Map<String, Object> mensagem) throws IOException {
        int idConta = ((Number) mensagem.get("idConta")).intValue();
        double valor = ((Number) mensagem.get("valor")).doubleValue();
        int origemAgencia = ((Number) mensagem.get("origemAgencia")).intValue();
        int[] vetorEnvio = paraVetor(mensagem.get("vetorEnvio"));

        int[] vetor = relogio.aoReceber(vetorEnvio);
        Conta conta = contas.get(idConta);

        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idConta", idConta);
        detalhes.put("valor", valor);
        detalhes.put("origemAgencia", origemAgencia);

        if (conta == null) {
            detalhes.put("motivo", "conta nao encontrada");
            registro.registrar("CREDITO_REMOTO_FALHOU", vetor, detalhes);
            throw new AmqpRejectAndDontRequeueException("conta nao encontrada");
        }

        conta.setSaldo(conta.getSaldo() + valor);
        registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", vetor, detalhes);
    }

    @RabbitListener(queues = "#{filaDeadLetter.name}")
    public void consumirDeadLetter(Map<String, Object> mensagem) throws IOException {
        int[] vetor = relogio.eventoLocal();
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idConta", mensagem.get("idConta"));
        detalhes.put("valor", mensagem.get("valor"));
        detalhes.put("origemAgencia", mensagem.get("origemAgencia"));
        detalhes.put("motivo", "mensagem enviada para dead-letter (conta nao encontrada)");
        registro.registrar("DEAD_LETTER", vetor, detalhes);
    }

    private int[] paraVetor(Object valor) {
        if (valor instanceof List<?> lista) {
            int[] vetor = new int[lista.size()];
            for (int i = 0; i < lista.size(); i++) {
                vetor[i] = ((Number) lista.get(i)).intValue();
            }
            return vetor;
        }
        throw new IllegalArgumentException("vetorEnvio ausente ou invalido");
    }
}
