package com.iceibank.agencia.bully;

import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.log.RegistroEventos;
import jakarta.annotation.PreDestroy;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

@Service
public class BullyService {

    private static final long ESPERA_COORDENADOR_MS = 5_000L;
    private static final long HEARTBEAT_INTERVALO_MS = 3_000L;

    private final int idAgencia;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final RestTemplate restTemplate;
    private final ExecutorService executor = Executors.newCachedThreadPool(r -> {
        Thread t = new Thread(r, "bully-" + System.nanoTime());
        t.setDaemon(true);
        return t;
    });
    private final ScheduledExecutorService heartbeatExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "bully-heartbeat");
        t.setDaemon(true);
        return t;
    });

    private final AtomicBoolean eleicaoEmAndamento = new AtomicBoolean(false);
    private final AtomicBoolean heartbeatEmAndamento = new AtomicBoolean(false);
    private final Object coordenadorMonitor = new Object();
    private volatile Integer liderAtual;
    private volatile boolean encerrado;

    public BullyService(
            int idAgencia,
            RelogioVetorial relogio,
            RegistroEventos registro,
            RestTemplate restTemplate
    ) {
        this.idAgencia = idAgencia;
        this.relogio = relogio;
        this.registro = registro;
        this.restTemplate = restTemplate;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void aoPronto() {
        executor.execute(this::iniciarEleicao);
        heartbeatExecutor.scheduleWithFixedDelay(
                this::verificarLider,
                HEARTBEAT_INTERVALO_MS,
                HEARTBEAT_INTERVALO_MS,
                TimeUnit.MILLISECONDS
        );
    }

    public Integer getLiderAtual() {
        return liderAtual;
    }

    public int getIdAgencia() {
        return idAgencia;
    }

    public void iniciarEleicao() {
        if (encerrado) {
            return;
        }
        if (!eleicaoEmAndamento.compareAndSet(false, true)) {
            return;
        }
        try {
            synchronized (coordenadorMonitor) {
                liderAtual = null;
            }
            int[] vetorInicio = relogio.eventoLocal();
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("idAgencia", idAgencia);
            registro.registrar("ELEICAO_INICIADA", vetorInicio, detalhes);

            boolean alguemMaiorRespondeu = false;
            for (ConfigAgencias.Agencia peer : ConfigAgencias.AGENCIAS) {
                if (peer.id() <= idAgencia) {
                    continue;
                }
                if (enviarEleicao(peer, relogio.aoEnviar())) {
                    alguemMaiorRespondeu = true;
                }
            }

            if (!alguemMaiorRespondeu) {
                tornarLider();
                return;
            }

            long prazo = System.currentTimeMillis() + ESPERA_COORDENADOR_MS;
            synchronized (coordenadorMonitor) {
                while (liderAtual == null || liderAtual <= idAgencia) {
                    long restante = prazo - System.currentTimeMillis();
                    if (restante <= 0) {
                        break;
                    }
                    coordenadorMonitor.wait(restante);
                }
            }

            // Um OK confirma um candidato maior. A falta do anúncio não autoriza
            // assumir sua liderança: permanecemos sem líder e o heartbeat tenta
            // outra eleição. Só vencemos quando nenhum candidato maior responde.
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } catch (IOException e) {
            System.err.println("[Bully] falha ao registrar eleição: " + e.getMessage());
        } finally {
            eleicaoEmAndamento.set(false);
        }
    }

    public void receberEleicao(int idOrigem, int[] vetorRecebido) throws IOException {
        validarId(idOrigem);
        validarVetor(vetorRecebido);
        if (idOrigem >= idAgencia) {
            throw new IllegalArgumentException("eleicao deve vir de uma agencia com ID menor");
        }
        int[] vetor = relogio.aoReceber(vetorRecebido);
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idOrigem", idOrigem);
        registro.registrar("ELEICAO_RECEBIDA", vetor, detalhes);
        executor.execute(this::iniciarEleicao);
    }

    public void receberCoordenador(int idLider, int[] vetorRecebido) throws IOException {
        validarId(idLider);
        validarVetor(vetorRecebido);
        int[] vetor = relogio.aoReceber(vetorRecebido);
        if (idLider < idAgencia) {
            // Um anúncio atrasado não pode rebaixar uma agência maior ainda viva.
            // A nova eleição anuncia o coordenador correto também aos demais pares.
            if (!encerrado) {
                executor.execute(this::iniciarEleicao);
            }
            return;
        }
        Map<String, Object> detalhes = new LinkedHashMap<>();
        detalhes.put("idLider", idLider);
        synchronized (coordenadorMonitor) {
            liderAtual = idLider;
            registro.registrar("LIDER_ANUNCIADO", vetor, detalhes);
            coordenadorMonitor.notifyAll();
        }
    }

    private void verificarLider() {
        if (encerrado || eleicaoEmAndamento.get()) {
            return;
        }
        if (!heartbeatEmAndamento.compareAndSet(false, true)) {
            return;
        }
        try {
            Integer lider = liderAtual;
            if (lider == null) {
                executor.execute(this::iniciarEleicao);
                return;
            }
            if (lider == idAgencia) {
                return;
            }

            ConfigAgencias.Agencia peer = ConfigAgencias.agenciaPorId(lider);
            try {
                // Consulta sem incrementar o relógio.
                restTemplate.getForEntity(peer.url() + "/bully/lider", Map.class);
            } catch (RestClientException e) {
                try {
                    int[] vetor = relogio.eventoLocal();
                    Map<String, Object> detalhes = new LinkedHashMap<>();
                    detalhes.put("idLider", lider);
                    detalhes.put("motivo", "timeout ou conexao recusada no heartbeat");
                    registro.registrar("LIDER_NAO_RESPONDEU", vetor, detalhes);
                } catch (IOException io) {
                    System.err.println("[Bully] falha ao registrar LIDER_NAO_RESPONDEU: " + io.getMessage());
                }
                synchronized (coordenadorMonitor) {
                    // Não apaga um anúncio novo por causa de um heartbeat antigo.
                    if (!lider.equals(liderAtual)) {
                        return;
                    }
                    liderAtual = null;
                }
                executor.execute(this::iniciarEleicao);
            }
        } finally {
            heartbeatEmAndamento.set(false);
        }
    }

    private void tornarLider() throws IOException {
        synchronized (coordenadorMonitor) {
            if (encerrado || (liderAtual != null && liderAtual > idAgencia)) {
                return;
            }
            liderAtual = idAgencia;
            int[] vetor = relogio.eventoLocal();
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("idLider", idAgencia);
            registro.registrar("TORNOU_LIDER", vetor, detalhes);
        }

        for (ConfigAgencias.Agencia peer : ConfigAgencias.AGENCIAS) {
            if (peer.id() == idAgencia) {
                continue;
            }
            anunciarCoordenador(peer, relogio.aoEnviar());
        }
        synchronized (coordenadorMonitor) {
            coordenadorMonitor.notifyAll();
        }
    }

    private boolean enviarEleicao(ConfigAgencias.Agencia peer, int[] vetor) {
        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("idOrigem", idAgencia);
            body.put("vetor", Arrays.stream(vetor).boxed().toList());
            ResponseEntity<String> resposta = restTemplate.postForEntity(
                    peer.url() + "/bully/eleicao",
                    body,
                    String.class
            );
            return resposta.getStatusCode().is2xxSuccessful();
        } catch (RestClientException e) {
            return false;
        }
    }

    private void anunciarCoordenador(ConfigAgencias.Agencia peer, int[] vetor) {
        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("idLider", idAgencia);
            body.put("vetor", Arrays.stream(vetor).boxed().toList());
            restTemplate.postForEntity(peer.url() + "/bully/coordenador", body, String.class);
        } catch (RestClientException e) {
            System.out.println("[Bully] nao conseguiu anunciar lider para agencia " + peer.id());
        }
    }

    public static void validarId(int id) {
        if (id < 0 || id >= ConfigAgencias.NUMERO_AGENCIAS) {
            throw new IllegalArgumentException("id de agencia invalido: " + id);
        }
    }

    public static void validarVetor(int[] vetor) {
        if (vetor == null || vetor.length != ConfigAgencias.NUMERO_AGENCIAS) {
            throw new IllegalArgumentException("vetor deve ter " + ConfigAgencias.NUMERO_AGENCIAS + " posicoes");
        }
        for (int v : vetor) {
            if (v < 0) {
                throw new IllegalArgumentException("vetor nao pode ter valores negativos");
            }
        }
    }

    public static int[] paraVetor(List<Integer> lista) {
        if (lista == null) {
            throw new IllegalArgumentException("vetor ausente");
        }
        int[] vetor = new int[lista.size()];
        for (int i = 0; i < lista.size(); i++) {
            if (lista.get(i) == null) {
                throw new IllegalArgumentException("vetor com posicao nula");
            }
            vetor[i] = lista.get(i);
        }
        return vetor;
    }

    @PreDestroy
    public void encerrar() {
        encerrado = true;
        heartbeatExecutor.shutdownNow();
        executor.shutdownNow();
        try {
            heartbeatExecutor.awaitTermination(2, TimeUnit.SECONDS);
            executor.awaitTermination(2, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
