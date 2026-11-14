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

  Future<ContaCache?> cacheDaConta(int contaId) async {
    final usuario = await session.usuario();
    if (usuario == null) return null;
    return store.lerCache(usuario, contaId);
  }

  Future<List<Pendencia>> pendenciasAbertas() async {
    final usuario = await session.usuario();
    if (usuario == null) return [];
    final todas = await store.listarPendencias(usuario);
    return todas
        .where((e) => e.estado != EstadoPendencia.sincronizada)
        .toList();
  }

  Future<void> limparPendenciasDaConta(int contaId) async {
    final usuario = await session.usuario();
    if (usuario == null) return;
    final fila = await store.listarPendencias(usuario);
    fila.removeWhere((e) => e.contaId == contaId);
    await store.salvarPendencias(usuario, fila);
  }

  Future<double> saldoProvisorio(int contaId) async {
    final cache = await cacheDaConta(contaId);
    final base = cache?.saldoConfirmado ?? 0;
    final pend = await pendenciasAbertas();
    var delta = 0.0;
    for (final p in pend.where((e) =>
        e.contaId == contaId &&
        (e.estado == EstadoPendencia.pendente ||
            e.estado == EstadoPendencia.enviando))) {
      if (p.tipo == 'DEPOSITO') delta += p.valor;
      if (p.tipo == 'SAQUE') delta -= p.valor;
    }
    return base + delta;
  }

  Future<ContaCache> atualizarCacheDoServidor(int contaId) async {
    final usuario = await session.usuario();
    if (usuario == null) {
      throw ApiException('Faça login.', statusCode: 401);
    }
    final snap = await bank.consultar(contaId);
    final vetor = (snap['vetorAtual'] as List)
        .map((e) => (e as num).toInt())
        .toList();
    final cache = ContaCache(
      usuario: usuario,
      agencia: AppConfig.agenciaDaConta(contaId),
      contaId: contaId,
      nome: snap['nomeAluno']?.toString() ?? '',
      saldoConfirmado: (snap['saldo'] as num).toDouble(),
      vetorConfirmado: vetor,
      lidoEm: DateTime.now(),
    );
    await store.salvarCache(cache);
    return cache;
  }

  Future<Pendencia> enfileirarOffline({
    required int contaId,
    required String tipo,
    required double valor,
  }) async {
    final usuario = await session.usuario();
    if (usuario == null) {
      throw ApiException('Faça login.', statusCode: 401);
    }
    var cache = await store.lerCache(usuario, contaId);
    if (cache == null) {
      try {
        cache = await atualizarCacheDoServidor(contaId);
      } on ApiException catch (e) {
        throw ApiException(
          'Sem cache local. Com as agências no ar, consulte o Saldo desta conta '
          'antes de operar offline. (${e.message})',
        );
      }
    }

    final abertas = await store.listarPendencias(usuario);
    final mesmaAgencia = abertas
        .where((e) =>
            e.agencia == cache!.agencia &&
            (e.estado == EstadoPendencia.pendente ||
                e.estado == EstadoPendencia.enviando))
        .toList()
      ..sort((a, b) => a.criadaEm.compareTo(b.criadaEm));

    // Vetor-base: último da fila da agência, senão o confirmado.
    final vetorBase = mesmaAgencia.isEmpty
        ? List<int>.from(cache.vetorConfirmado)
        : List<int>.from(mesmaAgencia.last.vetorBase);

    // Para a segunda pendência na mesma sessão offline, o vetor-base fica o
    // mesmo até o servidor confirmar; conflitos externos ainda estouram 409.
    final id =
        'op-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
    final pendencia = Pendencia(
      id: id,
      usuario: usuario,
      agencia: cache.agencia,
      contaId: contaId,
      tipo: tipo,
      valor: valor,
      vetorBase: vetorBase,
      criadaEm: DateTime.now(),
      estado: EstadoPendencia.pendente,
    );
    await store.upsertPendencia(pendencia);
    return pendencia;
  }

  Future<String> sincronizarAgora() async {
    if (_sincronizando) return 'Sincronização já em andamento.';
    _sincronizando = true;
    try {
      final usuario = await session.usuario();
      if (usuario == null) {
        throw ApiException('Faça login.', statusCode: 401);
      }

      final fila = await store.listarPendencias(usuario);
      final pendentes = fila
          .where((e) =>
              e.estado == EstadoPendencia.pendente ||
              e.estado == EstadoPendencia.enviando)
          .toList()
        ..sort((a, b) {
          final c = a.agencia.compareTo(b.agencia);
          if (c != 0) return c;
          return a.criadaEm.compareTo(b.criadaEm);
        });

      if (pendentes.isEmpty) return 'Nenhuma pendência para sincronizar.';

      var ok = 0;
      for (final p in pendentes) {
        p.estado = EstadoPendencia.enviando;
        await store.upsertPendencia(p);

        // Atualiza vetor-base com o cache confirmado mais recente da conta,
        // depois dos sucessos anteriores desta rodada.
        final cache = await store.lerCache(usuario, p.contaId);
        if (cache != null) {
          p.vetorBase = List<int>.from(cache.vetorConfirmado);
          await store.upsertPendencia(p);
        }

        final base = AppConfig.agenciaPorId(p.agencia).baseUrl;
        try {
          final resp = await api.postJson(
            base,
            '/contas/${p.contaId}/sincronizar',
            body: {
              'tipo': p.tipo,
              'valor': p.valor,
              'vetorConhecido': p.vetorBase,
              'operacaoId': p.id,
            },
          );
          final conta = resp['conta'] as Map<String, dynamic>? ?? {};
          final vetor = (resp['vetor'] as List? ?? conta['vetorAtual'] as List)
              .map((e) => (e as num).toInt())
              .toList();
          await store.salvarCache(
            ContaCache(
              usuario: usuario,
              agencia: p.agencia,
              contaId: p.contaId,
              nome: conta['nomeAluno']?.toString() ?? cache?.nome ?? '',
              saldoConfirmado: (conta['saldo'] as num).toDouble(),
              vetorConfirmado: vetor,
              lidoEm: DateTime.now(),
            ),
          );
          p.estado = EstadoPendencia.sincronizada;
          p.mensagemErro = null;
          await store.upsertPendencia(p);
          ok++;
        } on ApiException catch (e) {
          if (e.statusCode == 409) {
            p.estado = EstadoPendencia.conflito;
            p.mensagemErro = e.message;
            await store.upsertPendencia(p);
            final contaAtual =
                e.body?['contaAtual'] as Map<String, dynamic>?;
            if (contaAtual != null) {
              final vetor = (contaAtual['vetorAtual'] as List)
                  .map((x) => (x as num).toInt())
                  .toList();
              await store.salvarCache(
                ContaCache(
                  usuario: usuario,
                  agencia: p.agencia,
                  contaId: p.contaId,
                  nome: contaAtual['nomeAluno']?.toString() ?? '',
                  saldoConfirmado: (contaAtual['saldo'] as num).toDouble(),
                  vetorConfirmado: vetor,
                  lidoEm: DateTime.now(),
                ),
              );
            }
            return 'Conflito na operação ${p.id}. Fila pausada nesta sequência.';
          }
          if (e.statusCode == 401) {
            p.estado = EstadoPendencia.pendente;
            await store.upsertPendencia(p);
            rethrow;
          }
          if (e.statusCode == 400 || e.statusCode == 404) {
            p.estado = EstadoPendencia.falha;
            p.mensagemErro = e.message;
            await store.upsertPendencia(p);
            return 'Falha de negócio: ${e.message}. '
                'Se a agência reiniciou, crie a conta de novo e descarte esta pendência.';
          }
          // rede / timeout: volta para pendente, mesmo id para reconciliar
          p.estado = EstadoPendencia.pendente;
          p.mensagemErro = e.message;
          await store.upsertPendencia(p);
          return 'Sem conexão estável: ${e.message}';
        }
      }

      await store.limparSincronizadas(usuario);
      return 'Sincronizadas: $ok';
    } finally {
      _sincronizando = false;
    }
  }

  Future<void> descartarConflito(String operacaoId) async {
    final usuario = await session.usuario();
    if (usuario == null) return;
    final fila = await store.listarPendencias(usuario);
    fila.removeWhere((e) => e.id == operacaoId);
    await store.salvarPendencias(usuario, fila);
  }

  Future<void> reenfileirarAposConflito(String operacaoId) async {
    final usuario = await session.usuario();
    if (usuario == null) return;
    final fila = await store.listarPendencias(usuario);
    final p = fila.firstWhere((e) => e.id == operacaoId);
    final cache = await store.lerCache(usuario, p.contaId);
    if (cache == null) {
      throw ApiException('Sem cache atualizado para nova tentativa.');
    }
    p.vetorBase = List<int>.from(cache.vetorConfirmado);
    p.estado = EstadoPendencia.pendente;
    p.mensagemErro = null;
    // novo id para não colidir com recibo do servidor se o conteúdo mudar
    final nova = Pendencia(
      id:
          'op-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      usuario: p.usuario,
      agencia: p.agencia,
      contaId: p.contaId,
      tipo: p.tipo,
      valor: p.valor,
      vetorBase: p.vetorBase,
      criadaEm: DateTime.now(),
      estado: EstadoPendencia.pendente,
    );
    fila.removeWhere((e) => e.id == operacaoId);
    fila.add(nova);
    await store.salvarPendencias(usuario, fila);
  }
}
