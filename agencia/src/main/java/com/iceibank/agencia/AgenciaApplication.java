package com.iceibank.agencia;

import com.iceibank.agencia.config.ConfigAgencias;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration;

@SpringBootApplication(exclude = {UserDetailsServiceAutoConfiguration.class})
public class AgenciaApplication {

    public static void main(String[] args) {
        int idAgencia = ConfigAgencias.resolveIdAgencia();
        int porta = ConfigAgencias.portaDaAgencia(idAgencia);

        // System properties têm prioridade sobre application.yml
        System.setProperty("server.port", String.valueOf(porta));
        System.setProperty("iceibank.agencia-id", String.valueOf(idAgencia));

        System.out.println("[Agência " + idAgencia + "] iniciando na porta " + porta);
        SpringApplication.run(AgenciaApplication.class, args);
    }
}
