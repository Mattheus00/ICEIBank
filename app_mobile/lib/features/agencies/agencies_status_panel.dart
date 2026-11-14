import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/app_theme.dart';
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
      final lider = await widget.leadershipRepository.consultar(preferida: 0);
      final lista = await widget.statusRepository.consultar(
        liderAtual: lider.liderAtual,
      );
      if (!mounted) return;
      setState(() => _status = lista);
    } catch (_) {
      // mantém último estado
    } finally {
      _emVoo = false;
    }
  }

  @override
  Widget build(BuildContext context) => BankSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agências',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Disponibilidade observada pelo app',
          style: TextStyle(color: BankTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_status.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'Verificando conexão...',
              style: TextStyle(color: BankTheme.muted, fontSize: 13),
            ),
          )
        else ...[
          for (var i = 0; i < _status.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: BankTheme.canvas,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_status[i].id}',
                      style: const TextStyle(
                        color: BankTheme.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agência ${_status[i].id}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _status[i].ehLider
                              ? 'Líder observada'
                              : 'Agência participante',
                          style: const TextStyle(
                            color: BankTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: _status[i].responde
                        ? BankTheme.green
                        : BankTheme.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _status[i].responde ? 'Disponível' : 'Sem resposta',
                    style: TextStyle(
                      fontSize: 12,
                      color: _status[i].responde
                          ? BankTheme.green
                          : BankTheme.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_status.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Última consulta às ${BankTheme.time(_status.first.consultadoEm)}',
            style: const TextStyle(color: BankTheme.muted, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}
