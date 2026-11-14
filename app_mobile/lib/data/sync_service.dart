import 'dart:math';

import '../core/api_client.dart';
import '../core/config.dart';
import '../core/session.dart';
import 'bank_repository.dart';
import 'offline_models.dart';
import 'offline_store.dart';

class SyncService {
  SyncService({
    required this.session,
    required this.api,
    required this.bank,
    required this.store,
  });

  final SessionStore session;
  final ApiClient api;
  final BankRepository bank;
  final OfflineStore store;
  bool _sincronizando = false;
  bool _encerrado = false;

  void encerrar() => _encerrado = true;

  Future<ContaCache?> cacheDaConta(int contaId) async {
    final usuario = await session.usuario();
    return usuario == null ? null : store.lerCache(usuario, contaId);
  }

  Future<List<Pendencia>> pendenciasAbertas() async {
    final usuario = await session.usuario();
    if (usuario == null) return [];
    return (await store.listarPendencias(usuario))
        .where((e) => e.estado != EstadoPendencia.sincronizada)
        .toList();
  }

  void _exigirFilaLivre() {
    if (_sincronizando) {
      throw ApiException('Aguarde a sincronização antes de alterar a fila.');
    }
  }

  bool _podeDescartar(Pendencia p) =>
      !p.tentada ||
      p.estado == EstadoPendencia.conflito ||
      p.estado == EstadoPendencia.falha ||
      p.estado == EstadoPendencia.sincronizada;

  Future<void> limparPendenciasDaConta(int contaId) async {
    _exigirFilaLivre();
    final usuario = await session.usuario();
    if (usuario == null) return;
    await store.alterarPendencias(usuario, (fila) {
      if (fila.any((p) => p.contaId == contaId && !_podeDescartar(p))) {
        throw ApiException(
          'Há uma operação com resultado não confirmado. '
          'Sincronize antes de limpar a fila.',
        );
      }
      fila.removeWhere((p) => p.contaId == contaId);
    });
  }

  Future<double> saldoProvisorio(int contaId) async {
    final cache = await cacheDaConta(contaId);
    var saldo = cache?.saldoConfirmado ?? 0;
    for (final p in await pendenciasAbertas()) {
      if (p.contaId == contaId &&
          (p.estado == EstadoPendencia.pendente ||
              p.estado == EstadoPendencia.enviando)) {
        saldo += p.tipo == 'DEPOSITO' ? p.valor : -p.valor;
      }
    }
    return saldo;
  }

  ContaCache _cache(
    String usuario,
    int contaId,
    Map<String, dynamic> conta,
    List<int> vetor,
  ) => ContaCache(
    usuario: usuario,
    agencia: AppConfig.agenciaDaConta(contaId),
    contaId: contaId,
    nome: conta['nomeAluno']?.toString() ?? '',
    saldoConfirmado: (conta['saldo'] as num).toDouble(),
    vetorConfirmado: vetor,
    lidoEm: DateTime.now(),
  );

  List<int> _vetor(dynamic valor) =>
      (valor as List).map((e) => (e as num).toInt()).toList();

  Future<ContaCache> atualizarCacheDoServidor(int contaId) async {
    final usuario = await session.usuario();
    if (usuario == null) throw ApiException('Faça login.', statusCode: 401);
    final snap = await bank.consultar(contaId);
    final cache = _cache(usuario, contaId, snap, _vetor(snap['vetorAtual']));
    // Ler um saldo novo nunca altera a versão das operações já enfileiradas.
    await store.salvarCache(cache);
    return cache;
  }

  /// Também usado online: persiste ID e versão ANTES do primeiro envio.
  Future<Pendencia> enfileirarOffline({
    required int contaId,
    required String tipo,
    required double valor,
  }) async {
    if (contaId < 0 ||
        !valor.isFinite ||
        valor <= 0 ||
        (tipo != 'DEPOSITO' && tipo != 'SAQUE')) {
      throw ApiException(
        'Informe conta válida, valor positivo e depósito ou saque.',
      );
    }
    final usuario = await session.usuario();
    if (usuario == null) throw ApiException('Faça login.', statusCode: 401);
    var cache = await store.lerCache(usuario, contaId);
    if (cache == null) {
      try {
        cache = await atualizarCacheDoServidor(contaId);
      } on ApiException catch (e) {
        if (e.statusCode != null) rethrow;
        throw ApiException(
          'Sem cache local. Consulte o saldo com a agência '
          'acessível antes de operar offline.',
        );
      }
    }
    final p = Pendencia(
      id: 'op-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      usuario: usuario,
      agencia: cache.agencia,
      contaId: contaId,
      tipo: tipo,
      valor: valor,
      vetorBase: List<int>.from(cache.vetorConfirmado),
      criadaEm: DateTime.now(),
      estado: EstadoPendencia.pendente,
    );
    await store.upsertPendencia(p);
    return p;
  }

