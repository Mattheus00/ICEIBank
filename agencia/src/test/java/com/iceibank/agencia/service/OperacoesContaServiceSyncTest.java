package com.iceibank.agencia.service;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;

import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class OperacoesContaServiceSyncTest {

    @TempDir
    Path temp;

    private OperacoesContaService service;
    private RelogioVetorial relogio;

    @BeforeEach
    void setup() throws Exception {
        System.setProperty("user.dir", temp.toString());
        ConcurrentHashMap<Integer, Conta> contas = new ConcurrentHashMap<>();
        relogio = new RelogioVetorial(0, 3);
        RegistroEventos registro = new RegistroEventos("agencia-0");
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
}
