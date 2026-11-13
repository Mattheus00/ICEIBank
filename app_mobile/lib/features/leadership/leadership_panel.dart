import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../data/leadership_repository.dart';

class LeadershipPanel extends StatefulWidget {
  const LeadershipPanel({
    super.key,
    required this.repository,
    this.agenciaPreferida = 0,
  });

  final LeadershipRepository repository;
  final int agenciaPreferida;

  @override
  State<LeadershipPanel> createState() => _LeadershipPanelState();
}

class _LeadershipPanelState extends State<LeadershipPanel>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _emVoo = false;
  LeadershipSnapshot? _snap;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciarPolling();
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
      _iniciarPolling();
      _consultar();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _iniciarPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.intervaloLideranca, (_) => _consultar());
  }

  Future<void> _consultar() async {
    if (_emVoo || !mounted) return;
    _emVoo = true;
    try {
      final snap =
          await widget.repository.consultar(preferida: widget.agenciaPreferida);
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _erro = snap.aviso;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString());
    } finally {
      _emVoo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Painel de liderança',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              snap == null
                  ? 'Consultando...'
                  : 'Líder atual: ${snap.liderAtual ?? "desconhecido"} (${snap.estado})',
            ),
            if (snap != null)
              Text(
                'Observado via agência ${snap.consultadoEmAgencia} às '
                '${_hora(snap.atualizadoEm)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            if (_erro != null) ...[
              const SizedBox(height: 6),
              Text(_erro!, style: const TextStyle(color: Colors.deepOrange)),
            ],
            const SizedBox(height: 4),
            const Text(
              'A líder é informativa. Operações da conta vão para a agência do id % 3.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _hora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