  Future<String> sincronizarAgora() async {
    if (_encerrado) return 'Sincronização encerrada.';
    if (_sincronizando) return 'Sincronização já em andamento.';
    _sincronizando = true;
    try {
      final usuario = await session.usuario();
      if (usuario == null) throw ApiException('Faça login.', statusCode: 401);
      // Snapshot apenas dos IDs. Releia cada item para usar o avanço persistido
      // pelo recibo anterior, inclusive entre contas da mesma agência.
      final fila = await store.listarPendencias(usuario);
      final bloqueadas = <int>{};
      final avisos = <String>[];
      var ok = 0;
      for (final item in fila) {
        if (_encerrado || await session.usuario() != usuario) break;
        if (bloqueadas.contains(item.agencia)) continue;
        final atual = await store.listarPendencias(usuario);
        final encontrados = atual.where((e) => e.id == item.id);
        if (encontrados.isEmpty) continue;
        final p = encontrados.first;
        if (p.estado == EstadoPendencia.sincronizada) continue;
        if (p.estado == EstadoPendencia.conflito ||
            p.estado == EstadoPendencia.falha) {
          bloqueadas.add(p.agencia);
          avisos.add(
            'Agência ${p.agencia}: resolva a operação ${p.id} antes de continuar.',
          );
          continue;
        }

        p.estado = EstadoPendencia.enviando;
        p.tentada = true;
        await store.upsertPendencia(p);
        try {
          final resp = await api.postJson(
            AppConfig.agenciaPorId(p.agencia).baseUrl,
            '/contas/${p.contaId}/sincronizar',
            body: {
              'tipo': p.tipo,
              'valor': p.valor,
              'vetorConhecido': List<int>.from(p.vetorBase),
              'operacaoId': p.id,
            },
          );
          final conta = resp['conta'] as Map<String, dynamic>;
          final vetor = _vetor(resp['vetor'] ?? conta['vetorAtual']);
          await store.confirmar(p, _cache(usuario, p.contaId, conta, vetor));
          ok++;
        } on ApiException catch (e) {
          p.mensagemErro = e.message;
          bloqueadas.add(p.agencia);
          if (e.statusCode == 409) {
            p.estado = EstadoPendencia.conflito;
            await store.upsertPendencia(p);
            final conta = e.body?['contaAtual'] as Map<String, dynamic>?;
            if (conta != null) {
              await store.salvarCache(
                _cache(
                  usuario,
                  p.contaId,
                  conta,
                  _vetor(conta['vetorAtual'] ?? e.body?['vetorAtual']),
                ),
              );
            }
            avisos.add(
              'Conflito em ${p.id}. Agência ${p.agencia} pausada até sua decisão.',
            );
          } else if (e.statusCode == 401) {
            p.estado = EstadoPendencia.pendente;
            await store.upsertPendencia(p);
            rethrow;
          } else if (e.statusCode != null &&
              e.statusCode! >= 400 &&
              e.statusCode! < 500 &&
              e.statusCode != 408 &&
              e.statusCode != 429) {
            p.estado = EstadoPendencia.falha;
            await store.upsertPendencia(p);
            avisos.add(
              'Operação recusada: ${e.message}. Agência ${p.agencia} pausada.',
            );
          } else {
            // Timeout/5xx não provam que o servidor deixou de aplicar. Reenvie
            // exatamente a mesma operação; não permita descartar um resultado incerto.
            p.estado = EstadoPendencia.pendente;
            p.mensagemErro =
                'Aguardando confirmação; nova tentativa com o mesmo ID. ${e.message}';
            await store.upsertPendencia(p);
            avisos.add(
              'Sem confirmação da agência ${p.agencia}; tentativa automática pendente.',
            );
          }
        }
      }
      await store.limparSincronizadas(usuario);
      if (ok == 0 && avisos.isEmpty) {
        return 'Nenhuma pendência para sincronizar.';
      }
      return [if (ok > 0) 'Sincronizadas: $ok', ...avisos].join('\n');
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> descartarConflito(String operacaoId) async {
    _exigirFilaLivre();
    final usuario = await session.usuario();
    if (usuario == null) return;
    await store.alterarPendencias(usuario, (fila) {
      final p = fila.firstWhere((e) => e.id == operacaoId);
      if (!_podeDescartar(p)) {
        throw ApiException(
          'Resultado não confirmado. Sincronize antes de descartar.',
        );
      }
      fila.removeWhere((e) => e.id == operacaoId);
    });
  }

  Future<void> reenfileirarAposConflito(String operacaoId) async {
    _exigirFilaLivre();
    final usuario = await session.usuario();
    if (usuario == null) return;
    final fila = await store.listarPendencias(usuario);
    final p = fila.firstWhere((e) => e.id == operacaoId);
    if (p.estado != EstadoPendencia.conflito) {
      throw ApiException('A nova tentativa exige um conflito confirmado.');
    }
    final cache = await atualizarCacheDoServidor(p.contaId);
    await store.alterarPendencias(usuario, (fila) {
      final atual = fila.firstWhere((e) => e.id == operacaoId);
      if (atual.estado != EstadoPendencia.conflito) {
        throw ApiException('O estado da operação mudou; confira a fila.');
      }
      // A pessoa autorizou usar a versão atual. Preserve posição e ID: o 409
      // confirma que esta operação não foi aplicada, portanto não existe recibo.
      atual.vetorBase = List<int>.from(cache.vetorConfirmado);
      atual.estado = EstadoPendencia.pendente;
      atual.tentada = false;
      atual.mensagemErro = null;
    });
  }
}
