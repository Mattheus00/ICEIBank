package com.iceibank.agencia.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestTemplate;

import com.iceibank.agencia.clock.RelogioLamport;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;

@Configuration
public class AgenciaBeansConfig {

    @Bean
    int idAgencia() {
        return ConfigAgencias.resolveIdAgencia();
    }

    @Bean
    RelogioLamport relogioLamport() {
        return new RelogioLamport();
    }

    @Bean
    RegistroEventos registroEventos(int idAgencia) throws IOException {
        return new RegistroEventos("agencia-" + idAgencia);
    }

    @Bean
    ConcurrentHashMap<Integer, Conta> contas() {
        return new ConcurrentHashMap<>();
    }

    @Bean
    RestTemplate restTemplate() {
        return new RestTemplate();
    }
}
