package com.iceibank.agencia.messaging;

import com.iceibank.agencia.service.OperacoesContaService;
import org.springframework.amqp.AmqpRejectAndDontRequeueException;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.List;
import java.util.Map;

@Component
public class CreditoConsumer {

    private final OperacoesContaService operacoes;

    public CreditoConsumer(OperacoesContaService operacoes) {
        this.operacoes = operacoes;
    }

    @RabbitListener(queues = "#{filaAgencia.name}")
    public void consumirCredito(Map<String, Object> mensagem) throws IOException {
        int idConta = ((Number) mensagem.get("idConta")).intValue();
        double valor = ((Number) mensagem.get("valor")).doubleValue();
        int origemAgencia = ((Number) mensagem.get("origemAgencia")).intValue();
        int[] vetorEnvio = paraVetor(mensagem.get("vetorEnvio"));

        try {
            operacoes.creditarRemoto(idConta, valor, origemAgencia, vetorEnvio);
        } catch (OperacoesContaService.ContaAusenteException e) {
            throw new AmqpRejectAndDontRequeueException(e.getMessage());
        }
    }

    @RabbitListener(queues = "#{filaDeadLetter.name}")
    public void consumirDeadLetter(Map<String, Object> mensagem) throws IOException {
        operacoes.registrarDeadLetter(mensagem);
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
