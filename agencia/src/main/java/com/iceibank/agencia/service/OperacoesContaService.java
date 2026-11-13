package com.iceibank.agencia.service;

import com.iceibank.agencia.clock.ComparadorVetores;
import com.iceibank.agencia.clock.RelogioVetorial;
import com.iceibank.agencia.config.ConfigAgencias;
import com.iceibank.agencia.log.RegistroEventos;
import com.iceibank.agencia.model.Conta;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class OperacoesContaService {

    private final Object estadoLock = new Object();
    private final int idAgencia;
    private final ConcurrentHashMap<Integer, Conta> contas;
    private final RelogioVetorial relogio;
    private final RegistroEventos registro;
    private final ConcurrentHashMap<String, Recibo> recibos = new ConcurrentHashMap<>();

    public OperacoesContaService(
            int idAgencia,
            ConcurrentHashMap<Integer, Conta> contas,
            RelogioVetorial relogio,
            RegistroEventos registro
    ) {
        this.idAgencia = idAgencia;
        this.contas = contas;
        this.relogio = relogio;
        this.registro = registro;
    }

    public Map<String, Object> snapshot(int id) {
        synchronized (estadoLock) {
            Conta conta = contas.get(id);
            if (conta == null) {
                return null;
            }
            return copiaConta(conta, relogio.copia());
        }
    }

    public Conta criarConta(int id, String nomeAluno, double saldoInicial) throws IOException {
        synchronized (estadoLock) {
            if (ConfigAgencias.agenciaResponsavel(id) != idAgencia) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Conta " + id + " não pertence a esta agência.");
            }
            if (contas.containsKey(id)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "Conta já existe.");
            }
            int[] vetor = relogio.eventoLocal();
            Conta conta = new Conta(id, nomeAluno, saldoInicial);
            contas.put(id, conta);
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", id);
            detalhes.put("nomeAluno", nomeAluno);
            detalhes.put("saldoInicial", saldoInicial);
            registro.registrar("CRIAR_CONTA", vetor, detalhes);
            return new Conta(conta.getId(), conta.getNomeAluno(), conta.getSaldo());
        }
    }

    public Conta depositar(int id, double valor) throws IOException {
        synchronized (estadoLock) {
            Conta conta = exigirConta(id);
            int[] vetor = relogio.eventoLocal();
            conta.setSaldo(conta.getSaldo() + valor);
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", id);
            detalhes.put("valor", valor);
            detalhes.put("novoSaldo", conta.getSaldo());
            registro.registrar("DEPOSITO", vetor, detalhes);
            return new Conta(conta.getId(), conta.getNomeAluno(), conta.getSaldo());
        }
    }

    public Conta sacar(int id, double valor) throws IOException {
        synchronized (estadoLock) {
            Conta conta = exigirConta(id);
            if (conta.getSaldo() < valor) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");
            }
            int[] vetor = relogio.eventoLocal();
            conta.setSaldo(conta.getSaldo() - valor);
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", id);
            detalhes.put("valor", valor);
            detalhes.put("novoSaldo", conta.getSaldo());
            registro.registrar("SAQUE", vetor, detalhes);
            return new Conta(conta.getId(), conta.getNomeAluno(), conta.getSaldo());
        }
    }

    public Map<String, Object> sincronizar(
            int id,
            String tipo,
            double valor,
            List<Integer> vetorConhecidoLista,
            String operacaoId,
            String usuario
    ) throws IOException {
        if (valor <= 0 || Double.isNaN(valor) || Double.isInfinite(valor)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "valor deve ser positivo e finito");
        }
        String tipoNorm = tipo == null ? "" : tipo.trim().toUpperCase();
        if (!tipoNorm.equals("DEPOSITO") && !tipoNorm.equals("SAQUE")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "tipo deve ser DEPOSITO ou SAQUE");
        }

        int[] vetorConhecido;
        try {
            vetorConhecido = ComparadorVetores.validarECopiar(vetorConhecidoLista);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage());
        }

        String chaveRecibo = null;
        String assinatura = null;
        if (operacaoId != null && !operacaoId.isBlank()) {
            chaveRecibo = usuario + "|" + id + "|" + operacaoId.trim();
            assinatura = tipoNorm + "|" + valor;
        }

        synchronized (estadoLock) {
            if (chaveRecibo != null) {
                Recibo previo = recibos.get(chaveRecibo);
                if (previo != null) {
                    if (!previo.assinatura().equals(assinatura)) {
                        throw new ResponseStatusException(
                                HttpStatus.BAD_REQUEST,
                                "operacaoId reutilizado com conteudo diferente"
                        );
                    }
                    return new LinkedHashMap<>(previo.resposta());
                }
            }

            Conta conta = contas.get(id);
            if (conta == null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
            }

            int[] vetorAtual = relogio.copia();
            String relacao = ComparadorVetores.comparar(vetorConhecido, vetorAtual);
            if (!"IGUAIS".equals(relacao)) {
                Map<String, Object> conflito = new LinkedHashMap<>();
                conflito.put("erro", "conflito de versao");
                conflito.put("relacao", relacao);
                conflito.put("vetorConhecido", ComparadorVetores.paraLista(vetorConhecido));
                conflito.put("vetorAtual", ComparadorVetores.paraLista(vetorAtual));
                conflito.put("contaAtual", copiaConta(conta, vetorAtual));
                throw new ConflitoSincronizacaoException(conflito);
            }

            if (tipoNorm.equals("SAQUE") && conta.getSaldo() < valor) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");
            }

            if (tipoNorm.equals("DEPOSITO")) {
                conta.setSaldo(conta.getSaldo() + valor);
            } else {
                conta.setSaldo(conta.getSaldo() - valor);
            }

            int[] vetorNovo = relogio.eventoLocal();
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("id", id);
            detalhes.put("tipo", tipoNorm);
            detalhes.put("valor", valor);
            detalhes.put("operacaoId", operacaoId);
            detalhes.put("usuario", usuario);
            detalhes.put("novoSaldo", conta.getSaldo());
            registro.registrar("SINCRONIZACAO_OFFLINE", vetorNovo, detalhes);

            Map<String, Object> resposta = new LinkedHashMap<>();
            resposta.put("conta", copiaConta(conta, vetorNovo));
            resposta.put("vetor", ComparadorVetores.paraLista(vetorNovo));
            resposta.put("mensagem", "sincronizacao aplicada");

            if (chaveRecibo != null) {
                recibos.put(chaveRecibo, new Recibo(assinatura, resposta));
            }
            return new LinkedHashMap<>(resposta);
        }
    }

    /** Débito da transferência; retorna se o destino é local. Publicação RabbitMQ fica fora do lock. */
    public ResultadoDebitoTransferencia debitarParaTransferencia(int idOrigem, int idDestino, double valor)
            throws IOException {
        synchronized (estadoLock) {
            Conta origem = contas.get(idOrigem);
            if (origem == null) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Conta de origem não encontrada nesta agência.");
            }
            if (origem.getSaldo() < valor) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Saldo insuficiente.");
            }

            int agenciaDestino = ConfigAgencias.agenciaResponsavel(idDestino);
            int[] vetorDebito = relogio.eventoLocal();
            origem.setSaldo(origem.getSaldo() - valor);
            Map<String, Object> detalhesDebito = new LinkedHashMap<>();
            detalhesDebito.put("idOrigem", idOrigem);
            detalhesDebito.put("idDestino", idDestino);
            detalhesDebito.put("valor", valor);
            registro.registrar("TRANSFERENCIA_DEBITO", vetorDebito, detalhesDebito);

            if (agenciaDestino == idAgencia) {
                Conta destino = contas.get(idDestino);
                if (destino == null) {
                    origem.setSaldo(origem.getSaldo() + valor);
                    throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Conta de destino não encontrada.");
                }
                int[] vetorCredito = relogio.eventoLocal();
                destino.setSaldo(destino.getSaldo() + valor);
                Map<String, Object> detalhesCredito = new LinkedHashMap<>();
                detalhesCredito.put("idOrigem", idOrigem);
                detalhesCredito.put("idDestino", idDestino);
                detalhesCredito.put("valor", valor);
                registro.registrar("TRANSFERENCIA_CREDITO", vetorCredito, detalhesCredito);
                return new ResultadoDebitoTransferencia(true, agenciaDestino, null);
            }

            int[] vetorEnvio = relogio.aoEnviar();
            return new ResultadoDebitoTransferencia(false, agenciaDestino, vetorEnvio);
        }
    }

    public void creditarRemoto(int idConta, double valor, int origemAgencia, int[] vetorEnvio) throws IOException {
        synchronized (estadoLock) {
            int[] vetor = relogio.aoReceber(vetorEnvio);
            Conta conta = contas.get(idConta);
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("idConta", idConta);
            detalhes.put("valor", valor);
            detalhes.put("origemAgencia", origemAgencia);

            if (conta == null) {
                detalhes.put("motivo", "conta nao encontrada");
                registro.registrar("CREDITO_REMOTO_FALHOU", vetor, detalhes);
                throw new ContaAusenteException("conta nao encontrada");
            }

            conta.setSaldo(conta.getSaldo() + valor);
            registro.registrar("TRANSFERENCIA_CREDITO_REMOTO", vetor, detalhes);
        }
    }

    public void registrarDeadLetter(Map<String, Object> mensagem) throws IOException {
        synchronized (estadoLock) {
            int[] vetor = relogio.eventoLocal();
            Map<String, Object> detalhes = new LinkedHashMap<>();
            detalhes.put("idConta", mensagem.get("idConta"));
            detalhes.put("valor", mensagem.get("valor"));
            detalhes.put("origemAgencia", mensagem.get("origemAgencia"));
            detalhes.put("motivo", "mensagem enviada para dead-letter (conta nao encontrada)");
            registro.registrar("DEAD_LETTER", vetor, detalhes);
        }
    }

    private Conta exigirConta(int id) {
        Conta conta = contas.get(id);
        if (conta == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Conta não encontrada nesta agência.");
        }
        return conta;
    }

    private Map<String, Object> copiaConta(Conta conta, int[] vetor) {
        Map<String, Object> copia = new LinkedHashMap<>();
        copia.put("id", conta.getId());
        copia.put("nomeAluno", conta.getNomeAluno());
        copia.put("saldo", conta.getSaldo());
        copia.put("vetorAtual", ComparadorVetores.paraLista(vetor));
        return copia;
    }

    public record ResultadoDebitoTransferencia(boolean local, int agenciaDestino, int[] vetorEnvio) {}

    private record Recibo(String assinatura, Map<String, Object> resposta) {}

    public static class ConflitoSincronizacaoException extends RuntimeException {
        private final Map<String, Object> corpo;

        public ConflitoSincronizacaoException(Map<String, Object> corpo) {
            super("conflito de versao");
            this.corpo = corpo;
        }

        public Map<String, Object> getCorpo() {
            return corpo;
        }
    }

    public static class ContaAusenteException extends RuntimeException {
        public ContaAusenteException(String message) {
            super(message);
        }
    }
}
