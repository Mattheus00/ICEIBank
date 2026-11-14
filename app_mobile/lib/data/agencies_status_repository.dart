import '../core/api_client.dart';
import '../core/config.dart';

class AgenciaStatus {
  AgenciaStatus({
    required this.id,
    required this.responde,
    required this.consultadoEm,
    this.erro,
    this.ehLider = false,
  });

  final int id;
  final bool responde;
  final DateTime consultadoEm;
  final String? erro;
  final bool ehLider;
}

class AgenciesStatusRepository {
  AgenciesStatusRepository(this._api);

  final ApiClient _api;

  Future<List<AgenciaStatus>> consultar({int? liderAtual}) async {
    final agora = DateTime.now();
    final resultados = <AgenciaStatus>[];

    for (final ag in AppConfig.agencias) {
      try {
        await _api.getJson(ag.baseUrl, '/health', auth: false);
        resultados.add(
          AgenciaStatus(
            id: ag.id,
            responde: true,
            consultadoEm: agora,
            ehLider: liderAtual != null && liderAtual == ag.id,
          ),
        );
      } catch (e) {
        resultados.add(
          AgenciaStatus(
            id: ag.id,
            responde: false,
            consultadoEm: agora,
            erro: e.toString(),
            ehLider: liderAtual != null && liderAtual == ag.id,
          ),
        );
      }
    }
    return resultados;
  }
}
