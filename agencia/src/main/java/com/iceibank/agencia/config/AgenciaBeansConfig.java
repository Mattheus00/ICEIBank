package com.iceibank.agencia.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.iceibank.agencia.clock.RelogioVetorial;
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
    RelogioVetorial relogioVetorial(int idAgencia) {
        return new RelogioVetorial(idAgencia, ConfigAgencias.NUMERO_AGENCIAS);
    }

    @Bean
    RegistroEventos registroEventos(int idAgencia) throws IOException {
        return new RegistroEventos("agencia-" + idAgencia);
    }

    @Bean
    ConcurrentHashMap<Integer, Conta> contas() {
        return new ConcurrentHashMap<>();
    }

}
