package com.iceibank.agencia.messaging;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class MensageriaService {

    private final RabbitTemplate rabbitTemplate;

    public MensageriaService(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publicarCredito(int agenciaDestino, Map<String, Object> mensagem) {
        String routingKey = "agencia." + agenciaDestino + ".creditar";
        rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE, routingKey, mensagem);
        System.out.println("[RabbitMQ] publicado " + routingKey + " " + mensagem);
    }
}
