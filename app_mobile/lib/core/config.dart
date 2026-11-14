import 'package:flutter/foundation.dart';

/// Endereços das 3 agências.
/// No emulador Android, o host da máquina é 10.0.2.2 (não localhost).
/// No Windows/Chrome do laboratório, usa localhost.
class AppConfig {
  static String get _host {
    // Web (Chrome) e desktop usam localhost.
    // Só o emulador Android precisa de 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static List<AgenciaEndpoint> get agencias => [
        AgenciaEndpoint(id: 0, baseUrl: 'http://$_host:4000'),
        AgenciaEndpoint(id: 1, baseUrl: 'http://$_host:4001'),
        AgenciaEndpoint(id: 2, baseUrl: 'http://$_host:4002'),
      ];

  static AgenciaEndpoint agenciaPorId(int id) =>
      agencias.firstWhere((a) => a.id == id);

  static int agenciaDaConta(int idConta) => idConta % 3;

  static const Duration timeoutHttp = Duration(seconds: 10);
  static const Duration intervaloLideranca = Duration(seconds: 3);
}

class AgenciaEndpoint {
  final int id;
  final String baseUrl;

  const AgenciaEndpoint({required this.id, required this.baseUrl});
}
