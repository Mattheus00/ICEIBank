import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../data/agencies_status_repository.dart';
import '../../data/leadership_repository.dart';

/// Extra Sprint 3: indicador das 3 agências via /health.
/// "Não responde" é a observação do cliente, não prova que o processo morreu.
class AgenciesStatusPanel extends StatefulWidget {
  const AgenciesStatusPanel({
    super.key,
    required this.statusRepository,
    required this.leadershipRepository,
  });

  final AgenciesStatusRepository statusRepository;
  final LeadershipRepository leadershipRepository;

  @override
  State<AgenciesStatusPanel> createState() => _AgenciesStatusPanelState();
}

class _AgenciesStatusPanelState extends State<AgenciesStatusPanel>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _emVoo = false;
  List<AgenciaStatus> _status = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
    _consultar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _iniciar();
      _consultar();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _iniciar() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.intervaloLideranca, (_) => _consultar());
  }

  Future<void> _consultar() async {
    if (_emVoo || !mounted) return;
    _emVoo = true;
    try {
      final lider =
          await widget.leadershipRepository.consultar(preferida: 0);
      final lista = await widget.statusRepository
          .consultar(liderAtual: lider.liderAtual);
      if (!mounted) return;
      setState(() => _status = lista);
    } catch (_) {
      // mantém último estado
    } finally {
      _emVoo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agências ativas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consulta /health. "Não responde" é só a observação deste app.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            if (_status.isEmpty)
              const Text('Consultando...')
            else
              ..._status.map((s) {
                final hora =
                    '${s.consultadoEm.hour.toString().padLeft(2, '0')}:'
                    '${s.consultadoEm.minute.toString().padLeft(2, '0')}:'
                    '${s.consultadoEm.second.toString().padLeft(2, '0')}';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    s.responde ? Icons.check_circle : Icons.cancel,
                    color: s.responde ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    'Agência ${s.id}'
                    '${s.ehLider ? '  ★ líder' : ''}',
                  ),
                  subtitle: Text(
                    s.responde
                        ? 'Responde · última consulta $hora'
                        : 'Não responde · última consulta $hora',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
