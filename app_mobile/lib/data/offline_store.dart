import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_models.dart';

/// Serializa read-modify-write entre instâncias no mesmo isolate.
/// SharedPreferences não oferece uma transação entre abas/processos.
class OfflineStore {
  static String _cacheKey(String usuario) => 'cache_$usuario';
  static String _filaKey(String usuario) => 'fila_$usuario';
  static Future<void> _ultimaEscrita = Future.value();

  Future<T> _exclusivo<T>(Future<T> Function() acao) async {
    final anterior = _ultimaEscrita;
    final concluida = Completer<void>();
    _ultimaEscrita = concluida.future;
    await anterior;
    try {
      return await acao();
    } finally {
      concluida.complete();
    }
  }

  Future<void> _gravar(String chave, Object valor) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(chave, jsonEncode(valor))) {
      throw StateError('Não foi possível persistir os dados locais.');
    }
  }

  Future<ContaCache?> lerCache(String usuario, int contaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(usuario));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final item = map['$contaId'];
    return item is Map<String, dynamic> ? ContaCache.fromJson(item) : null;
  }

  Future<void> _salvarCache(ContaCache cache) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(cache.usuario));
    final map = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map['${cache.contaId}'] = cache.toJson();
    await _gravar(_cacheKey(cache.usuario), map);
  }

  Future<void> salvarCache(ContaCache cache) =>
      _exclusivo(() => _salvarCache(cache));

  Future<List<Pendencia>> listarPendencias(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filaKey(usuario));
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Pendencia.fromJson(e as Map<String, dynamic>))
        // A ordem persistida de inserção é a FIFO, mesmo se o relógio do
        // dispositivo mudar ou duas operações tiverem o mesmo timestamp.
        .toList();
  }

  Future<void> alterarPendencias(
    String usuario,
    void Function(List<Pendencia>) alterar,
  ) => _exclusivo(() async {
    final fila = await listarPendencias(usuario);
    alterar(fila);
    await _gravar(_filaKey(usuario), fila.map((e) => e.toJson()).toList());
  });

  Future<void> upsertPendencia(Pendencia p) =>
      alterarPendencias(p.usuario, (fila) {
        final idx = fila.indexWhere((e) => e.id == p.id);
        if (idx >= 0) {
          fila[idx] = p;
        } else {
          fila.add(p);
        }
      });

  static bool mesmosVetores(List<int> a, List<int> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  /// O recibo confirma apenas o efeito desta operação. Só avança a versão das
  /// operações seguintes ainda não enviadas que compartilham a base.
  /// Confirmação e avanço são persistidos no mesmo JSON da fila. Se houver queda
  /// antes dessa gravação, o reenvio usa o mesmo ID e reconcilia com o recibo.
  Future<void> confirmar(Pendencia p, ContaCache recibo) => _exclusivo(
    () async {
      final anterior = await lerCache(p.usuario, p.contaId);
      final reciboAntigo =
          anterior != null &&
          anterior.vetorConfirmado.length == recibo.vetorConfirmado.length &&
          List.generate(
            recibo.vetorConfirmado.length,
            (i) => anterior.vetorConfirmado[i] >= recibo.vetorConfirmado[i],
          ).every((e) => e);
      if (!reciboAntigo) await _salvarCache(recibo);
      final fila = await listarPendencias(p.usuario);
      final idx = fila.indexWhere((e) => e.id == p.id);
      if (idx < 0) throw StateError('Operação em envio não está na fila.');
      fila[idx].estado = EstadoPendencia.sincronizada;
      fila[idx].mensagemErro = null;
      for (final proxima in fila.skip(idx + 1)) {
        if (proxima.agencia == p.agencia &&
            proxima.estado == EstadoPendencia.pendente &&
            !proxima.tentada &&
            mesmosVetores(proxima.vetorBase, p.vetorBase)) {
          proxima.vetorBase = List<int>.from(recibo.vetorConfirmado);
        }
      }
      await _gravar(_filaKey(p.usuario), fila.map((e) => e.toJson()).toList());
    },
  );

  Future<void> limparSincronizadas(String usuario) => alterarPendencias(
    usuario,
    (fila) => fila.removeWhere((e) => e.estado == EstadoPendencia.sincronizada),
  );
}
