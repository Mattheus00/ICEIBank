import '../core/api_client.dart';
import '../core/config.dart';

class LeadershipSnapshot {
  final int? liderAtual;
  final String estado;
  final int consultadoEmAgencia;
  final DateTime atualizadoEm;
  final String? aviso;

  LeadershipSnapshot({
    required this.liderAtual,
    required this.estado,
    required this.consultadoEmAgencia,
    required this.atualizadoEm,
    this.aviso,
  });
}

class LeadershipRepository {
  LeadershipRepository(this._api);

  final ApiClient _api;

  /// Tenta a agência preferida e, se falhar, as demais.
  /// Não inventa votação no cliente: devolve a última observação válida.
  Future<LeadershipSnapshot> consultar({int preferida = 0}) async {
    final ordem = <int>[
      preferida,
      ...AppConfig.agencias.map((a) => a.id).where((id) => id != preferida),
    ];

    Object? ultimoErro;
    for (final id in ordem) {
      final base = AppConfig.agenciaPorId(id).baseUrl;
      try {
        final resp = await _api.getJson(base, '/bully/lider', auth: false);
        final lider = resp['liderAtual'];
        return LeadershipSnapshot(
          liderAtual: lider is int ? lider : int.tryParse('$lider'),
          estado: resp['estado']?.toString() ?? 'DESCONHECIDO',
          consultadoEmAgencia: id,
          atualizadoEm: DateTime.now(),
          aviso: id == preferida
              ? null
              : 'Agência $preferida falhou; observação via agência $id.',
        );
      } catch (e) {
        ultimoErro = e;
      }
    }

    return LeadershipSnapshot(
      liderAtual: null,
      estado: 'DESCONHECIDO',
      consultadoEmAgencia: preferida,
      atualizadoEm: DateTime.now(),
      aviso: 'Nenhuma agência respondeu. Último erro: $ultimoErro',
    );
  }
}
