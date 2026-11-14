package com.iceibank.agencia.service;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;

import java.nio.file.Path;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class OperacoesContaServiceSyncTest {

    @TempDir
    Path temp;

    private OperacoesContaService service;
    private RelogioVetorial relogio;

    @BeforeEach
    void setup() throws Exception {
        ConcurrentHashMap<Integer, Conta> contas = new ConcurrentHashMap<>();
        relogio = new RelogioVetorial(0, 3);
        RegistroEventos registro = new RegistroEventos("agencia-0", temp);
        service = new OperacoesContaService(0, contas, relogio, registro);
        service.criarConta(3, "Ana", 100);
    }

    @Test
    void aplicaQuandoVetoresIguais() throws Exception {
        Map<String, Object> snap = service.snapshot(3);
        @SuppressWarnings("unchecked")
        List<Integer> vetor = (List<Integer>) snap.get("vetorAtual");
        Map<String, Object> resp = service.sincronizar(3, "DEPOSITO", 10, vetor, "op-1", "admin");
        @SuppressWarnings("unchecked")
        Map<String, Object> conta = (Map<String, Object>) resp.get("conta");
        assertEquals(110.0, (Double) conta.get("saldo"), 0.001);
    }

    @Test
    void conflitoComVetorAntigo() throws Exception {
        Map<String, Object> snap = service.snapshot(3);
        @SuppressWarnings("unchecked")
        List<Integer> vetorAntigo = (List<Integer>) snap.get("vetorAtual");
        service.depositar(3, 5);
        assertThrows(
                OperacoesContaService.ConflitoSincronizacaoException.class,
                () -> service.sincronizar(3, "DEPOSITO", 10, vetorAntigo, "op-2", "admin")
        );
        assertEquals(105.0, (Double) service.snapshot(3).get("saldo"), 0.001);
    }

    @Test
    void naoDuplicaMesmaOperacao() throws Exception {
        Map<String, Object> snap = service.snapshot(3);
        @SuppressWarnings("unchecked")
        List<Integer> vetor = (List<Integer>) snap.get("vetorAtual");
        service.sincronizar(3, "DEPOSITO", 10, vetor, "op-3", "admin");
        Map<String, Object> snap2 = service.snapshot(3);
        @SuppressWarnings("unchecked")
        List<Integer> vetor2 = (List<Integer>) snap2.get("vetorAtual");
        // repetição com mesmo id e conteúdo — devolve recibo sem aplicar de novo
        service.sincronizar(3, "DEPOSITO", 10, vetor, "op-3", "admin");
        assertEquals(110.0, (Double) service.snapshot(3).get("saldo"), 0.001);
        assertEquals(vetor2, service.snapshot(3).get("vetorAtual"));
    }

    @Test
    void saqueSemSaldo() throws Exception {
        Map<String, Object> snap = service.snapshot(3);
        @SuppressWarnings("unchecked")
        List<Integer> vetor = (List<Integer>) snap.get("vetorAtual");
        assertThrows(
                ResponseStatusException.class,
                () -> service.sincronizar(3, "SAQUE", 999, vetor, "op-4", "admin")
        );
        assertEquals(100.0, (Double) service.snapshot(3).get("saldo"), 0.001);
    }

    @Test
    void rejeitaVetorInvalidoEIdReutilizadoComOutroConteudo() throws Exception {
        assertThrows(ResponseStatusException.class,
                () -> service.sincronizar(3, "DEPOSITO", 10, List.of(1, -1, 0), "a", "admin"));
        assertThrows(ResponseStatusException.class,
                () -> service.sincronizar(3, "DEPOSITO", 10, List.of(1, 0), "a", "admin"));
        service.sincronizar(3, "DEPOSITO", 10, List.of(1, 0, 0), "a", "admin");
        assertThrows(ResponseStatusException.class,
                () -> service.sincronizar(3, "DEPOSITO", 20, List.of(1, 0, 0), "a", "admin"));
        assertEquals(110.0, (Double) service.snapshot(3).get("saldo"));
    }

    @Test
    void falhaNoLogNaoPerdeReciboDaOperacaoJaAplicada() throws Exception {
        RegistroEventos falho = new RegistroEventos("falho", temp) {
            @Override
            public synchronized Map<String, Object> registrar(String tipo, int[] vetor,
                    Map<String, Object> detalhes) throws IOException {
                if (tipo.equals("SINCRONIZACAO_OFFLINE")) throw new IOException("disco indisponivel");
                return super.registrar(tipo, vetor, detalhes);
            }
        };
        var banco = new OperacoesContaService(0, new ConcurrentHashMap<>(),
                new RelogioVetorial(0, 3), falho);
        banco.criarConta(3, "Ana", 100);
        assertThrows(IOException.class,
                () -> banco.sincronizar(3, "DEPOSITO", 10, List.of(1, 0, 0), "a", "admin"));
        banco.sincronizar(3, "DEPOSITO", 10, List.of(1, 0, 0), "a", "admin");
        assertEquals(110.0, (Double) banco.snapshot(3).get("saldo"));
    }

    @Test
    void eventoDeEleicaoEsperaConclusaoDaSincronizacao() throws Exception {
        CountDownLatch noLog = new CountDownLatch(1);
        CountDownLatch liberar = new CountDownLatch(1);
        CountDownLatch eventoIniciado = new CountDownLatch(1);
        RegistroEventos registro = new RegistroEventos("concorrencia", temp) {
            @Override
            public synchronized Map<String, Object> registrar(String tipo, int[] vetor,
                    Map<String, Object> detalhes) throws IOException {
                if (tipo.equals("SINCRONIZACAO_OFFLINE")) {
                    noLog.countDown();
                    try {
                        if (!liberar.await(5, TimeUnit.SECONDS)) throw new IOException("timeout do teste");
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new IOException(e);
                    }
                }
                return super.registrar(tipo, vetor, detalhes);
            }
        };
        var banco = new OperacoesContaService(0, new ConcurrentHashMap<>(), relogio, registro);
        banco.criarConta(6, "Bia", 100);
        List<Integer> base = java.util.Arrays.stream(relogio.copia()).boxed().toList();
        var pool = Executors.newFixedThreadPool(2);
        try {
            var sync = pool.submit(() -> banco.sincronizar(6, "DEPOSITO", 10, base, "a", "admin"));
            assertTrue(noLog.await(3, TimeUnit.SECONDS));
            var eleicao = pool.submit(() -> {
                eventoIniciado.countDown();
                return relogio.aoReceber(new int[]{0, 0, 5});
            });
            assertTrue(eventoIniciado.await(3, TimeUnit.SECONDS));
            assertThrows(TimeoutException.class, () -> eleicao.get(200, TimeUnit.MILLISECONDS));
            liberar.countDown();
            sync.get(3, TimeUnit.SECONDS);
            eleicao.get(3, TimeUnit.SECONDS);
            assertEquals(110.0, (Double) banco.snapshot(6).get("saldo"));
            assertEquals(5, relogio.copia()[2]);
        } finally {
            liberar.countDown();
            pool.shutdownNow();
        }
    }

    @Test
    void escritasConcorrentesNaoPerdemSaldoECreditoRemotoContinuaFuncionando() throws Exception {
        var pool = Executors.newFixedThreadPool(4);
        try {
            var tarefas = new java.util.ArrayList<java.util.concurrent.Future<?>>();
            for (int i = 0; i < 20; i++) {
                tarefas.add(pool.submit(() -> service.depositar(3, 1)));
            }
            for (var tarefa : tarefas) tarefa.get(3, TimeUnit.SECONDS);
            service.criarConta(6, "Bia", 0);
            service.debitarParaTransferencia(3, 6, 10);
            service.creditarRemoto(6, 5, 1, new int[]{0, 2, 0});
            assertEquals(110.0, (Double) service.snapshot(3).get("saldo"));
            assertEquals(15.0, (Double) service.snapshot(6).get("saldo"));
        } finally {
            pool.shutdownNow();
        }
    }
}
