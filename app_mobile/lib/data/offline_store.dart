import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_models.dart';

/// Persistência local por usuário (cache + fila).
/// SharedPreferences (JSON) para funcionar no Chrome do laboratório;
/// sqflite não roda em web sem camada extra.
class OfflineStore {
  static String _cacheKey(String usuario) => 'cache_$usuario';
  static String _filaKey(String usuario) => 'fila_$usuario';

  Future<ContaCache?> lerCache(String usuario, int contaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(usuario));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final item = map['$contaId'];
    if (item is! Map<String, dynamic>) return null;
    return ContaCache.fromJson(item);
  }

  Future<void> salvarCache(ContaCache cache) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(cache.usuario));
    final map = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    map['${cache.contaId}'] = cache.toJson();
    await prefs.setString(_cacheKey(cache.usuario), jsonEncode(map));
  }

  Future<List<Pendencia>> listarPendencias(String usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filaKey(usuario));
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Pendencia.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.criadaEm.compareTo(b.criadaEm));
  }

  Future<void> salvarPendencias(String usuario, List<Pendencia> fila) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _filaKey(usuario),
      jsonEncode(fila.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> upsertPendencia(Pendencia p) async {
    final fila = await listarPendencias(p.usuario);
    final idx = fila.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      fila[idx] = p;
    } else {
      fila.add(p);
    }
    await salvarPendencias(p.usuario, fila);
  }

  Future<void> limparSincronizadas(String usuario) async {
    final fila = await listarPendencias(usuario);
    final restam = fila
        .where((e) => e.estado != EstadoPendencia.sincronizada)
        .toList();
    await salvarPendencias(usuario, restam);
  }
}
