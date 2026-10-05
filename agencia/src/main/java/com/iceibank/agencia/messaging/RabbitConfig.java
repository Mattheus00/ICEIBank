package com.iceibank.agencia.messaging;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.amqp.rabbit.connection.CachingConnectionFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.amqp.core.MessageDeliveryMode;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.net.URISyntaxException;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.Map;

@Configuration
public class RabbitConfig {

    public static final String EXCHANGE = "iceibank.eventos";
    public static final String DLX = "iceibank.dlx";

    @Bean
    ConnectionFactory connectionFactory(int idAgencia) {
        String url = urlDoAmbiente();
        try {
            com.rabbitmq.client.ConnectionFactory cliente = new com.rabbitmq.client.ConnectionFactory();
            cliente.setUri(url);
            if (cliente.getHost() == null || cliente.getHost().isBlank()) {
                throw new IllegalStateException("RABBITMQ_URL sem host.");
            }
            System.out.println("[Agência " + idAgencia + "] RabbitMQ em " + cliente.getHost() + ":" + cliente.getPort());
            CachingConnectionFactory factory = new CachingConnectionFactory(cliente);
            factory.setConnectionNameStrategy(cf -> "agencia-" + idAgencia);
            return factory;
        } catch (URISyntaxException | NoSuchAlgorithmException | KeyManagementException e) {
            throw new IllegalStateException(
                    "RABBITMQ_URL invalida. Cole a URL amqps:// do painel do CloudAMQP, entre aspas.",
                    e
            );
        }
    }

    private static String urlDoAmbiente() {
        String url = System.getenv("RABBITMQ_URL");
        if (url == null || url.isBlank()) {
            throw new IllegalStateException(
                    "Defina RABBITMQ_URL neste terminal, antes do mvn spring-boot:run."
            );
        }
        url = url.trim();
        if ((url.startsWith("\"") && url.endsWith("\"")) || (url.startsWith("'") && url.endsWith("'"))) {
            url = url.substring(1, url.length() - 1).trim();
        }
        if (url.contains("sua url") || url.contains("...")) {
            throw new IllegalStateException(
                    "RABBITMQ_URL ainda esta com o texto de exemplo. Cole a URL amqps:// do CloudAMQP."
            );
        }
        return url;
    }

    @Bean
    TopicExchange eventosExchange() {
        return new TopicExchange(EXCHANGE, true, false);
    }

    @Bean
    TopicExchange deadLetterExchange() {
        return new TopicExchange(DLX, true, false);
    }

    @Bean
    Queue filaAgencia(int idAgencia) {
        Map<String, Object> args = new HashMap<>();
        args.put("x-dead-letter-exchange", DLX);
        args.put("x-dead-letter-routing-key", "agencia." + idAgencia + ".dlq");
        return new Queue(nomeFila(idAgencia), true, false, false, args);
    }

    @Bean
    Queue filaDeadLetter(int idAgencia) {
        return new Queue(nomeFilaDeadLetter(idAgencia), true);
    }

    @Bean
    Binding bindFilaCredito(Queue filaAgencia, TopicExchange eventosExchange, int idAgencia) {
        return BindingBuilder.bind(filaAgencia).to(eventosExchange).with("agencia." + idAgencia + ".creditar");
    }

    @Bean
    Binding bindFilaDeadLetter(Queue filaDeadLetter, TopicExchange deadLetterExchange, int idAgencia) {
        return BindingBuilder.bind(filaDeadLetter).to(deadLetterExchange).with("agencia." + idAgencia + ".dlq");
    }

    @Bean
    MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    RabbitTemplate rabbitTemplate(ConnectionFactory connectionFactory, MessageConverter jsonMessageConverter) {
        RabbitTemplate template = new RabbitTemplate(connectionFactory);
        template.setMessageConverter(jsonMessageConverter);
        template.setBeforePublishPostProcessors(message -> {
            message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
            return message;
        });
        return template;
    }

    public static String nomeFila(int idAgencia) {
        return "fila-agencia-" + idAgencia;
    }

    public static String nomeFilaDeadLetter(int idAgencia) {
        return "fila-agencia-" + idAgencia + ".dlq";
    }
}
