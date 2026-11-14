import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../data/agencies_status_repository.dart';
import '../../data/bank_repository.dart';
import '../../data/leadership_repository.dart';
import '../../data/offline_models.dart';
import '../../data/offline_store.dart';
import '../../data/sync_service.dart';
import '../agencies/agencies_status_panel.dart';
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _idConta = TextEditingController(text: '12');
  final _nome = TextEditingController(text: 'Fiona');
  final _valor = TextEditingController(text: '10');
  final _idDestino = TextEditingController(text: '1');

  String? _resultado;
  String? _erro;
  bool _busy = false;
  ContaCache? _cache;
  List<Pendencia> _pendencias = [];
  double? _provisorio;

  late final LeadershipRepository _leadership =
      LeadershipRepository(widget.api);
  late final AgenciesStatusRepository _agenciesStatus =
      AgenciesStatusRepository(widget.api);
  late final SyncService _sync = SyncService(
    session: widget.session,
    api: widget.api,
    bank: widget.bank,
    store: OfflineStore(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recarregarOffline();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idConta.dispose();
    _nome.dispose();
    _valor.dispose();
    _idDestino.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tentarSincronizarAutomatico();
    }
  }

  int get _contaId => int.tryParse(_idConta.text.trim()) ?? -1;
  double get _valorNum =>
      double.tryParse(_valor.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _recarregarOffline() async {
    if (_contaId < 0) return;
    final cache = await _sync.cacheDaConta(_contaId);
    final pend = await _sync.pendenciasAbertas();
    final prov = await _sync.saldoProvisorio(_contaId);
    if (!mounted) return;
    setState(() {
      _cache = cache;
      _pendencias = pend.where((e) => e.contaId == _contaId).toList();
      _provisorio = cache == null ? null : prov;
    });
  }

  Future<void> _tentarSincronizarAutomatico() async {
    try {
      final msg = await _sync.sincronizarAgora();
      if (!mounted) return;
      setState(() => _resultado = msg);
      await _recarregarOffline();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() => _erro =
            'Sessão expirada. Pendências preservadas — faça login de novo.');
      }
    } catch (_) {
      // silencioso no auto
    }
  }

  Future<void> _rodar(Future<void> Function() acao) async {
    setState(() {
      _busy = true;
      _erro = null;
      _resultado = null;
    });
    try {
      await acao();
      await _recarregarOffline();
    } on ApiException catch (e) {
      setState(() {
        _erro = e.statusCode == null
            ? e.message
            : '[${e.statusCode}] ${e.message}';
      });
      if (e.statusCode == 401 && mounted) {
        // Não apaga a fila.
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

  Future<void> _depositarOuEnfileirar() async {
    try {
      final r = await widget.bank.depositar(_contaId, _valorNum);
      await _sync.atualizarCacheDoServidor(_contaId);
      setState(() => _resultado = 'Depósito online: $r');
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400 || e.statusCode == 404) {
        rethrow;
      }
      final p = await _sync.enfileirarOffline(
        contaId: _contaId,
        tipo: 'DEPOSITO',
        valor: _valorNum,
      );
      setState(() => _resultado =
          'Sem rede. Depósito ${p.id} enfileirado. Saldo provisório atualizado.');
    }
  }

  Future<void> _sacarOuEnfileirar() async {
    try {
      final r = await widget.bank.sacar(_contaId, _valorNum);
      await _sync.atualizarCacheDoServidor(_contaId);
      setState(() => _resultado = 'Saque online: $r');
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 400 || e.statusCode == 404) {
        rethrow;
      }
      final p = await _sync.enfileirarOffline(
        contaId: _contaId,
        tipo: 'SAQUE',
        valor: _valorNum,
      );
      setState(() => _resultado =
          'Sem rede. Saque ${p.id} enfileirado. Saldo provisório atualizado.');
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
            tooltip: 'Sincronizar agora',
            onPressed: _busy
                ? null
                : () => _rodar(() async {
                      final msg = await _sync.sincronizarAgora();
                      setState(() => _resultado = msg);
                    }),
            icon: const Icon(Icons.sync),
          ),
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
          const SizedBox(height: 12),
          AgenciesStatusPanel(
            statusRepository: _agenciesStatus,
            leadershipRepository: _leadership,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cache / offline',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _rodar(() async {
                                  await _sync.limparPendenciasDaConta(_contaId);
                                  setState(() => _resultado =
                                      'Pendências da conta $_contaId limpas.');
                                }),
                        child: const Text('Limpar fila'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _cache == null
                        ? 'Sem saldo confirmado em cache para esta conta.'
                        : 'Confirmado: ${_cache!.saldoConfirmado.toStringAsFixed(2)}'
                            '  |  Provisório: ${(_provisorio ?? _cache!.saldoConfirmado).toStringAsFixed(2)}'
                            '\nVetor: ${_cache!.vetorConfirmado}'
                            '\nLido em: ${_cache!.lidoEm}',
                  ),
                  if (_pendencias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Pendências:'),
                    ..._pendencias.map(
                      (p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${p.tipo} ${p.valor} (${p.estado.name})',
                        ),
                        subtitle: Text(
                          '${p.id}${p.mensagemErro == null ? '' : ' — ${p.mensagemErro}'}',
                        ),
                        trailing: (p.estado == EstadoPendencia.conflito ||
                                p.estado == EstadoPendencia.falha ||
                                p.estado == EstadoPendencia.pendente)
                            ? Wrap(
                                children: [
                                  TextButton(
                                    onPressed: () => _rodar(() async {
                                      await _sync.descartarConflito(p.id);
                                      setState(() =>
                                          _resultado = 'Pendência descartada.');
                                    }),
                                    child: const Text('Descartar'),
                                  ),
                                  if (p.estado == EstadoPendencia.conflito)
                                    TextButton(
                                      onPressed: () => _rodar(() async {
                                        await _sync
                                            .reenfileirarAposConflito(p.id);
                                        final msg =
                                            await _sync.sincronizarAgora();
                                        setState(() => _resultado = msg);
                                      }),
                                      child: const Text('Nova tentativa'),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            onChanged: (_) {
              setState(() {});
              _recarregarOffline();
            },
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
              labelText: 'ID destino (transferência — só online)',
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
                          await _sync.atualizarCacheDoServidor(_contaId);
                          setState(() => _resultado = r.toString());
                        }),
                child: const Text('Criar'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(() async {
                          try {
                            final cache =
                                await _sync.atualizarCacheDoServidor(_contaId);
                            setState(() => _resultado =
                                'Saldo online/confirmado: ${cache.saldoConfirmado}');
                          } on ApiException catch (e) {
                            if (e.statusCode == 401) rethrow;
                            if (e.statusCode == 404) {
                              throw ApiException(
                                'Conta não existe nesta agência (reinício apaga a memória). '
                                'Clique em Criar e depois em Saldo.',
                                statusCode: 404,
                              );
                            }
                            final cache = await _sync.cacheDaConta(_contaId);
                            if (cache == null) {
                              throw ApiException(
                                'Sem rede e sem cache. Suba as agências, '
                                'consulte o Saldo uma vez, depois desligue-as.',
                              );
                            }
                            setState(() => _resultado =
                                'Sem rede. Cache de ${cache.lidoEm}: saldo ${cache.saldoConfirmado}');
                          }
                        }),
                child: const Text('Saldo'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _rodar(_depositarOuEnfileirar),
                child: const Text('Depositar'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _rodar(_sacarOuEnfileirar),
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
                                '$msg\n(Transferência continua só online.)';
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
