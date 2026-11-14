package com.iceibank.agencia.bully;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

class BullyServiceTest {
    @TempDir Path temp;

    private static class Rede extends RestTemplate {
        volatile boolean maiorResponde = true;
        final CountDownLatch anuncios = new CountDownLatch(2);

        @Override
        public <T> ResponseEntity<T> postForEntity(
                String url, Object request, Class<T> type, Object... variables) {
            if (url.endsWith("/eleicao") && !maiorResponde) {
                throw new ResourceAccessException("peer indisponivel");
            }
            if (url.endsWith("/coordenador")) anuncios.countDown();
            return ResponseEntity.ok(type.cast("OK"));
        }
    }

    @Test
    void okSemAnuncioNaoAutorizaLiderMenorENovaEleicaoPodeRecuperar() throws Exception {
        Rede rede = new Rede();
        BullyService bully = new BullyService(1, new RelogioVetorial(1, 3),
                new RegistroEventos("agencia-1", temp), rede);
        try {
            bully.iniciarEleicao(); // agência 2 responde OK, mas nunca anuncia
            assertNull(bully.getLiderAtual());
            rede.maiorResponde = false;
            bully.iniciarEleicao(); // na nova tentativa a maior realmente está ausente
            assertEquals(1, bully.getLiderAtual());
        } finally {
            bully.encerrar();
        }
    }

    @Test
    void agenciaMaiorRejeitaCoordenadorMenorEAnunciaEleicaoCorreta() throws Exception {
        Rede rede = new Rede();
        BullyService bully = new BullyService(2, new RelogioVetorial(2, 3),
                new RegistroEventos("agencia-2", temp), rede);
        try {
            bully.receberCoordenador(1, new int[]{0, 1, 0});
            assertNotEquals(Integer.valueOf(1), bully.getLiderAtual());
            assertTrue(rede.anuncios.await(3, TimeUnit.SECONDS));
            assertEquals(2, bully.getLiderAtual());
        } finally {
            bully.encerrar();
        }
    }

    @Test
    void anuncioMaiorRecebidoDuranteEleicaoImpedeAutoproclamacao() throws Exception {
        BullyService[] servico = new BullyService[1];
        RestTemplate rede = new RestTemplate() {
            @Override
            public <T> ResponseEntity<T> postForEntity(
                    String url, Object request, Class<T> type, Object... variables) {
                try {
                    servico[0].receberCoordenador(2, new int[]{0, 0, 1});
                } catch (Exception e) {
                    throw new AssertionError(e);
                }
                // Simula timeout da resposta de eleição depois de chegar o anúncio.
                throw new ResourceAccessException("resposta perdida");
            }
        };
        servico[0] = new BullyService(1, new RelogioVetorial(1, 3),
                new RegistroEventos("agencia-1", temp), rede);
        try {
            servico[0].iniciarEleicao();
            assertEquals(2, servico[0].getLiderAtual());
        } finally {
            servico[0].encerrar();
        }
    }

    @Test
    void heartbeatElegeSubstitutaQuandoLiderParaDeResponder() throws Exception {
        Rede rede = new Rede() {
            @Override
            public <T> ResponseEntity<T> getForEntity(String url, Class<T> type, Object... variables) {
                throw new ResourceAccessException("lider caiu");
            }
        };
        rede.maiorResponde = false;
        BullyService bully = new BullyService(1, new RelogioVetorial(1, 3),
                new RegistroEventos("agencia-1", temp), rede);
        try {
            bully.receberCoordenador(2, new int[]{0, 0, 1});
            // Invoca a verificação sem aguardar o agendador: mesma rotina do heartbeat.
            var verificar = BullyService.class.getDeclaredMethod("verificarLider");
            verificar.setAccessible(true);
            verificar.invoke(bully);
            assertTrue(rede.anuncios.await(3, TimeUnit.SECONDS));
            assertEquals(1, bully.getLiderAtual());
        } finally {
            bully.encerrar();
        }
    }
}
