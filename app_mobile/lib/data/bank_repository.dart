import '../core/api_client.dart';
import '../core/config.dart';

class BankRepository {
  BankRepository(this._api);

  final ApiClient _api;

  String _baseDaConta(int idConta) =>
      AppConfig.agenciaPorId(AppConfig.agenciaDaConta(idConta)).baseUrl;

  Future<String> login(int agenciaId, String usuario, String senha) async {
    final base = AppConfig.agenciaPorId(agenciaId).baseUrl;
    final resp = await _api.postJson(
      base,
      '/auth/login',
      body: {'username': usuario, 'password': senha},
      auth: false,
    );
    final token = resp['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Login sem token.');
    }
    return token;
  }

  Future<Map<String, dynamic>> criarConta({
    required int id,
    required String nome,
    required double saldoInicial,
  }) {
    return _api.postJson(
      _baseDaConta(id),
      '/contas',
      body: {'id': id, 'nomeAluno': nome, 'saldoInicial': saldoInicial},
    );
  }

  Future<Map<String, dynamic>> consultar(int id) {
    return _api.getJson(_baseDaConta(id), '/contas/$id');
  }

  Future<Map<String, dynamic>> depositar(int id, double valor) {
    return _api.postJson(
      _baseDaConta(id),
      '/contas/$id/depositar',
      body: {'valor': valor},
    );
  }

  Future<Map<String, dynamic>> sacar(int id, double valor) {
    return _api.postJson(
      _baseDaConta(id),
      '/contas/$id/sacar',
      body: {'valor': valor},
    );
  }

  /// Transferência: a chamada vai na agência da conta de origem.
  Future<Map<String, dynamic>> transferir({
    required int idOrigem,
    required int idDestino,
    required double valor,
  }) {
    return _api.postJson(
      _baseDaConta(idOrigem),
      '/transferencias',
      body: {
        'idOrigem': idOrigem,
        'idDestino': idDestino,
        'valor': valor,
      },
    );
  }
}
