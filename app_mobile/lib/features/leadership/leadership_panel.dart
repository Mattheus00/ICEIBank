import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/app_theme.dart';
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
      final snap = await widget.repository.consultar(
        preferida: widget.agenciaPreferida,
      );
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
    final known = snap?.liderAtual != null;
    return BankSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 20, color: BankTheme.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Liderança da rede',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  known ? 'Agência ${snap!.liderAtual}' : 'Em verificação',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
              ),
              Icon(
                known ? Icons.verified_outlined : Icons.hourglass_top_rounded,
                color: known ? BankTheme.green : BankTheme.amber,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 10),
          BankBadge(
            known ? 'Líder atual' : 'Aguardando resposta',
            color: known ? BankTheme.green : BankTheme.amber,
            background: known ? BankTheme.pale : const Color(0xFFFFF1D9),
          ),
          const SizedBox(height: 22),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            snap == null
                ? 'Consultando as agências...'
                : 'Consulta às ${BankTheme.time(snap.atualizadoEm)} · Agência ${snap.consultadoEmAgencia}',
            style: const TextStyle(fontSize: 12, color: BankTheme.muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'Atualiza automaticamente. A liderança não altera a agência da sua conta.',
            style: TextStyle(fontSize: 12, color: BankTheme.muted, height: 1.6),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 10),
            Text(
              known
                  ? 'Observação obtida por outra agência.'
                  : 'Não foi possível confirmar a liderança.',
              style: const TextStyle(
                color: BankTheme.amber,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
