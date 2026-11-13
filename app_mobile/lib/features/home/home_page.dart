import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../data/bank_repository.dart';
import '../../data/leadership_repository.dart';
import '../leadership/leadership_panel.dart';
import '../login/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.api,
    required this.bank,
    required this.agenciaPreferida,
  });

  final SessionStore session;
  final ApiClient api;
  final BankRepository bank;
  final int agenciaPreferida;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _idConta = TextEditingController(text: '12');
  final _nome = TextEditingController(text: 'Fiona');
  final _valor = TextEditingController(text: '10');
  final _idDestino = TextEditingController(text: '1');

  String? _resultado;
  String? _erro;
  bool _busy = false;

  late final LeadershipRepository _leadership =
      LeadershipRepository(widget.api);

  @override
  void dispose() {
    _idConta.dispose();
    _nome.dispose();
    _valor.dispose();
    _idDestino.dispose();
    super.dispose();
  }

  int get _contaId => int.tryParse(_idConta.text.trim()) ?? -1;
  double get _valorNum =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _rodar(Future<void> Function() acao) async {
    setState(() {
      _busy = true;
      _erro = null;
      _resultado = null;
    });
    try {
      await acao();
    } on ApiException catch (e) {
      setState(() {
        _erro = e.statusCode == null
            ? e.message
            : '[${e.statusCode}] ${e.message}';
      });
      if (e.statusCode == 401 && mounted) {
        await widget.session.limpar();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginPage(
              session: widget.session,
              api: widget.api,
              bank: widget.bank,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _erro = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agenciaConta =
        _contaId >= 0 ? AppConfig.agenciaDaConta(_contaId) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ICEIBank'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await widget.session.limpar();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LoginPage(
                    session: widget.session,
                    api: widget.api,
                    bank: widget.bank,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LeadershipPanel(
            repository: _leadership,
            agenciaPreferida: widget.agenciaPreferida,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _idConta,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ID da conta',
              helperText: agenciaConta == null
                  ? null
                  : 'Agência responsável: $agenciaConta (não confundir com a líder)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nome,
            decoration: const InputDecoration(
              labelText: 'Nome (criar conta)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idDestino,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ID destino (transferência)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          final r = await widget.bank.criarConta(
                            id: _contaId,
                            nome: _nome.text.trim(),
                            saldoInicial: _valorNum,
                          );
                          setState(() => _resultado = r.toString());
                        }),
                child: const Text('Criar'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          final r = await widget.bank.consultar(_contaId);
                          setState(() => _resultado = r.toString());
                        }),
                child: const Text('Saldo'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          final r =
                              await widget.bank.depositar(_contaId, _valorNum);
                          setState(() => _resultado = r.toString());
                        }),
                child: const Text('Depositar'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          final r =
                              await widget.bank.sacar(_contaId, _valorNum);
                          setState(() => _resultado = r.toString());
                        }),
                child: const Text('Sacar'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          final destino =
                              int.tryParse(_idDestino.text.trim()) ?? -1;
                          final r = await widget.bank.transferir(
                            idOrigem: _contaId,
                            idDestino: destino,
                            valor: _valorNum,
                          );
                          final msg = r['mensagem']?.toString() ?? r.toString();
                          setState(() {
                            _resultado =
                                '$msg\n(Se for remota: enviada para processamento, crédito ainda assíncrono.)';
                          });
                        }),
                child: const Text('Transferir'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_erro != null)
            Text(_erro!, style: const TextStyle(color: Colors.red)),
          if (_resultado != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF3F3F3),
              child: Text(_resultado!),
            ),
        ],
      ),
    );
  }
}
